package receipt

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestOwnershipFraming(t *testing.T) {
	body := envelope(validReceipt)
	chunk := func(body, tail string) string {
		return "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nTrailer: X-Final\r\n\r\n" + fmt.Sprintf("%x\r\n%s\r\n0\r\n", len(body), body) + tail
	}
	plain := func(body string) string {
		return fmt.Sprintf("HTTP/1.1 200 OK\r\nContent-Length: %d\r\n\r\n%s", len(body), body)
	}
	maxBody := body + strings.Repeat(" ", maxResponseSize-len(body))
	maxText := envelope(validReceipt + strings.Repeat(" ", maxTextSize-len(validReceipt)))
	var compressed bytes.Buffer
	z := gzip.NewWriter(&compressed)
	z.Write([]byte(body))
	z.Close()
	gz := compressed.String()
	info := "HTTP/1.1 103 Early Hints\r\nLink: <synthetic>\r\n\r\n"
	headerPrefix := fmt.Sprintf("HTTP/1.1 200 OK\r\nContent-Length: %d\r\nX-Pad: ", len(body))
	maxHeader := headerPrefix + strings.Repeat("h", providerHeaderLimit-len(headerPrefix)-4) + "\r\n\r\n" + body
	for _, tc := range []struct {
		name, wire string
		code       ParseErrorCode
	}{
		{"content_length", plain(body), ""}, {"chunked_trailer", chunk(body, "X-Final: yes\r\n\r\n"), ""},
		{"eof_delimited", "HTTP/1.1 200 OK\r\nConnection: close\r\n\r\n" + body, ""},
		{"header_exact_32KiB", maxHeader, ""}, {"header_plus_one", strings.Replace(maxHeader, "X-Pad: ", "X-Pad: h", 1), ErrProviderDown},
		{"decoded_exact_2MiB", plain(maxBody), ""}, {"text_exact_512KiB", plain(maxText), ""},
		{"infos_4", strings.Repeat(info, 4) + plain(body), ""}, {"infos_5", strings.Repeat(info, 5) + plain(body), ErrProviderDown},
		{"info_aggregate_cap", strings.Repeat(info, 4) + maxHeader, ErrProviderDown},
		{"upgrade_101", "HTTP/1.1 101 Switching Protocols\r\nUpgrade: synthetic\r\n\r\n", ErrProviderDown},
		{"conflicting_lengths", "HTTP/1.1 200 OK\r\nContent-Length: 1\r\nContent-Length: 2\r\n\r\n{}", ErrProviderDown},
		{"truncated_length", "HTTP/1.1 200 OK\r\nContent-Length: 10000\r\n\r\n" + body, ErrBadResponse},
		{"invalid_chunk", "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nZ\r\n", ErrBadResponse},
		{"truncated_chunk", chunk(body, "X-Final: yes\r\n"), ErrBadResponse},
		{"oversize_trailer", chunk(body, "X-Final: "+strings.Repeat("t", 5000)+"\r\n\r\n"), ErrBadResponse},
		{"invalid_transfer", "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked, gzip\r\n\r\n", ErrProviderDown},
		{"bad_status", "SYNTHETIC_PRIVATE_RECEIPT\r\n\r\n", ErrProviderDown},
		{"gzip_chunked", strings.Replace(chunk(gz, "X-Final: yes\r\n\r\n"), "Trailer: X-Final\r\n", "Trailer: X-Final\r\nContent-Encoding: gzip\r\n", 1), ""},
		{"gzip_case", fmt.Sprintf("HTTP/1.1 200 OK\r\nContent-Encoding: GZip\r\nContent-Length: %d\r\n\r\n%s", len(gz), gz), ""},
		{"gzip_bad_header", "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: 7\r\n\r\nnotgzip", ErrBadResponse},
		{"gzip_truncated", fmt.Sprintf("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: %d\r\n\r\n%s", len(gz)-3, gz[:len(gz)-3]), ErrBadResponse},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var posts atomic.Int32
			finished := make(chan struct{})
			s, _, _ := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
				defer close(finished)
				posts.Add(1)
				io.Copy(io.Discard, r.Body)
				c, b, e := w.(http.Hijacker).Hijack()
				if e != nil {
					return
				}
				defer c.Close()
				io.WriteString(b, tc.wire)
				b.Flush()
			})
			got, e := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
			proofWait(t, finished, "framing fixture cleanup")
			if tc.code == "" {
				if e != nil || got == nil {
					t.Fatalf("valid wire rejected: %v", e)
				}
			} else {
				requireCode(t, e, tc.code)
			}
			if posts.Load() != 1 {
				t.Fatal("wire attempt count")
			}
		})
	}
}

