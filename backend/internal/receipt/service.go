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

// BoundingBox represents the normalized coordinates (0.0–1.0) of an item on the receipt image.
type BoundingBox struct {
	X      float64 `json:"x"`
	Y      float64 `json:"y"`
	Width  float64 `json:"width"`
	Height float64 `json:"height"`
}

// ParsedItem represents a single line item from a receipt.
type ParsedItem struct {
	Name        string       `json:"name"`
	Price       float64      `json:"price"`
	Quantity    int          `json:"quantity,omitempty"`
	BoundingBox *BoundingBox `json:"bounding_box,omitempty"`
	RawOcrName  string       `json:"raw_ocr_name,omitempty"`
}

// ParsedReceipt represents the structured data extracted from a receipt image.
type ParsedReceipt struct {
	Vendor   string       `json:"vendor,omitempty"`
	Items    []ParsedItem `json:"items"`
	Subtotal *float64     `json:"subtotal,omitempty"`
	Tax      *float64     `json:"tax,omitempty"`
	Tip      *float64     `json:"tip,omitempty"`
	Total    *float64     `json:"total,omitempty"`
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

const receiptPrompt = `You are a receipt-parsing expert. Extract EVERY piece of structured data from this receipt image with extreme precision.

Return ONLY valid JSON — no explanation, no markdown, no text outside the JSON object.

Schema (follow EXACTLY):
{
  "vendor": "Store Name",
  "items": [
    {"name": "Item Name", "price": 5.98, "quantity": 2, "bounding_box": {"x": 0.05, "y": 0.23, "width": 0.90, "height": 0.04}}
  ],
  "subtotal": 10.00,
  "tax": 0.80,
  "tip": 0.00,
  "total": 10.80
}

CRITICAL RULES — read carefully:

1. QUANTITIES: Receipts show quantity in many formats. You MUST detect all of them:
   - "2 @ 2.99" or "2 x 2.99" or "2x2.99" → quantity: 2, price: 5.98 (total line price)
   - "QTY: 4" or "QTY 4" on a separate line above/below the item
   - A number before the item name like "3 Bananas  2.67" → quantity: 3
   - "ORANGE JUICE  4.49" followed by "4 @ 4.49 = 17.96" → quantity: 4, price: 17.96
   - If the line price is clearly quantity × unit price, set quantity and price = line total
   - The "price" field must ALWAYS be the total price paid for that line (quantity × unit price), NOT the per-unit price

2. PRICES: Every price must be a JSON number, never a string. Negative prices are valid (discounts, coupons).

3. ITEM NAMES: Convert ALL-CAPS or abbreviated text to readable Title Case.
   - "FL ORNG JUICE PULP FR" → "Florida Orange Juice Pulp Free"
   - "GV 2% MILK GAL" → "Great Value 2% Milk Gallon"
   - "BNLS SKNLS CHKN BRST" → "Boneless Skinless Chicken Breast"
   Use your best judgment to expand common grocery/retail abbreviations.

4. INCLUDE: Every printed line item — products, weighted items, discounts, coupons, bottle deposits.

5. EXCLUDE: Payment methods, card numbers, change due, cashier info, barcodes, loyalty card numbers, transaction IDs.

6. TOTALS: Extract subtotal, tax, tip, and total if visible. Omit any you cannot find. The "items" array is always required even if empty.

7. VALIDATION: Before responding, verify that your item prices sum close to the subtotal or total. If they don't, re-examine the receipt for missed quantities or items.

8. BOUNDING BOXES: For each item, estimate its bounding box on the receipt image. Coordinates are normalized fractions of image dimensions (0.0 to 1.0). "x" and "y" are the top-left corner. "width" and "height" are the fraction of the image the text line spans. If you cannot confidently determine the bounding box for an item, omit the "bounding_box" field for that item.

Think step by step: first identify the vendor, then read every line item carefully checking for quantity indicators, estimate each item's position on the receipt, then extract totals.`

const receiptTextPrompt = `You are a receipt-parsing expert. You will receive raw OCR text extracted from a receipt image. Extract EVERY piece of structured data with extreme precision.

Return ONLY valid JSON — no explanation, no markdown, no text outside the JSON object.

Schema (follow EXACTLY):
{
  "vendor": "Store Name",
  "items": [
    {"name": "Item Name", "price": 5.98, "quantity": 2, "raw_ocr_name": "ITM NM"}
  ],
  "subtotal": 10.00,
  "tax": 0.80,
  "tip": 0.00,
  "total": 10.80
}

CRITICAL RULES — read carefully:

1. QUANTITIES: Receipts show quantity in many formats. You MUST detect all of them:
   - "2 @ 2.99" or "2 x 2.99" or "2x2.99" → quantity: 2, price: 5.98 (total line price)
   - "QTY: 4" or "QTY 4" on a separate line above/below the item
   - A number before the item name like "3 Bananas  2.67" → quantity: 3
   - "ORANGE JUICE  4.49" followed by "4 @ 4.49 = 17.96" → quantity: 4, price: 17.96
   - If the line price is clearly quantity × unit price, set quantity and price = line total
   - The "price" field must ALWAYS be the total price paid for that line (quantity × unit price), NOT the per-unit price

2. PRICES: Every price must be a JSON number, never a string. Negative prices are valid (discounts, coupons).

3. ITEM NAMES: Convert ALL-CAPS or abbreviated text to readable Title Case.
   - "FL ORNG JUICE PULP FR" → "Florida Orange Juice Pulp Free"
   - "GV 2% MILK GAL" → "Great Value 2% Milk Gallon"
   - "BNLS SKNLS CHKN BRST" → "Boneless Skinless Chicken Breast"
   Use your best judgment to expand common grocery/retail abbreviations.

4. INCLUDE: Every printed line item — products, weighted items, discounts, coupons, bottle deposits.

5. EXCLUDE: Payment methods, card numbers, change due, cashier info, barcodes, loyalty card numbers, transaction IDs.

6. TOTALS: Extract subtotal, tax, tip, and total if visible. Omit any you cannot find. The "items" array is always required even if empty.

7. VALIDATION: Before responding, verify that your item prices sum close to the subtotal or total. If they don't, re-examine the receipt for missed quantities or items.

8. RAW OCR NAME: For each item, include a "raw_ocr_name" field containing the exact OCR text that corresponds to that item's name (before your Title Case cleanup). This must be the verbatim text from the OCR input, not your cleaned-up version.

Think step by step: first identify the vendor, then read every line item carefully checking for quantity indicators, then extract totals.`

const anthropicEndpoint = "https://api.anthropic.com/v1/messages"
const anthropicModel = "claude-sonnet-4-5-20250929"
const anthropicVersion = "2023-06-01"

// messagesRequest is the Anthropic Messages API request body.
type messagesRequest struct {
	Model     string           `json:"model"`
	MaxTokens int              `json:"max_tokens"`
	Messages  []anthropicMsg   `json:"messages"`
}

type anthropicMsg struct {
	Role    string              `json:"role"`
	Content []anthropicContent  `json:"content"`
}

type anthropicContent struct {
	Type      string          `json:"type"`
	Text      string          `json:"text,omitempty"`
	Source    *imageSource    `json:"source,omitempty"`
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

	return s.callAnthropic(reqBody)
}

// ParseText sends raw OCR text to Anthropic and returns structured receipt data.
func (s *Service) ParseText(ocrText string) (*ParsedReceipt, error) {
	ocrText = strings.TrimSpace(ocrText)
	if ocrText == "" {
		return nil, &ParseError{Code: ErrInvalidRequest, Message: "OCR text is empty"}
	}

	reqBody := messagesRequest{
		Model:     anthropicModel,
		MaxTokens: 4096,
		Messages: []anthropicMsg{
			{
				Role: "user",
				Content: []anthropicContent{
					{
						Type: "text",
						Text: receiptTextPrompt + "\n\n--- OCR TEXT ---\n" + ocrText,
					},
				},
			},
		},
	}

	return s.callAnthropic(reqBody)
}

// callAnthropic sends a messagesRequest to the Anthropic API and returns the parsed receipt.
func (s *Service) callAnthropic(reqBody messagesRequest) (*ParsedReceipt, error) {
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
		return nil, classifyAPIError(resp.StatusCode, respBody)
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

// classifyAPIError maps an Anthropic HTTP error status to a structured ParseError.
func classifyAPIError(statusCode int, body []byte) *ParseError {
	var errResp messagesResponse
	json.Unmarshal(body, &errResp)
	detail := ""
	if errResp.Error != nil {
		detail = errResp.Error.Message
	}

	log.Printf("[receipt] Anthropic returned status %d", statusCode)

	switch statusCode {
	case http.StatusUnauthorized: // 401
		return &ParseError{Code: ErrAuthFailed, Message: "API authentication failed: " + detail}
	case http.StatusForbidden: // 403
		return &ParseError{Code: ErrAuthFailed, Message: "API key lacks permission: " + detail}
	case http.StatusTooManyRequests: // 429
		return &ParseError{Code: ErrRateLimited, Message: "Rate limited: " + detail}
	case http.StatusRequestEntityTooLarge: // 413
		return &ParseError{Code: ErrImageTooLarge, Message: "Image too large for processing"}
	case http.StatusBadRequest: // 400
		return &ParseError{Code: ErrInvalidRequest, Message: "Invalid request: " + detail}
	case 529: // Anthropic overloaded
		return &ParseError{Code: ErrOverloaded, Message: "AI service is temporarily overloaded"}
	default:
		if statusCode >= 500 {
			return &ParseError{Code: ErrProviderDown, Message: "AI service error: " + detail}
		}
		return &ParseError{Code: ErrInvalidRequest, Message: fmt.Sprintf("Unexpected status %d: %s", statusCode, detail)}
	}
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
