package main

import (
	"backend/internal/bill"
	"backend/internal/currency"
	"backend/internal/exchange"
	"backend/internal/tab"
	"backend/pkg/models"
	"context"
	"encoding/json"
	"fmt"
	"github.com/gin-gonic/gin"
	"io"
	"log"
	"reflect"
	"strings"
	"testing"
)

type jsonContractBills struct {
	bill.BillService
	calls   int
	updates []bill.ItemAssignmentsUpdate
}

func (s *jsonContractBills) UpdateItemAssignmentsBatch(_ context.Context, c bill.ClaimCommand) error {
	s.calls++
	s.updates = c.Updates
	return nil
}
func (s *jsonContractBills) GetBill(uint) (*models.Bill, error) { return &models.Bill{ID: 1}, nil }

type jsonContractTabs struct {
	tab.TabService
	calls   int
	updates []bill.ItemAssignmentsUpdate
}

func (s *jsonContractTabs) UpdateBillItemAssignmentsBatch(_ context.Context, c tab.AssignmentCommand) error {
	s.calls++
	s.updates = c.Updates
	return nil
}

func TestJSONAssignmentWireContract(t *testing.T) {
	oldMode := gin.Mode()
	gin.SetMode(gin.TestMode)
	defer gin.SetMode(oldMode)
	gw, lw := gin.DefaultWriter, log.Writer()
	gin.DefaultWriter = io.Discard
	log.SetOutput(io.Discard)
	defer func() { gin.DefaultWriter = gw; log.SetOutput(lw) }()
	t.Setenv("TRUSTED_PROXY_CIDRS", "")
	one := func(name string, pct float64) []models.ItemAssignment {
		return []models.ItemAssignment{{PersonName: name, Percentage: pct}}
	}
	cases := []struct {
		name, body  string
		status      int
		assignments []models.ItemAssignment
	}{
		{"escaped_case_duplicate_unknown", `{"UPDATES":[{"item_id":1,"ITEM_ID":2,"assignments":[{"PERSON_NAME":"old","person_\u006eame":" \u003cb\u003e界\u003c/b\u003e ","percentage":1,"PERCENTAGE":100,"paid":true}],"ignored":[{},{}]}]}`, 200, one("界", 100)},
		{"empty_assignments", `{"updates":[{"item_id":2,"assignments":[]}]}`, 200, []models.ItemAssignment{}},
		{"replacement_arrays", `{"updates":[{"item_id":2,"assignments":[{"person_name":"old","percentage":100}],"ASSIGNMENTS":[{"person_name":"New","percentage":1e2}]}]}`, 200, one("New", 100)},
		{"null_scalar", `{"updates":[{"item_id":2,"assignments":[{"person_name":"Alex","person_name":null,"percentage":100,"percentage":null}]}]}`, 200, one("Alex", 100)},
		{"FEFF_retained", `{"updates":[{"item_id":2,"assignments":[{"person_name":"\ufeffAlex\ufeff","percentage":100}]}]}`, 200, one("\ufeffAlex\ufeff", 100)},
		{"escaped_punctuation", `{"updates":[{"item_id":2,"assignments":[{"person_name":"a,b[\"\\]{}","percentage":100}]}]}`, 200, one("a,b[\"\\]{}", 100)},
		{"null_assignments", `{"updates":[{"item_id":2,"assignments":null}]}`, 400, nil},
		{"null_update", `{"updates":[null]}`, 400, nil}, {"null_updates", `{"updates":null}`, 400, nil},
		{"empty_updates", `{"updates":[]}`, 400, nil},
		{"type_error", `{"updates":[{"item_id":2,"assignments":[{"person_name":1,"percentage":100}]}]}`, 400, nil},
		{"finite_overflow", `{"updates":[{"item_id":2,"assignments":[{"person_name":"Alex","percentage":1e309}]}]}`, 400, nil},
		{"duplicate_sanitized", `{"updates":[{"item_id":2,"assignments":[{"person_name":"<b>Alex</b>","percentage":50},{"person_name":" alex ","percentage":50}]}]}`, 400, nil},
		{"HTML_empty", `{"updates":[{"item_id":2,"assignments":[{"person_name":"<b></b>","percentage":100}]}]}`, 400, nil},
		{"text_excess", `{"updates":[{"item_id":2,"assignments":[{"person_name":"` + strings.Repeat("界", 31) + `","percentage":100}]}]}`, 400, nil},
		{"nested_count_excess", `{"updates":[{"item_id":2,"assignments":[` + strings.Repeat(`{},`, 100) + `{}]}]}`, 400, nil},
		{"updates_count_excess", `{"updates":[` + strings.Repeat(`{},`, 500) + `{}]}`, 400, nil},
		{"first_duplicate_array_excess", `{"updates":[{"item_id":2,"assignments":[` + strings.Repeat(`{},`, 100) + `{}],"assignments":[]}]}`, 400, nil},
		{"trailing_document", `{"updates":[{"item_id":2,"assignments":[]}]} {}`, 400, nil},
		{"truncated", `{"updates":[{"item_id":2,"assignments":[`, 400, nil},
	}
	for _, attached := range []bool{false, true} {
		scope, path := "standalone", "/api/bills/1/assignments"
		if attached {
			scope, path = "attached", "/api/tabs/1/bills/1/assignments"
		}
		t.Run(scope, func(t *testing.T) {
			for _, tc := range cases {
				t.Run(tc.name, func(t *testing.T) {
					bs, ts := &jsonContractBills{}, &jsonContractTabs{}
					router, err := newRouter(bill.NewBillHandler(bs), currency.NewHandler(exchange.NewClient("http://127.0.0.1:1")), tab.NewTabHandler(ts), nil, nil)
					if err != nil {
						t.Fatal(err)
					}
					w := compositionRequest(router, "PATCH", path, tc.body)
					calls, updates := bs.calls, bs.updates
					if attached {
						calls, updates = ts.calls, ts.updates
					}
					if w.Code != tc.status {
						t.Fatalf("status=%d want=%d body=%s", w.Code, tc.status, w.Body)
					}
					if tc.status != 200 {
						if calls != 0 {
							t.Fatal("invalid input reached service")
						}
						return
					}
					if calls != 1 || len(updates) != 1 || updates[0].ItemID != 2 || !reflect.DeepEqual(updates[0].Assignments, tc.assignments) {
						t.Fatalf("calls=%d command=%#v", calls, updates)
					}
				})
			}
		})
	}
}

