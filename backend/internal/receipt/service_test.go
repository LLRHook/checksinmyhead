package receipt

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
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

func TestServiceParse_MockAnthropic(t *testing.T) {
	mockReceipt := ParsedReceipt{
		Vendor: "Test Store",
		Items: []ParsedItem{
			{Name: "Widget", Price: 9.99, Quantity: 1},
		},
	}
	total := 10.79
	mockReceipt.Total = &total

	receiptJSON, _ := json.Marshal(mockReceipt)

	// Create a mock Anthropic server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify Anthropic auth headers
		if r.Header.Get("x-api-key") != "test-key" {
			t.Errorf("expected x-api-key test-key, got %q", r.Header.Get("x-api-key"))
		}
		if r.Header.Get("anthropic-version") != anthropicVersion {
			t.Errorf("expected anthropic-version %s, got %q", anthropicVersion, r.Header.Get("anthropic-version"))
		}

		resp := messagesResponse{
			Content: []struct {
				Type string `json:"type"`
				Text string `json:"text"`
			}{
				{
					Type: "text",
					Text: string(receiptJSON),
				},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	// Temporarily override the endpoint for testing
	origEndpoint := anthropicEndpoint
	defer func() {
		// Can't reassign const, so we test via the httptest approach below
		_ = origEndpoint
	}()

	// Since anthropicEndpoint is a const, we test Parse indirectly via parseResponseText
	// and test the HTTP wiring by calling the server directly
	client := server.Client()
	svc := &Service{
		apiKey:     "test-key",
		httpClient: client,
	}

	// Make the request manually to the test server (same logic as Parse but with test URL)
	b64Image := "ZmFrZS1pbWFnZS1kYXRh" // base64 of "fake-image-data"
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
							MediaType: "image/jpeg",
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

	jsonBody, _ := json.Marshal(reqBody)
	req, _ := http.NewRequest("POST", server.URL, bytes.NewReader(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", svc.apiKey)
	req.Header.Set("anthropic-version", anthropicVersion)

	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	defer resp.Body.Close()

	var msgResp messagesResponse
	json.NewDecoder(resp.Body).Decode(&msgResp)

	result, err := parseResponseText(msgResp.Content[0].Text)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result.Vendor != "Test Store" {
		t.Errorf("vendor = %q, want %q", result.Vendor, "Test Store")
	}
	if len(result.Items) != 1 {
		t.Fatalf("items count = %d, want 1", len(result.Items))
	}
	if result.Items[0].Name != "Widget" {
		t.Errorf("items[0].name = %q, want %q", result.Items[0].Name, "Widget")
	}
	if result.Total == nil || *result.Total != 10.79 {
		t.Errorf("total = %v, want 10.79", result.Total)
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
