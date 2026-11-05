package safehttp

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestIdentity0003HeaderAndMemberProofs(t *testing.T) {
	for _, tc := range []struct {
		name   string
		header http.Header
		want   int16
		ok     bool
	}{
		{"absent", http.Header{}, 1, true}, {"one", http.Header{IdentityHeader: {"1"}}, 1, true}, {"two", http.Header{IdentityHeader: {"2"}}, 2, true},
		{"unknown", http.Header{IdentityHeader: {"3"}}, 0, false}, {"empty", http.Header{IdentityHeader: {""}}, 0, false}, {"space", http.Header{IdentityHeader: {" 2"}}, 0, false},
		{"comma", http.Header{IdentityHeader: {"1,2"}}, 0, false}, {"duplicate", http.Header{IdentityHeader: {"2", "2"}}, 0, false},
		{"case_duplicate", http.Header{IdentityHeader: {"2"}, strings.ToLower(IdentityHeader): {"2"}}, 0, false}, {"empty_slice", http.Header{IdentityHeader: {}}, 0, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if v, ok := ParseIdentityVersion(tc.header); v != tc.want || ok != tc.ok {
				t.Fatalf("got %d/%t", v, ok)
			}
		})
	}
	for _, tc := range []struct {
		name, query string
		header      http.Header
		want        string
	}{
		{"absent", "", http.Header{}, ""}, {"header", "", http.Header{"X-Member-Token": {"current"}}, "current"}, {"query", "?m=current", http.Header{}, "current"},
		{"supplied_empty", "", http.Header{"X-Member-Token": {""}}, "\x00"}, {"duplicates", "", http.Header{"X-Member-Token": {"a", "a"}}, "\x00"},
		{"case_duplicate", "", http.Header{"X-Member-Token": {"a"}, "x-member-token": {"a"}}, "\x00"}, {"invalid_header_no_query_fallback", "?m=current", http.Header{"X-Member-Token": {""}}, "\x00"},
		{"query_empty", "?m=", http.Header{}, "\x00"}, {"query_duplicate", "?m=a&m=a", http.Header{}, "\x00"},
	} {
		t.Run("member_"+tc.name, func(t *testing.T) {
			c, _ := gin.CreateTestContext(httptest.NewRecorder())
			c.Request = httptest.NewRequest("GET", "/"+tc.query, nil)
			c.Request.Header = tc.header
			if got := MemberToken(c); got != tc.want {
				t.Fatalf("member proof got %q want %q", got, tc.want)
			}
		})
	}
	c, w := gin.CreateTestContext(httptest.NewRecorder())
	_ = w
	c.Request = httptest.NewRequest("GET", "/", nil)
	c.Writer.Header().Add("Vary", "Origin, Authorization")
	IdentityVersion(c)
	IdentityVersion(c)
	seen := map[string]int{}
	for _, line := range c.Writer.Header().Values("Vary") {
		for _, v := range strings.Split(line, ",") {
			seen[strings.ToLower(strings.TrimSpace(v))]++
		}
	}
	for _, name := range []string{"origin", "authorization", "x-member-token", strings.ToLower(IdentityHeader)} {
		if seen[name] != 1 {
			t.Fatalf("Vary token %s duplicated/lost: %v", name, seen)
		}
	}
	if c.Writer.Header().Get("Cache-Control") != "private, no-store" {
		t.Fatal("private response cache policy absent")
	}
}
