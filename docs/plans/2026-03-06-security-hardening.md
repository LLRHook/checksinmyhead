# Security Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix all identified security vulnerabilities across backend, web viewer, and mobile app.

**Architecture:** Backend gets a security middleware layer (headers, CORS, rate limiting), constant-time token comparison, and sanitized error responses. Web viewer moves tokens from URL query params to Authorization headers and adds CSP. Mobile adds deep link domain validation and strips debug logging.

**Tech Stack:** Go/Gin backend, Next.js web viewer, Flutter/Dart mobile app

---

### Task 1: Backend — Constant-time token comparison

**Files:**
- Modify: `backend/internal/bill/handler.go:90`
- Modify: `backend/internal/tab/handler.go:66`
- Modify: `backend/internal/image/handler.go:69`
- Modify: `backend/internal/web/handler.go:52`

**Step 1: Update bill handler**

In `backend/internal/bill/handler.go`, add `"crypto/subtle"` to imports, then replace line 90:

```go
// BEFORE:
if URLtoken != bill.AccessToken {

// AFTER:
if subtle.ConstantTimeCompare([]byte(URLtoken), []byte(bill.AccessToken)) != 1 {
```

**Step 2: Update tab handler**

In `backend/internal/tab/handler.go`, add `"crypto/subtle"` to imports, then replace line 66:

```go
// BEFORE:
if urlToken != tab.AccessToken {

// AFTER:
if subtle.ConstantTimeCompare([]byte(urlToken), []byte(tab.AccessToken)) != 1 {
```

**Step 3: Update image handler**

In `backend/internal/image/handler.go`, add `"crypto/subtle"` to imports, then replace line 69:

```go
// BEFORE:
if urlToken != t.AccessToken {

// AFTER:
if subtle.ConstantTimeCompare([]byte(urlToken), []byte(t.AccessToken)) != 1 {
```

**Step 4: Update web handler**

In `backend/internal/web/handler.go`, add `"crypto/subtle"` to imports, then replace line 52:

```go
// BEFORE:
if URLtoken != bill.AccessToken {

// AFTER:
if subtle.ConstantTimeCompare([]byte(URLtoken), []byte(bill.AccessToken)) != 1 {
```

**Step 5: Verify it compiles**

Run: `cd backend && go build ./...`
Expected: No errors

**Step 6: Commit**

```
security: use constant-time comparison for token validation
```

---

### Task 2: Backend — Security headers middleware + CORS restriction

**Files:**
- Modify: `backend/cmd/bill-service/main.go:53-60`

**Step 1: Add security headers middleware and restrict CORS**

In `backend/cmd/bill-service/main.go`, replace the CORS block (lines 54-60) and add a security headers middleware before it. The `AllowOrigins` list should be configurable via `CORS_ORIGINS` env var, defaulting to `https://billingtonapp.vercel.app`.

```go
// Security headers middleware
r.Use(func(c *gin.Context) {
    c.Header("X-Content-Type-Options", "nosniff")
    c.Header("X-Frame-Options", "DENY")
    c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
    c.Next()
})

// CORS
origins := []string{"https://billingtonapp.vercel.app"}
if extra := os.Getenv("CORS_ORIGINS"); extra != "" {
    for _, o := range strings.Split(extra, ",") {
        if trimmed := strings.TrimSpace(o); trimmed != "" {
            origins = append(origins, trimmed)
        }
    }
}
r.Use(cors.New(cors.Config{
    AllowOrigins:  origins,
    AllowMethods:  []string{"GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"},
    AllowHeaders:  []string{"Origin", "Content-Type", "Accept", "Authorization", "X-Member-Token"},
    ExposeHeaders: []string{"Content-Length"},
}))
```

