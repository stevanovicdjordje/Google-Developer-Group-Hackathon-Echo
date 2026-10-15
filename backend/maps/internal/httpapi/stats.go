package httpapi

import (
	"cmp"
	"fmt"
	"net/http"
	"slices"
	"strconv"
	"time"

	"github.com/Ilij4n/eho/backend/maps/internal/auth"
	"github.com/Ilij4n/eho/backend/maps/internal/routing"
	"github.com/Ilij4n/eho/backend/maps/internal/stats"
	"github.com/Ilij4n/eho/backend/maps/internal/venue"
)

// Limits of the stats endpoints.
const (
	maxStatsBatch = 50  // events per request
	maxStatsDays  = 366 // days per stats query
	defaultDays   = 30
	topN          = 20 // entries per top list
	// Per signed-in user: 120 events at once, then 120 per minute.
	statsBurst     = 120
	statsPerMinute = 120
)

type statsEventInput struct {
	Type        stats.Kind `json:"type"`
	Query       *string    `json:"query"`
	ResultCount *int       `json:"resultCount"`
	FeatureID   string     `json:"featureId"`
}

type statsBatchInput struct {
	Events []statsEventInput `json:"events"`
}

// publishedGraph returns the routing graph (with the features) of the
// published map of e, from the cache, and the version it was built from.
func (s *server) publishedGraph(r *http.Request, e *venue.Event) (*routing.Graph, int, error) {
	version := 0
	g, err := s.routes.Get(e.ID, e.PublishedVersion, func() (*venue.Map, int, error) {
		m, v, err := s.store.GetPublished(r.Context(), e.ID)
		version = v
		return m, v, err
	})
	if version == 0 {
		version = e.PublishedVersion
	}
	return g, version, err
}

// recordStats counts a batch of attendee interactions on a published map.
// Events about features that are not (or no longer) on the published map are
// dropped, not rejected: the map may change while an attendee has it open.
func (s *server) recordStats(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, err := s.store.GetEvent(r.Context(), r.PathValue("eventId"))
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	if !e.Published() {
		writeError(w, http.StatusNotFound, "not_found", "resource not found", nil)
		return
	}
	var in statsBatchInput
	if !decode(w, r, &in) {
		return
	}
	var verr venue.ValidationError
	if n := len(in.Events); n == 0 || n > maxStatsBatch {
		verr = append(verr, venue.FieldError{Field: "events", Message: fmt.Sprintf("send 1 to %d events", maxStatsBatch)})
	}
	for i, ev := range in.Events {
		field := fmt.Sprintf("events[%d]", i)
		switch ev.Type {
		case stats.Search:
			if ev.Query == nil || ev.ResultCount == nil || *ev.ResultCount < 0 || ev.FeatureID != "" {
				verr = append(verr, venue.FieldError{Field: field, Message: "search needs query and resultCount ≥ 0, and no featureId"})
			}
		case stats.FeatureView, stats.Route, stats.QRScan:
			if ev.FeatureID == "" || ev.Query != nil || ev.ResultCount != nil {
				verr = append(verr, venue.FieldError{Field: field, Message: string(ev.Type) + " needs featureId only"})
			}
		default:
			verr = append(verr, venue.FieldError{Field: field + ".type", Message: "one of search, feature_view, route, qr_scan"})
		}
	}
	if len(verr) > 0 {
		s.respondErr(w, r, verr)
		return
	}
	if ok, wait := s.limiter.Allow(p.UID, len(in.Events)); !ok {
		w.Header().Set("Retry-After", strconv.Itoa(int(wait.Seconds())))
		writeError(w, http.StatusTooManyRequests, "rate_limited", "too many stats events; retry later", nil)
		return
	}

	g, _, err := s.publishedGraph(r, e)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	events := make([]stats.Event, 0, len(in.Events))
	for _, ev := range in.Events {
		out := stats.Event{Kind: ev.Type}
		if ev.Type == stats.Search {
			if out.Query = stats.NormalizeQuery(*ev.Query); out.Query == "" {
				continue
			}
			out.ResultCount = *ev.ResultCount
		} else {
			f, ok := g.Feature(ev.FeatureID)
			// QR scans are markers; everything else is a place people go to.
			if !ok || (ev.Type == stats.QRScan) != (f.Type == venue.TypeMarker) {
				continue
			}
			out.FeatureID = f.ID
		}
		events = append(events, out)
	}
	s.stats.Add(e.ID, events)
	writeJSON(w, http.StatusAccepted, map[string]int{"accepted": len(events), "dropped": len(in.Events) - len(events)})
}

type statsCounts struct {
	Searches          int `json:"searches"`
	SearchesNoResults int `json:"searchesNoResults"`
	FeatureViews      int `json:"featureViews"`
	Routes            int `json:"routes"`
	QRScans           int `json:"qrScans"`
}

type statsDay struct {
	Date string `json:"date"`
	statsCounts
}

