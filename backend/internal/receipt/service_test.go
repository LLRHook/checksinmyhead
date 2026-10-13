package receipt

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestParseResponseText_CleanJSON(t *testing.T) {
	input := `{
		"vendor": "Walmart",
		"items": [
			{"name": "Milk", "price": 3.99, "quantity": 1},
			{"name": "Bread", "price": 2.49, "quantity": 2}
		],
		"subtotal": 8.97,
		"tax": 0.72,
		"total": 9.69
	}`

	receipt, err := parseResponseText(input)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if receipt.Vendor != "Walmart" {
		t.Errorf("vendor = %q, want %q", receipt.Vendor, "Walmart")
	}
	if len(receipt.Items) != 2 {
		t.Fatalf("items count = %d, want 2", len(receipt.Items))
	}
	if receipt.Items[0].Name != "Milk" {
		t.Errorf("items[0].name = %q, want %q", receipt.Items[0].Name, "Milk")
	}
	if receipt.Items[0].Price != 3.99 {
		t.Errorf("items[0].price = %f, want 3.99", receipt.Items[0].Price)
	}
	if receipt.Items[1].Quantity != 2 {
		t.Errorf("items[1].quantity = %d, want 2", receipt.Items[1].Quantity)
	}
	if receipt.Subtotal == nil || *receipt.Subtotal != 8.97 {
		t.Errorf("subtotal = %v, want 8.97", receipt.Subtotal)
	}
	if receipt.Tax == nil || *receipt.Tax != 0.72 {
		t.Errorf("tax = %v, want 0.72", receipt.Tax)
	}
	if receipt.Total == nil || *receipt.Total != 9.69 {
		t.Errorf("total = %v, want 9.69", receipt.Total)
	}
	if receipt.Tip != nil {
		t.Errorf("tip = %v, want nil", receipt.Tip)
	}
}

func TestParseResponseText_MarkdownFences(t *testing.T) {
	input := "```json\n{\"vendor\": \"Target\", \"items\": [{\"name\": \"Socks\", \"price\": 5.99}], \"total\": 6.47}\n```"

	receipt, err := parseResponseText(input)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if receipt.Vendor != "Target" {
		t.Errorf("vendor = %q, want %q", receipt.Vendor, "Target")
	}
	if len(receipt.Items) != 1 {
		t.Fatalf("items count = %d, want 1", len(receipt.Items))
	}
	if receipt.Items[0].Name != "Socks" {
		t.Errorf("items[0].name = %q, want %q", receipt.Items[0].Name, "Socks")
	}
}

func TestParseResponseText_EmptyItems(t *testing.T) {
	input := `{"vendor": "Unknown", "total": 5.00}`

	receipt, err := parseResponseText(input)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if receipt.Items == nil {
		t.Fatal("items should be empty slice, not nil")
	}
	if len(receipt.Items) != 0 {
		t.Errorf("items count = %d, want 0", len(receipt.Items))
	}
}

func TestParseResponseText_InvalidJSON(t *testing.T) {
	input := "This is not JSON at all"

	_, err := parseResponseText(input)
	if err == nil {
		t.Fatal("expected error for invalid JSON")
	}
}