func TestOwnershipVerifiedTLS(t *testing.T) {
	for _, name := range []string{"verified_http1", "bad_CA", "bad_hostname", "insecure_rejected", "TLS12"} {
		t.Run(name, func(t *testing.T) {
			var posts atomic.Int32
			var version atomic.Uint32
			var protocol atomic.Value
			s, _, cfg := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
				posts.Add(1)
				version.Store(uint32(r.TLS.Version))
				protocol.Store(r.Proto + "/" + r.TLS.NegotiatedProtocol)
				io.Copy(io.Discard, r.Body)
				io.WriteString(w, envelope(validReceipt))
			})
			switch name {
			case "bad_CA":
				cfg.RootCAs = x509.NewCertPool()
			case "bad_hostname":
				cfg.ServerName = "synthetic-wrong.invalid"
			case "insecure_rejected":
				cfg.InsecureSkipVerify = true
			case "TLS12":
				cfg.MaxVersion = tls.VersionTLS12
			}
			_, e := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
			if name == "verified_http1" || name == "TLS12" {
				if e != nil {
					t.Fatal(e)
				}
				if posts.Load() != 1 || version.Load() < tls.VersionTLS12 || protocol.Load() != "HTTP/1.1/http/1.1" {
					t.Fatal("TLS/wire contract")
				}
			} else {
				requireCode(t, e, ErrProviderDown)
				if posts.Load() != 0 {
					t.Fatal("unverified TLS sent POST")
				}
			}
		})
	}
}

// Real HTTP server responds before reading a 13MiB encoded upload. TCP send
// buffering cannot absorb it all; response completion must interrupt/join writer.
func TestOwnershipEarlyResponse(t *testing.T) {
	for _, status := range []int{200, 401} {
		t.Run(fmt.Sprint(status), func(t *testing.T) {
			exited := make(chan struct{})
			var posts atomic.Int32
			s, _, _ := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
				defer close(exited)
				posts.Add(1)
				c, b, e := w.(http.Hijacker).Hijack()
				if e != nil {
					return
				}
				defer c.Close()
				body := ""
				if status == 200 {
					body = envelope(validReceipt)
				}
				fmt.Fprintf(b, "HTTP/1.1 %d Synthetic\r\nContent-Length: %d\r\n\r\n%s", status, len(body), body)
				b.Flush()
				io.Copy(io.Discard, c)
			})
			ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
			defer cancel()
			got, e := s.Parse(ctx, make([]byte, maxReceiptSize), "image/jpeg")
			proofWait(t, exited, "early fixture closed")
			if status == 200 {
				if e != nil || got == nil {
					t.Fatalf("early200: %v", e)
				}
			} else {
				requireCode(t, e, ErrAuthFailed)
			}
			if ctx.Err() != nil || posts.Load() != 1 {
				t.Fatal("early response waited for whole upload deadline/replayed")
			}
		})
	}
}

