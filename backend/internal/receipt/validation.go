package receipt

import (
	"bytes"
	"encoding/json"
	"io"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"
)

// Walk tokens before decoding typed envelopes or item slices. Every occurrence,
// including ignored/duplicate fields, is bounded; strings remain under the outer
// byte cap. No recursive allocation of arbitrary maps/slices is needed.
func boundedJSON(data []byte) bool {
	d := json.NewDecoder(bytes.NewReader(data))
	d.UseNumber()
	tokens := 0
	var value func(int, string) bool
	next := func() (json.Token, error) {
		tokens++
		if tokens > 16384 {
			return nil, io.ErrUnexpectedEOF
		}
		return d.Token()
	}
	value = func(depth int, key string) bool {
		t, err := next()
		if err != nil {
			return false
		}
		if text, ok := t.(string); ok && strings.EqualFold(key, "text") && len(text) > maxTextSize {
			return false
		}
		delim, ok := t.(json.Delim)
		if !ok {
			return true
		}
		if depth >= 16 {
			return false
		}
		switch delim {
		case '{':
			for d.More() {
				k, err := next()
				if err != nil {
					return false
				}
				s, ok := k.(string)
				if !ok || !value(depth+1, s) {
					return false
				}
			}
			t, err = next()
			return err == nil && t == json.Delim('}')
		case '[':
			limit := 512
			if strings.EqualFold(key, "content") {
				limit = 16
			}
			if strings.EqualFold(key, "items") {
				limit = 500
			}
			n := 0
			for d.More() {
				n++
				if n > limit || !value(depth+1, "") {
					return false
				}
			}
			t, err = next()
			return err == nil && t == json.Delim(']')
		default:
			return false
		}
	}
	if !value(0, "") {
		return false
	}
	_, err := d.Token()
	return err == io.EOF
}

func validReceiptShape(r *ParsedReceipt) bool {
	if utf8.RuneCountInString(r.Vendor) > 255 || len(r.Items) > 500 {
		return false
	}
	if r.CurrencySymbol != nil && utf8.RuneCountInString(*r.CurrencySymbol) > 16 {
		return false
	}
	if r.CurrencyCode != nil {
		if len(*r.CurrencyCode) != 3 {
			return false
		}
		for _, c := range *r.CurrencyCode {
			if !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z') {
				return false
			}
		}
	}
	if r.CurrencyConfidence != nil && (!finite(*r.CurrencyConfidence) || *r.CurrencyConfidence < 0 || *r.CurrencyConfidence > 1) {
		return false
	}
	for _, m := range []*float64{r.Subtotal, r.Tax, r.Tip, r.Total} {
		if m != nil && !validMoney(*m) {
			return false
		}
	}
	count := 0
	for _, item := range r.Items {
		if utf8.RuneCountInString(item.Name) > 255 || !validMoney(item.Price) {
			return false
		}
		n := max(1, item.Quantity)
		// Subtraction proves the bound without overflow, even for MaxInt.
		if n > 500-count {
			return false
		}
		count += n
	}
	return true
}

func finite(n float64) bool     { return !math.IsNaN(n) && !math.IsInf(n, 0) }
func validMoney(n float64) bool { return finite(n) && math.Abs(n) <= 1e9 }

func retryAfter(input string, now time.Time) int {
	if len(input) > 128 {
		return 60
	}
	s := strings.TrimSpace(input)
	if s != "" && strings.IndexFunc(s, func(r rune) bool { return r < '0' || r > '9' }) < 0 {
		n, err := strconv.ParseUint(s, 10, 64)
		if err != nil || n > 86400 {
			return 0
		}
		return max(1, int(n))
	}
	if date, err := http.ParseTime(s); err == nil {
		d := date.Sub(now)
		if d > 24*time.Hour {
			return 0
		}
		return max(1, int((d+time.Second-1)/time.Second))
	}
	return 60
}
