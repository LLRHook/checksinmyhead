package tab

import (
	billpkg "backend/internal/bill"
	"backend/pkg/models"
	"context"
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func authorizationDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{Logger: logger.Default.LogMode(logger.Silent)})
	if err != nil {
		t.Fatal(err)
	}
	sql, err := db.DB()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = sql.Close() })
	if err := db.AutoMigrate(&models.Tab{}, &models.TabMember{}, &models.Bill{}, &models.Person{}, &models.BillItem{}, &models.ItemAssignment{}, &models.PersonShare{}); err != nil {
		t.Fatal(err)
	}
	return db
}

func authorizationRouter(db *gorm.DB, providers ...billpkg.ExchangeRateProvider) *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	var provider billpkg.ExchangeRateProvider = authorizationQuote{}
	if len(providers) > 0 {
		provider = providers[0]
	}
	b := billpkg.NewBillHandler(billpkg.NewBillService(billpkg.NewBillRepository(db), provider))
	h := NewTabHandler(NewTabService(NewTabRepository(db)))
	r.POST("/api/bills", b.CreateBill)
	r.GET("/api/bills/:id", b.GetBill)
	r.PATCH("/api/bills/:id/items/:itemId/assignments", b.UpdateLazyItemAssignments)
	r.PATCH("/api/bills/:id/assignments", b.UpdateLazyItemAssignmentsBatch)
	r.POST("/api/tabs", h.CreateTab)
	r.GET("/api/tabs/:id", h.GetTab)
	r.POST("/api/tabs/:id/bills", h.AddBillToTab)
	return r
}

func authRequest(r *gin.Engine, method, path, body, token, member string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	if member != "" {
		req.Header.Set("X-Member-Token", member)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}

func saveAuthFixture(t *testing.T, db *gorm.DB, v any) {
	t.Helper()
	if err := db.Create(v).Error; err != nil {
		t.Fatal(err)
	}
}

func authSnapshot(t *testing.T, db *gorm.DB) string {
	t.Helper()
	tables := []string{"tabs", "tab_members", "bills", "people", "bill_participants", "bill_items", "item_assignments", "person_shares"}
	result := map[string]any{}
	for _, table := range tables {
		var rows []map[string]any
		if err := db.Table(table).Order("1, 2").Find(&rows).Error; err != nil {
			t.Fatal(err)
		}
		result[table] = rows
	}
	data, err := json.Marshal(result)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}

func TestAuthorizationMissingSourceProofNeverAttachesOrDiscloses(t *testing.T) {
	db := authorizationDB(t)
	r := authorizationRouter(db)
	dst := models.Tab{Name: "Attacker tab", AccessToken: "destination"}
	saveAuthFixture(t, db, &dst)
	victim := models.Bill{Name: "Victim private receipt", Subtotal: 10, Total: 10, AccessToken: "source", PaymentMethods: []models.PaymentMethod{{Name: "Venmo", Identifier: "@private-victim"}}}
	saveAuthFixture(t, db, &victim)
	before := authSnapshot(t, db)
	w := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/bills", dst.ID), fmt.Sprintf(`{"bill_id":%d}`, victim.ID), "destination", "")
	read := authRequest(r, "GET", fmt.Sprintf("/api/tabs/%d", dst.ID), "", "destination", "")
	if w.Code != 400 {
		t.Errorf("missing source proof: got %d, want 400", w.Code)
	}
	if strings.Contains(read.Body.String(), "Victim private") || strings.Contains(read.Body.String(), "@private-victim") {
		t.Error("destination disclosed victim content")
	}
	if authSnapshot(t, db) != before {
		t.Error("rejection changed ownership/content")
	}
}

func TestAuthorizationAttachmentCredentialsAndState(t *testing.T) {
	for _, tc := range []struct {
		name, token, member, source     string
		status                          int
		finalized, memberless, attached bool
	}{
		{"empty_source", "dest", "member", "", 400, false, false, false},
		{"blank_source", "dest", "member", " \t ", 400, false, false, false},
		{"wrong_source", "dest", "member", "wrong", 404, false, false, false},
		{"other_bill_token", "dest", "member", "unrelated", 404, false, false, false},
		{"missing_source_bill", "dest", "member", "source", 404, false, false, false},
		{"missing_destination", "", "member", "source", 403, false, false, false},
		{"wrong_destination", "wrong", "member", "source", 403, false, false, false},
		{"missing_member", "dest", "", "source", 403, false, false, false},
		{"wrong_member", "dest", "wrong", "source", 403, false, false, false},
		{"other_tab_member", "dest", "foreign-member", "source", 403, false, false, false},
		{"finalized", "dest", "member", "source", 400, true, false, false},
		{"other_tab_source", "dest", "member", "source", 404, false, false, true},
		{"legacy_invalid_member", "dest", "wrong", "source", 403, false, true, false},
		{"legacy", "dest", "", "source", 200, false, true, false},
		{"authorized", "dest", "member", "source", 200, false, false, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			db := authorizationDB(t)
			r := authorizationRouter(db)
			dst := models.Tab{Name: "Destination", AccessToken: "dest", Finalized: tc.finalized}
			saveAuthFixture(t, db, &dst)
			other := models.Tab{Name: "Other", AccessToken: "other"}
			saveAuthFixture(t, db, &other)
			member := models.TabMember{TabID: dst.ID, DisplayName: "Alex", MemberToken: "member"}
			if !tc.memberless {
				saveAuthFixture(t, db, &member)
			}
			foreign := models.TabMember{TabID: other.ID, DisplayName: "Other", MemberToken: "foreign-member"}
			saveAuthFixture(t, db, &foreign)
			source := models.Bill{Name: "Private source", AccessToken: "source", Subtotal: 10, Total: 10, PaymentMethods: []models.PaymentMethod{{Name: "Venmo", Identifier: "@private"}}}
			if tc.attached {
				source.TabID = &other.ID
			}
			saveAuthFixture(t, db, &source)
			unrelated := models.Bill{Name: "Unrelated", AccessToken: "unrelated", Subtotal: 1, Total: 1}
			saveAuthFixture(t, db, &unrelated)
			before := authSnapshot(t, db)
			sourceID := source.ID
			if tc.name == "missing_source_bill" {
				sourceID += 100000
			}
			body := fmt.Sprintf(`{"bill_id":%d,"bill_token":%q}`, sourceID, tc.source)
			w := authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/bills", dst.ID), body, tc.token, tc.member)
			if w.Code != tc.status {
				t.Fatalf("status=%d want=%d: %s", w.Code, tc.status, w.Body.String())
			}
			if tc.status != 200 {
				if before != authSnapshot(t, db) {
					t.Fatal("rejected operation changed state")
				}
				if strings.Contains(w.Body.String(), "Private") || strings.Contains(w.Body.String(), "source\"") || strings.Contains(w.Body.String(), "@private") {
					t.Fatal("error discloses content")
				}
				read := authRequest(r, "GET", fmt.Sprintf("/api/tabs/%d", dst.ID), "", "dest", "")
				if strings.Contains(read.Body.String(), "Private source") {
					t.Fatal("victim disclosure")
				}
			} else {
				got, err := billpkg.NewBillRepository(db).GetById(source.ID)
				if err != nil {
					t.Fatal(err)
				}
				if got.TabID == nil || *got.TabID != dst.ID {
					t.Fatal("not attached")
				}
				if tc.memberless {
					if got.AddedByMemberID != nil || got.PaidByMemberID != nil {
						t.Fatal("invented attribution")
					}
				} else if got.AddedByMemberID == nil || *got.AddedByMemberID != member.ID || got.PaidByMemberID == nil || *got.PaidByMemberID != member.ID {
					t.Fatal("wrong attribution")
				}
			}
		})
	}
}

