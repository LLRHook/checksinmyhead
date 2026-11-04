package security

import (
	"math/rand"
	"regexp"
	"strings"
	"testing"
)

func TestSanitizeStringCompatibility(t *testing.T) {
	// Independent specification of the established HTML/Go-whitespace contract.
	tags := regexp.MustCompile(`<[^>]*>`)
	cases := []string{"", "Alex", " \tAlex\r\n", "\u00a0界\u2003", "\ufeffAlex\ufeff", "<b>Alex</b>", "<\n>Alex", "a<b<c>d", "a>b", "a<unfinished", "a<one> <two>b", "a\\<b>c", "&lt;b&gt;", "<>", string([]byte{0xff, 'A', 0xfe}), "\x00Alex"}
	for _, value := range cases {
		t.Run(value, func(t *testing.T) {
			want := strings.TrimSpace(tags.ReplaceAllString(value, ""))
			if got := SanitizeString(value); got != want {
				t.Fatalf("got %q want %q", got, want)
			}
		})
	}
	// Brackets, escaped-looking strings, arbitrary bytes and Unicode whitespace
	// exercise the fast path and the regexp path without assuming valid UTF-8.
	random := rand.New(rand.NewSource(4507))
	alphabet := []byte("<>/\\\" \t\r\nAlex012" + "\u2003\ufeff界" + string([]byte{0, 0xff, 0xfe}))
	for i := 0; i < 2048; i++ {
		raw := make([]byte, random.Intn(256))
		for j := range raw {
			raw[j] = alphabet[random.Intn(len(alphabet))]
		}
		value := string(raw)
		want := strings.TrimSpace(tags.ReplaceAllString(value, ""))
		if got := SanitizeString(value); got != want {
			t.Fatalf("case %d: got %q want %q", i, got, want)
		}
	}
}
