// Package httpapi wires the HTTP router, middleware and handlers.
// The contract is contracts/openapi.yaml.
package httpapi

import (
	"log/slog"
	"net/http"

	"github.com/Ilij4n/eho/backend/maps/internal/auth"
	"github.com/Ilij4n/eho/backend/maps/internal/planimage"
	"github.com/Ilij4n/eho/backend/maps/internal/store"
)

// Options configures the HTTP handler.
type Options struct {
	Logger         *slog.Logger
	AllowedOrigins []string
	Store          store.Store
	Verifier       auth.Verifier
	Images         planimage.Inspector
}

type server struct {
	log    *slog.Logger
	store  store.Store
	verify auth.Verifier
	images planimage.Inspector
}

// NewHandler returns the root HTTP handler with all routes and middleware.
func NewHandler(opts Options) http.Handler {
	s := &server{log: opts.Logger, store: opts.Store, verify: opts.Verifier, images: opts.Images}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", handleHealthz)

	if s.store != nil && s.verify != nil {
		// Organizer: events.
		mux.Handle("GET /v1/events", s.authed(s.listEvents))
		mux.Handle("POST /v1/events", s.authed(s.createEvent))
		mux.Handle("GET /v1/events/{eventId}", s.authed(s.getEvent))
		mux.Handle("PATCH /v1/events/{eventId}", s.authed(s.updateEvent))
		mux.Handle("DELETE /v1/events/{eventId}", s.authed(s.deleteEvent))
		mux.Handle("GET /v1/events/{eventId}/draft", s.authed(s.getDraft))
		mux.Handle("POST /v1/events/{eventId}/publish", s.authed(s.publish))
		// Organizer: floors.
		mux.Handle("POST /v1/events/{eventId}/floors", s.authed(s.createFloor))
		mux.Handle("PATCH /v1/events/{eventId}/floors/{floorId}", s.authed(s.updateFloor))
		mux.Handle("DELETE /v1/events/{eventId}/floors/{floorId}", s.authed(s.deleteFloor))
		mux.Handle("PUT /v1/events/{eventId}/floors/{floorId}/georef", s.authed(s.putGeoref))
		mux.Handle("DELETE /v1/events/{eventId}/floors/{floorId}/georef", s.authed(s.deleteGeoref))
		mux.Handle("PUT /v1/events/{eventId}/floors/{floorId}/graph", s.authed(s.putGraph))
		// Organizer: features.
		mux.Handle("POST /v1/events/{eventId}/features", s.authed(s.createFeature))
		mux.Handle("PATCH /v1/events/{eventId}/features/{featureId}", s.authed(s.updateFeature))
		mux.Handle("DELETE /v1/events/{eventId}/features/{featureId}", s.authed(s.deleteFeature))
	}

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
