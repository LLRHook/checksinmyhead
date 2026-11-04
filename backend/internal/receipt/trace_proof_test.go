package receipt

import (
	"context"
	"net/http/httptrace"
	"sync/atomic"
)

func httptraceContext(ctx context.Context, wrote *atomic.Bool) context.Context {
	return httptrace.WithClientTrace(ctx, &httptrace.ClientTrace{WroteRequest: func(httptrace.WroteRequestInfo) { wrote.Store(true) }})
}
