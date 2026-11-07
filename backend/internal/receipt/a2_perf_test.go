//go:build a2perf

package receipt

import (
	"backend/pkg/safehttp"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"runtime"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"testing"
	"time"
)

// Optional qualified local measurements; no external endpoint, shortened retention
// wait, global tuning or normal test-count inflation. Raw samples live in ignored
// evidence supplied by the driver.
func TestA2Measurements(t *testing.T) {
	type series struct {
		Path             string
		Run              int
		Samples          []float64
		Median, P95, Max float64
		Target           float64
		Met              bool
	}
	type memory struct {
		Slots                                                int
		IncrementalSnapshot, TotalAllocUpperBound, IdleDelta int64
		GoroutinesBefore, GoroutinesAfter                    int
		RSSHighWaterBefore, RSSHighWaterAfter                int64
	}
	record := struct {
		Go, OS, Arch                string
		GOMAXPROCS, NumCPU          int
		Warmups, Samples            int
		Runs                        []series
		Memory                      []memory
		LimiterBytes                uint64
		RetentionSeconds            int
		UploadTransportCloseSamples []float64
	}{Go: runtime.Version(), OS: runtime.GOOS, Arch: runtime.GOARCH, GOMAXPROCS: runtime.GOMAXPROCS(0), NumCPU: runtime.NumCPU(), Warmups: 5, Samples: 100, RetentionSeconds: 75}
	measure := func(name string, target float64, f func()) {
		for run := 1; run <= 3; run++ {
			for i := 0; i < 5; i++ {
				f()
			}
			s := series{Path: name, Run: run, Target: target}
			for i := 0; i < 100; i++ {
				start := time.Now()
				f()
				s.Samples = append(s.Samples, float64(time.Since(start).Nanoseconds())/1e6)
			}
			sorted := append([]float64(nil), s.Samples...)
			sort.Float64s(sorted)
			s.Median = sorted[49]
			s.P95 = sorted[94]
			s.Max = sorted[99]
			s.Met = s.P95 < target
			record.Runs = append(record.Runs, s)
			t.Logf("%s run%d p95=%.3f target=%.3f", name, run, s.P95, target)
		}
	}
	a := newAdmission(policy{2})
	defer a.close()
	now := time.Now()
	measure("admission", 5, func() {
		now = now.Add(time.Minute)
		r, e := a.acquire(context.Background(), "192.0.2.1", func() time.Time { return now })
		if e != nil {
			t.Fatal(e)
		}
		r()
	})
	r1, _ := a.acquire(context.Background(), "192.0.2.2", func() time.Time { return now })
	r2, _ := a.acquire(context.Background(), "192.0.2.3", func() time.Time { return now })
	measure("slot_reject", 5, func() {
		if r, e := a.acquire(context.Background(), "192.0.2.4", func() time.Time { return now }); r != nil || e.Code != ErrOverloaded {
			t.Fatal("saturation")
		}
	})
	r2()
	r1()
	s := fixtureService(t, envelope(validReceipt))
	_, router := receiptRouter(t, s)
	makeUpload := func(size int) ([]byte, string) {
		var b bytes.Buffer
		w := multipart.NewWriter(&b)
		p, _ := w.CreateFormFile("image", "fixture.jpg")
		_, _ = p.Write(append([]byte{255, 216, 255}, bytes.Repeat([]byte{0}, size-3)...))
		_ = w.Close()
		return b.Bytes(), w.FormDataContentType()
	}
	small, smallCT := makeUpload(4096)
	maxBody, maxCT := makeUpload(maxReceiptSize - 242) // adjusted below to exactly TOTAL 10 MiB
	// Boundary/header overhead is measured rather than assumed.
	overhead := len(maxBody) - (maxReceiptSize - 242)
	maxBody, maxCT = makeUpload(maxReceiptSize - overhead)
	if len(maxBody) != maxReceiptSize {
		t.Fatal("maximum total fixture size")
	}
	var seq atomic.Int64
	path := func(body []byte, ct string) {
		ip := seq.Add(1)
		peer := fmt.Sprintf("10.%d.%d.%d:1234", (ip>>16)&255, (ip>>8)&255, ip&255)
		out := uploadRequest(router, body, ct, peer, context.Background())
		if out.Code != 200 {
			t.Fatalf("success status %d", out.Code)
		}
	}
	items := strings.Repeat(`{"name":"`+strings.Repeat("界", 255)+`","price":-1,"quantity":1},`, 499) + `{"name":"last","price":1,"quantity":1}`
	text := `{"items":[` + items + `],"currency_code":"JPY","total":-498}`
	text += strings.Repeat(" ", maxTextSize-len(text))
	response := envelope(text)
	response += strings.Repeat(" ", maxResponseSize-len(response))
	s.httpClient.Transport = roundTripFunc(func(r *http.Request) (*http.Response, error) {
		return &http.Response{StatusCode: 200, Header: make(http.Header), Body: io.NopCloser(strings.NewReader(response)), Request: r}, nil
	})
	measure("representative_upload_prep_parse", 250, func() { path(small, smallCT) })
	measure("maximum_upload_prep_parse", 250, func() { path(maxBody, maxCT) })
	measure("maximum_receipt_parse", 250, func() {
		if _, err := parseResponseText(text); err != nil {
			t.Fatal(err)
		}
	})
	measure("shape_reject", 5, func() {
		if _, err := parseResponseText(`{"items":[{"quantity":501}]}`); err == nil {
			t.Fatal("quantity accepted")
		}
	})
	// Real local TLS response-body cancellation, measured from observed cancel to
	// handler/provider/permit exit, excluding intentionally blocked I/O time.
	arrived := make(chan struct{}, 1)
	provider, _ := tlsService(t, func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.Copy(io.Discard, r.Body)
		w.WriteHeader(200)
		w.(http.Flusher).Flush()
		arrived <- struct{}{}
		<-r.Context().Done()
	})
	_, cancelRouter := receiptRouter(t, provider)
	for run := 1; run <= 3; run++ {
		series := series{Path: "observed_cancel_release", Run: run, Target: 250}
		for i := -5; i < 100; i++ {
			ctx, cancel := context.WithCancel(context.Background())
			done := make(chan struct{})
			ip := seq.Add(1)
			go func() {
				defer close(done)
				_ = uploadRequest(cancelRouter, small, smallCT, fmt.Sprintf("10.%d.%d.%d:1", (ip>>16)&255, (ip>>8)&255, ip&255), ctx)
			}()
			<-arrived
			start := time.Now()
			cancel()
			<-done
			if i >= 0 {
				series.Samples = append(series.Samples, float64(time.Since(start).Nanoseconds())/1e6)
			}
		}
		sorted := append([]float64(nil), series.Samples...)
		sort.Float64s(sorted)
		series.Median = sorted[49]
		series.P95 = sorted[94]
		series.Max = sorted[99]
		series.Met = series.Max <= 250
		record.Runs = append(record.Runs, series)
	}
	// Actual incomplete TCP upload cancellation, including handler/permit exit
	// AND StateClosed while the client still withholds the remainder.
	type uploadObservation struct {
		cancel   context.CancelFunc
		finished <-chan struct{}
		peer     string
	}
	observations := make(chan uploadObservation, 1)
	socketClosed := make(chan struct{}, 315)
	var closeMu sync.Mutex
	closeStarts := make(map[string]time.Time)
	uploadService := fixtureService(t, envelope(validReceipt))
	_, uploadRouter := receiptRouter(t, uploadService)
	uploadServer := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithCancel(r.Context())
		defer cancel()
		finished := make(chan struct{})
		defer close(finished)
		socketPeer := r.RemoteAddr
		ip := seq.Add(1)
		r = r.WithContext(ctx)
		// Distinct synthetic peers keep this I/O measurement independent of quota.
		r.RemoteAddr = fmt.Sprintf("198.18.%d.%d:1", (ip>>8)&255, ip&255)
		r.Body = &secondReadSignal{ReadCloser: r.Body, signal: func() { observations <- uploadObservation{cancel, finished, socketPeer} }}
		uploadRouter.ServeHTTP(w, r)
	}))
	uploadPolicy := safehttp.DefaultServerPolicy()
	uploadServer.Config.ReadHeaderTimeout = uploadPolicy.ReadHeader
	uploadServer.Config.ReadTimeout = uploadPolicy.Read
	uploadServer.Config.WriteTimeout = uploadPolicy.Write
	uploadServer.Config.ConnState = func(conn net.Conn, state http.ConnState) {
		if state == http.StateClosed {
			closeMu.Lock()
			if start, ok := closeStarts[conn.RemoteAddr().String()]; ok {
				record.UploadTransportCloseSamples = append(record.UploadTransportCloseSamples, float64(time.Since(start).Nanoseconds())/1e6)
			}
			closeMu.Unlock()
			socketClosed <- struct{}{}
		}
	}
	uploadServer.Start()
	defer uploadServer.Close()
	for run := 1; run <= 3; run++ {
		series := series{Path: "observed_upload_cancel_release", Run: run, Target: 250}
		for i := -5; i < 100; i++ {
			conn, err := net.Dial("tcp", uploadServer.Listener.Addr().String())
			if err != nil {
				t.Fatal(err)
			}
			prefix := "--fixture\r\nContent-Disposition: form-data; name=\"image\"; filename=\"fixture.jpg\"\r\n\r\n" + string(append([]byte{255, 216, 255}, make([]byte, 512)...))
			_, err = fmt.Fprintf(conn, "POST /parse HTTP/1.1\r\nHost: fixture\r\nContent-Type: multipart/form-data; boundary=fixture\r\nContent-Length: 10000\r\n\r\n%s", prefix)
			if err != nil {
				_ = conn.Close()
				t.Fatal(err)
			}
			var observed uploadObservation
			select {
			case observed = <-observations:
			case <-time.After(time.Second):
				_ = conn.Close()
				t.Fatal("upload did not block in actual body read")
			}
			start := time.Now()
			closeMu.Lock()
			closeStarts[observed.peer] = start
			closeMu.Unlock()
			observed.cancel()
			select {
			case <-observed.finished:
			case <-time.After(time.Second):
				_ = conn.Close()
				t.Fatal("upload handler/permit did not exit")
			}
			if i >= 0 {
				series.Samples = append(series.Samples, float64(time.Since(start).Nanoseconds())/1e6)
			}
			_ = conn.Close()
		}
		sorted := append([]float64(nil), series.Samples...)
		sort.Float64s(sorted)
		series.Median = sorted[49]
		series.P95 = sorted[94]
		series.Max = sorted[99]
		series.Met = series.Max <= 250
		record.Runs = append(record.Runs, series)
	}
	// net/http can deliberately wait 500ms for TCP RST avoidance after the
	// synchronous read/callback/permit have exited. Observe and join every transport
	// close separately; do not label that timer as continued OCR work or hide it.
	for i := 0; i < 315; i++ {
		select {
		case <-socketClosed:
		case <-time.After(time.Second):
			t.Fatal("upload transport cleanup stalled")
		}
	}
	uploadServer.Close()
	// Fill actual admission state; retained heap after two GCs, not allocations.
	limiter := newAdmission(policy{2})
	runtime.GC()
	runtime.GC()
	var before, after runtime.MemStats
	runtime.ReadMemStats(&before)
	for i := 0; i < maxPeerKeys; i++ {
		r, e := limiter.acquire(context.Background(), fmt.Sprintf("10.%d.%d.1", i>>8, i&255), func() time.Time { return time.Now() })
		if e != nil {
			t.Fatal(e)
		}
		r()
	}
	rateNow := time.Now()
	for i := 0; i < 10; i++ {
		release, e := limiter.acquire(context.Background(), "10.0.0.1", func() time.Time { return rateNow })
		if e != nil {
			break
		}
		release()
	}
	measure("quota_reject", 5, func() {
		if release, e := limiter.acquire(context.Background(), "10.0.0.1", func() time.Time { return rateNow }); release != nil || e.Code != ErrRateLimited {
			t.Fatal("quota rejection")
		}
	})
	existing := 1
	measure("full_table_existing_admission", 5, func() {
		i := existing
		existing++
		release, e := limiter.acquire(context.Background(), fmt.Sprintf("10.%d.%d.1", i>>8, i&255), func() time.Time { return rateNow })
		if e != nil {
			t.Fatal(e)
		}
		release()
	})
	measure("full_table_new_peer_reject", 5, func() {
		if release, e := limiter.acquire(context.Background(), "198.51.100.1", func() time.Time { return rateNow }); release != nil || e.Code != ErrOverloaded {
			t.Fatal("table rejection")
		}
	})
	measure("invalid_peer_reject", 5, func() {
		if release, e := limiter.acquire(context.Background(), "invalid", func() time.Time { return rateNow }); release != nil || e.Code != ErrInvalidPeer {
			t.Fatal("peer rejection")
		}
	})
	runtime.GC()
	runtime.GC()
	runtime.ReadMemStats(&after)
	record.LimiterBytes = after.HeapAlloc - before.HeapAlloc
	runtime.KeepAlive(limiter)
	limiter.close()
	limiter = nil
	// Compare idle retention with the PRE-burst baseline, retaining all external
	// fixture buffers across both readings so their reclamation cannot hide a leak.
	runtime.GC()
	runtime.GC()
	var retentionBase runtime.MemStats
	runtime.ReadMemStats(&retentionBase)
	retentionG := runtime.NumGoroutine()
	rssHighWater := func() int64 {
		var usage syscall.Rusage
		if syscall.Getrusage(syscall.RUSAGE_SELF, &usage) != nil {
			t.Fatal("RSS observation unavailable")
		}
		n := usage.Maxrss
		if runtime.GOOS == "linux" {
			n *= 1024
		}
		return n
	}
	for _, slots := range []int{1, 2} {
		// Retained fixture buffers are baseline inputs; per-operation allocations start
		// before upload. Sampling is a lower bound on true peak; TotalAlloc bounds all
		// allocations over this burst conservatively (not just live bytes).
		service, memoryServer := tlsService(t, func(w http.ResponseWriter, r *http.Request) {
			_, _ = io.Copy(io.Discard, r.Body)
			w.Header().Set("Content-Type", "application/json")
			_, _ = io.WriteString(w, response)
		})
		h, rr := receiptRouter(t, service)
		var wg sync.WaitGroup
		runtime.GC()
		runtime.GC()
		runtime.ReadMemStats(&before)
		g := runtime.NumGoroutine()
		rssBefore := rssHighWater()
		var peak atomic.Uint64
		peak.Store(before.HeapAlloc)
		stop := make(chan struct{})
		samplerDone := make(chan struct{})
		go func() {
			defer close(samplerDone)
			ticker := time.NewTicker(time.Millisecond)
			defer ticker.Stop()
			for {
				select {
				case <-stop:
					return
				case <-ticker.C:
					var m runtime.MemStats
					runtime.ReadMemStats(&m)
					for old := peak.Load(); m.HeapAlloc > old && !peak.CompareAndSwap(old, m.HeapAlloc); old = peak.Load() {
					}
					runtime.Gosched()
				}
			}
		}()
		for j := 0; j < slots; j++ {
			wg.Add(1)
			go func(j int) {
				defer wg.Done()
				out := uploadRequest(rr, maxBody, maxCT, fmt.Sprintf("192.0.2.%d:1", j+1), context.Background())
				if out.Code != 200 {
					t.Errorf("burst status=%d", out.Code)
				}
			}(j)
		}
		wg.Wait()
		close(stop)
		<-samplerDone
		runtime.ReadMemStats(&after)
		record.Memory = append(record.Memory, memory{Slots: slots, IncrementalSnapshot: int64(peak.Load()) - int64(before.HeapAlloc), TotalAllocUpperBound: int64(after.TotalAlloc - before.TotalAlloc), GoroutinesBefore: g, RSSHighWaterBefore: rssBefore, RSSHighWaterAfter: rssHighWater()})
		runtime.KeepAlive(h)
		h.Close()
		memoryServer.Close()
	}
	// Both sweeper and pooled transport are lifecycle-owned. Keep the default
	// lifecycle alive during idle retention so fixed goroutines are included.
	runtime.GC()
	runtime.GC()
	time.Sleep(75 * time.Second)
	runtime.GC()
	runtime.GC()
	runtime.ReadMemStats(&after)
	for i := range record.Memory {
		record.Memory[i].IdleDelta = int64(after.HeapAlloc) - int64(retentionBase.HeapAlloc)
		record.Memory[i].GoroutinesAfter = runtime.NumGoroutine()
		record.Memory[i].GoroutinesBefore = retentionG
	}
	runtime.KeepAlive(maxBody)
	runtime.KeepAlive(small)
	runtime.KeepAlive(response)
	raw, _ := json.MarshalIndent(record, "", "  ")
	file := os.Getenv("OCR_MEASUREMENT_OUTPUT")
	if file == "" {
		t.Fatal("explicit ignored measurement output required")
	}
	if err := os.WriteFile(file, append(raw, '\n'), 0600); err != nil {
		t.Fatal(err)
	}
}

// Signals once when multipart buffering needs the absent remainder. The actual
// server body Read remains synchronous and is interrupted by ResponseController.
type secondReadSignal struct {
	io.ReadCloser
	reads  int
	signal func()
}

func (r *secondReadSignal) Read(p []byte) (int, error) {
	r.reads++
	if r.reads == 2 {
		r.signal()
	}
	return r.ReadCloser.Read(p)
}
