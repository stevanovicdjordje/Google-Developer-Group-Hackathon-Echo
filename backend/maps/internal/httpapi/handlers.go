package httpapi

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/maps/internal/auth"
	"github.com/Ilij4n/eho/backend/maps/internal/geo"
	"github.com/Ilij4n/eho/backend/maps/internal/planimage"
	"github.com/Ilij4n/eho/backend/maps/internal/store"
	"github.com/Ilij4n/eho/backend/maps/internal/venue"
)

const maxBodyBytes = 2 << 20 // graphs with thousands of nodes fit comfortably

// decode reads a JSON body strictly (unknown fields rejected) into dst.
// It writes the error response and returns false on failure.
func decode(w http.ResponseWriter, r *http.Request, dst any) bool {
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxBodyBytes))
	if err != nil {
		writeError(w, http.StatusRequestEntityTooLarge, "body_too_large", fmt.Sprintf("request body exceeds %d bytes", maxBodyBytes), nil)
		return false
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_json", "request body is not valid JSON for this operation", err.Error())
		return false
	}
	return true
}

// respondErr maps domain and store errors to HTTP responses.
func (s *server) respondErr(w http.ResponseWriter, r *http.Request, err error) {
	var ve venue.ValidationError
	switch {
	case errors.As(err, &ve):
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "input is invalid", []venue.FieldError(ve))
	case errors.Is(err, store.ErrNotFound):
		writeError(w, http.StatusNotFound, "not_found", "resource not found", nil)
	case errors.Is(err, store.ErrConflict):
		writeError(w, http.StatusConflict, "conflict", "resource already exists", nil)
	default:
		s.log.ErrorContext(r.Context(), "request failed", "route", r.Pattern, "err", err)
		writeError(w, http.StatusInternalServerError, "internal", "internal server error", nil)
	}
}

// ownedEvent loads the event and checks that p owns it.
func (s *server) ownedEvent(w http.ResponseWriter, r *http.Request, p auth.Principal) (*venue.Event, bool) {
	e, err := s.store.GetEvent(r.Context(), r.PathValue("eventId"))
	if err != nil {
		s.respondErr(w, r, err)
		return nil, false
	}
	if e.OwnerUID != p.UID {
		writeError(w, http.StatusForbidden, "forbidden", "only the event owner can do this", nil)
		return nil, false
	}
	return e, true
}

// ---- events ----

