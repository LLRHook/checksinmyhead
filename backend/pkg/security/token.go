package security

import (
	"crypto/rand"
)

func GenerateSecureToken() string {
	return rand.Text()
}
