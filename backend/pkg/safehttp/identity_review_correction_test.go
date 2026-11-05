package safehttp

import (
	"github.com/gin-gonic/gin"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestIdentityBReviewMalformedQueryProof(t *testing.T) {
	for _, tc := range []struct{ name, query, header, want string }{
		{"absent", "", "", ""},
		{"valid_query", "?m=current", "", "current"},
		{"bad_value", "?m=%ZZ", "", "\x00"},
		{"bad_encoded_member", "?%6d=%ZZ", "", "\x00"},
		{"partial_valid_proof_with_parse_error", "?m=current&x=%ZZ", "", "\x00"},
		{"header_precedence", "?m=%ZZ", "current", "current"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			c, _ := gin.CreateTestContext(httptest.NewRecorder())
			c.Request = httptest.NewRequest(http.MethodPost, "/join"+tc.query, nil)
			if tc.header != "" {
				c.Request.Header.Set("X-Member-Token", tc.header)
			}
			if got := MemberToken(c); got != tc.want {
				t.Fatalf("invalid-proof distinction failed: got invalid=%t absent=%t", got == "\x00", got == "")
			}
		})
	}
}
