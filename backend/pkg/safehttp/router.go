package safehttp

import (
	"errors"
	"github.com/gin-gonic/gin"
	"net/netip"
	"strings"
)

var errProxyConfig = errors.New("invalid trusted proxy configuration")

// NewRouter is the common production trust/recovery boundary. It never consults
// platform-specific forwarding headers or trusts a proxy by default.
func NewRouter(config string) (*gin.Engine, error) {
	proxies, err := parseProxies(config)
	if err != nil {
		return nil, err
	}
	r := gin.New()
	r.TrustedPlatform = ""
	r.AppEngine = false
	r.ForwardedByClientIP = true
	r.RemoteIPHeaders = []string{"X-Forwarded-For"}
	if err := r.SetTrustedProxies(proxies); err != nil {
		return nil, errProxyConfig
	}
	r.Use(normalizeForwardedIP, RequestLogger(), Recovery())
	return r, nil
}
func parseProxies(config string) ([]string, error) {
	if config == "" {
		return nil, nil
	}
	if len(config) > 2048 {
		return nil, errProxyConfig
	}
	entries := strings.Split(config, ",")
	if len(entries) > 32 {
		return nil, errProxyConfig
	}
	for i, entry := range entries {
		entry = strings.TrimSpace(entry)
		prefix, err := netip.ParsePrefix(entry)
		if err != nil || prefix.Bits() == 0 || prefix.Addr().Is4In6() || prefix.Masked().String() != entry {
			return nil, errProxyConfig
		}
		entries[i] = entry
	}
	return entries, nil
}

// Gin normalizes socket addresses, but returns a validated XFF token verbatim.
// Normalize mapped IPv4 there too so both future admission and RequestLogger see
// one ClientIP identity. Preserve invalid tokens: Gin must still fall back to
// the socket if its right-to-left trust walk reaches one, but it may select a
// valid untrusted suffix without visiting an invalid left prefix.
func normalizeForwardedIP(c *gin.Context) {
	values := c.Request.Header.Values("X-Forwarded-For")
	if len(values) > 0 {
		entries := strings.Split(strings.Join(values, ","), ",")
		for i, s := range entries {
			ip, err := netip.ParseAddr(strings.TrimSpace(s))
			if err != nil || ip.Zone() != "" {
				continue
			}
			entries[i] = ip.Unmap().String()
		}
		c.Request.Header.Set("X-Forwarded-For", strings.Join(entries, ","))
	}
	c.Next()
}
