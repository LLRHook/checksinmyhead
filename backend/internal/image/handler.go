package image

import (
	"backend/internal/tab"
	"backend/pkg/models"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

const maxUploadSize = 10 << 20 // 10 MB

type ImageHandler struct {
	service    ImageService
	tabService tab.TabService
	uploadDir  string
	limiter    *RateLimiter
}

func NewImageHandler(service ImageService, tabService tab.TabService, uploadDir string) *ImageHandler {
	return &ImageHandler{
		service:    service,
		tabService: tabService,
		uploadDir:  uploadDir,
		limiter:    NewRateLimiter(20, time.Hour),
	}
}

// validateTabToken parses the tab ID, fetches the tab, and checks the token.
// Returns the tab ID on success or writes an error response and returns 0.
func (h *ImageHandler) validateTabToken(c *gin.Context) uint {
	id := c.Param("id")
	urlToken := c.Query("t")

	idUint, err := strconv.ParseUint(id, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id format"})
		return 0
	}

	t, err := h.tabService.GetTab(uint(idUint))
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "tab not found"})
			return 0
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return 0
	}

	if urlToken != t.AccessToken {
		c.JSON(http.StatusForbidden, gin.H{"error": "token mismatch"})
		return 0
	}

	return uint(idUint)
}

// UploadImage handles POST /api/tabs/:id/images?t=token
func (h *ImageHandler) UploadImage(c *gin.Context) {
	tabID := h.validateTabToken(c)
	if tabID == 0 {
		return
	}

	if !h.limiter.Allow(tabID) {
		c.JSON(http.StatusTooManyRequests, gin.H{"error": "upload rate limit exceeded (20/hour)"})
		return
	}

	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxUploadSize)

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

	// Seek back to beginning
	if _, err := file.Seek(0, io.SeekStart); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to process file"})
		return
	}

	// Generate random filename with original extension
	ext := filepath.Ext(header.Filename)
	if ext == "" {
		ext = ".jpg"
	}
	randBytes := make([]byte, 16)
	rand.Read(randBytes)
	filename := hex.EncodeToString(randBytes) + ext

	// Create directory
	dir := filepath.Join(h.uploadDir, "tabs", fmt.Sprintf("%d", tabID))
	if err := os.MkdirAll(dir, 0755); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create directory"})
		return
	}

	// Write file to disk
	dst, err := os.Create(filepath.Join(dir, filename))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save file"})
		return
	}
	defer dst.Close()

	if _, err := io.Copy(dst, file); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to write file"})
		return
	}

	url := fmt.Sprintf("/uploads/tabs/%d/%s", tabID, filename)

	image := &models.TabImage{
		TabID:      tabID,
		Filename:   filename,
		URL:        url,
		Size:       header.Size,
		MimeType:   mimeType,
		Processed:  false,
		UploadedBy: c.Query("uploaded_by"),
	}

	if err := h.service.Create(image); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save image record"})
		return
	}

	c.JSON(http.StatusCreated, image)
}

// ListImages handles GET /api/tabs/:id/images?t=token
func (h *ImageHandler) ListImages(c *gin.Context) {
	tabID := h.validateTabToken(c)
	if tabID == 0 {
		return
	}

	images, err := h.service.GetByTabID(tabID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, images)
}

// UpdateImage handles PATCH /api/tabs/:id/images/:imageId?t=token
func (h *ImageHandler) UpdateImage(c *gin.Context) {
	tabID := h.validateTabToken(c)
	if tabID == 0 {
		return
	}

	imageID, err := strconv.ParseUint(c.Param("imageId"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid image id"})
		return
	}

	// Verify image belongs to this tab
	image, err := h.service.GetByID(uint(imageID))
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "image not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if image.TabID != tabID {
		c.JSON(http.StatusForbidden, gin.H{"error": "image does not belong to this tab"})
		return
	}

	var body struct {
		Processed *bool `json:"processed"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || body.Processed == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "processed field required"})
		return
	}

	if err := h.service.UpdateProcessed(uint(imageID), *body.Processed); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

// DeleteImage handles DELETE /api/tabs/:id/images/:imageId?t=token
func (h *ImageHandler) DeleteImage(c *gin.Context) {
	tabID := h.validateTabToken(c)
	if tabID == 0 {
		return
	}

	imageID, err := strconv.ParseUint(c.Param("imageId"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid image id"})
		return
	}

	// Verify image belongs to this tab
	image, err := h.service.GetByID(uint(imageID))
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "image not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if image.TabID != tabID {
		c.JSON(http.StatusForbidden, gin.H{"error": "image does not belong to this tab"})
		return
	}

	if err := h.service.Delete(uint(imageID), h.uploadDir); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
