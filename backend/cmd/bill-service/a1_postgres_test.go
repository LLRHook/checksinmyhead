//go:build integration

package main

import (
	"backend/internal/bill"
	"backend/internal/exchange"
	"backend/internal/tab"
	"backend/migrations"
	"backend/pkg/models"
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"github.com/gin-gonic/gin"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestA1PostgresProductionJSON(t *testing.T) {
	gin.SetMode(gin.TestMode)
	t.Setenv("TRUSTED_PROXY_CIDRS", "")
	q := &currencyQueryCount{}
	db := currencyPostgres(t, q)
	sql, _ := db.DB()
	state, err := migrations.Run(context.Background(), sql, migrations.Verify)
	if err != nil {
		t.Fatal(err)
	}
	b, c := newCurrencyHandlers(bill.NewBillRepository(db), exchange.NewClient("http://127.0.0.1:1"))
	r, err := newRouter(b, c, tab.NewTabHandler(tab.NewTabService(tab.NewTabRepository(db))), nil, state)
	if err != nil {
		t.Fatal(err)
	}
	snapshot := func() string {
		var counts []int64
		for _, model := range []any{&models.Tab{}, &models.TabMember{}, &models.Bill{}, &models.BillItem{}, &models.ItemAssignment{}, &models.PersonShare{}, &models.Person{}} {
			var n int64
			if err := db.Model(model).Count(&n).Error; err != nil {
				t.Fatal(err)
			}
			counts = append(counts, n)
		}
		return fmt.Sprint(counts)
	}
	for _, tc := range []struct {
		name, path, method, body string
		status                   int
	}{
		{"tab_byte_excess", "/api/tabs", "POST", `{}` + strings.Repeat(" ", (16<<10)-1), 413},
		{"tab_text_excess", "/api/tabs", "POST", `{"name":"` + strings.Repeat("界", 256) + `"}`, 400},
		{"tab_description_excess", "/api/tabs", "POST", `{"description":"` + strings.Repeat("x", 4097) + `"}`, 400},
		{"tab_creator_excess", "/api/tabs", "POST", `{"creator_display_name":"` + strings.Repeat("界", 31) + `"}`, 400},
		{"tab_second_doc", "/api/tabs", "POST", `{} {}`, 400},
		{"bill_strict_nested", "/api/bills", "POST", `{"name":"Old","subtotal":0,"total":0,"items":[{"name":"x","price":0,"id":1}]}`, 400},
		{"creation_items_501", "/api/bills", "POST", `{"name":"Old","subtotal":0,"total":0,"items":[` + strings.Repeat(`{},`, 500) + `{}]}`, 400},
		{"mutation_updates_501", "/api/bills/1/assignments", "PATCH", `{"updates":[` + strings.Repeat(`{},`, 500) + `{}]}`, 400},
		{"tab_updates_501", "/api/tabs/1/bills/1/assignments", "PATCH", `{"updates":[` + strings.Repeat(`{},`, 500) + `{}]}`, 400},
		{"mutation_assignments_101", "/api/bills/1/items/1/assignments", "PATCH", `{"assignments":[` + strings.Repeat(`{},`, 100) + `{}]}`, 400},
		{"tab_assignments_101", "/api/tabs/1/bills/1/items/1/assignments", "PATCH", `{"assignments":[` + strings.Repeat(`{},`, 100) + `{}]}`, 400},
		{"source_paid_oversize", "/api/bills/1/shares/1", "PATCH", `{"paid":true}` + strings.Repeat(" ", 4096), 400},
		{"attachment_strict", "/api/tabs/1/bills", "POST", `{"bill_id":1,"bill_token":"synthetic","tab_id":2}`, 400},
		{"attachment_oversize", "/api/tabs/1/bills", "POST", `{"bill_id":1,"bill_token":"synthetic"}` + strings.Repeat(" ", 4096), 400},
		{"tab_settings_oversize", "/api/tabs/1", "PATCH", `{}` + strings.Repeat(" ", 4<<20), 400},
	} {
		t.Run(tc.name, func(t *testing.T) {
			before := snapshot()
			q.data.Store(0)
			q.control.Store(0)
			q.enabled.Store(true)
			w := compositionRequest(r, tc.method, tc.path, tc.body)
			q.enabled.Store(false)
			if w.Code != tc.status || q.data.Load() != 0 || q.control.Load() != 0 || snapshot() != before {
				t.Errorf("reject=%d want=%d SQLdata=%d controls=%d", w.Code, tc.status, q.data.Load(), q.control.Load())
			}
		})
	}
	t.Run("normal_creator_and_ignored_graph", func(t *testing.T) {
		w := compositionRequest(r, "POST", "/api/tabs", `{"name":"<b>Trip</b>","creator_display_name":"<b>界</b>","members":[{"id":99}],"bills":[{"id":99}]}`)
		if w.Code != 201 {
			t.Fatalf("create=%d", w.Code)
		}
		var created struct {
			TabID, MemberID uint
			Token           string `json:"access_token"`
			MemberToken     string `json:"member_token"`
		}
		var wire map[string]any
		json.Unmarshal(w.Body.Bytes(), &wire)
		created.TabID = uint(wire["tab_id"].(float64))
		created.MemberID = uint(wire["member_id"].(float64))
		json.Unmarshal(w.Body.Bytes(), &created)
		var saved models.Tab
		var creator models.TabMember
		if err := db.First(&saved, created.TabID).Error; err != nil {
			t.Fatal(err)
		}
		if err := db.First(&creator, created.MemberID).Error; err != nil {
			t.Fatal(err)
		}
		if saved.Name != "Trip" || saved.DisplayCurrency != "USD" || creator.DisplayName != "界" || creator.TabID != saved.ID || creator.Role != "creator" || creator.MemberToken != created.MemberToken || saved.AccessToken != created.Token {
			t.Error("creator content/authority mismatch")
		}
	})
	t.Run("memberless_optional_names", func(t *testing.T) {
		w := compositionRequest(r, "POST", "/api/tabs", `{}`)
		if w.Code != 201 || strings.Contains(w.Body.String(), "member_id") {
			t.Errorf("optional/memberless %d", w.Code)
		}
	})
	t.Run("creator_failure_atomic", func(t *testing.T) {
		if err := db.Exec(`CREATE FUNCTION a1_reject_member() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'synthetic creator failure'; END $$; CREATE TRIGGER a1_reject_member BEFORE INSERT ON tab_members FOR EACH ROW EXECUTE FUNCTION a1_reject_member()`).Error; err != nil {
			t.Fatal(err)
		}
		before := snapshot()
		w := compositionRequest(r, "POST", "/api/tabs", `{"name":"Atomic","creator_display_name":"Alex"}`)
		if w.Code != 500 || snapshot() != before {
			t.Error("creator failure left a tab")
		}
		if err := db.Exec(`DROP TRIGGER a1_reject_member ON tab_members;DROP FUNCTION a1_reject_member()`).Error; err != nil {
			t.Fatal(err)
		}
	})
	t.Run("old_client_and_max_creation", func(t *testing.T) {
		var items []any
		for i := 0; i < 500; i++ {
			var assignments []any
			for j := 0; j < 10; j++ {
				assignments = append(assignments, map[string]any{"person_name": fmt.Sprint("Person", j), "percentage": 10})
			}
			items = append(items, map[string]any{"name": "Item", "price": 1, "assignments": assignments})
		}
		data, _ := json.Marshal(map[string]any{"name": "Max", "lazy_mode": true, "subtotal": 500, "total": 500, "items": items})
		for _, body := range []string{`{"name":"Old saved history","subtotal":1,"total":1,"person_shares":[{"person_name":"Alex","total":1}]}`, string(data)} {
			w := compositionRequest(r, "POST", "/api/bills", body)
			if w.Code != 201 {
				t.Fatalf("valid create=%d", w.Code)
			}
		}
	})
	t.Run("saturation_reads_health_and_cleanup", func(t *testing.T) {
		server := httptest.NewServer(r)
		defer server.Close()
		address := strings.TrimPrefix(server.URL, "http://")
		var sockets []net.Conn
		defer func() {
			for _, s := range sockets {
				s.Close()
			}
		}()
		// Expect/100-continue is emitted by net/http only when the admitted
		// handler reads Body. It observes all eight slots without racing a probe.
		q.data.Store(0)
		q.control.Store(0)
		q.enabled.Store(true)
		for i := 0; i < 8; i++ {
			conn, err := net.DialTimeout("tcp", address, time.Second)
			if err != nil {
				t.Fatal(err)
			}
			sockets = append(sockets, conn)
			conn.SetDeadline(time.Now().Add(3 * time.Second))
			fmt.Fprint(conn, "POST /api/tabs HTTP/1.1\r\nHost: fixture\r\nExpect: 100-continue\r\nContent-Length: 20\r\n\r\n")
			interim, err := http.ReadResponse(bufio.NewReader(conn), nil)
			if err != nil {
				t.Fatal(err)
			}
			interim.Body.Close()
			if interim.StatusCode != 100 {
				t.Fatalf("body not admitted=%d", interim.StatusCode)
			}
			fmt.Fprint(conn, "{")
		}

		w := compositionRequest(r, "POST", "/api/bills", `{"name":"Refused","subtotal":0,"total":0}`)
		if w.Code != 503 || w.Header().Get("Retry-After") != "1" || q.data.Load() != 0 || q.control.Load() != 0 {
			t.Error("saturated request reached SQL")
		}
		q.data.Store(0)
		q.control.Store(0)
		health := compositionRequest(r, "GET", "/health", "")
		if health.Code != 200 || q.data.Load() != 1 || q.control.Load() != 0 {
			t.Errorf("health=%d data=%d controls=%d", health.Code, q.data.Load(), q.control.Load())
		}
		q.enabled.Store(false)
		for _, conn := range sockets {
			tcp := conn.(*net.TCPConn)
			tcp.CloseWrite()
			conn.SetReadDeadline(time.Now().Add(2 * time.Second))
			resp, err := http.ReadResponse(bufio.NewReader(conn), nil)
			if err != nil {
				t.Fatal(err)
			}
			io.Copy(io.Discard, resp.Body)
			resp.Body.Close()
			if resp.StatusCode != 400 {
				t.Errorf("truncated=%d", resp.StatusCode)
			}
			conn.Close()
		}
		if w := compositionRequest(r, "POST", "/api/tabs", `{}`); w.Code != 201 {
			t.Errorf("slots not reusable=%d", w.Code)
		}
	})
}
