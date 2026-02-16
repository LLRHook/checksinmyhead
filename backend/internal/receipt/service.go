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

// Service handles receipt parsing via the Gemini Vision API.
type Service struct {
	apiKey     string
	httpClient *http.Client
}

// NewService creates a new receipt parsing service.
// Reads GEMINI_API_KEY from environment.
func NewService() (*Service, error) {
	apiKey := os.Getenv("GEMINI_API_KEY")
	if apiKey == "" {
		return nil, fmt.Errorf("GEMINI_API_KEY environment variable is required")
	}
	return &Service{
		apiKey: apiKey,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}, nil
}

const geminiPrompt = `Parse this receipt image. Return ONLY valid JSON with this exact structure:
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

// geminiRequest is the request body for Gemini's generateContent endpoint.
type geminiRequest struct {
	Contents         []geminiContent        `json:"contents"`
	GenerationConfig map[string]interface{} `json:"generationConfig,omitempty"`
}

type geminiContent struct {
	Parts []geminiPart `json:"parts"`
}

type geminiPart struct {
	Text       string          `json:"text,omitempty"`
	InlineData *geminiInlineData `json:"inlineData,omitempty"`
}

type geminiInlineData struct {
	MimeType string `json:"mimeType"`
	Data     string `json:"data"`
}

// geminiResponse is the response from Gemini's generateContent endpoint.
type geminiResponse struct {
	Candidates []struct {
		Content struct {
			Parts []struct {
				Text string `json:"text"`
			} `json:"parts"`
		} `json:"content"`
	} `json:"candidates"`
	Error *struct {
		Message string `json:"message"`
		Code    int    `json:"code"`
	} `json:"error"`
}

// Parse sends a receipt image to Gemini Flash and returns structured receipt data.
func (s *Service) Parse(imageData []byte, mimeType string) (*ParsedReceipt, error) {
	b64Image := base64.StdEncoding.EncodeToString(imageData)

	reqBody := geminiRequest{
		Contents: []geminiContent{
			{
				Parts: []geminiPart{
					{
						InlineData: &geminiInlineData{
							MimeType: mimeType,
							Data:     b64Image,
						},
					},
					{
						Text: geminiPrompt,
					},
				},
			},
		},
		GenerationConfig: map[string]interface{}{
			"temperature":     0.1,
			"maxOutputTokens": 1024,
			"responseMimeType": "application/json",
		},
	}

	jsonBody, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	url := fmt.Sprintf(
		"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=%s",
		s.apiKey,
	)

	resp, err := s.httpClient.Post(url, "application/json", bytes.NewReader(jsonBody))
	if err != nil {
		return nil, fmt.Errorf("gemini API request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode == http.StatusTooManyRequests {
		return nil, fmt.Errorf("rate_limited")
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("gemini API returned status %d: %s", resp.StatusCode, string(respBody))
	}

	var geminiResp geminiResponse
	if err := json.Unmarshal(respBody, &geminiResp); err != nil {
		return nil, fmt.Errorf("failed to parse gemini response: %w", err)
	}

	if geminiResp.Error != nil {
		return nil, fmt.Errorf("gemini error: %s", geminiResp.Error.Message)
	}

	if len(geminiResp.Candidates) == 0 || len(geminiResp.Candidates[0].Content.Parts) == 0 {
		return nil, fmt.Errorf("gemini returned empty response")
	}

	rawText := geminiResp.Candidates[0].Content.Parts[0].Text
	return parseGeminiText(rawText)
}

// parseGeminiText extracts JSON from Gemini's response text, which may
// include markdown code fences.
func parseGeminiText(text string) (*ParsedReceipt, error) {
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
