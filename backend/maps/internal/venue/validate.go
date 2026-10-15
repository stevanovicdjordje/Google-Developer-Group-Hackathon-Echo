package venue

import (
	"fmt"
	"net/url"
	"slices"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/Ilij4n/eho/backend/maps/internal/geo"
)

// Limits keep documents well below Firestore's 1 MiB document limit
// (a node is ~60 bytes, an edge ~40 bytes when encoded).
const (
	MaxNodesPerFloor = 5000
	MaxEdgesPerFloor = 10000
	MaxPolygonPoints = 200
	maxNameLen       = 120
	maxTextLen       = 2000
)

// Allowed enum values.
var (
	SponsorTiers = []string{"none", "bronze", "silver", "gold"}
	PoiKinds     = []string{"entrance", "toilet", "info", "cloakroom", "food", "lift", "stairs"}
	// ConnectorKinds are the kinds of floor connectors.
	ConnectorKinds = []string{"lift", "stairs"}
)

// FieldError describes one invalid input field.
type FieldError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

// ValidationError is a list of field errors.
type ValidationError []FieldError

func (v ValidationError) Error() string {
	parts := make([]string, len(v))
	for i, e := range v {
		parts[i] = e.Field + ": " + e.Message
	}
	return "validation failed: " + strings.Join(parts, "; ")
}

type checker struct{ errs ValidationError }

func (c *checker) add(field, format string, args ...any) {
	c.errs = append(c.errs, FieldError{Field: field, Message: fmt.Sprintf(format, args...)})
}

func (c *checker) err() error {
	if len(c.errs) == 0 {
		return nil
	}
	return c.errs
}

func (c *checker) text(field, v string, required bool, max int) {
	switch {
	case required && strings.TrimSpace(v) == "":
		c.add(field, "is required")
	case utf8.RuneCountInString(v) > max:
		c.add(field, "must be at most %d characters", max)
	}
}

func (c *checker) date(field, v string) {
	if _, err := time.Parse(time.DateOnly, v); err != nil {
		c.add(field, "must be a date in YYYY-MM-DD format")
	}
}

// ValidateEvent checks user-editable event fields.
func ValidateEvent(e *Event) error {
	var c checker
	c.text("name", e.Name, true, maxNameLen)
	c.text("address", e.Address, false, maxTextLen)
	c.date("startDate", e.StartDate)
	c.date("endDate", e.EndDate)
	if e.EndDate < e.StartDate {
		c.add("endDate", "must not be before startDate")
	}
	return c.err()
}

// ValidateFloor checks floor fields (dimensions are set by the server).
func ValidateFloor(f *Floor) error {
	var c checker
	c.text("name", f.Name, true, maxNameLen)
	if f.ImagePath == "" {
		c.add("imagePath", "is required")
	}
	if f.Width <= 0 || f.Height <= 0 {
		c.add("imagePath", "image has no valid dimensions")
	}
	return c.err()
}

// ValidateGeoref checks three control points against the floor and returns the
// fitted transform.
func ValidateGeoref(cps []geo.ControlPoint, f *Floor) (*geo.Georef, error) {
	var c checker
	if len(cps) != 3 {
		c.add("controlPoints", "exactly 3 control points are required")
		return nil, c.err()
	}
	for i, cp := range cps {
		if !geo.InBounds(cp.Px, f.Width, f.Height) {
			c.add(fmt.Sprintf("controlPoints[%d].px", i), "must lie within the floor plan (%dx%d)", f.Width, f.Height)
		}
		if cp.LatLng.Lat < -90 || cp.LatLng.Lat > 90 || cp.LatLng.Lng < -180 || cp.LatLng.Lng > 180 {
			c.add(fmt.Sprintf("controlPoints[%d].latLng", i), "is not a valid coordinate")
		}
	}
	if err := c.err(); err != nil {
		return nil, err
	}
	g, err := geo.NewGeoref([3]geo.ControlPoint{cps[0], cps[1], cps[2]})
	if err != nil {
		c.add("controlPoints", "%v", err)
		return nil, c.err()
	}
	return g, nil
}

