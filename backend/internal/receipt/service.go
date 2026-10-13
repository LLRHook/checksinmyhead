package receipt

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

// ParsedItem represents a single line item from a receipt.
type ParsedItem struct {
	Name     string  `json:"name"`
	Price    float64 `json:"price"`
	Quantity int     `json:"quantity,omitempty"`
}

// ParsedReceipt represents the structured data extracted from a receipt image.
type ParsedReceipt struct {
	Vendor             string       `json:"vendor,omitempty"`
	CurrencyCode       *string      `json:"currency_code,omitempty"`
	CurrencySymbol     *string      `json:"currency_symbol,omitempty"`
	CurrencyConfidence *float64     `json:"currency_confidence,omitempty"`
	Items              []ParsedItem `json:"items"`
	Subtotal           *float64     `json:"subtotal,omitempty"`
	Tax                *float64     `json:"tax,omitempty"`
	Tip                *float64     `json:"tip,omitempty"`
	Total              *float64     `json:"total,omitempty"`
}

// ParseErrorCode identifies specific receipt parsing failure reasons.
type ParseErrorCode string

const (
	ErrRateLimited    ParseErrorCode = "rate_limited"
	ErrAuthFailed     ParseErrorCode = "auth_failed"
	ErrInvalidRequest ParseErrorCode = "invalid_request"
	ErrImageTooLarge  ParseErrorCode = "image_too_large"
	ErrOverloaded     ParseErrorCode = "overloaded"
	ErrProviderDown   ParseErrorCode = "provider_down"
	ErrBadResponse    ParseErrorCode = "bad_response"
)

// ParseError is a structured error from receipt parsing with a machine-readable code.
type ParseError struct {
	Code    ParseErrorCode
	Message string
}

func (e *ParseError) Error() string {
	return e.Message
}

// Service handles receipt parsing via the Anthropic Messages API.
type Service struct {
	apiKey     string
	httpClient *http.Client
}

// NewService creates a new receipt parsing service.
// Reads ANTHROPIC_API_KEY from environment.
func NewService() (*Service, error) {
	apiKey := os.Getenv("ANTHROPIC_API_KEY")
	if apiKey == "" {
		return nil, fmt.Errorf("ANTHROPIC_API_KEY environment variable is required")
	}
	return &Service{
		apiKey: apiKey,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}, nil
}

const receiptPrompt = `Extract receipt data from the supplied image for a bill-splitting app. The image is the only source of truth. Be literal and conservative: do not invent, infer, or silently correct details that are not clearly visible.

Read the receipt from top to bottom. Distinguish purchased items from headings, subtotals, taxes, payment details, and other transaction metadata. Preserve each purchased item separately, including repeated items.

Some receipts wrap one item across multiple lines. When an unpriced, indented line immediately follows a priced item, treat it as part of that item's description (for example, "2 Well Gin" followed by "Diet Coke" and one "$12.00" amount is one item, not separate Gin and Diet Coke items). Attach continuation text to the preceding item and use its price only once. Start another item only when a new item row is indicated by its own quantity/description and price. Never create a separately priced item from an unpriced modifier or mixer.

For each item:
- Use the printed description. Correct only obvious OCR or casing noise; do not expand abbreviations or guess a brand or product variant.
- Set price to the signed extended amount charged for that line, not the unit price. If quantity and unit price are shown with no extended amount, multiply them. For weighed goods, use the printed charged amount and set quantity to 1.
- Set quantity to the printed count, including counts shown as QTY, N x price, or N @ price. Use 1 when no count is shown. Never treat a weight as a piece count.
- Include a printed discount, coupon, refund, or deposit as its own line only when it is a distinct charged/credited line. Represent credits with a negative price. Do not duplicate a discount already included in an item's printed amount.
- Do not include subtotal, tax, tip, total, tender, change, card/account details, loyalty identifiers, cashier details, barcodes, or transaction IDs as items.

For vendor, currency, and totals, use only clearly visible evidence. Read printed values and clearly legible handwritten values in labeled fields such as Tip and Total. Return null when a value is absent or unreadable. Do not calculate a missing tip from the total or a missing total from other values. Return the currency as an ISO 4217 code; do not infer a currency from an ambiguous symbol alone. Set currency_confidence between 0 and 1 to reflect the evidence.

Copy subtotal, tax, tip, and total as shown; do not calculate missing values or alter them to make the item sum match. Use the amounts as shown, including negative values where printed. If the receipt is not readable enough to identify any items, return an empty items array rather than fabricating entries.

Return only the schema-constrained receipt object. Do not include analysis or explanation.`

const anthropicEndpoint = "https://api.anthropic.com/v1/messages"

const anthropicModel = "claude-sonnet-5-5"
const anthropicVersion = "2023-06-01"

var receiptOutputSchema = map[string]any{
	"type": "object",
	"properties": map[string]any{
		"vendor":              map[string]any{"type": []string{"string", "null"}},
		"currency_code":       map[string]any{"type": []string{"string", "null"}},
		"currency_symbol":     map[string]any{"type": []string{"string", "null"}},
		"currency_confidence": map[string]any{"type": []string{"number", "null"}},
		"items": map[string]any{
			"type": "array",
			"items": map[string]any{
				"type": "object",
				"properties": map[string]any{
					"name":     map[string]any{"type": "string"},
					"price":    map[string]any{"type": "number"},
					"quantity": map[string]any{"type": "integer"},
				},
				"required":             []string{"name", "price", "quantity"},
				"additionalProperties": false,
			},
		},
		"subtotal": map[string]any{"type": []string{"number", "null"}},
		"tax":      map[string]any{"type": []string{"number", "null"}},
		"tip":      map[string]any{"type": []string{"number", "null"}},
		"total":    map[string]any{"type": []string{"number", "null"}},
	},
	"required": []string{
		"vendor", "currency_code", "currency_symbol", "currency_confidence",
		"items", "subtotal", "tax", "tip", "total",
	},
	"additionalProperties": false,
}

