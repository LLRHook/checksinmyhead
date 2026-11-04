package receipt

import (
	"backend/pkg/safehttp"
	"bufio"
	"bytes"
	"context"
	"fmt"
	"github.com/gin-gonic/gin"
	"io"
	"mime/multipart"
	"net"
	"net/http"
	"net/http/httptest"
	"net/textproto"
	"strings"
	"sync"
	"testing"
	"time"
)

func receiptRouter(t *testing.T, s *Service) (*Handler, http.Handler) {
	t.Helper()
	h := NewHandler(s)
	t.Cleanup(h.Close)
	r, err := safehttp.NewRouter("")
	if err != nil {
		t.Fatal(err)
	}
	r.POST("/parse", h.ParseReceipt)
	return h, r
}

func uploadRequest(r http.Handler, b []byte, ct, peer string, ctx context.Context) *httptest.ResponseRecorder {
	req := httptest.NewRequest("POST", "/parse", bytes.NewReader(b)).WithContext(ctx)
	req.RemoteAddr = peer
	req.Header.Set("Content-Type", ct)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}

func TestMultipartLimits(t *testing.T) {
	for _, tc := range []struct {
		name                                   string
		parts, headers, headerBytes, imageSize int
		duplicate                              bool
		want                                   int
	}{
		{name: "valid", parts: 1, want: 200},
		{name: "at_parts", parts: 32, want: 200},
		{name: "over_parts", parts: 33, want: 413},
		{name: "at_headers", parts: 1, headers: 62, want: 200}, // plus disposition and type
		{name: "over_headers", parts: 1, headers: 63, want: 413},
		{name: "header_size", parts: 1, headerBytes: 16 << 10, want: 413},
		{name: "duplicate", parts: 2, duplicate: true, want: 400},
		{name: "oversize_known", parts: 1, imageSize: maxReceiptSize, want: 413},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s := fixtureService(t, envelope(validReceipt))
			h, r := receiptRouter(t, s)
			var b bytes.Buffer
			w := multipart.NewWriter(&b)
			for i := 0; i < tc.parts; i++ {
				header := make(textproto.MIMEHeader)
				name := "extra"
				if i == 0 || tc.duplicate {
					name = "image"
				}
				header.Set("Content-Disposition", fmt.Sprintf(`form-data; name="%s"; filename="fixture.jpg"`, name))
				header.Set("Content-Type", "image/jpeg")
				for j := 0; j < tc.headers; j++ {
					header.Add("X-Fixture", "x")
				}
				if tc.headerBytes > 0 {
					header.Set("X-Long", strings.Repeat("x", tc.headerBytes))
				}
				p, err := w.CreatePart(header)
				if err != nil {
					t.Fatal(err)
				}
				_, _ = p.Write(append([]byte{255, 216, 255}, bytes.Repeat([]byte{0}, max(512, tc.imageSize))...))
			}
			_ = w.Close()
			out := uploadRequest(r, b.Bytes(), w.FormDataContentType(), "192.0.2.1:44", context.Background())
			if out.Code != tc.want {
				t.Fatalf("status=%d want=%d body=%s", out.Code, tc.want, out.Body.String())
			}
			if h.admission.inflight != 0 {
				t.Fatal("permit leaked")
			}
		})
	}
	t.Run("invalid_images_charged_no_forwarded_bypass", func(t *testing.T) {
		s := fixtureService(t, envelope(validReceipt))
		h, r := receiptRouter(t, s)
		for i := 0; i < 11; i++ {
			req := httptest.NewRequest("POST", "/parse", strings.NewReader("invalid"))
			req.RemoteAddr = "192.0.2.1:55"
			req.Header.Set("X-Forwarded-For", fmt.Sprintf("198.51.100.%d", i))
			out := httptest.NewRecorder()
			r.ServeHTTP(out, req)
			want := 400
			if i == 10 {
				want = 429
			}
			if out.Code != want {
				t.Fatalf("request=%d status=%d", i, out.Code)
			}
		}
		if len(h.admission.peers) != 1 {
			t.Fatal("forwarded peer state")
		}
	})
	t.Run("precancel_zero_reads", func(t *testing.T) {
		s := fixtureService(t, envelope(validReceipt))
		h, r := receiptRouter(t, s)
		b, ct := multipartImage(t, false)
		ctx, cancel := context.WithCancel(context.Background())
		cancel()
		out := uploadRequest(r, b, ct, "192.0.2.1:2", ctx)
		if h.admission.inflight != 0 || len(h.admission.peers) != 0 || out.Body.Len() != 0 {
			t.Fatal("canceled admission wrote or charged")
		}
	})
	t.Run("panic_and_reentry", func(t *testing.T) {
		s := fixtureService(t, envelope(validReceipt))
		h, r := receiptRouter(t, s)
		original := s.httpClient.Transport
		s.httpClient.Transport = roundTripFunc(func(*http.Request) (*http.Response, error) { panic("synthetic-private-panic") })
		b, ct := multipartImage(t, false)
		out := uploadRequest(r, b, ct, "192.0.2.1:2", context.Background())
		if out.Code != 500 || h.admission.inflight != 0 {
			t.Fatal("panic leaked permit")
		}
		s.httpClient.Transport = original
		out = uploadRequest(r, b, ct, "192.0.2.1:2", context.Background())
		if out.Code != 200 {
			t.Fatal("not readmitted")
		}
	})
}