// ValidateFeature checks a feature against its floor.
func ValidateFeature(ft *Feature, floor *Floor) error {
	var c checker
	c.text("name", ft.Name, true, maxNameLen)
	c.text("description", ft.Description, false, maxTextLen)
	c.text("company", ft.Company, false, maxNameLen)
	c.text("category", ft.Category, false, maxNameLen)

	allowedKinds := map[FeatureType][]GeometryKind{
		TypeRoom:   {KindPolygon, KindRect},
		TypeStand:  {KindPoint, KindRect},
		TypePOI:    {KindPoint},
		TypeMarker: {KindPoint},
	}
	kinds, ok := allowedKinds[ft.Type]
	if !ok {
		c.add("type", "must be one of room, stand, poi, marker")
	} else if !slices.Contains(kinds, ft.Geometry.Kind) {
		c.add("geometry.kind", "%q is not allowed for %s (allowed: %v)", ft.Geometry.Kind, ft.Type, kinds)
	}
	if floor == nil {
		c.add("floorId", "floor does not exist")
	} else {
		validateGeometry(&c, ft.Geometry, floor)
	}

	if ft.Capacity < 0 {
		c.add("capacity", "must not be negative")
	}
	if ft.SponsorTier != "" && !slices.Contains(SponsorTiers, ft.SponsorTier) {
		c.add("sponsorTier", "must be one of %v", SponsorTiers)
	}
	if ft.Type == TypePOI && !slices.Contains(PoiKinds, ft.PoiKind) {
		c.add("poiKind", "must be one of %v", PoiKinds)
	}
	if ft.Type != TypePOI && ft.PoiKind != "" {
		c.add("poiKind", "only allowed for type poi")
	}
	if ft.Link != "" {
		u, err := url.Parse(ft.Link)
		if err != nil || (u.Scheme != "http" && u.Scheme != "https") || u.Host == "" {
			c.add("link", "must be an http(s) URL")
		}
	}
	return c.err()
}

func validateGeometry(c *checker, g Geometry, floor *Floor) {
	n := len(g.Coords)
	switch g.Kind {
	case KindPoint:
		if n != 1 {
			c.add("geometry.coords", "a point needs exactly 1 coordinate")
		}
	case KindRect:
		if n != 2 {
			c.add("geometry.coords", "a rect needs exactly 2 corner coordinates")
		} else if g.Coords[0].X == g.Coords[1].X || g.Coords[0].Y == g.Coords[1].Y {
			c.add("geometry.coords", "rect must have non-zero width and height")
		}
	case KindPolygon:
		switch {
		case n < 3:
			c.add("geometry.coords", "a polygon needs at least 3 coordinates")
		case n > MaxPolygonPoints:
			c.add("geometry.coords", "a polygon may have at most %d coordinates", MaxPolygonPoints)
		case !geo.IsSimplePolygon(g.Coords):
			c.add("geometry.coords", "polygon must not intersect itself and must have an area")
		}
	default:
		c.add("geometry.kind", "must be one of point, rect, polygon")
	}
	for i, p := range g.Coords {
		if !geo.InBounds(p, floor.Width, floor.Height) {
			c.add(fmt.Sprintf("geometry.coords[%d]", i), "must lie within the floor plan (%dx%d)", floor.Width, floor.Height)
		}
	}
}

// ValidateGraph checks a floor's walkway graph.
func ValidateGraph(g *Graph, floor *Floor) error {
	var c checker
	if len(g.Nodes) > MaxNodesPerFloor {
		c.add("nodes", "at most %d nodes per floor", MaxNodesPerFloor)
	}
	if len(g.Edges) > MaxEdgesPerFloor {
		c.add("edges", "at most %d edges per floor", MaxEdgesPerFloor)
	}
	if err := c.err(); err != nil {
		return err
	}
	ids := make(map[string]bool, len(g.Nodes))
	for i, n := range g.Nodes {
		field := fmt.Sprintf("nodes[%d]", i)
		switch {
		case n.ID == "" || len(n.ID) > 64:
			c.add(field+".id", "must be 1-64 characters")
		case ids[n.ID]:
			c.add(field+".id", "duplicate node id %q", n.ID)
		}
		ids[n.ID] = true
		if !geo.InBounds(n.Point(), floor.Width, floor.Height) {
			c.add(field, "must lie within the floor plan (%dx%d)", floor.Width, floor.Height)
		}
		if n.Connector != "" && !slices.Contains(ConnectorKinds, n.ConnectorKind) {
			c.add(field+".connectorKind", "must be one of %v when connector is set", ConnectorKinds)
		}
	}
	for i, e := range g.Edges {
		field := fmt.Sprintf("edges[%d]", i)
		if !ids[e.From] || !ids[e.To] {
			c.add(field, "references an unknown node")
		} else if e.From == e.To {
			c.add(field, "must connect two different nodes")
		}
	}
	return c.err()
}
