package auth

import (
	"net/mail"
	"net/url"
	"strings"
	"unicode/utf8"
)

// FieldErrors maps a form field to an i18n error key. It is also an error, so
// services can return it directly.
type FieldErrors map[string]string

func (f FieldErrors) Error() string { return "validation failed" }

func (f FieldErrors) Add(field, key string) {
	if _, ok := f[field]; !ok {
		f[field] = key
	}
}

func (f FieldErrors) Empty() bool { return len(f) == 0 }

const (
	MinPasswordLen = 8
	MaxPasswordLen = 128
)

func NormalizeEmail(s string) string { return strings.ToLower(strings.TrimSpace(s)) }

func ValidEmail(s string) bool {
	if s == "" || len(s) > 254 {
		return false
	}
	a, err := mail.ParseAddress(s)
	return err == nil && a.Address == s && strings.Contains(s[strings.LastIndex(s, "@"):], ".")
}

func checkName(f FieldErrors, field, value string, min, max int, key string) {
	n := utf8.RuneCountInString(value)
	if n < min || n > max {
		f.Add(field, key)
	}
}

func checkPassword(f FieldErrors, pw, confirm string) {
	switch {
	case len(pw) < MinPasswordLen:
		f.Add("password", "err.password_short")
	case len(pw) > MaxPasswordLen:
		f.Add("password", "err.password_long")
	case pw != confirm:
		f.Add("password_confirm", "err.password_mismatch")
	}
}

// normalizeWebsite returns "" for empty input and prefixes https:// when no
// scheme was given. ok is false for anything that is not an http(s) URL.
func normalizeWebsite(s string) (string, bool) {
	s = strings.TrimSpace(s)
	if s == "" {
		return "", true
	}
	if !strings.Contains(s, "://") {
		s = "https://" + s
	}
	u, err := url.Parse(s)
	if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" || !strings.Contains(u.Host, ".") {
		return "", false
	}
	return s, true
}
