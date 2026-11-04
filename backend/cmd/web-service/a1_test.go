package main

import (
	"backend/internal/bill"
	"backend/internal/web"
	"backend/pkg/models"
	"bytes"
	"github.com/gin-gonic/gin"
	"log"
	"net/http/httptest"
	"strings"
	"testing"
)

type a1Reader struct{ bill.BillService }

func (a1Reader) GetBill(uint) (*models.Bill, error) {
	return &models.Bill{ID: 1, AccessToken: "synthetic", Name: "HTML positive control", CurrencyCode: "USD", Total: 1}, nil
}
func TestA1WebProductionRouter(t *testing.T) {
	t.Chdir("../..")
	t.Setenv("TRUSTED_PROXY_CIDRS", "")
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
			r, err := newRouter(web.NewWebpageHandler(a1Reader{}), nil)
			if err != nil {
				t.Fatal(err)
			}
			r.GET("/a1/panic", func(*gin.Context) { panic("A1_WEB_PRIVATE_PANIC") })
			r.GET("/a1/ip", func(c *gin.Context) { c.String(200, c.ClientIP()) })
			for _, tc := range []struct {
				path   string
				status int
				body   string
			}{
				{"/a1/panic?t=A1_WEB_PRIVATE_QUERY", 500, `{"error":"an internal error occurred"}`},
				{"/b/1?t=synthetic", 200, "HTML positive control"},
				{"/b/1", 403, "token mismatch"}, {"/health", 503, "service unavailable"},
			} {
				req := httptest.NewRequest("GET", tc.path, nil)
				req.Header.Set("X-Member-Token", "A1_WEB_PRIVATE_MEMBER")
				w := httptest.NewRecorder()
				r.ServeHTTP(w, req)
				if w.Code != tc.status || !strings.Contains(w.Body.String(), tc.body) {
					t.Errorf("path=%s status=%d", strings.Split(tc.path, "?")[0], w.Code)
				}
			}
			req := httptest.NewRequest("GET", "/a1/ip", nil)
			req.RemoteAddr = "192.0.2.1:1"
			req.Header.Set("X-Forwarded-For", "198.51.100.1")
			req.Header.Set("X-Real-IP", "203.0.113.1")
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)
			if w.Body.String() != "192.0.2.1" {
				t.Error("web trusted unconfigured proxy")
			}
			if strings.Contains(output.String(), "A1_WEB_PRIVATE") || strings.Contains(output.String(), "recovery.go:") {
				t.Error("web recovery leaked")
			}
			if !strings.Contains(output.String(), "event=http_recovery") {
				t.Error("finite diagnostic missing")
			}
		})
	}
	t.Setenv("TRUSTED_PROXY_CIDRS", "example.invalid/private-config")
	if _, err := newRouter(web.NewWebpageHandler(a1Reader{}), nil); err == nil || strings.Contains(err.Error(), "example") {
		t.Error("web config validation absent or raw")
	}
}
