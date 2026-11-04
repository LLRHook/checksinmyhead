package receipt

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net"
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
	ErrInvalidPeer    ParseErrorCode = "invalid_peer"
)

// ParseError contains only finite policy data, never an upstream cause or payload.
type ParseError struct {
	Code             ParseErrorCode
	RetryAfter       int // seconds; zero deliberately omits a retry hint
	unsupportedImage bool
}

func (e *ParseError) Error() string {
	switch e.Code {
	case ErrRateLimited:
		return "receipt rate limited"
	case ErrAuthFailed:
		return "receipt authentication unavailable"
	case ErrInvalidRequest:
		return "invalid receipt request"
	case ErrImageTooLarge:
		return "receipt image too large"
	case ErrOverloaded:
		return "receipt scanner overloaded"
	case ErrProviderDown:
		return "receipt provider unavailable"
	case ErrBadResponse:
		return "invalid receipt response"
	case ErrInvalidPeer:
		return "invalid receipt peer"
	default:
		return "receipt parsing failed"
	}
}

// Service owns a private, bounded HTTP/1 transport for the fixed provider.
type Service struct {
	apiKey     string
	httpClient *http.Client
	transport  *http.Transport
	policy     policy
}

// NewService reads only backend configuration. Missing keys preserve route omission;
// malformed policy is checked separately by the executable even when OCR is disabled.
func NewService() (*Service, error) {
	p, err := parsePolicy(os.Getenv("OCR_MAX_INFLIGHT"))
	if err != nil {
		return nil, err
	}
	key := os.Getenv("ANTHROPIC_API_KEY")
	if key == "" {
		return nil, errors.New("receipt API key is not configured")
	}
	protocols := new(http.Protocols)
	protocols.SetHTTP1(true)
	transport := &http.Transport{
		Proxy:       nil, // Fixed direct destination; do not inherit arbitrary proxy credentials/routes.
		DialContext: (&net.Dialer{Timeout: 10 * time.Second, KeepAlive: 30 * time.Second}).DialContext,
		Protocols:   protocols, MaxConnsPerHost: p.slots, MaxIdleConns: p.slots, MaxIdleConnsPerHost: p.slots,
		IdleConnTimeout: 60 * time.Second, TLSHandshakeTimeout: 10 * time.Second, ResponseHeaderTimeout: providerTimeout,
		MaxResponseHeaderBytes: 32 << 10,
	}
	return &Service{apiKey: key, policy: p, transport: transport, httpClient: &http.Client{Transport: redirectOpaqueTransport{transport},
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}}, nil
}

func (s *Service) Close() {
	if s.transport != nil {
		s.transport.CloseIdleConnections()
	}
}

