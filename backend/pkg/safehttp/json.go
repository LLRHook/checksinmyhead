package safehttp

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"github.com/gin-gonic/gin"
	"io"
	"net/http"
	"time"
)

var (
	ErrJSONTooLarge = errors.New("JSON body too large")
	ErrInvalidJSON  = errors.New("invalid JSON document")
)

const MutationBodyLimit int64 = 4 << 20

// DecodeJSON admits exactly one document, including all trailing whitespace within
// the same byte cap. Syntax errors are returned immediately, without a drain.
// No arbitrary decoder/reader error becomes public diagnostic text.
func DecodeJSON(w http.ResponseWriter, r *http.Request, dst any, limit int64, strict bool) error {
	if r.ContentLength > limit {
		return ErrJSONTooLarge
	}
	if r.Context().Err() != nil {
		return ErrInvalidJSON
	}
	callbackDone := make(chan struct{})
	stop := context.AfterFunc(r.Context(), func() {
		defer close(callbackDone)
		_ = http.NewResponseController(w).SetReadDeadline(time.Now())
	})
	defer func() {
		if !stop() {
			<-callbackDone
		}
	}()
	d := json.NewDecoder(http.MaxBytesReader(w, r.Body, limit))
	if strict {
		d.DisallowUnknownFields()
	}
	if err := d.Decode(dst); err != nil {
		return jsonError(err)
	}
	// Token, rather than decoding an arbitrary second graph, avoids allocating it.
	if _, err := d.Token(); err != io.EOF {
		if err != nil {
			return jsonError(err)
		}
		return ErrInvalidJSON
	}
	return nil
}
func jsonError(err error) error {
	var size *http.MaxBytesError
	if errors.As(err, &size) {
		return ErrJSONTooLarge
	}
	return ErrInvalidJSON
}

// DecodeArray checks the number of top-level elements before allocating the
// typed slice. Called by content DTOs' UnmarshalJSON, after JSON syntax validation.
// Strings/escapes and nested containers cannot manufacture element separators.
func DecodeStrictArray[T any](data []byte, limit int) ([]T, error) {
	return decodeArray[T](data, limit, true)
}
func DecodeArray[T any](data []byte, limit int) ([]T, error) {
	return decodeArray[T](data, limit, false)
}
func decodeArray[T any](data []byte, limit int, strict bool) ([]T, error) {
	depth, count := 0, 0
	inString, escaped, hasValue := false, false, false
	for _, b := range data {
		if inString {
			if escaped {
				escaped = false
			} else if b == '\\' {
				escaped = true
			} else if b == '"' {
				inString = false
			}
			continue
		}
		if depth == 1 && b != ']' && b != ',' && b != ' ' && b != '\n' && b != '\t' && b != '\r' && !hasValue {
			count++
			hasValue = true
			if count > limit {
				return nil, ErrInvalidJSON
			}
		}
		switch b {
		case '"':
			inString = true
		case '[', '{':
			depth++
		case ']', '}':
			depth--
		case ',':
			if depth == 1 {
				hasValue = false
			}
		}
	}
	var result []T
	d := json.NewDecoder(bytes.NewReader(data))
	if strict {
		d.DisallowUnknownFields()
	}
	if err := d.Decode(&result); err != nil {
		return nil, ErrInvalidJSON
	}
	return result, nil
}

// One shared gate for the process, not one semaphore per route or router. It is
// explicitly installed on JSON mutation routes, independent of Content-Type.
var jsonMutations = make(chan struct{}, 8)

func JSONMutation(c *gin.Context) {
	if c.Request.Context().Err() != nil {
		c.Abort()
		return
	}
	select {
	case jsonMutations <- struct{}{}:
		defer func() { <-jsonMutations }()
		if c.Request.Context().Err() != nil {
			c.Abort()
			return
		}
		c.Next()
	default:
		c.Header("Retry-After", "1")
		c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{"error": "service temporarily unavailable"})
	}
}
