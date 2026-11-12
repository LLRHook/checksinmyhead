package safehttp

import (
	"bytes"
	"context"
	"encoding/json"
	"encoding/json/jsontext"
	jsonv2 "encoding/json/v2"
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
// the same byte cap. Rejection stops transport reads as well as decoder reads.
// No arbitrary decoder/reader error becomes public diagnostic text.
func DecodeJSON(w http.ResponseWriter, r *http.Request, dst any, limit int64, strict bool) error {
	return decodeJSON(w, r, dst, limit, strict, false)
}

// DecodeJSONStream has the same byte cap, single-document rule, cancellation and
// public errors as DecodeJSON, but binds dst while reading instead of buffering
// and validating the whole document first. It is for large bounded bodies whose
// collection DTOs implement UnmarshalJSONFrom with DecodeArrayFrom: a rejected
// count, type or syntax error stops reading at that point, and no pass over the
// document is repeated. Accepted documents decode to the same values.
func DecodeJSONStream(w http.ResponseWriter, r *http.Request, dst any, limit int64, strict bool) error {
	return decodeJSON(w, r, dst, limit, strict, true)
}

// Streaming keeps every encoding/json compatibility option (case-insensitive
// names, duplicate names, invalid UTF-8 replacement, null merging) and turns off
// only legacy error reporting. That option makes the decoder validate and buffer
// each complete value before binding it and continue after a type error; neither
// changes which documents are accepted or the values they produce.
var (
	streamOptions       = jsonv2.JoinOptions(json.DefaultOptionsV1(), json.ReportErrorsWithLegacySemantics(false))
	strictStreamOptions = jsonv2.JoinOptions(streamOptions, jsonv2.RejectUnknownMembers(true))
)

func decodeJSON(w http.ResponseWriter, r *http.Request, dst any, limit int64, strict, stream bool) (err error) {
	defer func() {
		if err != nil {
			StopRejectedBody(w, r)
		}
	}()
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
	if stream {
		options := streamOptions
		if strict {
			options = strictStreamOptions
		}
		d := jsontext.NewDecoder(http.MaxBytesReader(w, r.Body, limit), options)
		if err := jsonv2.UnmarshalDecode(d, dst, options); err != nil {
			return jsonError(err)
		}
		if _, err := d.ReadToken(); err != io.EOF {
			if err != nil {
				return jsonError(err)
			}
			return ErrInvalidJSON
		}
		return nil
	}
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

// net/http may drain an unread HTTP/1 body before flushing a response and again
// during post-handler cleanup. A close header alone does not stop the latter.
// Keep the read deadline expired after rejection; there will be no next request
// on this HTTP/1 connection. HTTP/2 deadlines affect only the rejected stream.
// StopRejectedBody stops incomplete rejected uploads, including transport cleanup.
func StopRejectedBody(w http.ResponseWriter, r *http.Request) {
	if r.Body == nil || r.Body == http.NoBody {
		return
	}
	if r.ProtoMajor == 1 {
		w.Header().Set("Connection", "close")
	}
	_ = http.NewResponseController(w).SetReadDeadline(time.Now())
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
	// The enclosing decoder supplies one complete value to UnmarshalJSON. The
	// non-strict path can decode those bytes without another streaming buffer.
	// Strict DTOs retain DisallowUnknownFields, including nested fields.
	// Reserve only after the count guard; null and empty retain stdlib semantics.
	var result []T
	if count > 0 {
		result = make([]T, 0, count)
	}
	if !strict {
		if err := json.Unmarshal(data, &result); err != nil {
			return nil, ErrInvalidJSON
		}
		return result, nil
	}
	d := json.NewDecoder(bytes.NewReader(data))
	d.DisallowUnknownFields()
	if err := d.Decode(&result); err != nil {
		return nil, ErrInvalidJSON
	}
	return result, nil
}

// DecodeArrayFrom is the streaming form of DecodeArray for UnmarshalJSONFrom.
// It binds one element at a time with the decoder's own options and refuses
// element limit+1 before binding it, so at most limit typed elements are ever
// allocated; under DecodeJSONStream nothing after the excess element is read.
// Null and empty arrays keep the stdlib results (nil and empty); any other
// value kind is invalid.
func DecodeArrayFrom[T any](dec *jsontext.Decoder, limit int) ([]T, error) {
	switch dec.PeekKind() {
	case jsontext.KindNull:
		_, err := dec.ReadToken()
		return nil, err
	case jsontext.KindBeginArray:
	default:
		// Syntax errors surface from the read; a well-formed other kind is a type error.
		if err := dec.SkipValue(); err != nil {
			return nil, err
		}
		return nil, ErrInvalidJSON
	}
	if _, err := dec.ReadToken(); err != nil {
		return nil, err
	}
	result := []T{}
	for dec.PeekKind() != jsontext.KindEndArray {
		if len(result) == limit {
			// A pending read or syntax error is reported as itself, not as a count.
			if dec.PeekKind() == jsontext.KindInvalid {
				if _, err := dec.ReadToken(); err != nil {
					return nil, err
				}
			}
			return nil, ErrInvalidJSON
		}
		if len(result) == cap(result) {
			grown := make([]T, len(result), min(max(2*cap(result), 8), limit))
			copy(grown, result)
			result = grown
		}
		result = result[:len(result)+1]
		if err := jsonv2.UnmarshalDecode(dec, &result[len(result)-1], dec.Options()); err != nil {
			return nil, err
		}
	}
	if _, err := dec.ReadToken(); err != nil {
		return nil, err
	}
	return result, nil
}

// One shared gate for the process, not one semaphore per route or router. It is
// explicitly installed on JSON mutation routes, independent of Content-Type.
var jsonMutations = make(chan struct{}, 8)

func JSONMutation(c *gin.Context) {
	if c.Request.Context().Err() != nil {
		StopRejectedBody(c.Writer, c.Request)
		c.Abort()
		return
	}
	select {
	case jsonMutations <- struct{}{}:
		defer func() { <-jsonMutations }()
		if c.Request.Context().Err() != nil {
			StopRejectedBody(c.Writer, c.Request)
			c.Abort()
			return
		}
		c.Next()
	default:
		StopRejectedBody(c.Writer, c.Request)
		c.Header("Retry-After", "1")
		c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{"error": "service temporarily unavailable"})
	}
}
