package safehttp_test

import (
	"backend/internal/bill"
	"backend/internal/tab"
	"backend/pkg/models"
	"bytes"
	"errors"
	"fmt"
	"log"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgconn"
	"gorm.io/gorm"
)

type failingBillReader struct {
	bill.BillService
	failure error
}

func (s failingBillReader) GetBill(uint) (*models.Bill, error) {
	return nil, s.failure
}

type failingTabReader struct {
	tab.TabService
	failure error
}

func (s failingTabReader) GetTab(uint) (*models.Tab, error) {
	return nil, s.failure
}

func TestRequestDatabaseErrorLogsStaySafe(t *testing.T) {
	gin.SetMode(gin.TestMode)
	routes := []struct {
		name    string
		handler func(error) gin.HandlerFunc
	}{
		{"bill", func(err error) gin.HandlerFunc { return bill.NewBillHandler(failingBillReader{failure: err}).GetBill }},
		{"tab", func(err error) gin.HandlerFunc { return tab.NewTabHandler(failingTabReader{failure: err}).GetTab }},
	}
	for _, route := range routes {
		t.Run(route.name, func(t *testing.T) {
			for _, tc := range []struct {
				name         string
				failure      error
				code         int
				class, state string
			}{
				{"constraint", &pgconn.PgError{Code: "23505", Message: "SYNTHETIC_RECEIPT_PRIVATE\nFORGED_LOG_LINE", Detail: "SYNTHETIC_PAYMENT_PRIVATE"}, 500, "constraint", "23505"},
				{"wrapped_connection", fmt.Errorf("wrapper: %w", &pgconn.PgError{Code: "08006", Message: "SYNTHETIC_RECEIPT_PRIVATE\nFORGED_LOG_LINE", Hint: "SYNTHETIC_PAYMENT_PRIVATE"}), 500, "connection", "08006"},
				{"arbitrary", errors.New("SYNTHETIC_RECEIPT_PRIVATE\nFORGED_LOG_LINE SYNTHETIC_PAYMENT_PRIVATE"), 500, "database", "unknown"},
				{"not_found", gorm.ErrRecordNotFound, 404, "", ""},
			} {
				t.Run(tc.name, func(t *testing.T) {
					var captured bytes.Buffer
					writer, flags, prefix := log.Writer(), log.Flags(), log.Prefix()
					log.SetOutput(&captured)
					log.SetFlags(0)
					log.SetPrefix("")
					t.Cleanup(func() { log.SetOutput(writer); log.SetFlags(flags); log.SetPrefix(prefix) })
					router := gin.New()
					router.GET("/probe/:id", route.handler(tc.failure))
					response := httptest.NewRecorder()
					router.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/probe/1", nil))
					if response.Code != tc.code {
						t.Errorf("status=%d want=%d", response.Code, tc.code)
					}
					for _, marker := range []string{"SYNTHETIC_RECEIPT_PRIVATE", "SYNTHETIC_PAYMENT_PRIVATE", "FORGED_LOG_LINE"} {
						if strings.Contains(captured.String(), marker) {
							t.Error("private marker reached process log")
						}
						if strings.Contains(response.Body.String(), marker) {
							t.Error("private marker reached HTTP response")
						}
					}
					if tc.code == 404 {
						if captured.Len() != 0 {
							t.Error("not-found branch gained an error log")
						}
					} else if !strings.Contains(captured.String(), "class="+tc.class+" sqlstate="+tc.state) {
						t.Error("safe error categories missing")
					}
				})
			}
		})
	}
}
