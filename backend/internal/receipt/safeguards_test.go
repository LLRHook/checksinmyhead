package receipt

import (
	"bytes"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"backend/pkg/safehttp"
)

func envelope(text string) string {
	b, _ := json.Marshal(map[string]any{"content": []map[string]string{{"type": "text", "text": text}}})
	return string(b)
}

const validReceipt = `{"vendor":null,"items":[{"name":"Coffee","price":4.5,"quantity":1},{"name":"Discount","price":-1,"quantity":1}],"tax":null,"total":3.5}`

func configuredService(t *testing.T, slots string) *Service {
	t.Helper()
	t.Setenv("ANTHROPIC_API_KEY", "synthetic-local-fixture")
	t.Setenv("OCR_MAX_INFLIGHT", slots)
	s, err := NewService()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(s.Close)
	return s
}

func fixtureService(t *testing.T, response string) *Service {
	t.Helper()
	s := configuredService(t, "")
	s.httpClient.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
		return &http.Response{StatusCode: 200, Header: make(http.Header), Body: io.NopCloser(strings.NewReader(response)), Request: r}, nil
	})
	return s
}

func multipartImage(t *testing.T, duplicate bool) ([]byte, string) {
	t.Helper()
	var body bytes.Buffer
	w := multipart.NewWriter(&body)
	count := 1
	if duplicate {
		count = 2
	}
	for i := 0; i < count; i++ {
		p, err := w.CreateFormFile("image", "fixture.jpg")
		if err != nil {
			t.Fatal(err)
		}
		_, _ = p.Write(append([]byte{0xff, 0xd8, 0xff}, bytes.Repeat([]byte{0}, 512)...))
	}
	_ = w.Close()
	return body.Bytes(), w.FormDataContentType()
}

func TestReceiptSafeguards(t *testing.T) {
	for _, tc := range []struct {
		name, text string
		valid      bool
	}{
		{"success", validReceipt, true},
		{"nulls", `{"vendor":null,"items":null,"tax":null}`, true},
		{"fences", "```json\n" + validReceipt + "\n```", true},
		{"quantity", `{"items":[{"quantity":501}]}`, false},
		{"money", `{"total":1000000001}`, false},
		{"vendor", `{"vendor":"` + strings.Repeat("x", 256) + `"}`, false},
		{"confidence", `{"currency_confidence":1.01}`, false},
		{"depth", `{"ignored":` + strings.Repeat("[", 17) + "0" + strings.Repeat("]", 17) + `}`, false},
		{"array", `{"ignored":[` + strings.Repeat("0,", 512) + `0]}`, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			_, err := parseResponseText(tc.text)
			if (err == nil) != tc.valid {
				t.Fatalf("valid=%v got error=%v", tc.valid, err)
			}
		})
	}
	t.Run("finite_error", func(t *testing.T) {
		_, err := parseResponseText("synthetic-private-receipt")
		if err == nil || strings.Contains(err.Error(), "synthetic-private-receipt") {
			t.Fatal("parse failure retained input")
		}
	})
	for _, dup := range []bool{false, true} {
		t.Run(map[bool]string{false: "http_success", true: "duplicate"}[dup], func(t *testing.T) {
			s := fixtureService(t, envelope(validReceipt))
			h := NewHandler(s)
			t.Cleanup(h.Close)
			r, err := safehttp.NewRouter("")
			if err != nil {
				t.Fatal(err)
			}
			r.POST("/parse", h.ParseReceipt)
			b, ct := multipartImage(t, dup)
			req := httptest.NewRequest("POST", "/parse", bytes.NewReader(b))
			req.Header.Set("Content-Type", ct)
			req.RemoteAddr = "192.0.2.10:1234"
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)
			want := 200
			if dup {
				want = 400
			}
			if w.Code != want {
				t.Fatalf("status=%d want=%d", w.Code, want)
			}
		})
	}
}
