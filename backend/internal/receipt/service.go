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

// Service handles receipt parsing via the OpenRouter API.
type Service struct {
	apiKey     string
	endpoint   string
	httpClient *http.Client
}

// NewService creates a new receipt parsing service.
// Reads OPENROUTER_API_KEY from environment.
func NewService() (*Service, error) {
	apiKey := os.Getenv("OPENROUTER_API_KEY")
	if apiKey == "" {
		return nil, fmt.Errorf("OPENROUTER_API_KEY environment variable is required")
	}
	return &Service{
		apiKey:   apiKey,
		endpoint: "https://openrouter.ai/api/v1/chat/completions",
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}, nil
}

const receiptPrompt = `Parse this receipt image. Return ONLY valid JSON with this exact structure:
{
  "vendor": "store name",
  "items": [{"name": "item name", "price": 1.99, "quantity": 1}],
  "subtotal": 10.00,
  "tax": 0.80,
  "tip": 0.00,
  "total": 10.80
}
Rules:
- Every price must be a number (not string)
- Include ALL line items, even discounts (negative prices)
- If quantity > 1, include it; default is 1
- Omit fields you can't determine (except items, which is required)
- For item names: clean up ALL-CAPS text to Title Case
- Do NOT include payment info, card numbers, or non-item lines`

// chatRequest is the OpenAI-compatible request body for OpenRouter.
type chatRequest struct {
	Model    string        `json:"model"`
	Messages []chatMessage `json:"messages"`
}

type chatMessage struct {
	Role    string        `json:"role"`
	Content []contentPart `json:"content"`
}

type contentPart struct {
	Type     string    `json:"type"`
	Text     string    `json:"text,omitempty"`
	ImageURL *imageURL `json:"image_url,omitempty"`
}

type imageURL struct {
	URL string `json:"url"`
}

// chatResponse is the OpenAI-compatible response from OpenRouter.
type chatResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
	Error *struct {
		Message string `json:"message"`
		Code    int    `json:"code"`
	} `json:"error"`
}

// Parse sends a receipt image to OpenRouter and returns structured receipt data.
func (s *Service) Parse(imageData []byte, mimeType string) (*ParsedReceipt, error) {
	b64Image := base64.StdEncoding.EncodeToString(imageData)
	dataURL := fmt.Sprintf("data:%s;base64,%s", mimeType, b64Image)

	reqBody := chatRequest{
		Model: "openrouter/free",
		Messages: []chatMessage{
			{
				Role: "user",
				Content: []contentPart{
					{
						Type:     "image_url",
						ImageURL: &imageURL{URL: dataURL},
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

	req, err := http.NewRequest("POST", s.endpoint, bytes.NewReader(jsonBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+s.apiKey)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("OpenRouter API request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		fmt.Printf("[receipt] OpenRouter returned status %d: %s\n", resp.StatusCode, truncate(string(respBody), 500))
		if resp.StatusCode == http.StatusTooManyRequests {
			return nil, fmt.Errorf("rate_limited")
		}
		return nil, fmt.Errorf("OpenRouter API returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var chatResp chatResponse
	if err := json.Unmarshal(respBody, &chatResp); err != nil {
		return nil, fmt.Errorf("failed to parse OpenRouter response: %w", err)
	}

	if chatResp.Error != nil {
		return nil, fmt.Errorf("OpenRouter error: %s", chatResp.Error.Message)
	}

	if len(chatResp.Choices) == 0 {
		return nil, fmt.Errorf("OpenRouter returned empty response")
	}

	rawText := chatResp.Choices[0].Message.Content
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