func TestOwnershipPoolCap(t *testing.T) {
	for _, cap := range []int{1, 2, 8} {
		t.Run(fmt.Sprint(cap), func(t *testing.T) {
			release, free := proofGate(t)
			arrived := make(chan struct{}, cap)
			var posts, dials, live, peak atomic.Int32
			s, server, cfg := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
				posts.Add(1)
				io.Copy(io.Discard, r.Body)
				arrived <- struct{}{}
				<-release
				io.WriteString(w, envelope(validReceipt))
			})
			// NewService's real slot value is set by its policy; this fixture reconstructs
			// it with the selected public configuration, retaining dial/CA injection only.
			s.Close()
			t.Setenv("OCR_MAX_INFLIGHT", fmt.Sprint(cap))
			var e error
			s, e = NewService()
			if e != nil {
				t.Fatal(e)
			}
			t.Cleanup(s.Close)
			proofSetTLS(s, cfg)
			proofSetDial(s, func(ctx context.Context, _, _ string) (net.Conn, error) {
				dials.Add(1)
				c, e := (&net.Dialer{}).DialContext(ctx, "tcp", server.Listener.Addr().String())
				if e != nil {
					return nil, e
				}
				v := live.Add(1)
				for p := peak.Load(); v > p && !peak.CompareAndSwap(p, v); p = peak.Load() {
				}
				return &proofCountClose{Conn: c, live: &live}, nil
			})
			done := make(chan error, cap)
			for i := 0; i < cap; i++ {
				go func() { _, e := s.Parse(context.Background(), []byte("fixture"), "image/jpeg"); done <- e }()
			}
			defer func() { free(); s.Close() }()
			for i := 0; i < cap; i++ {
				select {
				case <-arrived:
				case <-time.After(2 * time.Second):
					free()
					t.Fatal("cap fixture not arrived")
				}
			}
			overflow, cancelOverflow := context.WithTimeout(context.Background(), 200*time.Millisecond)
			defer cancelOverflow()
			_, e = s.Parse(overflow, []byte("overflow"), "image/jpeg")
			requireCode(t, e, ErrProviderDown)
			if dials.Load() != int32(cap) || live.Load() != int32(cap) {
				t.Fatal("cap grew while occupied")
			}
			free()
			for i := 0; i < cap; i++ {
				select {
				case e := <-done:
					if e != nil {
						t.Error(e)
					}
				case <-time.After(2 * time.Second):
					t.Fatal("cap cleanup")
				}
			}
			for i := 0; i < cap; i++ {
				if _, e := s.Parse(context.Background(), []byte("manual"), "image/jpeg"); e != nil {
					t.Fatal(e)
				}
				<-arrived
			}
			if dials.Load() != int32(cap) || peak.Load() > int32(cap) || posts.Load() != int32(cap*2) {
				t.Fatalf("reuse/cap: dials=%d peak=%d posts=%d", dials.Load(), peak.Load(), posts.Load())
			}
			s.Close()
			if live.Load() != 0 {
				t.Fatal("open socket after Close")
			}
			s.transport.mu.Lock()
			n := s.transport.count
			idle := len(s.transport.idle)
			s.transport.mu.Unlock()
			if n != 0 || idle != 0 {
				t.Fatal("pool reservations retained")
			}
			t.Logf("proof: cap=%d dials=%d peak_open=%d wire_POSTs=%d final_open=%d", cap, dials.Load(), peak.Load(), posts.Load(), live.Load())
		})
	}
}

type proofCountClose struct {
	net.Conn
	live *atomic.Int32
	once sync.Once
}

func (c *proofCountClose) Close() error {
	var e error
	c.once.Do(func() { e = c.Conn.Close(); c.live.Add(-1) })
	return e
}

