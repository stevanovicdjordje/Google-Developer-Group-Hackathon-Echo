package events

import (
	"errors"
	"log"
	"net/http"
	"net/url"
	"strconv"

	"github.com/Ilij4n/eho/backend/onboarding/internal/httpx"
	"github.com/Ilij4n/eho/backend/onboarding/internal/users"
)

// Access resolves the event in the URL ({id}) and checks that the signed-in
// organizer owns it (ownerUid, as in the other services). Other organizers
// get 404, so event IDs don't leak.
type Access struct {
	Events Repository
	View   *httpx.Renderer
}

func (a Access) OwnedEvent(w http.ResponseWriter, r *http.Request) (Event, bool) {
	p := httpx.PrincipalFrom(r.Context())
	if p == nil || p.Role != string(users.RoleOrganizer) {
		a.View.Error(w, r, http.StatusForbidden, "error.title")
		return Event{}, false
	}
	ev, err := a.Events.Get(r.Context(), r.PathValue("id"))
	if errors.Is(err, ErrNotFound) || (err == nil && ev.OwnerUID != p.UserID) {
		a.View.Error(w, r, http.StatusNotFound, "error.title")
		return Event{}, false
	}
	if err != nil {
		a.Fail(w, r, err)
		return Event{}, false
	}
	return ev, true
}

func (a Access) Fail(w http.ResponseWriter, r *http.Request, err error) {
	log.Printf("%s %s: %v", r.Method, r.URL.Path, err)
	a.View.Error(w, r, http.StatusInternalServerError, "error.title")
}

// IsOrganizerOf reports whether p owns ev.
func IsOrganizerOf(p *httpx.Principal, ev Event) bool {
	return p != nil && p.Role == string(users.RoleOrganizer) && ev.OwnerUID == p.UserID
}

// MapEmbedURL returns a Google Maps Embed API URL, or "" when there is no
// API key or no coordinates (then the page shows only the address).
func MapEmbedURL(apiKey string, e Event) string {
	if apiKey == "" || e.Lat == nil || e.Lng == nil {
		return ""
	}
	q := strconv.FormatFloat(*e.Lat, 'f', 6, 64) + "," + strconv.FormatFloat(*e.Lng, 'f', 6, 64)
	return "https://www.google.com/maps/embed/v1/place?key=" + url.QueryEscape(apiKey) + "&q=" + url.QueryEscape(q)
}