func TestUploadSocketRelease(t *testing.T) {
	for _, kind := range []string{"malformed", "unsupported", "duplicate", "size", "context_deadline", "disconnect"} {
		t.Run(kind, func(t *testing.T) {
			s := fixtureService(t, envelope(validReceipt))
			h, router := receiptRouter(t, s)
			finished := make(chan struct{}, 1)
			closed := make(chan struct{}, 1)
			parent, cancel := context.WithCancel(context.Background())
			defer cancel()
			server := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				defer func() { finished <- struct{}{} }()
				if kind == "context_deadline" {
					ctx, c := context.WithTimeout(r.Context(), 30*time.Millisecond)
					defer c()
					r = r.WithContext(ctx)
				}
				router.ServeHTTP(w, r)
			}))
			p := safehttp.DefaultServerPolicy()
			server.Config.ReadTimeout = p.Read
			server.Config.ReadHeaderTimeout = p.ReadHeader
			server.Config.WriteTimeout = p.Write
			server.Config.IdleTimeout = p.Idle
			server.Config.BaseContext = func(net.Listener) context.Context { return parent }
			server.Config.ConnState = func(_ net.Conn, state http.ConnState) {
				if state == http.StateClosed {
					closed <- struct{}{}
				}
			}
			server.Start()
			defer server.Close()
			conn, err := net.Dial("tcp", server.Listener.Addr().String())
			if err != nil {
				t.Fatal(err)
			}
			defer conn.Close()
			_ = conn.SetDeadline(time.Now().Add(2 * time.Second))
			prefix := "--fixture\r\nContent-Disposition: form-data; name=\"image\"; filename=\"fixture.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n"
			data := prefix
			length := 100000
			switch kind {
			case "malformed":
				data = "--fixture\r\nBrokenHeader\r\n\r\n"
			case "unsupported":
				data += strings.Repeat("x", 512)
			case "duplicate":
				data += string(append([]byte{255, 216, 255}, bytes.Repeat([]byte{0}, 512)...)) + "\r\n" + prefix
			case "size":
				length = maxReceiptSize + 1
			}
			_, err = fmt.Fprintf(conn, "POST /parse HTTP/1.1\r\nHost: fixture\r\nContent-Type: multipart/form-data; boundary=fixture\r\nContent-Length: %d\r\n\r\n%s", length, data)
			if err != nil {
				t.Fatal(err)
			}
			if kind == "disconnect" {
				waitInflight(t, h, 1)
				_ = conn.Close()
			}
			if kind != "disconnect" {
				response, err := http.ReadResponse(bufio.NewReader(conn), nil)
				if err != nil {
					t.Fatal(err)
				}
				_, err = io.ReadAll(response.Body)
				_ = response.Body.Close()
				if err != nil {
					t.Fatal(err)
				}
				want := 400
				if kind == "size" {
					want = 413
				}
				if kind == "context_deadline" {
					want = 503
				}
				if response.StatusCode != want {
					t.Fatalf("status=%d want=%d", response.StatusCode, want)
				}
			}
			select {
			case <-finished:
			case <-time.After(time.Second):
				t.Fatal("actual upload/handler did not exit")
			}
			waitInflight(t, h, 0)
			select {
			case <-closed:
			case <-time.After(time.Second):
				t.Fatal("transport cleanup drained missing remainder")
			}
		})
	}
}