func TestOwnershipIdleAndClose(t *testing.T) {
	t.Run("timer_expiry", func(t *testing.T) {
		s, server, _ := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
			io.Copy(io.Discard, r.Body)
			io.WriteString(w, envelope(validReceipt))
		})
		s.transport.idleTimeout = 40 * time.Millisecond
		closed := make(chan struct{})
		var once sync.Once
		proofSetDial(s, func(ctx context.Context, _, _ string) (net.Conn, error) {
			c, e := (&net.Dialer{}).DialContext(ctx, "tcp", server.Listener.Addr().String())
			if e != nil {
				return nil, e
			}
			return &proofObserveClose{Conn: c, closed: closed, once: &once}, nil
		})
		if _, e := s.Parse(context.Background(), []byte("fixture"), "image/jpeg"); e != nil {
			t.Fatal(e)
		}
		proofWait(t, closed, "idle timer socket close")
		s.Close()
		proofWait(t, s.transport.done, "idle worker join")
		s.transport.mu.Lock()
		n := s.transport.count
		s.transport.mu.Unlock()
		if n != 0 {
			t.Fatal("timer reservation retained")
		}
	})
	t.Run("Close_active_and_idempotent", func(t *testing.T) {
		arrived := make(chan struct{})
		serverDone := make(chan struct{})
		s, _, _ := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
			defer close(serverDone)
			io.Copy(io.Discard, r.Body)
			close(arrived)
			<-r.Context().Done()
		})
		done := make(chan error, 1)
		go func() { _, e := s.Parse(context.Background(), []byte("fixture"), "image/jpeg"); done <- e }()
		proofWait(t, arrived, "Close active start")
		closed := make(chan struct{})
		go func() { defer close(closed); s.Close() }()
		proofWait(t, closed, "Close joins active IO")
		requireCode(t, <-done, ErrProviderDown)
		proofWait(t, serverDone, "Close fixture exit")
		s.Close()
		_, e := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
		requireCode(t, e, ErrProviderDown)
	})
	t.Run("idle_unsolicited_no_replay", func(t *testing.T) {
		suffix, release := proofGate(t)
		sent := make(chan struct{})
		finished := make(chan struct{})
		var posts, dials atomic.Int32
		var second atomic.Bool
		posted := make(chan struct{})
		s, server, cfg := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
			posts.Add(1)
			io.Copy(io.Discard, r.Body)
			c, b, e := w.(http.Hijacker).Hijack()
			if e != nil {
				return
			}
			defer c.Close()
			defer close(finished)
			body := envelope(validReceipt)
			fmt.Fprintf(b, "HTTP/1.1 200 OK\r\nContent-Length: %d\r\n\r\n%s", len(body), body)
			b.Flush()
			<-suffix
			io.WriteString(b, "SYNTHETIC_IDLE_PRIVATE")
			b.Flush()
			close(sent)
			if next, e := http.ReadRequest(b.Reader); e == nil {
				if next.Method == "POST" {
					posts.Add(1)
				}
				io.Copy(io.Discard, next.Body)
			}
		})
		proofSetConnect(s, func(ctx context.Context, _, _ string) (net.Conn, error) {
			dials.Add(1)
			c, e := (&tls.Dialer{Config: cfg}).DialContext(ctx, "tcp", server.Listener.Addr().String())
			if e != nil {
				return nil, e
			}
			return &proofSecondReadConn{Conn: c, second: &second, posted: posted}, nil
		})
		if _, e := s.Parse(context.Background(), []byte("fixture"), "image/jpeg"); e != nil {
			t.Fatal(e)
		}
		release()
		proofWait(t, sent, "unsolicited bytes sent")
		s.transport.mu.Lock()
		if len(s.transport.idle) != 1 {
			s.transport.mu.Unlock()
			t.Fatal("no actual idle connection")
		}
		idle := s.transport.idle[0]
		s.transport.mu.Unlock()
		proofWait(t, idle.done, "idle watcher saw unsolicited data")
		second.Store(true)
		_, e := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
		requireCode(t, e, ErrProviderDown)
		s.Close()
		proofWait(t, finished, "idle fixture cleanup")
		t.Logf("proof: dirty idle wire_POSTs=%d TLS_connections=%d", posts.Load(), dials.Load())
		if posts.Load() != 1 || dials.Load() != 1 {
			t.Fatal("stale connection triggered another POST/dial")
		}
	})
}

type proofObserveClose struct {
	net.Conn
	closed chan struct{}
	once   *sync.Once
}

