package httpapi

import (
	"net/http"
	"strings"

	"github.com/Ilij4n/eho/backend/find/internal/auth"
)

// authed requires a valid Firebase ID token (`Authorization: Bearer <token>`).
// Anonymous attendees pass.
func (s *server) authed(h func(http.ResponseWriter, *http.Request, auth.Principal)) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok || strings.TrimSpace(token) == "" {
			writeError(w, http.StatusUnauthorized, "unauthenticated", "missing bearer token", nil)
			return
		}
		p, err := s.verify.Verify(r.Context(), strings.TrimSpace(token))
		if err != nil {
			// The verification error is not echoed: it may describe the token.
			writeError(w, http.StatusUnauthorized, "unauthenticated", "invalid or expired ID token", nil)
			return
		}
		h(w, r.WithContext(auth.WithPrincipal(r.Context(), p)), p)
	})
}