func TestJSONMaximumMutationContract(t *testing.T) {
	oldMode := gin.Mode()
	gin.SetMode(gin.TestMode)
	defer gin.SetMode(oldMode)
	t.Setenv("TRUSTED_PROXY_CIDRS", "")
	// Unique names per item at the approved aggregate cap. Real router and
	// transformations must pass all 50,000 assignments to the service unchanged.
	var updates []bill.AssignmentUpdateInput
	for i := 1; i <= 500; i++ {
		input := bill.AssignmentUpdateInput{ItemID: uint(i)}
		for j := 0; j < 100; j++ {
			input.Assignments = append(input.Assignments, bill.AssignmentInput{PersonName: fmt.Sprintf("Person%03d", j), Percentage: 1})
		}
		updates = append(updates, input)
	}
	body, _ := json.Marshal(map[string]any{"updates": updates})
	bs := &jsonContractBills{}
	r, err := newRouter(bill.NewBillHandler(bs), currency.NewHandler(exchange.NewClient("http://127.0.0.1:1")), tab.NewTabHandler(&jsonContractTabs{}), nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	w := compositionRequest(r, "PATCH", "/api/bills/1/assignments", string(body))
	if w.Code != 200 || bs.calls != 1 || len(bs.updates) != 500 {
		t.Fatalf("status=%d calls=%d updates=%d", w.Code, bs.calls, len(bs.updates))
	}
	for i, u := range bs.updates {
		if u.ItemID != uint(i+1) || len(u.Assignments) != 100 {
			t.Fatalf("item %d: wrong count/ID", i)
		}
		for j, a := range u.Assignments {
			if a.PersonName != fmt.Sprintf("Person%03d", j) || a.Percentage != 1 {
				t.Fatalf("item %d assignment %d changed", i, j)
			}
		}
	}
}
