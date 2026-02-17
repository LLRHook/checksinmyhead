package receipt

import (
	"errors"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"
)

const maxReceiptSize = 10 << 20 // 10 MB

// Handler handles HTTP requests for receipt parsing.
type Handler struct {
	service *Service
}

// NewHandler creates a new receipt handler.
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// ParseReceipt handles POST /api/receipts/parse
// Accepts a multipart image and returns structured receipt data.
func (h *Handler) ParseReceipt(c *gin.Context) {
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
