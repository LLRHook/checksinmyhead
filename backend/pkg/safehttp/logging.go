package safehttp

import (
	"fmt"
	"strings"

	"github.com/gin-gonic/gin"
)

func AccessToken(c *gin.Context) string {
	authorization := c.GetHeader("Authorization")
	if strings.HasPrefix(authorization, "Bearer ") {
		return strings.TrimPrefix(authorization, "Bearer ")
	}
	return c.Query("t")
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
