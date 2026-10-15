package httpapi

import (
	"errors"
	"net/http"

	"github.com/Ilij4n/eho/backend/maps/internal/auth"
	"github.com/Ilij4n/eho/backend/maps/internal/geo"
	"github.com/Ilij4n/eho/backend/maps/internal/routing"
	"github.com/Ilij4n/eho/backend/maps/internal/venue"
)

type routeEndpointInput struct {
	FeatureID string     `json:"featureId"`
	FloorID   string     `json:"floorId"`
	Point     *geo.Point `json:"point"`
}

type routeInput struct {
	From       routeEndpointInput `json:"from"`
	To         routeEndpointInput `json:"to"`
	Accessible bool               `json:"accessible"`
}

type routeResponse struct {
	PublishedVersion int `json:"publishedVersion"`
	*routing.Route
}

func (in routeEndpointInput) endpoint(field string, c *venue.ValidationError) routing.Endpoint {
	switch {
	case in.FeatureID != "" && in.FloorID == "" && in.Point == nil:
		return routing.Endpoint{FeatureID: in.FeatureID}
	case in.FeatureID == "" && in.FloorID != "" && in.Point != nil:
		return routing.Endpoint{FloorID: in.FloorID, Point: *in.Point}
	}
	*c = append(*c, venue.FieldError{Field: field, Message: "give either featureId, or floorId and point"})
	return routing.Endpoint{}
}

// getRoute computes a walking route on the published map. Positions in the
// request are used for this computation only; they are never stored or logged.
func (s *server) getRoute(w http.ResponseWriter, r *http.Request, _ auth.Principal) {
	e, err := s.store.GetEvent(r.Context(), r.PathValue("eventId"))
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	if !e.Published() {
		writeError(w, http.StatusNotFound, "not_found", "resource not found", nil)
		return
	}
	var in routeInput
	if !decode(w, r, &in) {
		return
	}
	var verr venue.ValidationError
	from, to := in.From.endpoint("from", &verr), in.To.endpoint("to", &verr)
	if len(verr) > 0 {
		s.respondErr(w, r, verr)
		return
	}

	g, version, err := s.publishedGraph(r, e)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}

	route, err := g.Route(from, to, routing.Options{Accessible: in.Accessible})
	switch {
	case errors.Is(err, routing.ErrUnknownFeature):
		s.respondErr(w, r, venue.ValidationError{{Field: "featureId", Message: "no such feature on the published map"}})
	case errors.Is(err, routing.ErrUnknownFloor):
		s.respondErr(w, r, venue.ValidationError{{Field: "floorId", Message: "no such floor on the published map"}})
	case errors.Is(err, routing.ErrNoWalkway), errors.Is(err, routing.ErrNoRoute):
		writeError(w, http.StatusUnprocessableEntity, "no_route", err.Error(), nil)
	case err != nil:
		s.respondErr(w, r, err)
	default:
		writeJSON(w, http.StatusOK, routeResponse{PublishedVersion: version, Route: route})
	}
}