// ValidatePolicy permits startup to reject invalid supplied policy independently
// of the optional provider key. It never exposes configuration text.
func ValidatePolicy() error { _, err := parsePolicy(os.Getenv("OCR_MAX_INFLIGHT")); return err }

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
func (s *Service) Parse(ctx context.Context, imageData []byte, mimeType string) (receipt *ParsedReceipt, resultErr error) {
	ctx, cancel := context.WithTimeout(ctx, providerTimeout)
	defer cancel()
	// Response/request cleanup can outlive parsing. Recheck AFTER its defers have
	// joined actual I/O, before the owner cancels this context itself.
	defer func() {
		if ctx.Err() != nil {
			receipt = nil
			resultErr = &ParseError{Code: ErrProviderDown, RetryAfter: 60}
		}
	}()

	if ctx.Err() != nil {
		return nil, &ParseError{Code: ErrProviderDown, RetryAfter: 60}
	}
	if len(imageData) > maxReceiptSize {
		return nil, &ParseError{Code: ErrImageTooLarge}
	}
	const imageMarker = "__billington_image_bytes__"

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
							Data:      imageMarker,
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
		return nil, &ParseError{Code: ErrInvalidRequest}
	}

	prefix, suffix, found := bytes.Cut(jsonBody, []byte(imageMarker))
	requestSize := len(prefix) + base64.StdEncoding.EncodedLen(len(imageData)) + len(suffix)
	if !found || len(prefix)+len(suffix) > 64<<10 || requestSize > base64.StdEncoding.EncodedLen(maxReceiptSize)+(64<<10) {
		return nil, &ParseError{Code: ErrImageTooLarge}
	}
	if ctx.Err() != nil {
		return nil, &ParseError{Code: ErrProviderDown, RetryAfter: 60}
	}
	// Encode once into owned storage; JSON-safe base64 can be sent between the
	// small marshaled envelope fragments without another full JSON/base64 copy.
	encoded := make([]byte, base64.StdEncoding.EncodedLen(len(imageData)))
	base64.StdEncoding.Encode(encoded, imageData)
	if ctx.Err() != nil {
		return nil, &ParseError{Code: ErrProviderDown, RetryAfter: 60}
	}
	// NopCloser hides readers from NewRequest: a nonempty, nonreplayable body
	// prevents net/http from transparently retrying a stale pooled connection.
	req, err := http.NewRequestWithContext(ctx, "POST", anthropicEndpoint, io.NopCloser(io.MultiReader(bytes.NewReader(prefix), bytes.NewReader(encoded), bytes.NewReader(suffix))))
	if err == nil {
		req.ContentLength = int64(requestSize)
		req.GetBody = nil
	}
	if err != nil {
		return nil, &ParseError{Code: ErrInvalidRequest}
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", s.apiKey)
	req.Header.Set("anthropic-version", anthropicVersion)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, &ParseError{Code: ErrProviderDown, RetryAfter: 60}
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		// Error bodies and redirect targets carry no required application data. Close
		// immediately, abandoning HTTP/1 reuse rather than draining a stalled body.
		code := ErrProviderDown
		switch resp.StatusCode {
		case 401, 403:
			code = ErrAuthFailed
		case 429:
			code = ErrRateLimited
		case 413:
			code = ErrImageTooLarge
		case 400:
			code = ErrInvalidRequest
		case 529:
			code = ErrOverloaded
		}
		retry := 0
		if code == ErrProviderDown || code == ErrRateLimited || code == ErrOverloaded {
			retry = retryAfter(resp.Header.Get("Retry-After"), time.Now())
		}
		return nil, &ParseError{Code: code, RetryAfter: retry}
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseSize+1))
	if ctx.Err() != nil {
		return nil, &ParseError{Code: ErrProviderDown, RetryAfter: 60}
	}
	if err != nil || len(body) > maxResponseSize {
		return nil, &ParseError{Code: ErrBadResponse}
	}
	if !boundedJSON(body) {
		return nil, &ParseError{Code: ErrBadResponse}
	}
	var message messagesResponse
	if json.Unmarshal(body, &message) != nil || len(message.Content) == 0 || message.Error != nil {
		return nil, &ParseError{Code: ErrBadResponse}
	}
	result, err := parseResponseText(message.Content[0].Text)
	if ctx.Err() != nil {
		return nil, &ParseError{Code: ErrProviderDown, RetryAfter: 60}
	}
	return result, err
}

// parseResponseText extracts JSON from the model's response text, which may
// include markdown code fences.
func parseResponseText(text string) (*ParsedReceipt, error) {
	if len(text) > maxTextSize {
		return nil, &ParseError{Code: ErrBadResponse}
	}
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

	if !boundedJSON([]byte(cleaned)) {
		return nil, &ParseError{Code: ErrBadResponse}
	}
	var receipt ParsedReceipt
	if err := json.Unmarshal([]byte(cleaned), &receipt); err != nil {
		return nil, &ParseError{Code: ErrBadResponse}
	}

	if !validReceiptShape(&receipt) {
		return nil, &ParseError{Code: ErrBadResponse}
	}
	if receipt.Items == nil {
		receipt.Items = []ParsedItem{}
	}

	return &receipt, nil
}
