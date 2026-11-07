//go:build integration

package testpostgres

import "testing"

func TestUnsafeFixtureDSNsFailBeforeConnection(t *testing.T) {
	for name, dsn := range map[string]string{
		"remote":        "host=example.invalid user=billington_test dbname=billington_test",
		"fallback":      "host=127.0.0.1,example.invalid user=billington_test dbname=billington_test",
		"database":      "host=127.0.0.1 user=billington_test dbname=production",
		"user":          "host=127.0.0.1 user=postgres dbname=billington_test",
		"schema":        "host=127.0.0.1 user=billington_test dbname=billington_test search_path=public",
		"empty_schema":  "host=127.0.0.1 user=billington_test dbname=billington_test search_path=''",
		"options":       "host=127.0.0.1 user=billington_test dbname=billington_test options='-c search_path=public'",
		"empty_options": "host=127.0.0.1 user=billington_test dbname=billington_test options=''",
		"socket":        "host=/tmp user=billington_test dbname=billington_test",
		"malformed":     "postgres://%",
	} {
		t.Run(name, func(t *testing.T) {
			if cfg, err := safeConfig(dsn); err == nil || cfg != nil {
				t.Fatal("unsafe fixture accepted")
			}
		})
	}
}
func TestLoopbackFixtureDSNs(t *testing.T) {
	for _, host := range []string{"127.0.0.1", "::1", "localhost", "127.0.0.1,::1"} {
		t.Run(host, func(t *testing.T) {
			if _, err := safeConfig("host=" + host + " user=billington_test dbname=billington_test sslmode=disable"); err != nil {
				t.Fatal(err)
			}
		})
	}
}
