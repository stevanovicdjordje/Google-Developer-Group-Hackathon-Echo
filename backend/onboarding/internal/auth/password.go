// Package auth implements registration, login and cookie sessions.
package auth

import "golang.org/x/crypto/bcrypt"

// bcrypt silently ignores bytes past 72, so longer passwords are rejected.
const (
	MinPasswordLen = 8
	MaxPasswordLen = 72
)

func HashPassword(pw string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(pw), bcrypt.DefaultCost)
	return string(b), err
}

func CheckPassword(hash, pw string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(pw)) == nil
}

// dummyHash is compared against when the email is unknown, so response time
// does not reveal whether an account exists.
var dummyHash, _ = HashPassword("not-a-real-password")