func TestParseResponseText_NegativePrice(t *testing.T) {
	input := `{
		"items": [
			{"name": "Coffee", "price": 4.50},
			{"name": "Discount", "price": -1.00}
		],
		"total": 3.50
	}`

	receipt, err := parseResponseText(input)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(receipt.Items) != 2 {
		t.Fatalf("items count = %d, want 2", len(receipt.Items))
	}
	if receipt.Items[1].Price != -1.00 {
		t.Errorf("items[1].price = %f, want -1.00", receipt.Items[1].Price)
	}
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(request *http.Request) (*http.Response, error) {
	return f(request)
}

func TestServiceParse_MockAnthropic(t *testing.T) {
	receiptJSON, _ := json.Marshal(map[string]any{
		"vendor": "Test Store", "currency_code": "USD", "currency_symbol": "$",
		"currency_confidence": 0.99,
		"items":               []map[string]any{{"name": "Widget", "price": 9.99, "quantity": 1}},
		"subtotal":            9.99, "tax": 0.8, "tip": nil, "total": 10.79,
	})

	client := &http.Client{Transport: roundTripFunc(func(httpReq *http.Request) (*http.Response, error) {
		if httpReq.URL.String() != anthropicEndpoint {
			t.Errorf("request URL = %q, want %q", httpReq.URL, anthropicEndpoint)
		}
		if httpReq.Header.Get("x-api-key") != "test-key" {
			t.Errorf("x-api-key = %q, want test-key", httpReq.Header.Get("x-api-key"))
		}
		if httpReq.Header.Get("anthropic-version") != anthropicVersion {
			t.Errorf("anthropic-version = %q, want %q", httpReq.Header.Get("anthropic-version"), anthropicVersion)
		}
		var request messagesRequest
		if err := json.NewDecoder(httpReq.Body).Decode(&request); err != nil {
			t.Errorf("decode request: %v", err)
			return nil, err
		}
		if request.Model != "claude-sonnet-5-5" {
			t.Errorf("model = %q, want claude-sonnet-5-5", request.Model)
		}
		if request.OutputConfig.Format.Type != "json_schema" {
			t.Errorf("output format = %q, want json_schema", request.OutputConfig.Format.Type)
		}
		if len(request.Messages) != 1 || len(request.Messages[0].Content) != 2 {
			t.Errorf("unexpected message content: %#v", request.Messages)
		} else {
			image := request.Messages[0].Content[0]
			if image.Type != "image" || image.Source == nil || image.Source.MediaType != "image/jpeg" {
				t.Errorf("unexpected image content: %#v", image)
			}
			prompt := request.Messages[0].Content[1].Text
			if !strings.Contains(prompt, "do not expand abbreviations") {
				t.Errorf("request did not include conservative naming guidance")
			}
			if !strings.Contains(prompt, `"2 Well Gin" followed by "Diet Coke"`) || !strings.Contains(prompt, "clearly legible handwritten values") {
				t.Errorf("request did not include multi-line item and handwritten total guidance")
			}
		}
		if request.OutputConfig.Format.Schema["additionalProperties"] != false {
			t.Errorf("root schema must reject additional properties")
		}
		responseBody, err := json.Marshal(messagesResponse{
			Content: []struct {
				Type string `json:"type"`
				Text string `json:"text"`
			}{{Type: "text", Text: string(receiptJSON)}},
		})
		if err != nil {
			return nil, err
		}
		return &http.Response{
			StatusCode: http.StatusOK,
			Header:     make(http.Header),
			Body:       io.NopCloser(strings.NewReader(string(responseBody))),
			Request:    httpReq,
		}, nil
	})}

	svc := &Service{apiKey: "test-key", httpClient: client}
	result, err := svc.Parse([]byte("fake-image-data"), "image/jpeg")
	if err != nil {
		t.Fatalf("Parse returned error: %v", err)
	}
	if result.Vendor != "Test Store" || len(result.Items) != 1 || result.Items[0].Name != "Widget" {
		t.Fatalf("unexpected parsed receipt: %#v", result)
	}
	if result.Total == nil || *result.Total != 10.79 {
		t.Errorf("total = %v, want 10.79", result.Total)
	}
}

func TestReceiptOutputSchemaHasExpectedReceiptFields(t *testing.T) {
	properties, ok := receiptOutputSchema["properties"].(map[string]any)
	if !ok {
		t.Fatal("receipt output schema properties are missing")
	}
	for _, field := range []string{"vendor", "currency_code", "currency_symbol", "currency_confidence", "items", "subtotal", "tax", "tip", "total"} {
		if _, exists := properties[field]; !exists {
			t.Errorf("schema is missing %q", field)
		}
	}
}

func TestParseResponseText_RestaurantReceipt(t *testing.T) {
	input := `{
		"vendor": "Olive Garden",
		"items": [
			{"name": "Chicken Alfredo", "price": 18.99},
			{"name": "House Salad", "price": 8.49},
			{"name": "Iced Tea", "price": 3.29}
		],
		"subtotal": 30.77,
		"tax": 2.46,
		"tip": 6.15,
		"total": 39.38
	}`

	receipt, err := parseResponseText(input)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(receipt.Items) != 3 {
		t.Fatalf("items count = %d, want 3", len(receipt.Items))
	}
	if receipt.Tip == nil || *receipt.Tip != 6.15 {
		t.Errorf("tip = %v, want 6.15", receipt.Tip)
	}
}

func TestTruncate(t *testing.T) {
	if got := truncate("hello", 10); got != "hello" {
		t.Errorf("truncate short = %q, want %q", got, "hello")
	}
	if got := truncate("hello world", 5); got != "hello..." {
		t.Errorf("truncate long = %q, want %q", got, "hello...")
	}
}
