// Package id generates random opaque identifiers and tokens.
package id

import (
	"crypto/rand"
	"encoding/hex"
)

// New returns a random 128-bit identifier as 32 hex characters.
func New() string { return Token(16) }

// Token returns n random bytes hex-encoded (2n characters).
func Token(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		panic("id: crypto/rand failed: " + err.Error())
	}
	return hex.EncodeToString(b)
}
