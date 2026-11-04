package receipt

import (
	"backend/pkg/safehttp"
	"bytes"
	"context"
	"errors"
	"io"
	"mime/multipart"
	"net"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// Handler owns admission and its sweeper for the service lifetime. Close only
// after serving has stopped; an operation holds its permit until actual work exits.
type Handler struct {
	service   *Service
	admission *admission
}

func NewHandler(s *Service) *Handler { return &Handler{service: s, admission: newAdmission(s.policy)} }
func (h *Handler) Close()            { h.admission.close(); h.service.Close() }

func (h *Handler) ParseReceipt(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), operationTimeout)
	defer cancel()
	release, err := h.admission.acquire(ctx, c.ClientIP(), time.Now())
	if err != nil {
		safehttp.StopRejectedBody(c.Writer, c.Request)
		writeFailure(c, err)
		return
	}
	defer release()
	image, mimeType, readErr := readMultipart(ctx, c.Writer, c.Request)
	if readErr != nil {
		if readErr.Code == ErrInvalidRequest {
			if !errors.Is(c.Request.Context().Err(), context.Canceled) {
				message := "image file required"
				if readErr.unsupportedImage {
					message = "unsupported image type: " + mimeType
				}
				c.JSON(400, gin.H{"error": message})
			}
		} else {
			writeFailure(c, readErr)
		}
		return
	}
	receipt, parseErr := h.service.Parse(ctx, image, mimeType)
	if parseErr != nil {
		var e *ParseError
		if !errors.As(parseErr, &e) {
			e = &ParseError{Code: ErrBadResponse}
		}
		writeFailure(c, e)
		return
	}
	if errors.Is(c.Request.Context().Err(), context.Canceled) {
		return
	}
	if c.Request.Context().Err() != nil {
		writeFailure(c, &ParseError{Code: ErrProviderDown, RetryAfter: 60})
		return
	}
	c.JSON(http.StatusOK, receipt)
}

func readMultipart(ctx context.Context, w http.ResponseWriter, r *http.Request) (image []byte, mimeType string, result *ParseError) {
	// Join the cancellation callback before the response writer is reused. Rejection
	// then leaves the shared read deadline expired through net/http body cleanup.
	complete := false
	defer func() {
		if !complete {
			safehttp.StopRejectedBody(w, r)
		}
	}()
	if r.ContentLength > maxReceiptSize {
		return nil, "", &ParseError{Code: ErrImageTooLarge}
	}
	if ctx.Err() != nil {
		return nil, "", &ParseError{Code: ErrProviderDown, RetryAfter: 60}
	}
	done := make(chan struct{})
	stop := context.AfterFunc(ctx, func() { defer close(done); _ = http.NewResponseController(w).SetReadDeadline(time.Now()) })
	defer func() {
		if !stop() {
			<-done
		}
	}()
	r.Body = http.MaxBytesReader(w, r.Body, maxReceiptSize)
	reader, err := r.MultipartReader()
	if err != nil {
		return nil, "", &ParseError{Code: ErrInvalidRequest}
	}
	found := false
	for parts := 0; ; parts++ {
		// NextRawPart does not transparently decode quoted-printable bytes.
		part, err := reader.NextRawPart()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, "", uploadFailure(ctx, err)
		}
		if parts >= 32 {
			return nil, "", &ParseError{Code: ErrImageTooLarge}
		}
		headers, size := 0, 0
		for key, values := range part.Header {
			headers += len(values)
			for _, v := range values {
				size += len(key) + len(v) + 4
			}
		}
		if headers > 64 || size > 16<<10 {
			return nil, "", &ParseError{Code: ErrImageTooLarge}
		}
		if part.FormName() != "image" {
			if _, err = io.Copy(io.Discard, part); err != nil {
				return nil, "", uploadFailure(ctx, err)
			}
			continue
		}
		if found || part.FileName() == "" {
			return nil, "", &ParseError{Code: ErrInvalidRequest}
		}
		found = true
		var prefix [512]byte
		n, err := io.ReadFull(part, prefix[:])
		if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
			return nil, "", uploadFailure(ctx, err)
		}
		mimeType = http.DetectContentType(prefix[:n])
		switch mimeType {
		case "image/jpeg", "image/png", "image/webp", "image/heic", "image/heif":
		default:
			return nil, mimeType, &ParseError{Code: ErrInvalidRequest, unsupportedImage: true}
		}
		// The total reader cap also bounds temporary multipart header allocations.
		image, err = io.ReadAll(io.MultiReader(bytes.NewReader(prefix[:n]), part))
		if err != nil {
			return nil, "", uploadFailure(ctx, err)
		}
		// Do not defer Part.Close: on early rejection it drains an unread remainder.
	}
	if _, err = io.Copy(io.Discard, r.Body); err != nil {
		return nil, "", uploadFailure(ctx, err)
	}
	if ctx.Err() != nil {
		return nil, "", &ParseError{Code: ErrProviderDown, RetryAfter: 60}
	}
	if !found {
		return nil, "", &ParseError{Code: ErrInvalidRequest}
	}
	complete = true
	return image, mimeType, nil
}

func uploadFailure(ctx context.Context, err error) *ParseError {
	var large *http.MaxBytesError
	if errors.As(err, &large) || errors.Is(err, multipart.ErrMessageTooLarge) {
		return &ParseError{Code: ErrImageTooLarge}
	}
	var network net.Error
	if ctx.Err() != nil || errors.As(err, &network) && network.Timeout() {
		return &ParseError{Code: ErrProviderDown, RetryAfter: 60}
	}
	return &ParseError{Code: ErrInvalidRequest}
}

func writeFailure(c *gin.Context, e *ParseError) {
	if errors.Is(c.Request.Context().Err(), context.Canceled) {
		return
	}
	status, message, code := http.StatusUnprocessableEntity, "Could not parse receipt. Try a clearer photo.", ErrInvalidRequest
	switch e.Code {
	case ErrInvalidPeer:
		status, message, code = 400, "invalid client address", ErrInvalidPeer
	case ErrRateLimited:
		status, message, code = 429, "Too many scans. Please wait a moment and try again.", ErrRateLimited
	case ErrAuthFailed:
		status, message, code = 503, "Receipt scanning is temporarily unavailable. Please try again later.", ErrAuthFailed
	case ErrImageTooLarge:
		status, message, code = 413, "Image is too large. Try a lower resolution photo.", ErrImageTooLarge
	case ErrOverloaded:
		status, message, code = 503, "Scanner is busy right now. Please try again in a moment.", ErrOverloaded
	case ErrProviderDown:
		status, message, code = 503, "Scanner is temporarily unavailable. Please try again later.", ErrProviderDown
	case ErrBadResponse:
		status, message, code = 422, "Could not read the receipt. Try a clearer photo.", ErrBadResponse
	}
	if e.RetryAfter > 0 && e.RetryAfter <= 86400 {
		c.Header("Retry-After", strconv.Itoa(e.RetryAfter))
	}
	c.JSON(status, gin.H{"error": message, "code": string(code)})
}