type termCount struct {
	Query string `json:"query"`
	Count int    `json:"count"`
}

type featureCount struct {
	FeatureID string `json:"featureId"`
	// Name and Type are empty if the feature is no longer on the published map.
	Name  string `json:"name"`
	Type  string `json:"type"`
	Count int    `json:"count"`
}

type statsResponse struct {
	From            string         `json:"from"`
	To              string         `json:"to"`
	Totals          statsCounts    `json:"totals"`
	Days            []statsDay     `json:"days"`
	TopSearches     []termCount    `json:"topSearches"`
	TopNoResults    []termCount    `json:"topNoResults"`
	TopFeatures     []featureCount `json:"topFeatures"`
	TopRouteTargets []featureCount `json:"topRouteTargets"`
	QRScans         []featureCount `json:"qrScans"`
}

func countsOf(d *stats.Day) statsCounts {
	return statsCounts{d.Searches, d.SearchesNoResults, d.FeatureViews, d.Routes, d.QRScans}
}

// top returns the n largest entries of m, by count then key.
func top(m map[string]int, n int) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	slices.SortFunc(keys, func(a, b string) int {
		return cmp.Or(cmp.Compare(m[b], m[a]), cmp.Compare(a, b))
	})
	if len(keys) > n {
		keys = keys[:n]
	}
	return keys
}

func parseDay(v string) (time.Time, bool) {
	t, err := time.Parse(time.DateOnly, v)
	return t, err == nil
}

// getStats returns the owner's stats of an event per day (UTC) and top lists
// over the range. Default range: the last 30 days up to today.
func (s *server) getStats(w http.ResponseWriter, r *http.Request, p auth.Principal) {
	e, ok := s.ownedEvent(w, r, p)
	if !ok {
		return
	}
	q := r.URL.Query()
	var verr venue.ValidationError
	to := time.Now().UTC().Truncate(24 * time.Hour)
	if v := q.Get("to"); v != "" {
		if to, ok = parseDay(v); !ok {
			verr = append(verr, venue.FieldError{Field: "to", Message: "use YYYY-MM-DD"})
		}
	}
	from := to.AddDate(0, 0, -(defaultDays - 1))
	if v := q.Get("from"); v != "" {
		if from, ok = parseDay(v); !ok {
			verr = append(verr, venue.FieldError{Field: "from", Message: "use YYYY-MM-DD"})
		}
	}
	if len(verr) == 0 {
		if days := int(to.Sub(from).Hours()/24) + 1; days < 1 || days > maxStatsDays {
			verr = append(verr, venue.FieldError{Field: "from", Message: fmt.Sprintf("from must be on or before to, at most %d days", maxStatsDays)})
		}
	}
	if len(verr) > 0 {
		s.respondErr(w, r, verr)
		return
	}

	// Counts still buffered on this instance are shown right away.
	if err := s.stats.FlushEvent(r.Context(), e.ID); err != nil {
		s.log.WarnContext(r.Context(), "stats flush before read failed", "err", err)
	}
	fromS, toS := from.Format(time.DateOnly), to.Format(time.DateOnly)
	stored, err := s.store.ListStats(r.Context(), e.ID, fromS, toS)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}

	sum := stats.NewDay("")
	byDate := map[string]*stats.Day{}
	for i := range stored {
		byDate[stored[i].Date] = &stored[i]
		sum.Merge(&stored[i])
	}
	out := statsResponse{From: fromS, To: toS, Totals: countsOf(sum), Days: []statsDay{}}
	for d := from; !d.After(to); d = d.AddDate(0, 0, 1) {
		date := d.Format(time.DateOnly)
		day := statsDay{Date: date}
		if sd := byDate[date]; sd != nil {
			day.statsCounts = countsOf(sd)
		}
		out.Days = append(out.Days, day)
	}

	terms := func(m map[string]int) []termCount {
		res := []termCount{}
		for _, k := range top(m, topN) {
			res = append(res, termCount{k, m[k]})
		}
		return res
	}
	// Names come from the current published map.
	var g *routing.Graph
	if e.Published() {
		if g, _, err = s.publishedGraph(r, e); err != nil {
			s.respondErr(w, r, err)
			return
		}
	}
	features := func(m map[string]int, n int) []featureCount {
		res := []featureCount{}
		for _, id := range top(m, n) {
			fc := featureCount{FeatureID: id, Count: m[id]}
			if g != nil {
				if f, ok := g.Feature(id); ok {
					fc.Name, fc.Type = f.Name, string(f.Type)
				}
			}
			res = append(res, fc)
		}
		return res
	}
	out.TopSearches = terms(sum.SearchTerms)
	out.TopNoResults = terms(sum.NoResultTerms)
	out.TopFeatures = features(sum.FeatureViewsBy, topN)
	out.TopRouteTargets = features(sum.RouteTargets, topN)
	out.QRScans = features(sum.QRScansBy, stats.MaxTermsPerDay)
	writeJSON(w, http.StatusOK, out)
}
