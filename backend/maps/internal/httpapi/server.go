// Package httpapi wires the HTTP router, middleware and handlers.
package httpapi

import (
	"log/slog"
	"net/http"
)

// Options configures the HTTP handler.
type Options struct {
	Logger         *slog.Logger
	AllowedOrigins []string
}

// NewHandler returns the root HTTP handler with all routes and middleware.
func NewHandler(opts Options) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", handleHealthz)
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		writeError(w, http.StatusNotFound, "not_found", "route not found", nil)
	})

	var h http.Handler = mux
	h = withLogging(opts.Logger, h)
	h = withRecover(opts.Logger, h)
	h = withCORS(opts.AllowedOrigins, h)
	return h
}

func handleHealthz(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
