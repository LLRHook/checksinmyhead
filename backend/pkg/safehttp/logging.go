package safehttp

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

func AccessToken(c *gin.Context) string {
	authorization := c.GetHeader("Authorization")
	if strings.HasPrefix(authorization, "Bearer ") {
		return tokenText(c, strings.TrimPrefix(authorization, "Bearer "))
	}
	return tokenText(c, c.Query("t"))
}

// NUL cannot occur in a stored PostgreSQL token. Refuse it at the reader rather
// than sending it to a query or treating supplied member proof as absent.
func tokenText(c *gin.Context, value string) string {
	if strings.ContainsRune(value, 0) {
		StopRejectedBody(c.Writer, c.Request)
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "access denied", "code": "access_denied"})
		return ""
	}
	return value
}

// RequestLogger logs request paths without query strings. Bill and trip
// bearer credentials are historically accepted as query parameters.
func RequestLogger() gin.HandlerFunc {
	return gin.LoggerWithFormatter(FormatRequestLog)
}

func FormatRequestLog(param gin.LogFormatterParams) string {
	return fmt.Sprintf("%s - [%s] \"%s %s %s\" %d %s\n",
		param.ClientIP,
		param.TimeStamp.Format("2006/01/02 - 15:04:05"),
		param.Method,
		param.Request.URL.Path,
		param.Request.Proto,
		param.StatusCode,
		param.Latency,
	)
}
