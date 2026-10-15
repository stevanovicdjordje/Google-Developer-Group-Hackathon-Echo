// Package httpapi wires the HTTP router, middleware and handlers.
// The contract is contracts/find/openapi.yaml.
package httpapi

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/Ilij4n/eho/backend/find/internal/auth"
	"github.com/Ilij4n/eho/backend/find/internal/match"
	"github.com/Ilij4n/eho/backend/find/internal/store"
)

// Options configures the HTTP handler.
type Options struct {
	Logger         *slog.Logger
	AllowedOrigins []string
	Store          store.Store
	Verifier       auth.Verifier
	Matcher        match.Matcher
	// AIBurst and AIPerMinute are the per-user token bucket shared by
	// recommendations and search (defaults 20 and 20).
	AIBurst     int
	AIPerMinute int
	// Now is the clock (default time.Now).
	Now func() time.Time
}

type server struct {
	log     *slog.Logger
	store   store.Store
	verify  auth.Verifier
	matcher match.Matcher
	aiLimit *limiter
	now     func() time.Time
}

// NewHandler returns the root HTTP handler with all routes and middleware.
func NewHandler(opts Options) http.Handler {
	if opts.AIBurst <= 0 {
		opts.AIBurst = 20
	}
	if opts.AIPerMinute <= 0 {
		opts.AIPerMinute = 20
	}
	if opts.Now == nil {
		opts.Now = time.Now
	}
	if opts.Logger == nil {
		opts.Logger = slog.Default()
	}
	s := &server{
		log: opts.Logger, store: opts.Store, verify: opts.Verifier, matcher: opts.Matcher,
		aiLimit: newLimiter(opts.AIBurst, opts.AIPerMinute, time.Minute),
		// Millisecond precision: Firestore keeps microseconds, so responses
		// before and after a read would differ otherwise.
		now: func() time.Time { return opts.Now().UTC().Truncate(time.Millisecond) },
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.handleHealthz)

	mux.Handle("GET /v1/me/profile", s.authed(s.getMyProfile))
	mux.Handle("PUT /v1/me/profile", s.authed(s.putMyProfile))
	mux.Handle("DELETE /v1/me/profile", s.authed(s.deleteMyProfile))

	const ev = "/v1/events/{eventId}"
	mux.Handle("PUT "+ev+"/people/me", s.authed(s.joinFind))
	mux.Handle("DELETE "+ev+"/people/me", s.authed(s.leaveFind))
	mux.Handle("GET "+ev+"/people/recommendations", s.authed(s.recommendations))
	mux.Handle("POST "+ev+"/people/search", s.authed(s.search))
	mux.Handle("GET "+ev+"/people/{personId}", s.authed(s.getPerson))
	mux.Handle("GET "+ev+"/contacts", s.authed(s.listContacts))
	mux.Handle("POST "+ev+"/contacts", s.authed(s.requestContact))
	mux.Handle("POST "+ev+"/contacts/{personId}/accept", s.authed(s.acceptContact))
	mux.Handle("PUT "+ev+"/contacts/{personId}/meeting-spot", s.authed(s.putMeetingSpot))
	mux.Handle("DELETE "+ev+"/contacts/{personId}/meeting-spot", s.authed(s.deleteMeetingSpot))

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		writeError(w, http.StatusNotFound, "not_found", "route not found", nil)
	})

	var h http.Handler = mux
	h = withLogging(opts.Logger, h)
	h = withRecover(opts.Logger, h)
	h = withCORS(opts.AllowedOrigins, h)
	return h
}

func (s *server) handleHealthz(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "model": s.matcher.Model()})
}
