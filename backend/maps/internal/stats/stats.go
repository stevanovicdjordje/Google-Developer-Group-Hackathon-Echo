// Package stats counts what attendees do on the published map (searches,
// opened features, route targets, QR scans) per event and day, so the
// organizer sees what people look for. It never sees positions, and stored
// aggregates hold no user IDs: only counters per search term or feature.
package stats

import (
	"strings"
	"time"
	"unicode/utf8"
)

// Kind is the type of an attendee interaction.
type Kind string

const (
	// Search is a finished search: the query and how many results it had.
	Search Kind = "search"
	// FeatureView is an opened details sheet of a room, stand or POI.
	FeatureView Kind = "feature_view"
	// Route is a requested route; FeatureID is its target.
	Route Kind = "route"
	// QRScan is an opened "you are here" QR marker link.
	QRScan Kind = "qr_scan"
)

// Limits on what is stored.
const (
	// MaxQueryRunes cuts long queries; longer text is not a search term.
	MaxQueryRunes = 60
	// MaxTermsPerDay caps the distinct keys of each per-day map, so a day
	// document stays far below Firestore's 1 MiB limit. Counts of keys over
	// the cap still go into the day's totals.
	MaxTermsPerDay = 500
)

// Event is one validated interaction.
type Event struct {
	Kind        Kind
	Query       string // Search: normalized query
	ResultCount int    // Search
	FeatureID   string // FeatureView, Route, QRScan
}

// Day is the aggregate of one event-day, stored as
// events/{eventId}/stats/{date} (see contracts/maps/realtime.md).
type Day struct {
	Date              string         `json:"date" firestore:"date"` // YYYY-MM-DD (UTC)
	Searches          int            `json:"searches" firestore:"searches"`
	SearchesNoResults int            `json:"searchesNoResults" firestore:"searchesNoResults"`
	FeatureViews      int            `json:"featureViews" firestore:"featureViews"`
	Routes            int            `json:"routes" firestore:"routes"`
	QRScans           int            `json:"qrScans" firestore:"qrScans"`
	SearchTerms       map[string]int `json:"searchTerms" firestore:"searchTerms"`
	NoResultTerms     map[string]int `json:"noResultTerms" firestore:"noResultTerms"`
	FeatureViewsBy    map[string]int `json:"featureViewsBy" firestore:"featureViewsBy"`
	RouteTargets      map[string]int `json:"routeTargets" firestore:"routeTargets"`
	QRScansBy         map[string]int `json:"qrScansBy" firestore:"qrScansBy"`
}

// NewDay returns an empty aggregate for date.
func NewDay(date string) *Day {
	return &Day{
		Date: date, SearchTerms: map[string]int{}, NoResultTerms: map[string]int{},
		FeatureViewsBy: map[string]int{}, RouteTargets: map[string]int{}, QRScansBy: map[string]int{},
	}
}

// DateOf returns the stats day of t (UTC).
func DateOf(t time.Time) string { return t.UTC().Format(time.DateOnly) }

func bump(m map[string]int, key string, n int) {
	if _, ok := m[key]; ok || len(m) < MaxTermsPerDay {
		m[key] += n
	}
}

// Add counts one event.
func (d *Day) Add(e Event) {
	switch e.Kind {
	case Search:
		d.Searches++
		bump(d.SearchTerms, e.Query, 1)
		if e.ResultCount == 0 {
			d.SearchesNoResults++
			bump(d.NoResultTerms, e.Query, 1)
		}
	case FeatureView:
		d.FeatureViews++
		bump(d.FeatureViewsBy, e.FeatureID, 1)
	case Route:
		d.Routes++
		bump(d.RouteTargets, e.FeatureID, 1)
	case QRScan:
		d.QRScans++
		bump(d.QRScansBy, e.FeatureID, 1)
	}
}

// Merge adds o's counts to d (same date). Maps may be nil in d (decoded docs).
func (d *Day) Merge(o *Day) {
	d.Searches += o.Searches
	d.SearchesNoResults += o.SearchesNoResults
	d.FeatureViews += o.FeatureViews
	d.Routes += o.Routes
	d.QRScans += o.QRScans
	for _, p := range []struct {
		dst *map[string]int
		src map[string]int
	}{
		{&d.SearchTerms, o.SearchTerms}, {&d.NoResultTerms, o.NoResultTerms},
		{&d.FeatureViewsBy, o.FeatureViewsBy}, {&d.RouteTargets, o.RouteTargets}, {&d.QRScansBy, o.QRScansBy},
	} {
		if *p.dst == nil {
			*p.dst = map[string]int{}
		}
		for k, n := range p.src {
			bump(*p.dst, k, n)
		}
	}
}

// Empty reports whether nothing was counted.
func (d *Day) Empty() bool {
	return d.Searches+d.FeatureViews+d.Routes+d.QRScans == 0
}

// NormalizeQuery lowercases, collapses whitespace and cuts the query to
// MaxQueryRunes. It returns "" for queries shorter than 2 characters, which
// are not counted (people still typing).
func NormalizeQuery(q string) string {
	q = strings.Join(strings.Fields(strings.ToLower(q)), " ")
	if utf8.RuneCountInString(q) > MaxQueryRunes {
		q = strings.TrimSpace(string([]rune(q)[:MaxQueryRunes]))
	}
	if utf8.RuneCountInString(q) < 2 {
		return ""
	}
	return q
}