Note: Add `"strings"` to the imports if not already present (it is already imported in the file via other packages, but `main.go` doesn't have it — add it).

**Step 2: Verify it compiles**

Run: `cd backend && go build ./...`
Expected: No errors

**Step 3: Commit**

```
security: add security headers and restrict CORS to allowed origins
```

---

### Task 3: Backend — Sanitize error responses

**Files:**
- Modify: `backend/internal/bill/handler.go` (lines 46, 87)
- Modify: `backend/internal/tab/handler.go` (lines 62, 112, 173, 210, 249, 277, 306, 326)
- Modify: `backend/internal/image/handler.go` (lines 65, 199, 226, 243, 275, 284)

**Step 1: Replace all `err.Error()` in 500 responses with generic messages**

The pattern is the same everywhere. Find every instance of:
```go
c.JSON(500, gin.H{"error": err.Error()})
// or
c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
```

Replace with:
```go
log.Printf("internal error: %v", err)
c.JSON(500, gin.H{"error": "an internal error occurred"})
// or for http.Status* variant:
log.Printf("internal error: %v", err)
c.JSON(http.StatusInternalServerError, gin.H{"error": "an internal error occurred"})
```

Add `"log"` to imports in each file that doesn't already have it.

**Do NOT change:**
- 400-level responses (those are fine — they return safe static strings like "bad request", "tab not found")
- The receipt handler (`receipt/handler.go`) — it already returns user-friendly messages

**Step 2: Sanitize receipt service logging**

In `backend/internal/receipt/service.go:213`, replace:
```go
fmt.Printf("[receipt] Anthropic returned status %d: %s\n", resp.StatusCode, truncate(string(respBody), 500))
```
With:
```go
log.Printf("[receipt] Anthropic returned status %d", resp.StatusCode)
```

Add `"log"` to imports, remove `"fmt"` if no longer used (check — it IS still used for `fmt.Errorf` on lines 190, 196, 203, 209, 240, so keep it).

**Step 3: Verify it compiles**

Run: `cd backend && go build ./...`
Expected: No errors

**Step 4: Commit**

```
security: sanitize error responses to prevent internal detail leakage
```

---

### Task 4: Backend — GenerateSecureToken returns error

**Files:**
- Modify: `backend/pkg/security/token.go:30-36`
- Modify: `backend/internal/bill/handler.go:39`
- Modify: `backend/internal/tab/handler.go:107`

**Step 1: Change GenerateSecureToken to return (string, error)**

In `backend/pkg/security/token.go`, replace:
```go
func GenerateSecureToken() string {
	b := make([]byte, 8)
	if _, err := rand.Read(b); err != nil {
		panic("crypto/rand failed: " + err.Error())
	}
	return base62Encode(b)
}
```

With:
```go
func GenerateSecureToken() (string, error) {
	b := make([]byte, 8)
	if _, err := rand.Read(b); err != nil {
		return "", fmt.Errorf("crypto/rand failed: %w", err)
	}
	return base62Encode(b), nil
}
```

Add `"fmt"` to imports.

**Step 2: Update bill handler caller**

In `backend/internal/bill/handler.go`, replace line 39:
```go
// BEFORE:
token := security.GenerateSecureToken()

// AFTER:
token, err := security.GenerateSecureToken()
if err != nil {
    log.Printf("internal error: %v", err)
    c.JSON(500, gin.H{"error": "an internal error occurred"})
    return
}
```

**Step 3: Update tab handler caller**

In `backend/internal/tab/handler.go`, replace line 107:
```go
// BEFORE:
token := security.GenerateSecureToken()

// AFTER:
token, err := security.GenerateSecureToken()
if err != nil {
    log.Printf("internal error: %v", err)
    c.JSON(500, gin.H{"error": "an internal error occurred"})
    return
}
```

**Step 4: Verify it compiles**

Run: `cd backend && go build ./...`
Expected: No errors

**Step 5: Commit**

```
security: return error from GenerateSecureToken instead of panicking
```

---

### Task 5: Backend — File extension whitelist + receipt rate limiting

**Files:**
- Modify: `backend/internal/image/handler.go:130-134`
- Modify: `backend/internal/receipt/handler.go`
- Modify: `backend/cmd/bill-service/main.go`

**Step 1: Add file extension whitelist in image handler**

In `backend/internal/image/handler.go`, replace lines 130-134:
```go
// BEFORE:
ext := filepath.Ext(header.Filename)
if ext == "" {
    ext = ".jpg"
}

// AFTER:
ext := strings.ToLower(filepath.Ext(header.Filename))
validExts := map[string]bool{".jpg": true, ".jpeg": true, ".png": true, ".webp": true, ".heic": true, ".heif": true}
if !validExts[ext] {
    ext = ".jpg"
}
```

**Step 2: Add rate limiter to receipt handler**

In `backend/internal/receipt/handler.go`, we need to move the rate limiter to a shared package or just add an IP-based one. Since the existing `image.RateLimiter` is tab-scoped and the receipt endpoint has no tab, we'll add a simple IP-based rate limit.

Add a rate limiter field to the Handler and check it:

```go
package receipt

import (
	"errors"
	"io"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

const maxReceiptSize = 10 << 20 // 10 MB

type ipLimiter struct {
	mu      sync.Mutex
	buckets map[string][]time.Time
	limit   int
	window  time.Duration
}

func newIPLimiter(limit int, window time.Duration) *ipLimiter {
	return &ipLimiter{
		buckets: make(map[string][]time.Time),
		limit:   limit,
		window:  window,
	}
}

func (rl *ipLimiter) Allow(ip string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	cutoff := now.Add(-rl.window)

	timestamps := rl.buckets[ip]
	valid := timestamps[:0]
	for _, ts := range timestamps {
		if ts.After(cutoff) {
			valid = append(valid, ts)
		}
	}

	if len(valid) >= rl.limit {
		rl.buckets[ip] = valid
		return false
	}

	rl.buckets[ip] = append(valid, now)
	return true
}

// Handler handles HTTP requests for receipt parsing.
type Handler struct {
	service *Service
	limiter *ipLimiter
}

// NewHandler creates a new receipt handler.
func NewHandler(service *Service) *Handler {
	return &Handler{
		service: service,
		limiter: newIPLimiter(10, time.Minute),
	}
}

// ParseReceipt handles POST /api/receipts/parse
func (h *Handler) ParseReceipt(c *gin.Context) {
	if !h.limiter.Allow(c.ClientIP()) {
		c.JSON(http.StatusTooManyRequests, gin.H{"error": "Too many scans. Please wait a moment and try again.", "code": "rate_limited"})
		return
	}

	// ... rest stays the same from the existing c.Request.Body = ... line onward
```

Rewrite the full file to include the limiter. Keep everything from `c.Request.Body = http.MaxBytesReader(...)` onward unchanged.

**Step 3: Verify it compiles**

Run: `cd backend && go build ./...`
Expected: No errors

**Step 4: Commit**

```
security: add file extension whitelist and receipt endpoint rate limiting
```

---

### Task 6: Web Viewer — Move tokens from URL params to Authorization headers

**Files:**
- Modify: `web-bill-viewer/src/lib/api.ts` (lines 92-167, 174-175)

**Step 1: Update all fetch calls to use Authorization header**

Replace each API function's fetch call. The pattern is the same for all GET requests:

```typescript
// BEFORE:
const response = await fetch(`${API_BASE_URL}/api/bills/${id}?t=${token}`);

// AFTER:
const response = await fetch(`${API_BASE_URL}/api/bills/${id}`, {
  headers: { Authorization: `Bearer ${token}` },
});
```

Apply to these functions:
- `getBill` (line 93)
- `getTab` (line 109)
- `getTabImages` (line 128-130)
- `getSettlements` (line 143-145)
- `getTabMembers` (line 158-160)

For `joinTab` (POST, line 174-175):
```typescript
// BEFORE:
const response = await fetch(
  `${API_BASE_URL}/api/tabs/${id}/join?t=${token}`,
  {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ display_name: displayName }),
  },
);

// AFTER:
const response = await fetch(
  `${API_BASE_URL}/api/tabs/${id}/join`,
  {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ display_name: displayName }),
  },
);
```

**Step 2: Verify it builds**

Run: `cd web-bill-viewer && npm run build`
Expected: No errors

**Step 3: Commit**

```
security: move tokens from URL query params to Authorization headers
```

---

### Task 7: Web Viewer — Add security headers via Next.js config

**Files:**
- Modify: `web-bill-viewer/next.config.ts`

**Step 1: Add security headers**

Replace the contents of `web-bill-viewer/next.config.ts`:

```typescript
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          {
            key: "Content-Security-Policy",
            value: [
              "default-src 'self'",
              "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
              "style-src 'self' 'unsafe-inline'",
              "img-src 'self' data: https:",
              "font-src 'self'",
              "connect-src 'self' https://billington-api.onrender.com",
              "frame-ancestors 'none'",
            ].join("; "),
          },
        ],
      },
    ];
  },
};

export default nextConfig;
```

Note: `'unsafe-inline'` and `'unsafe-eval'` are needed for Next.js to function. `connect-src` allows the production API domain.

**Step 2: Verify it builds**

Run: `cd web-bill-viewer && npm run build`
Expected: No errors

**Step 3: Commit**

```
security: add CSP and security headers to web viewer
```

---

### Task 8: Mobile — Deep link domain validation + sanitize debug logging

**Files:**
- Modify: `mobile/lib/screens/tabs/tab_manager.dart` (lines 213-220)
- Modify: `mobile/lib/services/receipt_api_service.dart` (lines 61, 97)

**Step 1: Add domain validation to joinTab URL parsing**

In `mobile/lib/screens/tabs/tab_manager.dart`, replace lines 213-220:

```dart
// BEFORE:
  // Parse URL: https://billington.app/t/{id}?t={token}
  final uri = Uri.parse(shareUrl);
  final pathSegments = uri.pathSegments;
  if (pathSegments.length < 2 || pathSegments[0] != 't') return null;

  final tabId = int.tryParse(pathSegments[1]);
  final accessToken = uri.queryParameters['t'];
  if (tabId == null || accessToken == null) return null;

// AFTER:
  // Parse and validate URL: https://billingtonapp.vercel.app/t/{id}?t={token}
  final uri = Uri.parse(shareUrl);

  const allowedHosts = {'billingtonapp.vercel.app', 'billington.app'};
  if (uri.scheme != 'https' || !allowedHosts.contains(uri.host)) {
    return null;
  }

  final pathSegments = uri.pathSegments;
  if (pathSegments.length < 2 || pathSegments[0] != 't') return null;

  final tabId = int.tryParse(pathSegments[1]);
  final accessToken = uri.queryParameters['t'];
  if (tabId == null || accessToken == null) return null;
```

**Step 2: Sanitize receipt API logging**

In `mobile/lib/services/receipt_api_service.dart`, replace line 61:
```dart
// BEFORE:
_logger.d('Receipt parse failed: ${response.statusCode} ${response.body}');

// AFTER:
_logger.d('Receipt parse failed: ${response.statusCode}');
```

Replace line 97:
```dart
// BEFORE:
_logger.d('Receipt parse error: $e');

// AFTER:
_logger.d('Receipt parse error');
```

**Step 3: Commit**

```
security: validate deep link domains and sanitize mobile logging
```

---

### Task 9: Final verification

**Step 1: Backend compiles clean**

Run: `cd backend && go build ./...`

**Step 2: Web viewer builds clean**

Run: `cd web-bill-viewer && npm run build`

**Step 3: Review all changes**

Run: `git diff` and verify:
- No `err.Error()` in 500 responses (backend)
- No `!=` token comparisons (backend)
- No `AllowAllOrigins: true` (backend)
- No `?t=` in fetch URLs (web viewer)
- CSP header configured (web viewer)
- Domain validation in deep link parsing (mobile)

**Step 4: Commit if any stragglers, then done**