func TestAuthorizationRetryPreservesAttributionAndOpaqueSourceToken(t *testing.T) {
	db := authorizationDB(t)
	r := authorizationRouter(db)
	dst := models.Tab{Name: "Destination", AccessToken: "dest"}
	saveAuthFixture(t, db, &dst)
	first := models.TabMember{TabID: dst.ID, DisplayName: "First", MemberToken: "first"}
	saveAuthFixture(t, db, &first)
	second := models.TabMember{TabID: dst.ID, DisplayName: "Second", MemberToken: "second"}
	saveAuthFixture(t, db, &second)
	source := models.Bill{Name: "Source", AccessToken: " source ", Subtotal: 10, Total: 10}
	saveAuthFixture(t, db, &source)
	path := fmt.Sprintf("/api/tabs/%d/bills?t=dest&m=first", dst.ID)
	body := fmt.Sprintf(`{"bill_id":%d,"bill_token":" source "}`, source.ID)
	w := authRequest(r, "POST", path, body, "", "")
	if w.Code != 200 {
		t.Fatalf("%d %s", w.Code, w.Body.String())
	}
	before := authSnapshot(t, db)
	w = authRequest(r, "POST", fmt.Sprintf("/api/tabs/%d/bills", dst.ID), body, "dest", "second")
	if w.Code != 200 || before != authSnapshot(t, db) {
		t.Fatal("retry changed attribution, quote or timestamps")
	}
	for _, token := range []string{"", "source"} {
		w = authRequest(r, "POST", path, fmt.Sprintf(`{"bill_id":%d,"bill_token":%q}`, source.ID, token), "", "")
		if w.Code == 200 || before != authSnapshot(t, db) {
			t.Fatal("retry bypasses independent source proof")
		}
	}
}

