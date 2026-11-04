package receipt

import (
	"context"
	"io"
	"net/http"
	"net/http/httptrace"
	"sync"
	"sync/atomic"
)

// The transport may return early response headers before its write loop exits.
// Track body closure AND the completed write callback so admission cannot release
// while an upload is still writing. Dial/validation failures close the body without
// starting a write; WroteHeaders precedes body I/O in the HTTP/1 Request.write path.
type providerRequestBody struct {
	io.ReadCloser
	once sync.Once
	done chan struct{}
	err  error
}

func (b *providerRequestBody) Close() error {
	b.once.Do(func() { b.err = b.ReadCloser.Close(); close(b.done) })
	return b.err
}

type providerResponseBody struct {
	io.ReadCloser
	once   sync.Once
	finish func()
	err    error
}

func (b *providerResponseBody) Close() error {
	b.once.Do(func() { b.err = b.ReadCloser.Close(); b.finish() })
	return b.err
}

// redirectOpaqueTransport owns each request's native HTTP/1 I/O lifetime. It drops
// redirect targets before http.Client can parse them; Header.Del reads no value.
// The client's redirect callback provides an additional refusal guard.
type redirectOpaqueTransport struct{ transport *http.Transport }

func (t redirectOpaqueTransport) RoundTrip(r *http.Request) (*http.Response, error) {
	ctx, cancel := context.WithCancel(r.Context())
	body := &providerRequestBody{ReadCloser: r.Body, done: make(chan struct{})}
	var headers atomic.Bool
	written := make(chan struct{})
	var wroteOnce sync.Once
	ctx = httptrace.WithClientTrace(ctx, &httptrace.ClientTrace{
		WroteHeaders: func() { headers.Store(true) },
		WroteRequest: func(httptrace.WroteRequestInfo) { wroteOnce.Do(func() { close(written) }) },
	})
	request := r.Clone(ctx)
	request.Body = body
	finish := func() {
		cancel() // Also interrupts a writer when the provider responded early.
		<-body.done
		if headers.Load() {
			<-written
		}
	}
	response, err := t.transport.RoundTrip(request)
	if err != nil {
		finish()
		return nil, err
	}
	if response.StatusCode >= 300 && response.StatusCode < 400 {
		response.Header.Del("Location")
	}
	if response.StatusCode != http.StatusOK {
		// No error-body reads/drain; close the connection and join the actual writer.
		_ = response.Body.Close()
		finish()
		response.Body = http.NoBody
	} else {
		response.Body = &providerResponseBody{ReadCloser: response.Body, finish: finish}
	}
	return response, nil
}
