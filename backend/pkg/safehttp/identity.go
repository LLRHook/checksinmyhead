package safehttp

import (
	"net/http"
	"net/url"
	"strings"

	"github.com/gin-gonic/gin"
)

const IdentityHeader = "X-Billington-Identity-Version"

func ParseIdentityVersion(h http.Header) (int16, bool) {
	count, value := 0, ""
	for k, values := range h {
		if strings.EqualFold(k, IdentityHeader) {
			if len(values) != 1 {
				return 0, false
			}
			count += len(values)
			value = values[0]
		}
	}
	if count == 0 {
		return 1, true
	}
	if count != 1 {
		return 0, false
	}
	if value == "1" {
		return 1, true
	}
	if value == "2" {
		return 2, true
	}
	return 0, false
}

func IdentityVersion(c *gin.Context) (int16, bool) {
	v, ok := ParseIdentityVersion(c.Request.Header)
	if !ok {
		StopRejectedBody(c.Writer, c.Request)
		c.AbortWithStatusJSON(400, gin.H{"error": "invalid identity version", "code": "invalid_identity_version"})
		return 0, false
	}
	c.Header(IdentityHeader, map[int16]string{1: "1", 2: "2"}[v])
	for _, name := range []string{IdentityHeader, "Authorization", "X-Member-Token"} {
		found := false
		for _, line := range c.Writer.Header().Values("Vary") {
			for _, token := range strings.Split(line, ",") {
				if strings.EqualFold(strings.TrimSpace(token), name) {
					found = true
				}
			}
		}
		if !found {
			c.Writer.Header().Add("Vary", name)
		}
	}
	c.Header("Cache-Control", "private, no-store")
	// Every token-gated route admits identity before calling its service. Read
	// both selected capabilities here so malformed text cannot reach any query.
	AccessToken(c)
	if !c.IsAborted() {
		MemberToken(c)
	}
	if c.IsAborted() {
		return 0, false
	}
	return v, true
}

func IdentityMiddleware(c *gin.Context) {
	if _, ok := IdentityVersion(c); ok {
		c.Next()
	}
}

// Supplied invalid/empty/duplicate proof must not become memberless authority.
// PostgreSQL text cannot contain NUL, so this sentinel cannot match a token.
func MemberToken(c *gin.Context) string {
	count, value, supplied := 0, "", false
	for name, values := range c.Request.Header {
		if strings.EqualFold(name, "X-Member-Token") {
			supplied = true
			if len(values) != 1 || values[0] == "" {
				return "\x00"
			}
			count += len(values)
			value = values[0]
		}
	}
	if supplied {
		if count != 1 {
			return "\x00"
		}
		return tokenText(c, value)
	}
	query, err := url.ParseQuery(c.Request.URL.RawQuery)
	if err != nil {
		return "\x00"
	}
	if values, present := query["m"]; present {
		if len(values) != 1 || values[0] == "" {
			return "\x00"
		}
		return tokenText(c, values[0])
	}
	return ""
}