func TestAuthorizationAttachMalformedBodiesAndIDs(t *testing.T) {
	db := authorizationDB(t)
	r := authorizationRouter(db)
	for _, body := range []string{`{"bill_id":4294967296,"bill_token":"source"}`, `{}`, `null`, `{"bill_id":0,"bill_token":"source"}`, `{"bill_id":-1,"bill_token":"source"}`, `{"bill_id":1.5,"bill_token":"source"}`, `{"bill_id":"1","bill_token":"source"}`, `{"bill_id":1,"bill_token":"source","paid_by_member_id":1}`, `{"bill_id":1,"bill_token":"source"} {}`, strings.Repeat(" ", 4096) + `{}`} {
		before := authSnapshot(t, db)
		if w := authRequest(r, "POST", "/api/tabs/1/bills", body, "dest", ""); w.Code != 400 {
			t.Fatalf("%s: %d", body[:min(60, len(body))], w.Code)
		}
		if before != authSnapshot(t, db) {
			t.Fatal("malformed request wrote state")
		}
	}
	for _, id := range []string{"0", "-1", "NaN", "4294967296"} {
		if w := authRequest(r, "POST", "/api/tabs/"+id+"/bills", `{"bill_id":1,"bill_token":"source"}`, "dest", ""); w.Code != 400 {
			t.Fatalf("id %s: %d", id, w.Code)
		}
	}
}

func assertStaleStandaloneClaim(t *testing.T, db *gorm.DB, batch bool) {
	t.Helper()
	source := models.Bill{Name: "Lazy", LazyMode: true, AccessToken: "source", Subtotal: 10, Total: 10, Items: []models.BillItem{{Name: "Dinner", Price: 10, Assignments: []models.ItemAssignment{{PersonName: "Alex", Percentage: 50}}}}, PersonShares: []models.PersonShare{{PersonName: "Alex", Subtotal: 5, Total: 5, Items: []models.ItemDetail{{Name: "Dinner", Amount: 5, IsShared: true}}}}}
	saveAuthFixture(t, db, &source)
	dst := models.Tab{Name: "Destination", AccessToken: "dest"}
	saveAuthFixture(t, db, &dst)
	loaded, resumeClaim := make(chan struct{}), make(chan struct{})
	var paused atomic.Bool
	if err := db.Callback().Query().After("gorm:query").Register("test:claim_discovery", func(tx *gorm.DB) {
		if tx.Statement.Table == "bills" && paused.CompareAndSwap(false, true) {
			close(loaded)
			<-resumeClaim
		}
	}); err != nil {
		t.Fatal(err)
	}
	service := billpkg.NewBillService(billpkg.NewBillRepository(db), authorizationQuote{})
	var resume sync.Once
	t.Cleanup(func() { resume.Do(func() { close(resumeClaim) }) })
	h := billpkg.NewBillHandler(service)
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.PATCH("/api/bills/:id/items/:itemId/assignments", h.UpdateLazyItemAssignments)
	r.PATCH("/api/bills/:id/assignments", h.UpdateLazyItemAssignmentsBatch)
	path := fmt.Sprintf("/api/bills/%d/items/%d/assignments", source.ID, source.Items[0].ID)
	body := `{"assignments":[{"person_name":"Sam","percentage":100}]}`
	if batch {
		path = fmt.Sprintf("/api/bills/%d/assignments", source.ID)
		body = fmt.Sprintf(`{"updates":[{"item_id":%d,"assignments":[{"person_name":"Sam","percentage":100}]}]}`, source.Items[0].ID)
	}
	result := make(chan *httptest.ResponseRecorder, 1)
	go func() { result <- authRequest(r, "PATCH", path, body, "source", "") }()
	select {
	case <-loaded:
	case <-time.After(10 * time.Second):
		t.Fatal("claim did not reach read barrier")
	}
	if err := NewTabRepository(db).AttachBill(context.Background(), AttachBillCommand{TabID: dst.ID, TabToken: "dest", BillID: source.ID, BillToken: "source"}); err != nil {
		t.Fatal(err)
	}
	// Snapshot after attachment: the stale request must not change any row.
	before := authSnapshot(t, db)
	resume.Do(func() { close(resumeClaim) })
	select {
	case w := <-result:
		if w.Code != 404 {
			t.Fatalf("stale claim status=%d body=%s", w.Code, w.Body.String())
		}
	case <-time.After(10 * time.Second):
		t.Fatal("claim failed to finish")
	}
	if before != authSnapshot(t, db) {
		t.Fatal("stale standalone claim changed assignments/shares")
	}
}

func TestAuthorizationStaleStandaloneSingleAndBatchClaims(t *testing.T) {
	for _, batch := range []bool{false, true} {
		t.Run(fmt.Sprint(batch), func(t *testing.T) { assertStaleStandaloneClaim(t, authorizationDB(t), batch) })
	}
}

func TestAuthorizationRepositoryRequiresSourceAndDestinationProof(t *testing.T) {
	for _, command := range []AttachBillCommand{
		{}, {TabID: 1, BillID: 1, TabToken: "destination"}, {TabID: 1, BillID: 1, TabToken: "destination", BillToken: " \t"},
		{TabID: 1, BillID: 1, BillToken: "source"},
	} {
		// Invalid internal commands must fail before a database is consulted.
		if err := (&tabRepository{db: &gorm.DB{}}).AttachBill(context.Background(), command); err == nil {
			t.Fatal("invalid internal command accepted")
		}
	}
}
