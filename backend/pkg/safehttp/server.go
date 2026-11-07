package safehttp

import (
	"context"
	"errors"
	"log"
	"net"
	"net/http"
	"time"
)

// ServerPolicy is injectable for real TCP tests. Both binaries use DefaultServerPolicy.
type ServerPolicy struct {
	ReadHeader, Read, Write, Idle, Shutdown time.Duration
	MaxHeaderBytes                          int
}

func DefaultServerPolicy() ServerPolicy {
	return ServerPolicy{5 * time.Second, 20 * time.Second, 50 * time.Second, 60 * time.Second, 25 * time.Second, 32 << 10}
}

var (
	errListen   = errors.New("HTTP listener unavailable")
	errServe    = errors.New("HTTP server failed")
	errShutdown = errors.New("HTTP shutdown deadline exceeded")
)

// opaqueServerLog never stores or forwards net/http's input. The standard library
// may format an error before Write; this sink prevents that text reaching output.
type opaqueServerLog struct{}

func (opaqueServerLog) Write(p []byte) (int, error) {
	log.Print("event=http_server category=transport route=other")
	return len(p), nil
}
func newServer(ctx context.Context, address string, handler http.Handler, p ServerPolicy) *http.Server {
	return &http.Server{Addr: address, Handler: handler, ReadHeaderTimeout: p.ReadHeader, ReadTimeout: p.Read, WriteTimeout: p.Write, IdleTimeout: p.Idle, MaxHeaderBytes: p.MaxHeaderBytes,
		BaseContext: func(net.Listener) context.Context { return ctx }, ErrorLog: log.New(opaqueServerLog{}, "", 0)}
}

// Serve owns listener shutdown. The caller owns signal cancellation, which reaches
// every request via BaseContext before Shutdown waits for active handlers.
func Serve(ctx context.Context, address string, handler http.Handler) error {
	listener, err := net.Listen("tcp", address)
	if err != nil {
		return errListen
	}
	return serve(ctx, listener, handler, DefaultServerPolicy())
}
func serve(parent context.Context, listener net.Listener, handler http.Handler, p ServerPolicy) error {
	ctx, cancel := context.WithCancel(parent)
	defer cancel()
	server := newServer(ctx, listener.Addr().String(), handler, p)
	done := make(chan error, 1)
	go func() { done <- server.Serve(listener) }()
	select {
	case err := <-done:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return errServe
	case <-ctx.Done():
		shutdown, cancelShutdown := context.WithTimeout(context.Background(), p.Shutdown)
		defer cancelShutdown()
		err := server.Shutdown(shutdown)
		// Close also terminates connections when handlers outlive the grace period.
		_ = server.Close()
		serveErr := <-done
		if err != nil {
			return errShutdown
		}
		if serveErr != nil && !errors.Is(serveErr, http.ErrServerClosed) {
			return errServe
		}
		return nil
	}
}