func (c *proofObserveClose) Close() error {
	e := c.Conn.Close()
	c.once.Do(func() { close(c.closed) })
	return e
}

// Synthetic DNS fixture only. Native Resolver does all production DNS parsing.
func proofDNSAnswer(t *testing.T, ctx context.Context, n, a string) (net.Conn, error) {
	c, peer := net.Pipe()
	done := make(chan struct{})
	go func() {
		defer close(done)
		defer peer.Close()
		var size [2]byte
		if _, e := io.ReadFull(peer, size[:]); e != nil {
			return
		}
		q := make([]byte, int(binary.BigEndian.Uint16(size[:])))
		if _, e := io.ReadFull(peer, q); e != nil {
			return
		}
		if len(q) < 16 {
			return
		}
		answer := append([]byte(nil), q...)
		answer[2] = 0x81
		answer[3] = 0x80
		answer[6] = 0
		answer[7] = 0
		// Queries can include EDNS; echo only the question, then a fixed A answer.
		pos := 12
		for pos < len(q) && q[pos] != 0 {
			pos += int(q[pos]) + 1
		}
		pos += 5
		if pos > len(q) {
			return
		}
		answer = answer[:pos]
		answer[10] = 0
		answer[11] = 0
		if binary.BigEndian.Uint16(q[pos-4:pos-2]) == 1 {
			answer[7] = 1
			answer = append(answer, 0xc0, 0x0c, 0, 1, 0, 1, 0, 0, 0, 0, 0, 4, 127, 0, 0, 1)
		}
		binary.BigEndian.PutUint16(size[:], uint16(len(answer)))
		peer.Write(append(size[:], answer...))
	}()
	return &proofDNSServerConn{Conn: c, done: done}, nil
}
func TestOwnershipDNSValidControl(t *testing.T) {
	var posts atomic.Int32
	s, server, _ := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
		posts.Add(1)
		io.Copy(io.Discard, r.Body)
		io.WriteString(w, envelope(validReceipt))
	})
	proofSetDNS(s, func(ctx context.Context, n, a string) (net.Conn, error) { return proofDNSAnswer(t, ctx, n, a) }, func(ctx context.Context, n, a string) (net.Conn, error) {
		h, _, e := net.SplitHostPort(a)
		if e != nil || h != "127.0.0.1" {
			return nil, errors.New("synthetic DNS unexpected answer")
		}
		return (&net.Dialer{}).DialContext(ctx, n, server.Listener.Addr().String())
	})
	got, e := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
	if e != nil || got == nil || posts.Load() != 1 {
		t.Fatalf("native DNS positive control: %v posts=%d", e, posts.Load())
	}
}

func TestOwnershipClosingReservation(t *testing.T) {
	s, server, _ := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
		io.Copy(io.Discard, r.Body)
		io.WriteString(w, envelope(validReceipt))
	})
	s.transport.idleTimeout = 20 * time.Millisecond
	closing := make(chan struct{})
	release, free := proofGate(t)
	var dials atomic.Int32
	proofSetDial(s, func(ctx context.Context, _, _ string) (net.Conn, error) {
		dials.Add(1)
		c, e := (&net.Dialer{}).DialContext(ctx, "tcp", server.Listener.Addr().String())
		if e != nil {
			return nil, e
		}
		return &proofCloseConn{Conn: c, entered: closing, release: release}, nil
	})
	defer func() { free(); s.Close() }()
	if _, e := s.Parse(context.Background(), []byte("fixture"), "image/jpeg"); e != nil {
		t.Fatal(e)
	}
	proofWait(t, closing, "idle expiry real Close held")
	_, e := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
	requireCode(t, e, ErrProviderDown)
	s.transport.mu.Lock()
	n := s.transport.count
	s.transport.mu.Unlock()
	if dials.Load() != 1 || n != 1 {
		t.Fatalf("closing reservation released early dials=%d occupied=%d", dials.Load(), n)
	}
	t.Logf("proof: closing occupied=%d new_dials=%d", n, dials.Load()-1)
	free()
	s.Close()
}