var eventIDPattern = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{2,39}$`)

type eventInput struct {
	ID        string `json:"id"` // optional; stable IDs for demo seeds
	Name      string `json:"name"`
	StartDate string `json:"startDate"`
	EndDate   string `json:"endDate"`
	Address   string `json:"address"`
}

func (s *server) createEvent(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	if p.Anonymous {
		writeError(w, http.StatusForbidden, "organizer_account_required", "sign in with an organizer account to create events", nil)
		return
	}
	var in eventInput
	if !decode(w, r, &in) {
		return
	}
	id := store.NewID()
	if in.ID != "" {
		if !eventIDPattern.MatchString(in.ID) {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "input is invalid",
				[]venue.FieldError{{Field: "id", Message: "must be 3-40 lowercase letters, digits or dashes"}})
			return
		}
		id = in.ID
	}
	now := time.Now().UTC()
	e := &venue.Event{
		ID: id, Name: strings.TrimSpace(in.Name), StartDate: in.StartDate, EndDate: in.EndDate,
		Address: strings.TrimSpace(in.Address), OwnerUID: p.UID, CreatedAt: now, UpdatedAt: now,
	}
	if err := venue.ValidateEvent(e); err != nil {
		s.respondErr(w, r, err)
		return
	}
	if err := s.store.CreateEvent(r.Context(), e); err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, e)
}

func (s *server) listEvents(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	events, err := s.store.ListEventsByOwner(r.Context(), p.UID)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"events": events})
}

// getEvent: the owner sees everything; anyone signed in sees a published event.
func (s *server) getEvent(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, err := s.store.GetEvent(r.Context(), r.PathValue("eventId"))
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	if e.OwnerUID != p.UID {
		if !e.Published() {
			writeError(w, http.StatusNotFound, "not_found", "resource not found", nil)
			return
		}
		e.OwnerUID = ""
	}
	writeJSON(w, http.StatusOK, e)
}

func (s *server) updateEvent(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, ok := s.ownedEvent(w, r, p)
	if !ok {
		return
	}
	in := eventInput{Name: e.Name, StartDate: e.StartDate, EndDate: e.EndDate, Address: e.Address}
	if !decode(w, r, &in) {
		return
	}
	e.Name, e.StartDate, e.EndDate, e.Address = strings.TrimSpace(in.Name), in.StartDate, in.EndDate, strings.TrimSpace(in.Address)
	e.UpdatedAt = time.Now().UTC()
	if err := venue.ValidateEvent(e); err != nil {
		s.respondErr(w, r, err)
		return
	}
	if err := s.store.UpdateEvent(r.Context(), e); err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, e)
}

func (s *server) deleteEvent(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, ok := s.ownedEvent(w, r, p)
	if !ok {
		return
	}
	if err := s.store.DeleteEvent(r.Context(), e.ID); err != nil {
		s.respondErr(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *server) getDraft(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, ok := s.ownedEvent(w, r, p)
	if !ok {
		return
	}
	m, err := s.store.GetDraft(r.Context(), e.ID)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, m.Normalize())
}

// publishBlocked is returned from the publish check to abort the transaction.
type publishBlocked struct{ errs, warnings []venue.Issue }

func (publishBlocked) Error() string { return "publish blocked by validation errors" }

func (s *server) publish(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, ok := s.ownedEvent(w, r, p)
	if !ok {
		return
	}
	var warnings []venue.Issue
	version, err := s.store.Publish(r.Context(), e.ID, func(m *venue.Map) error {
		errs, warns := venue.CheckPublish(m)
		if len(errs) > 0 {
			return publishBlocked{errs, warns}
		}
		warnings = warns
		return nil
	})
	var pb publishBlocked
	if errors.As(err, &pb) {
		writeError(w, http.StatusUnprocessableEntity, "publish_blocked", "fix the errors before publishing",
			map[string]any{"errors": pb.errs, "warnings": nonNil(pb.warnings)})
		return
	}
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"publishedVersion": version, "warnings": nonNil(warnings)})
}

func nonNil[T any](s []T) []T {
	if s == nil {
		return []T{}
	}
	return s
}

// ---- floors ----

type floorInput struct {
	Name      string `json:"name"`
	Order     int    `json:"order"`
	ImagePath string `json:"imagePath"`
}

// checkImage validates the storage path belongs to the event and reads the
// image dimensions.
func (s *server) checkImage(w http.ResponseWriter, r *http.Request, eventID string, f *venue.Floor) bool {
	prefix := "events/" + eventID + "/floors/"
	if rest, ok := strings.CutPrefix(f.ImagePath, prefix); !ok || rest == "" || strings.Contains(rest, "/") {
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "input is invalid",
			[]venue.FieldError{{Field: "imagePath", Message: "must be " + prefix + "<fileName>"}})
		return false
	}
	width, height, err := s.images.Dimensions(r.Context(), f.ImagePath)
	switch {
	case errors.Is(err, planimage.ErrNotFound):
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "input is invalid",
			[]venue.FieldError{{Field: "imagePath", Message: "no uploaded image at this path"}})
		return false
	case errors.Is(err, planimage.ErrUnsupported):
		writeError(w, http.StatusUnprocessableEntity, "validation_failed", "input is invalid",
			[]venue.FieldError{{Field: "imagePath", Message: err.Error()}})
		return false
	case err != nil:
		s.respondErr(w, r, err)
		return false
	}
	f.Width, f.Height = width, height
	return true
}

func (s *server) createFloor(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, ok := s.ownedEvent(w, r, p)
	if !ok {
		return
	}
	var in floorInput
	if !decode(w, r, &in) {
		return
	}
	f := &venue.Floor{ID: store.NewID(), Name: strings.TrimSpace(in.Name), Order: in.Order, ImagePath: in.ImagePath}
	if !s.checkImage(w, r, e.ID, f) {
		return
	}
	if err := venue.ValidateFloor(f); err != nil {
		s.respondErr(w, r, err)
		return
	}
	if err := s.store.PutFloor(r.Context(), e.ID, f); err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, f)
}

// draftFloor loads the draft map and finds the floor from the path.
func (s *server) draftFloor(w http.ResponseWriter, r *http.Request, eventID string) (*venue.Map, *venue.Floor, bool) {
	m, err := s.store.GetDraft(r.Context(), eventID)
	if err != nil {
		s.respondErr(w, r, err)
		return nil, nil, false
	}
	f := m.Floor(r.PathValue("floorId"))
	if f == nil {
		writeError(w, http.StatusNotFound, "not_found", "floor not found", nil)
		return nil, nil, false
	}
	return m, f, true
}

func (s *server) updateFloor(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, ok := s.ownedEvent(w, r, p)
	if !ok {
		return
	}
	_, f, ok := s.draftFloor(w, r, e.ID)
	if !ok {
		return
	}
	in := floorInput{Name: f.Name, Order: f.Order, ImagePath: f.ImagePath}
	if !decode(w, r, &in) {
		return
	}
	imageChanged := in.ImagePath != f.ImagePath
	f.Name, f.Order, f.ImagePath = strings.TrimSpace(in.Name), in.Order, in.ImagePath
	if imageChanged {
		if !s.checkImage(w, r, e.ID, f) {
			return
		}
		f.Georef = nil // control points refer to the old image
	}
	if err := venue.ValidateFloor(f); err != nil {
		s.respondErr(w, r, err)
		return
	}
	if err := s.store.PutFloor(r.Context(), e.ID, f); err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, f)
}

func (s *server) deleteFloor(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, ok := s.ownedEvent(w, r, p)
	if !ok {
		return
	}
	if err := s.store.DeleteFloor(r.Context(), e.ID, r.PathValue("floorId")); err != nil {
		s.respondErr(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type georefInput struct {
	ControlPoints []geo.ControlPoint `json:"controlPoints"`
}

func (s *server) putGeoref(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, ok := s.ownedEvent(w, r, p)
	if !ok {
		return
	}
	_, f, ok := s.draftFloor(w, r, e.ID)
	if !ok {
		return
	}
	var in georefInput
	if !decode(w, r, &in) {
		return
	}
	g, err := venue.ValidateGeoref(in.ControlPoints, f)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	f.Georef = &venue.Georeference{ControlPoints: in.ControlPoints, MetersPerPixel: g.MetersPerPixel()}
	if err := s.store.PutFloor(r.Context(), e.ID, f); err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"floor": f, "quality": g.Quality(f.Width, f.Height)})
}

func (s *server) deleteGeoref(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, ok := s.ownedEvent(w, r, p)
	if !ok {
		return
	}
	_, f, ok := s.draftFloor(w, r, e.ID)
	if !ok {
		return
	}
	f.Georef = nil
	if err := s.store.PutFloor(r.Context(), e.ID, f); err != nil {
		s.respondErr(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type graphInput struct {
	Nodes []venue.Node `json:"nodes"`
	Edges []venue.Edge `json:"edges"`
}

func (s *server) putGraph(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, ok := s.ownedEvent(w, r, p)
	if !ok {
		return
	}
	_, f, ok := s.draftFloor(w, r, e.ID)
	if !ok {
		return
	}
	var in graphInput
	if !decode(w, r, &in) {
		return
	}
	g := &venue.Graph{FloorID: f.ID, Nodes: nonNil(in.Nodes), Edges: nonNil(in.Edges)}
	if err := venue.ValidateGraph(g, f); err != nil {
		s.respondErr(w, r, err)
		return
	}
	if err := s.store.PutGraph(r.Context(), e.ID, g); err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, g)
}

// ---- features ----

// featureInput mirrors venue.Feature without the server-assigned id.
type featureInput struct {
	Type           venue.FeatureType `json:"type"`
	FloorID        string            `json:"floorId"`
	Name           string            `json:"name"`
	Description    string            `json:"description"`
	Geometry       venue.Geometry    `json:"geometry"`
	EntranceNodeID string            `json:"entranceNodeId"`
	Capacity       int               `json:"capacity"`
	Company        string            `json:"company"`
	Category       string            `json:"category"`
	Link           string            `json:"link"`
	SponsorTier    string            `json:"sponsorTier"`
	PoiKind        string            `json:"poiKind"`
}

func (in featureInput) apply(f *venue.Feature) {
	f.Type, f.FloorID, f.Name, f.Description = in.Type, in.FloorID, strings.TrimSpace(in.Name), strings.TrimSpace(in.Description)
	f.Geometry, f.EntranceNodeID, f.Capacity = in.Geometry, in.EntranceNodeID, in.Capacity
	f.Company, f.Category, f.Link = strings.TrimSpace(in.Company), strings.TrimSpace(in.Category), strings.TrimSpace(in.Link)
	f.SponsorTier, f.PoiKind = in.SponsorTier, in.PoiKind
}

func inputOf(f *venue.Feature) featureInput {
	return featureInput{
		Type: f.Type, FloorID: f.FloorID, Name: f.Name, Description: f.Description, Geometry: f.Geometry,
		EntranceNodeID: f.EntranceNodeID, Capacity: f.Capacity, Company: f.Company, Category: f.Category,
		Link: f.Link, SponsorTier: f.SponsorTier, PoiKind: f.PoiKind,
	}
}

func (s *server) saveFeature(w http.ResponseWriter, r *http.Request, eventID string, m *venue.Map, f *venue.Feature, status int) {
	if err := venue.ValidateFeature(f, m.Floor(f.FloorID)); err != nil {
		s.respondErr(w, r, err)
		return
	}
	if f.EntranceNodeID != "" {
		if g := m.Graph(f.FloorID); g == nil || !hasNode(g, f.EntranceNodeID) {
			writeError(w, http.StatusUnprocessableEntity, "validation_failed", "input is invalid",
				[]venue.FieldError{{Field: "entranceNodeId", Message: "no such node in the floor's graph"}})
			return
		}
	}
	if err := s.store.PutFeature(r.Context(), eventID, f); err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, status, f)
}

func hasNode(g *venue.Graph, id string) bool {
	for _, n := range g.Nodes {
		if n.ID == id {
			return true
		}
	}
	return false
}

func (s *server) createFeature(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, ok := s.ownedEvent(w, r, p)
	if !ok {
		return
	}
	var in featureInput
	if !decode(w, r, &in) {
		return
	}
	m, err := s.store.GetDraft(r.Context(), e.ID)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	f := &venue.Feature{ID: store.NewID()}
	in.apply(f)
	s.saveFeature(w, r, e.ID, m, f, http.StatusCreated)
}

// updateFeature merges the provided fields into the stored feature.
func (s *server) updateFeature(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, ok := s.ownedEvent(w, r, p)
	if !ok {
		return
	}
	m, err := s.store.GetDraft(r.Context(), e.ID)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	var f *venue.Feature
	for i := range m.Features {
		if m.Features[i].ID == r.PathValue("featureId") {
			f = &m.Features[i]
		}
	}
	if f == nil {
		writeError(w, http.StatusNotFound, "not_found", "feature not found", nil)
		return
	}
	in := inputOf(f)
	if !decode(w, r, &in) {
		return
	}
	in.apply(f)
	s.saveFeature(w, r, e.ID, m, f, http.StatusOK)
}

func (s *server) deleteFeature(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, ok := s.ownedEvent(w, r, p)
	if !ok {
		return
	}
	if err := s.store.DeleteFeature(r.Context(), e.ID, r.PathValue("featureId")); err != nil {
		s.respondErr(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
