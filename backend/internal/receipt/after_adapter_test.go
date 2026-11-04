package receipt

import (
	"context"
	"crypto/tls"
	"net"
)

func proofSetDial(s *Service, f func(context.Context, string, string) (net.Conn, error)) {
	s.transport.dialContext = f
}
func proofSetTLS(s *Service, c *tls.Config) { s.transport.tlsConfig = c }
func proofSetConnect(s *Service, f func(context.Context, string, string) (net.Conn, error)) {
	s.transport.connectTLS = f
}
func proofPrepareFinal(s *Service) {} // actual private production owner

func proofSetDNS(s *Service, dnsDial, tcpDial func(context.Context, string, string) (net.Conn, error)) func() {
	proofSetDial(s, func(ctx context.Context, n, a string) (net.Conn, error) {
		return providerDialWithDNS(ctx, n, a, dnsDial, tcpDial)
	})
	return func() {}
}