func proofDNSPacketAnswer(q []byte, truncated bool) []byte {
	if len(q) < 16 {
		return nil
	}
	answer := append([]byte(nil), q...)
	answer[2] = 0x81
	answer[3] = 0x80
	answer[6] = 0
	answer[7] = 0
	pos := 12
	for pos < len(q) && q[pos] != 0 {
		pos += int(q[pos]) + 1
	}
	pos += 5
	if pos > len(q) {
		return nil
	}
	answer = answer[:pos]
	answer[10] = 0
	answer[11] = 0
	if truncated {
		answer[2] |= 2
		return answer
	}
	if binary.BigEndian.Uint16(q[pos-4:pos-2]) == 1 {
		answer[7] = 1
		answer = append(answer, 0xc0, 0x0c, 0, 1, 0, 1, 0, 0, 0, 0, 0, 4, 127, 0, 0, 1)
	}
	return answer
}
func TestOwnershipDNSUDPAndTCP(t *testing.T) {
	for _, truncated := range []bool{false, true} {
		t.Run(fmt.Sprint(truncated), func(t *testing.T) {
			udp, e := net.ListenPacket("udp", "127.0.0.1:0")
			if e != nil {
				t.Fatal(e)
			}
			done := make(chan struct{})
			go func() {
				defer close(done)
				var q [4096]byte
				for {
					n, peer, e := udp.ReadFrom(q[:])
					if e != nil {
						return
					}
					udp.WriteTo(proofDNSPacketAnswer(q[:n], truncated), peer)
				}
			}()
			defer func() { udp.Close(); proofWait(t, done, "UDP DNS fixture exit") }()
			var udpCalls, tcpCalls, posts atomic.Int32
			s, server, _ := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
				posts.Add(1)
				io.Copy(io.Discard, r.Body)
				io.WriteString(w, envelope(validReceipt))
			})
			proofSetDNS(s, func(ctx context.Context, n, a string) (net.Conn, error) {
				if n == "udp" {
					udpCalls.Add(1)
					return (&net.Dialer{}).DialContext(ctx, n, udp.LocalAddr().String())
				}
				tcpCalls.Add(1)
				return proofDNSAnswer(t, ctx, n, a)
			}, func(ctx context.Context, n, a string) (net.Conn, error) {
				return (&net.Dialer{}).DialContext(ctx, n, server.Listener.Addr().String())
			})
			got, e := s.Parse(context.Background(), []byte("fixture"), "image/jpeg")
			if e != nil || got == nil || posts.Load() != 1 || udpCalls.Load() < 1 || (truncated && tcpCalls.Load() < 1) || (!truncated && tcpCalls.Load() != 0) {
				t.Fatalf("native DNS UDP/TCP control: %v UDP=%d TCP=%d POST=%d", e, udpCalls.Load(), tcpCalls.Load(), posts.Load())
			}
			t.Logf("proof: native DNS truncated=%v UDP=%d TCP=%d provider_POST=%d", truncated, udpCalls.Load(), tcpCalls.Load(), posts.Load())
		})
	}
}

// Delay only the counterfactual second operation's Read until its header Write
// has reached the actual TLS peer, making the dirty-idle removal discriminatory.
type proofSecondReadConn struct {
	net.Conn
	second *atomic.Bool
	posted chan struct{}
	once   sync.Once
}

func (c *proofSecondReadConn) Read(p []byte) (int, error) {
	if c.second.Load() {
		select {
		case <-c.posted:
		case <-time.After(time.Second):
			return 0, errors.New("synthetic second POST not written")
		}
	}
	return c.Conn.Read(p)
}
func (c *proofSecondReadConn) Write(p []byte) (int, error) {
	n, e := c.Conn.Write(p)
	if c.second.Load() && bytes.Contains(p, []byte("POST /v1/messages ")) {
		c.once.Do(func() { close(c.posted) })
	}
	return n, e
}

