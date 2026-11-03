// Package readiness shares the bounded database/ledger health contract.
package readiness

import (
	"backend/migrations"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

func Handler(state *migrations.State, status string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if state.Check(c.Request.Context()) != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"status": "service unavailable", "commit": os.Getenv("RENDER_GIT_COMMIT")})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": status, "commit": os.Getenv("RENDER_GIT_COMMIT")})
	}
}
