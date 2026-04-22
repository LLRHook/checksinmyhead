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
// Accepts a multipart image and returns structured receipt data.
func (h *Handler) ParseReceipt(c *gin.Context) {
	if !h.limiter.Allow(c.ClientIP()) {
		c.JSON(http.StatusTooManyRequests, gin.H{"error": "Too many scans. Please wait a moment and try again.", "code": "rate_limited"})
		return
	}

	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxReceiptSize)

	file, header, err := c.Request.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "image file required"})
		return
	}
	defer file.Close()

	// Detect MIME type from first 512 bytes
	buf := make([]byte, 512)
	n, err := file.Read(buf)
	if err != nil && err != io.EOF {
		c.JSON(http.StatusBadRequest, gin.H{"error": "failed to read file"})
		return
	}
	mimeType := http.DetectContentType(buf[:n])

	allowed := map[string]bool{
		"image/jpeg": true,
		"image/png":  true,
		"image/webp": true,
		"image/heic": true,
		"image/heif": true,
	}
	if !allowed[mimeType] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "unsupported image type: " + mimeType})
		return
	}

	// Seek back and read full image
	if _, err := file.Seek(0, io.SeekStart); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to process file"})
		return
	}

	imageData, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to read image"})
		return
	}

	_ = header // used for FormFile call, not needed beyond that

	receipt, err := h.service.Parse(imageData, mimeType)
	if err != nil {
		var parseErr *ParseError
		if errors.As(err, &parseErr) {
			switch parseErr.Code {
			case ErrRateLimited:
				c.JSON(http.StatusTooManyRequests, gin.H{"error": "Too many scans. Please wait a moment and try again.", "code": string(parseErr.Code)})
			case ErrAuthFailed:
				c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Receipt scanning is temporarily unavailable. Please try again later.", "code": string(parseErr.Code)})
			case ErrImageTooLarge:
				c.JSON(http.StatusRequestEntityTooLarge, gin.H{"error": "Image is too large. Try a lower resolution photo.", "code": string(parseErr.Code)})
			case ErrOverloaded:
				c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Scanner is busy right now. Please try again in a moment.", "code": string(parseErr.Code)})
			case ErrProviderDown:
				c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Scanner is temporarily unavailable. Please try again later.", "code": string(parseErr.Code)})
			case ErrBadResponse:
				c.JSON(http.StatusUnprocessableEntity, gin.H{"error": "Could not read the receipt. Try a clearer photo.", "code": string(parseErr.Code)})
			default:
				c.JSON(http.StatusUnprocessableEntity, gin.H{"error": "Could not parse receipt. Try a clearer photo.", "code": string(parseErr.Code)})
			}
		} else {
			c.JSON(http.StatusUnprocessableEntity, gin.H{"error": "Could not parse receipt. Try a clearer photo."})
		}
		return
	}

	c.JSON(http.StatusOK, receipt)
}
