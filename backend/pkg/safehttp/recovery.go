package safehttp

import (
	"log"
	"net"
	"net/http"
	"os"
	"syscall"

	"github.com/gin-gonic/gin"
)

// Recovery deliberately never formats, unwraps arbitrary user error types, or
// attaches the panic to gin.Context. Gin's default recovery logs before callbacks.
func Recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if value := recover(); value != nil {
				category := "panic"
				abort := c.Writer.Written() || c.Request.Context().Err() != nil || disconnected(value)
				if abort {
					category = "abort"
				}
				log.Printf("event=http_recovery category=%s route=%s", category, recoveryRoute(c.FullPath()))
				c.Abort()
				if abort {
					panic(http.ErrAbortHandler)
				}
				c.JSON(http.StatusInternalServerError, gin.H{"error": "an internal error occurred"})
			}
		}()
		c.Next()
	}
}
func disconnected(value any) bool {
	for depth := 0; depth < 8; depth++ {
		switch e := value.(type) {
		case *net.OpError:
			value = e.Err
		case *os.SyscallError:
			value = e.Err
		case syscall.Errno:
			return e == syscall.EPIPE || e == syscall.ECONNRESET
		case error:
			return e == http.ErrAbortHandler
		default:
			return false
		}
	}
	return false
}

// Only source-owned route patterns may appear in a recovery event. Unmatched or
// newly introduced routes use the same finite fallback until explicitly reviewed.
func recoveryRoute(route string) string {
	switch route {
	case "/health", "/b/:id", "/api/app/version-policy", "/api/currency/rate", "/api/bills/:id", "/api/bills", "/api/exchange-rates/:currency",
		"/api/bills/:id/shares/:shareId", "/api/bills/:id/items/:itemId/assignments", "/api/bills/:id/assignments", "/api/tabs", "/api/tabs/:id",
		"/api/tabs/:id/bills", "/api/tabs/:id/bills/:billId/items/:itemId/assignments", "/api/tabs/:id/bills/:billId/assignments",
		"/api/tabs/:id/bills/:billId/shares/:shareId/paid", "/api/tabs/:id/finalize", "/api/tabs/:id/settlements", "/api/tabs/:id/settlements/:settlementId",
		"/api/tabs/:id/join", "/api/tabs/:id/members/me", "/api/tabs/:id/members", "/api/receipts/parse":
		return route
	default:
		return "other"
	}
}
