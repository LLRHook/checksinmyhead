package safehttp

import (
	"context"
	"errors"
	"fmt"
	"github.com/gin-gonic/gin"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

type noDrain struct {
	reads int
	first bool
}

func (r *noDrain) Read(p []byte) (int, error) {
	r.reads++
	if !r.first {
		r.first = true
		return copy(p, "!"), nil
	}
	return 0, errors.New("private reader cause")
}
func (*noDrain) Close() error { return nil }
func TestA1SingleJSONDocument(t *testing.T) {
	for _, tc := range []struct {
		name, body string
		length     int64
		strict     bool
		want       error
	}{
		{"exact", `{"name":"x"}` + strings.Repeat(" ", 52), 64, false, nil},
		{"one_over_declared", `{}` + strings.Repeat(" ", 63), 65, false, ErrJSONTooLarge},
		{"one_over_streamed", `{}` + strings.Repeat(" ", 63), -1, false, ErrJSONTooLarge},
		{"strict", `{"unknown":1}`, 13, true, ErrInvalidJSON},
		{"ignored", `{"unknown":[{},{}]}`, 18, false, nil},
		{"truncated", `{"name":`, 8, false, ErrInvalidJSON},
		{"second_scalar", `{} 1`, 4, false, ErrInvalidJSON},
		{"second_array", `{} [` + strings.Repeat("0,", 20) + `0]`, 47, false, ErrInvalidJSON},
		{"syntax", `!`, 1, false, ErrInvalidJSON},
		{"known_size_precedes_syntax", `!` + strings.Repeat("x", 64), 65, false, ErrJSONTooLarge},
	} {
		t.Run(tc.name, func(t *testing.T) {
			r := httptest.NewRequest("POST", "/", strings.NewReader(tc.body))
			r.ContentLength = tc.length
			var value struct {
				Name string `json:"name"`
			}
			if err := DecodeJSON(httptest.NewRecorder(), r, &value, 64, tc.strict); err != tc.want {
				t.Errorf("error=%v want=%v", err, tc.want)
			}
		})
	}
	t.Run("no_malformed_drain", func(t *testing.T) {
		body := &noDrain{}
		r := httptest.NewRequest("POST", "/", nil)
		r.Body = body
		r.ContentLength = -1
		var v any
		if err := DecodeJSON(httptest.NewRecorder(), r, &v, 64, false); err != ErrInvalidJSON || body.reads != 1 {
			t.Errorf("err=%v reads=%d", err, body.reads)
		}
	})
}
func TestA1BoundedArray(t *testing.T) {
	for _, tc := range []struct {
		name, data  string
		limit, size int
		invalid     bool
	}{
		{"empty", "[]", 2, 0, false}, {"null", "null", 2, 0, false}, {"nested_strings", `[{"s":"a,b[\\\"]"},{"s":"x"}]`, 2, 2, false},
		{"excess_minimal", "[null,null,null]", 2, 0, true}, {"invalid", "[1,", 2, 0, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			v, err := DecodeArray[map[string]any]([]byte(tc.data), tc.limit)
			if (err != nil) != tc.invalid || len(v) != tc.size {
				t.Errorf("len=%d err=%v", len(v), err)
			}
		})
	}
}
func TestA1SharedGateRelease(t *testing.T) {
	old := gin.Mode()
	gin.SetMode(gin.TestMode)
	defer gin.SetMode(old)
	for _, finish := range []string{"success", "error", "panic", "cancel"} {
		t.Run(finish, func(t *testing.T) {
			// Two independently constructed routers still share exactly eight process slots.
			entered := make(chan struct{}, 8)
			release := make(chan struct{})
			var once sync.Once
			unblock := func() { once.Do(func() { close(release) }) }
			defer unblock()
			makeRouter := func() *gin.Engine {
				r, err := NewRouter("")
				if err != nil {
					t.Fatal(err)
				}
				r.POST("/work", JSONMutation, func(c *gin.Context) {
					entered <- struct{}{}
					select {
					case <-release:
					case <-c.Request.Context().Done():
					}
					switch finish {
					case "panic":
						panic("synthetic")
					case "error":
						c.Status(400)
					default:
						c.Status(200)
					}
				})
				r.GET("/health", func(c *gin.Context) { c.Status(200) })
				return r
			}
			first, second := makeRouter(), makeRouter()
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			done := make(chan struct{}, 8)
			for i := 0; i < 8; i++ {
				go func() {
					defer func() { recover(); done <- struct{}{} }()
					first.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest("POST", "/work", nil).WithContext(ctx))
				}()
			}
			for i := 0; i < 8; i++ {
				select {
				case <-entered:
				case <-time.After(2 * time.Second):
					t.Fatal("missing entrant")
				}
			}
			w := httptest.NewRecorder()
			req := httptest.NewRequest("POST", "/work", nil)
			req.Header.Set("Content-Type", "text/plain")
			second.ServeHTTP(w, req)
			if w.Code != 503 || w.Header().Get("Retry-After") != "1" {
				t.Error("ninth request not refused")
			}
			w = httptest.NewRecorder()
			second.ServeHTTP(w, httptest.NewRequest("GET", "/health", nil))
			if w.Code != 200 {
				t.Error("health gated")
			}
			observed := time.Now()
			if finish == "cancel" {
				cancel()
			} else {
				unblock()
			}
			for i := 0; i < 8; i++ {
				select {
				case <-done:
				case <-time.After(2 * time.Second):
					t.Fatal("slot release missing")
				}
			}
			if finish == "cancel" && time.Since(observed) > 250*time.Millisecond {
				t.Errorf("cancel release=%s", time.Since(observed))
			}
			// All eight can be re-acquired; no success/error/panic/cancel path leaked a slot.
			if len(jsonMutations) != 0 {
				t.Errorf("leaked slots=%d", len(jsonMutations))
			}
			for i := 0; i < 8; i++ {
				jsonMutations <- struct{}{}
			}
			for i := 0; i < 8; i++ {
				<-jsonMutations
			}
		})
	}
}
func TestA1CancelInterruptsJSONRead(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r, err := NewRouter("")
	if err != nil {
		t.Fatal(err)
	}
	entered, returned, released := make(chan struct{}), make(chan struct{}), make(chan struct{})
	r.POST("/work", func(c *gin.Context) { defer close(released); c.Next() }, JSONMutation, func(c *gin.Context) {
		close(entered)
		var value any
		_ = DecodeJSON(c.Writer, c.Request, &value, 4096, false)
		close(returned)
	})
	p := shortPolicy()
	p.Read = 5 * time.Second
	p.Shutdown = time.Second
	a, cancel, done := tcpServer(t, r, p)
	c := tcpDial(t, a)
	fmt.Fprint(c, "POST /work HTTP/1.1\r\nHost: fixture\r\nContent-Length: 20\r\n\r\n{")
	<-entered
	start := time.Now()
	cancel()
	select {
	case <-returned:
	case <-time.After(time.Second):
		t.Fatal("JSON read ignored cancellation")
	}
	select {
	case <-released:
	case <-time.After(time.Second):
		t.Fatal("gate release missing")
	}
	if time.Since(start) > 250*time.Millisecond {
		t.Errorf("cancel release exceeded target %s", time.Since(start))
	}
	select {
	case err := <-done:
		if err != nil {
			t.Errorf("cancel shutdown=%v", err)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("cancel shutdown blocked")
	}

	if len(jsonMutations) != 0 {
		t.Error("canceled body retained slot")
	}
}

var a1DecodedElements atomic.Int32

type a1CountedElement struct{}

func (*a1CountedElement) UnmarshalJSON([]byte) error { a1DecodedElements.Add(1); return nil }
func TestA1ArrayCountPrecedesTypedAllocation(t *testing.T) {
	for _, tc := range []struct {
		name, data string
		want       int
		invalid    bool
	}{
		{"at_limit", "[{},{}]", 2, false}, {"over_limit", "[{},{},{}]", 0, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			a1DecodedElements.Store(0)
			values, err := DecodeArray[a1CountedElement]([]byte(tc.data), 2)
			if (err != nil) != tc.invalid || len(values) != tc.want || int(a1DecodedElements.Load()) != tc.want {
				t.Errorf("typed values=%d decodes=%d error=%v", len(values), a1DecodedElements.Load(), err)
			}
		})
	}
}
