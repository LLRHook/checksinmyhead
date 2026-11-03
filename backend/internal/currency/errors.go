package currency

import (
	"errors"
	"github.com/gin-gonic/gin"
)

// UnavailableError carries a validated Retry-After without exposing upstream
// bodies, URLs or transport messages in responses or process logs.
type UnavailableError struct {
	RetryAfter string
	Cause      error
}

func (e *UnavailableError) Error() string { return "exchange rate provider unavailable" }
func (e *UnavailableError) Unwrap() error { return e.Cause }
func WriteRetryAfter(c *gin.Context, err error) {
	var failure *UnavailableError
	if errors.As(err, &failure) && failure.RetryAfter != "" {
		c.Header("Retry-After", failure.RetryAfter)
	}
}
