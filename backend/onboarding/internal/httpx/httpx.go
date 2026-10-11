// Package httpx holds shared HTTP plumbing: request principal, CSRF, role
// guards, security headers and template rendering.
package httpx

import (
	"context"
	"crypto/subtle"
	"log"
	"net/http"
	"net/url"
	"strings"

	"github.com/Ilij4n/eho/backend/onboarding/internal/id"
)

// Principal is the authenticated caller. Role is a plain string so httpx does
// not depend on the users package.
type Principal struct {
	UserID    string
	Name      string
	Email     string
	Role      string
	Onboarded bool // participants: onboarding finished
}

type ctxKey int

const (
	principalKey ctxKey = iota
	csrfKey
)

func WithPrincipal(ctx context.Context, p *Principal) context.Context {
	return context.WithValue(ctx, principalKey, p)
}

// PrincipalFrom returns the authenticated principal or nil.
func PrincipalFrom(ctx context.Context) *Principal {
	p, _ := ctx.Value(principalKey).(*Principal)
	return p
}

func CSRFToken(ctx context.Context) string {
	s, _ := ctx.Value(csrfKey).(string)
	return s
}

const (
	csrfCookie = "eho_csrf"
	csrfField  = "csrf_token"
	// MaxBodyBytes caps request bodies (plan uploads need a few MB).
	MaxBodyBytes = 12 << 20
)

// CSRF implements a double-submit-cookie check for every unsafe request.
// Browsers that send Sec-Fetch-Site: cross-site are rejected as well.
func CSRF(secure bool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			token := ""
			if c, err := r.Cookie(csrfCookie); err == nil && len(c.Value) == 64 {
				token = c.Value
			} else {
				token = id.Token(32)
				http.SetCookie(w, &http.Cookie{
					Name: csrfCookie, Value: token, Path: "/",
					HttpOnly: true, Secure: secure, SameSite: http.SameSiteLaxMode,
				})
			}
			switch r.Method {
			case http.MethodGet, http.MethodHead, http.MethodOptions:
			default:
				if r.Header.Get("Sec-Fetch-Site") == "cross-site" {
					http.Error(w, "forbidden", http.StatusForbidden)
					return
				}
				r.Body = http.MaxBytesReader(w, r.Body, MaxBodyBytes)
				got := r.PostFormValue(csrfField)
				if subtle.ConstantTimeCompare([]byte(got), []byte(token)) != 1 {
					http.Error(w, "forbidden", http.StatusForbidden)
					return
				}
			}
			next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), csrfKey, token)))
		})
	}
}

// RequireRole allows only an authenticated principal with the given role.
// Anonymous callers are sent to the login page, others get 403.
func RequireRole(role string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			p := PrincipalFrom(r.Context())
			if p == nil {
				http.Redirect(w, r, "/login?next="+url.QueryEscape(r.URL.RequestURI()), http.StatusSeeOther)
				return
			}
			if p.Role != role {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// RequireOnboarded sends participants who have not finished onboarding back to it.
func RequireOnboarded(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if p := PrincipalFrom(r.Context()); p != nil && !p.Onboarded {
			http.Redirect(w, r, "/onboarding", http.StatusSeeOther)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func SecurityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("X-Frame-Options", "DENY")
		h.Set("Referrer-Policy", "same-origin")
		// No scripts at all. The Maps embed is an iframe from google.com.
		h.Set("Content-Security-Policy",
			"default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'none'; "+
				"frame-src https://www.google.com; frame-ancestors 'none'; form-action 'self'; base-uri 'self'")
		next.ServeHTTP(w, r)
	})
}

func Recover(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if v := recover(); v != nil {
				log.Printf("panic: %v", v)
				http.Error(w, "internal error", http.StatusInternalServerError)
			}
		}()
		next.ServeHTTP(w, r)
	})
}

// SafeNext returns next if it is a local path, otherwise fallback. It blocks
// open redirects such as "//evil.com" or "/\evil.com".
func SafeNext(next, fallback string) string {
	if strings.HasPrefix(next, "/") && !strings.HasPrefix(next, "//") && !strings.Contains(next, "\\") {
		return next
	}
	return fallback
}
