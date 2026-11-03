// Package mutation defines the finite public failures and deadline shared by
// receipt/tab mutations. Transaction ownership stays in the repositories.
package mutation

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"errors"
	"github.com/jackc/pgx/v5/pgconn"
	"net"
	"time"

	"backend/pkg/database"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type Failure struct {
	Status        int
	Code, Message string
}

func (e *Failure) Error() string { return e.Message }

var (
	StandaloneOnly = &Failure{400, "standalone_lazy_required", "item claiming is only available on standalone lazy bills"}
	Forbidden      = &Failure{403, "access_denied", "access denied"}
	Review         = &Failure{409, "accounting_review_required", "accounting review required"}
	Finalized      = &Failure{400, "tab_finalized", "tab is finalized"}
	NoBills        = &Failure{400, "no_bills", "tab has no bills"}
	NoAllocation   = &Failure{400, "no_allocation", "tab has no allocated shares"}
	Invalid        = &Failure{400, "invalid_mutation", "invalid mutation"}
	Referenced     = &Failure{409, "member_referenced", "member has recorded bill provenance"}
	CreatorLeave   = &Failure{400, "creator_cannot_leave", "the tab creator cannot leave the tab"}
)

func Bound(ctx context.Context) (context.Context, context.CancelFunc) {
	return context.WithTimeout(ctx, 10*time.Second)
}
func WriteError(c *gin.Context, err error) {
	var failure *Failure
	switch {
	case errors.As(err, &failure):
		c.JSON(failure.Status, gin.H{"error": failure.Message, "code": failure.Code})
	case errors.Is(err, gorm.ErrRecordNotFound):
		c.JSON(404, gin.H{"error": "object not found"})
	default:
		database.LogRequestError(err)
		var state interface{ SQLState() string }
		var connection *pgconn.ConnectError
		var network net.Error
		transient := errors.Is(err, context.DeadlineExceeded) || errors.Is(err, context.Canceled) || errors.Is(err, driver.ErrBadConn) || errors.Is(err, sql.ErrConnDone) || errors.As(err, &connection) || errors.As(err, &network)
		if errors.As(err, &state) {
			switch state.SQLState() {
			case "08000", "08001", "08003", "08004", "08006", "08007", "08P01", "40001", "40P01", "55P03", "57014", "53300", "57P01", "57P02", "57P03":
				transient = true
			}
		}
		if transient {
			c.JSON(503, gin.H{"error": "temporarily unavailable; retry"})
		} else {
			c.JSON(500, gin.H{"error": "an internal error occurred"})
		}
	}
}
