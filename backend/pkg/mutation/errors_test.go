package mutation

import (
	"bytes"
	"context"
	"errors"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgconn"
	"gorm.io/gorm"
	"log"
	"net"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestMutationErrorsAreFiniteAndPreserveStatus(t *testing.T) {
	gin.SetMode(gin.TestMode)
	for _, tc := range []struct {
		name   string
		err    error
		status int
	}{
		{"forbidden", Forbidden, 403}, {"review", Review, 409}, {"invalid", Invalid, 400}, {"missing", gorm.ErrRecordNotFound, 404},
		{"constraint", &pgconn.PgError{Code: "23514", Message: "private-synthetic-error", Detail: "private-synthetic-detail"}, 500},
		{"connection", &pgconn.PgError{Code: "08006", Message: "private-synthetic-error"}, 503},
		{"network", &net.OpError{Op: "dial", Err: errors.New("private-synthetic-error")}, 503},
		{"deadline", context.DeadlineExceeded, 503}, {"arbitrary", errors.New("private-synthetic-error"), 500},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var logs bytes.Buffer
			old := log.Writer()
			log.SetOutput(&logs)
			defer log.SetOutput(old)
			w := httptest.NewRecorder()
			c, _ := gin.CreateTestContext(w)
			WriteError(c, tc.err)
			if w.Code != tc.status {
				t.Fatal(w.Code)
			}
			if strings.Contains(w.Body.String()+logs.String(), "private-synthetic") {
				t.Fatal("raw request failure leaked")
			}
		})
	}
}
func TestMutationContextHonorsEarlierDeadlines(t *testing.T) {
	started := time.Now()
	ctx, cancel := Bound(context.Background())
	defer cancel()
	deadline, ok := ctx.Deadline()
	if !ok || deadline.After(started.Add(10*time.Second+time.Millisecond)) {
		t.Fatal("mutation deadline exceeds 10s")
	}
	earlier, stop := context.WithTimeout(context.Background(), time.Second)
	defer stop()
	bounded, done := Bound(earlier)
	defer done()
	want, _ := earlier.Deadline()
	got, _ := bounded.Deadline()
	if !want.Equal(got) {
		t.Fatal("earlier deadline lost")
	}
}
