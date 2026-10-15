// Package httpapi wires the HTTP router, middleware and handlers.
// The contract is contracts/events/openapi.yaml.
package httpapi

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/Ilij4n/eho/backend/events/internal/auth"
	"github.com/Ilij4n/eho/backend/events/internal/extract"
	"github.com/Ilij4n/eho/backend/events/internal/store"
)

// Options configures the HTTP handler.
type Options struct {
	Logger         *slog.Logger
	AllowedOrigins []string
	Store          store.Store
	Verifier       auth.Verifier
	Extractor      *extract.Extractor
	// DraftBurst and DraftsPerMinute limit createDraft per user (defaults 5 and 5).
	DraftBurst      int
	DraftsPerMinute int
	// Now is the clock (default time.Now).
	Now func() time.Time
	// Location decides "today" for isPast (default Europe/Belgrade).
	Location *time.Location
}

type server struct {
	log      *slog.Logger
	store    store.Store
	verify   auth.Verifier
	extract  *extract.Extractor
	limit    *limiter
	now      func() time.Time
	location *time.Location
}

// NewHandler returns the root HTTP handler with all routes and middleware.
func NewHandler(opts Options) http.Handler {
	if opts.DraftBurst <= 0 {
		opts.DraftBurst = 5
	}
	if opts.DraftsPerMinute <= 0 {
		opts.DraftsPerMinute = 5
	}
	if opts.Now == nil {
		opts.Now = time.Now
	}
	if opts.Logger == nil {
		opts.Logger = slog.Default()
	}
	if opts.Location == nil {
		opts.Location = belgrade()
	}
	if opts.Extractor == nil {
		opts.Extractor = &extract.Extractor{}
	}
	s := &server{
		log: opts.Logger, store: opts.Store, verify: opts.Verifier, extract: opts.Extractor,
		limit: newLimiter(opts.DraftBurst, opts.DraftsPerMinute, time.Minute),
		// Millisecond precision: Firestore keeps microseconds.
		now:      func() time.Time { return opts.Now().UTC().Truncate(time.Millisecond) },
		location: opts.Location,
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.handleHealthz)

	const ev = "/v1/events/{eventId}"
	mux.Handle("GET "+ev+"/public", s.authed(s.getPublicEvent))
	mux.Handle("POST "+ev+"/join", s.authed(s.joinEvent))
	mux.Handle("DELETE "+ev+"/join", s.authed(s.leaveEvent))
	mux.Handle("GET "+ev+"/agenda", s.authed(s.getAgenda))
	mux.Handle("GET /v1/me/events", s.authed(s.listMyEvents))

	const dr = "/v1/organizer/drafts"
	mux.Handle("POST "+dr, s.organizer(s.createDraft))
	mux.Handle("GET "+dr+"/{draftId}", s.organizer(s.getDraft))
	mux.Handle("PUT "+dr+"/{draftId}", s.organizer(s.updateDraft))
	mux.Handle("POST "+dr+"/{draftId}/publish", s.organizer(s.publishDraft))

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
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "model": s.extract.ModelName()})
}

func belgrade() *time.Location {
	if loc, err := time.LoadLocation("Europe/Belgrade"); err == nil {
		return loc
	}
	return time.FixedZone("CET", 3600)
}
