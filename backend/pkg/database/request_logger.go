package database

import "log"

// LogRequestError records finite error metadata without exposing driver text.
// Callers retain the original typed error for status and business decisions.
func LogRequestError(err error) {
	class, state := errorMetadata(err)
	log.Printf("request error class=%s sqlstate=%s", class, state)
}
