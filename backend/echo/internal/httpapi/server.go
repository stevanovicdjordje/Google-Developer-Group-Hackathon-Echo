// Package httpapi wires the HTTP router, middleware and handlers.
// The contract is contracts/echo/openapi.yaml.
package httpapi

import (
	"log/slog"
	"net/http"
	"time"

	"golang.org/x/sync/singleflight"

	"github.com/Ilij4n/eho/backend/echo/internal/assist"
	"github.com/Ilij4n/eho/backend/echo/internal/auth"
	"github.com/Ilij4n/eho/backend/echo/internal/store"
)

// Options configures the HTTP handler.
type Options struct {
	Logger         *slog.Logger
	AllowedOrigins []string
	Store          store.Store
	Verifier       auth.Verifier
	Assistant      assist.Assistant
	// AILimit and QuestionLimit are per-user budgets per minute (defaults 30 and 10).
	AILimit       int
	QuestionLimit int
}

type server struct {
	log      *slog.Logger
	store    store.Store
	verify   auth.Verifier
	ai       assist.Assistant
	aiLimit  *limiter
	askLimit *limiter
	inflight singleflight.Group
}

// NewHandler returns the root HTTP handler with all routes and middleware.
func NewHandler(opts Options) http.Handler {
	if opts.AILimit <= 0 {
		opts.AILimit = 30
	}
	if opts.QuestionLimit <= 0 {
		opts.QuestionLimit = 10
	}
	s := &server{
		log: opts.Logger, store: opts.Store, verify: opts.Verifier, ai: opts.Assistant,
		aiLimit:  newLimiter(opts.AILimit, time.Minute),
		askLimit: newLimiter(opts.QuestionLimit, time.Minute),
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.handleHealthz)

	const sess = "/v1/events/{eventId}/sessions/{sessionId}"
	mux.Handle("POST "+sess+"/ask", s.authed(s.ask))
	mux.Handle("GET "+sess+"/catch-up", s.authed(s.catchUp))
	mux.Handle("GET "+sess+"/summary", s.authed(s.summary))
	mux.Handle("POST "+sess+"/translate", s.authed(s.translate))
	mux.Handle("GET "+sess+"/questions", s.authed(s.listQuestions))
	mux.Handle("POST "+sess+"/questions", s.authed(s.submitQuestion))
	mux.Handle("PUT "+sess+"/questions/{questionId}/vote", s.authed(s.vote(true)))
	mux.Handle("DELETE "+sess+"/questions/{questionId}/vote", s.authed(s.vote(false)))

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
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "model": s.ai.Model()})
}
