package safehttp

import (
	"encoding/json"
	"github.com/gin-gonic/gin"
)

// Marshal before writing headers: non-finite/corrupt historical raw values must
// produce a finite failure, never a partial successful JSON response.
func JSONValue(c *gin.Context, status int, value any) {
	body, err := json.Marshal(value)
	if err != nil {
		c.JSON(503, gin.H{"error": "stored representation is temporarily unavailable", "code": "representation_unavailable"})
		return
	}
	c.Data(status, "application/json; charset=utf-8", body)
}