// Close joins every native-DNS positive fixture producer as well as its socket.
type proofDNSServerConn struct {
	net.Conn
	done chan struct{}
	once sync.Once
}

func (c *proofDNSServerConn) Close() error {
	c.once.Do(func() { c.Conn.Close(); <-c.done })
	return nil
}

// Real native TLS Read sends an encrypted alert on an invalid post-response TLS
// record. Hold that actual raw Write's cleanup and require idle claim to interrupt
// BOTH directions and join it. NetConn is public and used only by this fixture.
func TestOwnershipIdleTLSWriteJoin(t *testing.T) {
	send, sendBad := proofGate(t)
	release, free := proofGate(t)
	entered := make(chan struct{})
	exited := make(chan struct{})
	finished := make(chan struct{})
	var hold atomic.Bool
	var dials atomic.Int32
	s, server, _ := proofTLS(t, func(w http.ResponseWriter, r *http.Request) {
		defer close(finished)
		io.Copy(io.Discard, r.Body)
		c, b, e := w.(http.Hijacker).Hijack()
		if e != nil {
			return
		}
		defer c.Close()
		body := envelope(validReceipt)
		fmt.Fprintf(b, "HTTP/1.1 200 OK\r\nContent-Length: %d\r\n\r\n%s", len(body), body)
		b.Flush()
		<-send
		tlsConn, ok := c.(*tls.Conn)
		if !ok {
			return
		}
		raw := tlsConn.NetConn()
		raw.Write([]byte{0x17, 0x03, 0x03, 0x00, 0x01, 0x00})
		io.Copy(io.Discard, raw)
	})
	proofSetDial(s, func(ctx context.Context, _, _ string) (net.Conn, error) {
		dials.Add(1)
		c, e := (&net.Dialer{}).DialContext(ctx, "tcp", server.Listener.Addr().String())
		if e != nil {
			return nil, e
		}
		return &proofIdleAlertConn{Conn: c, hold: &hold, entered: entered, exited: exited, release: release, free: free}, nil
	})
	defer func() { free(); sendBad(); s.Close(); proofWait(t, finished, "idle alert fixture cleanup") }()
	if _, e := s.Parse(context.Background(), []byte("fixture"), "image/jpeg"); e != nil {
		t.Fatal(e)
	}
	hold.Store(true)
	sendBad()
	proofWait(t, entered, "native TLS idle alert Write")
	ctx, cancel := context.WithTimeout(context.Background(), 200*time.Millisecond)
	defer cancel()
	done := make(chan error, 1)
	go func() { _, e := s.Parse(ctx, []byte("fixture"), "image/jpeg"); done <- e }()
	var result error
	joined := true
	select {
	case result = <-done:
	case <-time.After(350 * time.Millisecond):
		joined = false
	}
	free()
	if !joined {
		select {
		case result = <-done:
		case <-time.After(time.Second):
			t.Fatal("idle alert cleanup not joined")
		}
	}
	proofWait(t, exited, "native idle Write exit")
	requireCode(t, result, ErrProviderDown)
	if !joined {
		t.Error("idle claim did not interrupt/join native TLS-generated Write")
	}
	if dials.Load() != 1 {
		t.Error("dirty TLS idle socket redialed")
	}
	t.Logf("proof: idle native TLS alert writer joined=%v dials=%d", joined, dials.Load())
}

type proofIdleAlertConn struct {
	net.Conn
	hold            *atomic.Bool
	entered, exited chan struct{}
	release         <-chan struct{}
	free            func()
	once            sync.Once
}

func (c *proofIdleAlertConn) Write(p []byte) (int, error) {
	n, e := c.Conn.Write(p)
	if c.hold.Load() {
		c.once.Do(func() { close(c.entered); <-c.release; close(c.exited) })
	}
	return n, e
}
func (c *proofIdleAlertConn) SetDeadline(t time.Time) error {
	e := c.Conn.SetDeadline(t)
	if c.hold.Load() && !t.IsZero() {
		c.free()
	}
	return e
}