// messagesRequest is the Anthropic Messages API request body.
type messagesRequest struct {
	Model        string         `json:"model"`
	MaxTokens    int            `json:"max_tokens"`
	Messages     []anthropicMsg `json:"messages"`
	OutputConfig outputConfig   `json:"output_config"`
}

type outputConfig struct {
	Format outputFormat `json:"format"`
}

type outputFormat struct {
	Type   string         `json:"type"`
	Schema map[string]any `json:"schema"`
}

type anthropicMsg struct {
	Role    string             `json:"role"`
	Content []anthropicContent `json:"content"`
}

type anthropicContent struct {
	Type   string       `json:"type"`
	Text   string       `json:"text,omitempty"`
	Source *imageSource `json:"source,omitempty"`
}

type imageSource struct {
	Type      string `json:"type"`
	MediaType string `json:"media_type"`
	Data      string `json:"data"`
}

// messagesResponse is the Anthropic Messages API response body.
type messagesResponse struct {
	Content []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	} `json:"content"`
	Error *struct {
		Type    string `json:"type"`
		Message string `json:"message"`
	} `json:"error"`
}

// Parse sends a receipt image to Anthropic and returns structured receipt data.
func (s *Service) Parse(imageData []byte, mimeType string) (*ParsedReceipt, error) {
	b64Image := base64.StdEncoding.EncodeToString(imageData)

	reqBody := messagesRequest{
		Model:     anthropicModel,
		MaxTokens: 4096,
		OutputConfig: outputConfig{
			Format: outputFormat{Type: "json_schema", Schema: receiptOutputSchema},
		},
		Messages: []anthropicMsg{
			{
				Role: "user",
				Content: []anthropicContent{
					{
						Type: "image",
						Source: &imageSource{
							Type:      "base64",
							MediaType: mimeType,
							Data:      b64Image,
						},
					},
					{
						Type: "text",
						Text: receiptPrompt,
					},
				},
			},
		},
	}

	jsonBody, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequest("POST", anthropicEndpoint, bytes.NewReader(jsonBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", s.apiKey)
	req.Header.Set("anthropic-version", anthropicVersion)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("Anthropic API request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		log.Printf("[receipt] Anthropic returned status %d", resp.StatusCode)

		// Parse the error body for details
		var errResp messagesResponse
		json.Unmarshal(respBody, &errResp)
		detail := ""
		if errResp.Error != nil {
			detail = errResp.Error.Message
		}

		switch resp.StatusCode {
		case http.StatusUnauthorized: // 401
			return nil, &ParseError{Code: ErrAuthFailed, Message: "API authentication failed: " + detail}
		case http.StatusForbidden: // 403
			return nil, &ParseError{Code: ErrAuthFailed, Message: "API key lacks permission: " + detail}
		case http.StatusTooManyRequests: // 429
			return nil, &ParseError{Code: ErrRateLimited, Message: "Rate limited: " + detail}
		case http.StatusRequestEntityTooLarge: // 413
			return nil, &ParseError{Code: ErrImageTooLarge, Message: "Image too large for processing"}
		case http.StatusBadRequest: // 400
			return nil, &ParseError{Code: ErrInvalidRequest, Message: "Invalid request: " + detail}
		case 529: // Anthropic overloaded
			return nil, &ParseError{Code: ErrOverloaded, Message: "AI service is temporarily overloaded"}
		default:
			if resp.StatusCode >= 500 {
				return nil, &ParseError{Code: ErrProviderDown, Message: "AI service error: " + detail}
			}
			return nil, &ParseError{Code: ErrInvalidRequest, Message: fmt.Sprintf("Unexpected status %d: %s", resp.StatusCode, detail)}
		}
	}

	var msgResp messagesResponse
	if err := json.Unmarshal(respBody, &msgResp); err != nil {
		return nil, &ParseError{Code: ErrBadResponse, Message: "Failed to parse AI response"}
	}

	if msgResp.Error != nil {
		return nil, &ParseError{Code: ErrProviderDown, Message: "AI error: " + msgResp.Error.Message}
	}

	if len(msgResp.Content) == 0 {
		return nil, &ParseError{Code: ErrBadResponse, Message: "AI returned empty response"}
	}

	rawText := msgResp.Content[0].Text
	return parseResponseText(rawText)
}

// parseResponseText extracts JSON from the model's response text, which may
// include markdown code fences.
func parseResponseText(text string) (*ParsedReceipt, error) {
	cleaned := text

	// Strip markdown code fences if present
	if strings.Contains(cleaned, "```") {
		start := strings.Index(cleaned, "```")
		// Skip the opening fence line
		afterFence := cleaned[start+3:]
		if nl := strings.Index(afterFence, "\n"); nl >= 0 {
			afterFence = afterFence[nl+1:]
		}
		if end := strings.Index(afterFence, "```"); end >= 0 {
			cleaned = afterFence[:end]
		} else {
			cleaned = afterFence
		}
	}

	cleaned = strings.TrimSpace(cleaned)

	var receipt ParsedReceipt
	if err := json.Unmarshal([]byte(cleaned), &receipt); err != nil {
		return nil, fmt.Errorf("failed to parse receipt JSON: %w (raw: %s)", err, truncate(text, 200))
	}

	if receipt.Items == nil {
		receipt.Items = []ParsedItem{}
	}

	return &receipt, nil
}

func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}