func waitInflight(t *testing.T, h *Handler, want int) {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	for {
		h.admission.mu.Lock()
		n := h.admission.inflight
		h.admission.mu.Unlock()
		if n == want {
			return
		}
		if time.Now().After(deadline) {
			t.Fatalf("inflight=%d want=%d", n, want)
		}
		time.Sleep(time.Millisecond)
	}
}

func TestHandlerSaturationAndCancellation(t *testing.T) {
	for _, reverse := range []bool{false, true} {
		t.Run(fmt.Sprint(reverse), func(t *testing.T) {
			s := fixtureService(t, "")
			arrived := make(chan struct{}, 2)
			var active sync.WaitGroup
			s.httpClient.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
				arrived <- struct{}{}
				<-r.Context().Done()
				return nil, r.Context().Err()
			})
			h, router := receiptRouter(t, s)
			b, ct := multipartImage(t, false)
			cancels := make([]context.CancelFunc, 2)
			done := make(chan struct{}, 2)
			for i := 0; i < 2; i++ {
				ctx, c := context.WithCancel(context.Background())
				cancels[i] = c
				active.Add(1)
				go func(i int) {
					defer active.Done()
					uploadRequest(router, b, ct, fmt.Sprintf("192.0.2.%d:44", i+1), ctx)
					done <- struct{}{}
				}(i)
			}
			<-arrived
			<-arrived
			out := uploadRequest(router, b, ct, "192.0.2.3:44", context.Background())
			if out.Code != 503 || out.Header().Get("Retry-After") != "1" {
				t.Fatal("not immediately saturated")
			}
			h.admission.mu.Lock()
			keys := len(h.admission.peers)
			h.admission.mu.Unlock()
			if keys != 2 {
				t.Fatal("denial grew state")
			}
			first := 0
			if reverse {
				first = 1
			}
			start := time.Now()
			cancels[first]()
			<-done
			waitInflight(t, h, 1)
			if time.Since(start) > 250*time.Millisecond {
				t.Fatal("permit release too late")
			}
			cancels[1-first]()
			<-done
			active.Wait()
			waitInflight(t, h, 0)
		})
	}
}

func TestUploadStreamedTotalCap(t *testing.T) {
	s := fixtureService(t, envelope(validReceipt))
	h, r := receiptRouter(t, s)
	var b bytes.Buffer
	mw := multipart.NewWriter(&b)
	p, _ := mw.CreateFormFile("image", "fixture.jpg")
	_, _ = p.Write(append([]byte{255, 216, 255}, bytes.Repeat([]byte{0}, maxReceiptSize)...))
	_ = mw.Close()
	body := &countingBody{Reader: bytes.NewReader(b.Bytes())}
	req := httptest.NewRequest("POST", "/parse", body)
	req.ContentLength = -1
	req.Header.Set("Content-Type", mw.FormDataContentType())
	req.RemoteAddr = "192.0.2.1:1"
	out := httptest.NewRecorder()
	r.ServeHTTP(out, req)
	if out.Code != 413 || body.read != maxReceiptSize+1 || h.admission.inflight != 0 {
		t.Fatalf("streamed status=%d bytes=%d", out.Code, body.read)
	}
}

func TestFailureWireMapping(t *testing.T) {
	for _, tc := range []struct {
		code   ParseErrorCode
		status int
	}{{ErrRateLimited, 429}, {ErrAuthFailed, 503}, {ErrInvalidRequest, 422}, {ErrImageTooLarge, 413}, {ErrOverloaded, 503}, {ErrProviderDown, 503}, {ErrBadResponse, 422}, {ErrInvalidPeer, 400}, {"synthetic-private-code", 422}} {
		t.Run(string(tc.code), func(t *testing.T) {
			r, err := safehttp.NewRouter("")
			if err != nil {
				t.Fatal(err)
			}
			r.GET("/failure", func(c *gin.Context) { writeFailure(c, &ParseError{Code: tc.code, RetryAfter: 60}) })
			out := httptest.NewRecorder()
			r.ServeHTTP(out, httptest.NewRequest("GET", "/failure", nil))
			if out.Code != tc.status || out.Header().Get("Retry-After") != "60" || strings.Contains(out.Body.String(), "synthetic") {
				t.Fatal("finite status/retry mapping")
			}
		})
	}
}
