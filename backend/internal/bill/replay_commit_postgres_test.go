//go:build integration

package bill

import (
	"context"
	"database/sql"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/stdlib"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// commitLossProxy preserves real PG protocol traffic. It either disconnects before
// forwarding COMMIT (rollback) or discards its actual backend response through
// ReadyForQuery (committed). Neither outcome is inferred from a mock Tx result.
func commitLossProxy(t *testing.T, admin *sql.DB, after bool) (*gorm.DB, *atomic.Bool) {
	t.Helper()
	cfg, err := pgx.ParseConfig(os.Getenv("BILLINGTON_TEST_POSTGRES_DSN"))
	if err != nil {
		t.Fatal("test config")
	}
	if cfg.TLSConfig != nil || cfg.Host != "127.0.0.1" || cfg.Database != "billington_test" || cfg.User != "billington_test" {
		t.Fatal("unsafe proxy fixture")
	}
	var schema string
	if err := admin.QueryRow("SELECT current_schema()").Scan(&schema); err != nil {
		t.Fatal(err)
	}
	upstream := net.JoinHostPort(cfg.Host, fmtPort(cfg.Port))
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	var sessions sync.WaitGroup
	done := make(chan struct{})
	cut := &atomic.Bool{}
	var mu sync.Mutex
	var connections []net.Conn
	go func() {
		defer close(done)
		for {
			front, e := listener.Accept()
			if e != nil {
				return
			}
			back, e := net.DialTimeout("tcp", upstream, time.Second)
			if e != nil {
				front.Close()
				return
			}
			mu.Lock()
			connections = append(connections, front, back)
			mu.Unlock()
			sessions.Add(1)
			go func() {
				defer sessions.Done()
				defer front.Close()
				defer back.Close()
				front.SetDeadline(time.Now().Add(12 * time.Second))
				back.SetDeadline(time.Now().Add(12 * time.Second))
				// Startup is length-prefixed without a type byte. No credentials are retained.
				header := make([]byte, 4)
				if _, e := io.ReadFull(front, header); e != nil {
					return
				}
				n := int(binary.BigEndian.Uint32(header))
				if n < 8 || n > 65536 {
					return
				}
				payload := make([]byte, n-4)
				if _, e := io.ReadFull(front, payload); e != nil {
					return
				}
				if _, e := back.Write(append(header, payload...)); e != nil {
					return
				}
				var committing atomic.Bool
				childDone := make(chan struct{})
				go func() {
					defer close(childDone)
					defer front.Close()
					defer back.Close()
					for {
						packet, e := pgPacket(front)
						if e != nil {
							return
						}
						if packet[0] == 'Q' && strings.EqualFold(strings.TrimRight(string(packet[5:]), "\x00"), "commit") {
							committing.Store(true)
							if !after {
								cut.Store(true)
								return
							}
						}
						if _, e := back.Write(packet); e != nil {
							return
						}
					}
				}()
				defer func() { front.Close(); back.Close(); <-childDone }()
				for {
					packet, e := pgPacket(back)
					if e != nil {
						return
					}
					if committing.Load() {
						if packet[0] == 'Z' {
							cut.Store(true)
							return
						}
						continue
					}
					if _, e := front.Write(packet); e != nil {
						return
					}
				}
			}()
		}
	}()
	cfg.Host = "127.0.0.1"
	cfg.Port = uint16(listener.Addr().(*net.TCPAddr).Port)
	cfg.RuntimeParams["search_path"] = schema
	cfg.RuntimeParams["application_name"] = schema + "_commit_proxy"
	cfg.ConnectTimeout = time.Second
	db := stdlib.OpenDB(*cfg)
	db.SetMaxOpenConns(1)
	t.Cleanup(func() {
		db.Close()
		listener.Close()
		mu.Lock()
		for _, c := range connections {
			c.Close()
		}
		mu.Unlock()
		<-done
		sessions.Wait()
	})
	g, e := gorm.Open(postgres.New(postgres.Config{Conn: db}), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if e != nil {
		t.Fatal(e)
	}
	return g, cut
}
func fmtPort(v uint16) string { // fixed integer formatting without DSN output
	const digits = "0123456789"
	out := []byte{}
	n := int(v)
	for {
		out = append([]byte{digits[n%10]}, out...)
		n /= 10
		if n == 0 {
			return string(out)
		}
	}
}
func pgPacket(c net.Conn) ([]byte, error) {
	head := make([]byte, 5)
	if _, err := io.ReadFull(c, head); err != nil {
		return nil, err
	}
	n := int(binary.BigEndian.Uint32(head[1:]))
	if n < 4 || n > 4<<20 {
		return nil, errors.New("bounded PG packet")
	}
	data := make([]byte, n-4)
	_, err := io.ReadFull(c, data)
	return append(head, data...), err
}
func TestPostgresReplayRealCommitResponseLossAndRollbackRecovery(t *testing.T) {
	for _, after := range []bool{false, true} {
		t.Run(map[bool]string{false: "before_commit_rolled_back", true: "after_commit_durable"}[after], func(t *testing.T) {
			db, ordinary := replayPG(t)
			proxied, cut := commitLossProxy(t, db, after)
			input := replayInsert(t, "First", "attempt-token")
			r, err := (&billRepository{db: proxied}).Create(context.Background(), input)
			if !errors.Is(err, ErrCreateUncertain) || r.Result.BillID != 0 || r.Result.AccessToken != "" || !cut.Load() {
				t.Fatal("unknown outcome not discarded/finite")
			}
			want := 0
			if after {
				want = 1
			}
			replayGraph(t, db, want)
			// A fresh service/repository connection recovers SAME key/content. It does
			// not retry automatically inside the failed operation or use replacement keys.
			recovered, err := (&billRepository{db: ordinary}).Create(context.Background(), replayInsert(t, "First", "recovery-token"))
			if err != nil {
				t.Fatal(err)
			}
			token := "recovery-token"
			if after {
				token = "attempt-token"
			}
			if recovered.Result.AccessToken != token || recovered.Result.Replayed != after {
				t.Fatal("same-key outcome recovery failed")
			}
			replayGraph(t, db, 1)
		})
	}
}
