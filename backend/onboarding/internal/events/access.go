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

// Access resolves the event in the URL ({id}) and checks that it belongs to
// the signed-in organizer. Other organizers get 404, so event IDs don't leak.
type Access struct {
	Events Repository
	Users  users.Repository
	View   *httpx.Renderer
}

func (a Access) OwnedEvent(w http.ResponseWriter, r *http.Request) (Event, bool) {
	p := httpx.PrincipalFrom(r.Context())
	if p == nil || p.Role != string(users.RoleOrganizer) {
		a.View.Error(w, r, http.StatusForbidden, "error.title")
		return Event{}, false
	}
	ev, err := a.Events.Get(r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		a.View.Error(w, r, http.StatusNotFound, "error.title")
		return Event{}, false
	}
	if err != nil {
		a.Fail(w, r, err)
		return Event{}, false
	}
	org, err := a.Users.GetOrganizationByOwner(p.UserID)
	if err != nil || org.ID != ev.OrganizationID {
		a.View.Error(w, r, http.StatusNotFound, "error.title")
		return Event{}, false
	}
	return ev, true
}

func (a Access) Fail(w http.ResponseWriter, r *http.Request, err error) {
	log.Printf("%s %s: %v", r.Method, r.URL.Path, err)
	a.View.Error(w, r, http.StatusInternalServerError, "error.title")
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

// PlacedZone is a zone converted to floor-plan pixel coordinates for the SVG.
type PlacedZone struct {
	Zone
	PX, PY, PW, PH float64
	CX, CY         float64
}

// PlanView is the data for the "venue_svg" partial.
type PlanView struct {
	EventID  string
	Map      VenueMap
	Zones    []PlacedZone
	FontSize float64
	// LinkBase, when set, makes each zone a link to LinkBase + zone ID.
	LinkBase string
	Selected string
}

func NewPlanView(m VenueMap, zones []Zone, linkBase, selected string) PlanView {
	w, h := float64(m.Width), float64(m.Height)
	pv := PlanView{EventID: m.EventID, Map: m, LinkBase: linkBase, Selected: selected, FontSize: w / 68}
	for _, z := range zones {
		pz := PlacedZone{Zone: z, PX: z.X / 100 * w, PY: z.Y / 100 * h, PW: z.W / 100 * w, PH: z.H / 100 * h}
		pz.CX, pz.CY = pz.PX+pz.PW/2, pz.PY+pz.PH/2
		pv.Zones = append(pv.Zones, pz)
	}
	return pv
}
