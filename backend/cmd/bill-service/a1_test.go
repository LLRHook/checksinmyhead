package main

import (
	"backend/internal/exchange"
	"backend/internal/tab"
	"backend/pkg/models"
	"bytes"
	"context"
	"errors"
	"github.com/gin-gonic/gin"
	"log"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

type a1Tabs struct {
	tab.TabService
	calls  atomic.Int32
	create func(context.Context, *models.Tab, string) (*models.TabMember, error)
}

func (s *a1Tabs) CreateTab(ctx context.Context, v *models.Tab, name string) (*models.TabMember, error) {
	s.calls.Add(1)
	if s.create != nil {
		return s.create(ctx, v, name)
	}
	v.ID = 1
	return nil, nil
}
func a1Router(t *testing.T, tabs *a1Tabs) *gin.Engine {
	t.Helper()
	b, c := newCurrencyHandlers(&compositionRepo{}, exchange.NewClient("http://127.0.0.1:1"))
	r, err := newRouter(b, c, tab.NewTabHandler(tabs), nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	return r
}
func TestA1ProductionJSONAdmission(t *testing.T) {
	gin.SetMode(gin.TestMode)
	for _, tc := range []struct {
		name, body string
		want       int
	}{
		{"optional_name_memberless", `{}`, 201},
		{"ignored_privileged_graph", `{"bills":[{"id":1}],"members":[{"id":1,"member_token":"forged"}]}`, 201},
		{"name_unicode_max", `{"name":"` + strings.Repeat("界", 255) + `"}`, 201},
		{"name_unicode_excess", `{"name":"` + strings.Repeat("界", 256) + `"}`, 400},
		{"description_max", `{"description":"` + strings.Repeat("x", 4096) + `"}`, 201},
		{"description_excess", `{"description":"` + strings.Repeat("x", 4097) + `"}`, 400},
		{"creator_excess", `{"creator_display_name":"` + strings.Repeat("界", 31) + `"}`, 400},
		{"sanitized_name", `{"name":"<b>` + strings.Repeat("x", 255) + `</b>"}`, 201},
		{"byte_exact", `{}` + strings.Repeat(" ", (16<<10)-2), 201},
		{"byte_excess", `{}` + strings.Repeat(" ", (16<<10)-1), 413},
		{"second_document", `{} {}`, 400}, {"trailing_garbage", `{} x`, 400}, {"truncated", `{"name":`, 400},
	} {
		t.Run(tc.name, func(t *testing.T) {
			tabs := &a1Tabs{}
			r := a1Router(t, tabs)
			w := compositionRequest(r, "POST", "/api/tabs", tc.body)
			if w.Code != tc.want {
				t.Errorf("status=%d want=%d", w.Code, tc.want)
			}
			calls := int32(0)
			if tc.want == 201 {
				calls = 1
			}
			if tabs.calls.Load() != calls {
				t.Errorf("create calls=%d want=%d", tabs.calls.Load(), calls)
			}
		})
	}
	t.Run("existing_create_EOF", func(t *testing.T) {
		r := a1Router(t, &a1Tabs{})
		w := compositionRequest(r, "POST", "/api/bills", `{"name":"Legacy","subtotal":0,"total":0} {}`)
		if w.Code != 400 {
			t.Errorf("status=%d", w.Code)
		}
	})
}
func TestA1ProductionProxy(t *testing.T) {
	gin.SetMode(gin.TestMode)
	for _, tc := range []struct{ name, config, remote, xff, real, want string }{
		{"default", "", "192.0.2.1:8", "198.51.100.2", "203.0.113.2", "192.0.2.1"},
		{"trusted_multihop", "192.0.2.0/24,2001:db8::/32", "192.0.2.1:8", "198.51.100.2, 2001:db8::1", "203.0.113.2", "198.51.100.2"},
		{"untrusted_hop", "192.0.2.0/24", "192.0.2.1:8", "198.51.100.2, 203.0.113.2", "", "203.0.113.2"},
		{"untrusted_socket", "192.0.2.0/24", "203.0.113.1:8", "198.51.100.2", "", "203.0.113.1"},
		{"real_ip_ignored", "192.0.2.0/24", "192.0.2.1:8", "", "198.51.100.2", "192.0.2.1"},
		{"mapped_socket", "", "[::ffff:192.0.2.1]:8", "198.51.100.2", "", "192.0.2.1"},
		{"mapped_forwarded", "192.0.2.0/24", "192.0.2.1:8", "::ffff:198.51.100.2", "", "198.51.100.2"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv("TRUSTED_PROXY_CIDRS", tc.config)
			r := a1Router(t, &a1Tabs{})
			r.GET("/a1/client", func(c *gin.Context) { c.String(200, c.ClientIP()) })
			q := httptest.NewRequest("GET", "/a1/client", nil)
			q.RemoteAddr = tc.remote
			q.Header.Set("X-Forwarded-For", tc.xff)
			q.Header.Set("X-Real-IP", tc.real)
			q.Header.Set("X-Appengine-Remote-Addr", "10.0.0.1")
			w := httptest.NewRecorder()
			r.ServeHTTP(w, q)
			if w.Body.String() != tc.want {
				t.Errorf("client=%q want=%q", w.Body.String(), tc.want)
			}
		})
	}
	for _, bad := range []string{"0.0.0.0/0", "::/0", "192.0.2.1/24", "example.com", "192.0.2.0/24,", strings.Repeat("x", 2049), strings.Repeat("192.0.2.0/24,", 32) + "192.0.2.0/24"} {
		t.Run("invalid_"+strings.Split(bad, ",")[0][:min(len(strings.Split(bad, ",")[0]), 20)], func(t *testing.T) {
			t.Setenv("TRUSTED_PROXY_CIDRS", bad)
			b, c := newCurrencyHandlers(&compositionRepo{}, exchange.NewClient("http://127.0.0.1:1"))
			_, err := newRouter(b, c, tab.NewTabHandler(&a1Tabs{}), nil, nil)
			if err == nil {
				t.Error("invalid config accepted")
			} else if strings.Contains(err.Error(), bad) {
				t.Error("config echoed")
			}
		})
	}
}

type a1Private struct{ calls *atomic.Int32 }

func (v a1Private) String() string { v.calls.Add(1); return "A1_PRIVATE_PANIC" }
func (v a1Private) Error() string  { v.calls.Add(1); return "A1_PRIVATE_PANIC" }

type a1Stringer struct{ calls *atomic.Int32 }

func (v a1Stringer) String() string { v.calls.Add(1); return "A1_PRIVATE_STRINGER" }
func TestA1ProductionRecovery(t *testing.T) {
	for _, mode := range []string{gin.DebugMode, gin.ReleaseMode} {
		t.Run(mode, func(t *testing.T) {
			old := gin.Mode()
			gin.SetMode(mode)
			defer gin.SetMode(old)
			var output bytes.Buffer
			gw, ge, lw := gin.DefaultWriter, gin.DefaultErrorWriter, log.Writer()
			gin.DefaultWriter = &output
			gin.DefaultErrorWriter = &output
			log.SetOutput(&output)
			defer func() { gin.DefaultWriter = gw; gin.DefaultErrorWriter = ge; log.SetOutput(lw) }()
			r := a1Router(t, &a1Tabs{})
			var calls atomic.Int32
			r.POST("/a1/panic", func(*gin.Context) { panic(a1Private{&calls}) })
			req := httptest.NewRequest("POST", "/a1/panic?t=A1_PRIVATE_QUERY", strings.NewReader("A1_PRIVATE_BODY"))
			req.Header.Set("Authorization", "Bearer A1_PRIVATE_AUTH")
			req.Header.Set("X-Member-Token", "A1_PRIVATE_MEMBER")
			req.Header.Set("Location", "A1_PRIVATE_LOCATION")
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)
			if w.Code != 500 || w.Body.String() != `{"error":"an internal error occurred"}` {
				t.Errorf("generic500 missing status=%d", w.Code)
			}
			r.POST("/a1/stringer", func(*gin.Context) { panic(a1Stringer{&calls}) })
			other := compositionRequest(r, "POST", "/a1/stringer", "")
			if other.Code != 500 || other.Body.String() != `{"error":"an internal error occurred"}` {
				t.Error("Stringer generic500 missing")
			}
			if calls.Load() != 0 {
				t.Error("formatted panic")
			}
			for _, v := range []string{"A1_PRIVATE_", "goroutine ", "/a1/panic?t=", "recovery.go:"} {
				if strings.Contains(output.String(), v) {
					t.Errorf("private/stack output %q", v)
				}
			}
			if !strings.Contains(output.String(), "event=http_recovery") {
				t.Error("finite event missing")
			}
		})
	}
}
func TestA1ProductionMutationGate(t *testing.T) {
	gin.SetMode(gin.TestMode)
	entered := make(chan struct{}, 9)
	release := make(chan struct{})
	var releaseOnce sync.Once
	unblock := func() { releaseOnce.Do(func() { close(release) }) }
	defer unblock()
	tabs := &a1Tabs{}
	var n atomic.Int32
	tabs.create = func(ctx context.Context, _ *models.Tab, _ string) (*models.TabMember, error) {
		if n.Add(1) <= 8 {
			entered <- struct{}{}
			select {
			case <-release:
			case <-ctx.Done():
			}
		}
		return nil, errors.New("synthetic")
	}
	r := a1Router(t, tabs)
	done := make(chan struct{}, 8)
	for i := 0; i < 8; i++ {
		go func() { defer func() { done <- struct{}{} }(); compositionRequest(r, "POST", "/api/tabs", `{}`) }()
	}
	for i := 0; i < 8; i++ {
		select {
		case <-entered:
		case <-time.After(3 * time.Second):
			t.Fatal("eight entrants missing")
		}
	}
	req := httptest.NewRequest("POST", "/api/tabs", strings.NewReader(`{}`))
	req.Header.Set("Content-Type", "text/plain")
	req.Header.Set("Origin", "https://billingtonapp.vercel.app")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != 503 || w.Header().Get("Retry-After") != "1" || tabs.calls.Load() != 8 {
		t.Errorf("saturation status=%d retry=%q calls=%d", w.Code, w.Header().Get("Retry-After"), tabs.calls.Load())
	}
	if !strings.Contains(w.Header().Get("Access-Control-Expose-Headers"), "Retry-After") {
		t.Error("CORS retry missing")
	}
	r.GET("/a1/read", func(c *gin.Context) { c.String(200, "ok") })
	if compositionRequest(r, "GET", "/a1/read", "").Code != 200 {
		t.Error("read blocked")
	}
	unblock()
	for i := 0; i < 8; i++ {
		select {
		case <-done:
		case <-time.After(3 * time.Second):
			t.Fatal("gate cleanup")
		}
	}

}
