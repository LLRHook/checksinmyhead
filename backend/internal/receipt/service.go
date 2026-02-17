package receipt

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
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
	Vendor   string       `json:"vendor,omitempty"`
	Items    []ParsedItem `json:"items"`
	Subtotal *float64     `json:"subtotal,omitempty"`
	Tax      *float64     `json:"tax,omitempty"`
	Tip      *float64     `json:"tip,omitempty"`
	Total    *float64     `json:"total,omitempty"`
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
    {"name": "Item Name", "price": 5.98, "quantity": 2}
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
		fmt.Printf("[receipt] Anthropic returned status %d: %s\n", resp.StatusCode, truncate(string(respBody), 500))
		if resp.StatusCode == http.StatusTooManyRequests {
			return nil, fmt.Errorf("rate_limited")
		}
		return nil, fmt.Errorf("Anthropic API returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var msgResp messagesResponse
	if err := json.Unmarshal(respBody, &msgResp); err != nil {
		return nil, fmt.Errorf("failed to parse Anthropic response: %w", err)
	}

	if msgResp.Error != nil {
		return nil, fmt.Errorf("Anthropic error: %s", msgResp.Error.Message)
	}

	if len(msgResp.Content) == 0 {
		return nil, fmt.Errorf("Anthropic returned empty response")
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
