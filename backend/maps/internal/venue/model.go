// Package venue is the domain model of an event's venue map (floors, features,
// routing graphs) and its validation rules. It has no storage dependencies.
package venue

import (
	"time"

	"github.com/Ilij4n/eho/backend/maps/internal/geo"
)

// Event is the top-level document events/{eventId}.
type Event struct {
	ID               string     `json:"id" firestore:"-"`
	Name             string     `json:"name" firestore:"name"`
	StartDate        string     `json:"startDate" firestore:"startDate"` // YYYY-MM-DD
	EndDate          string     `json:"endDate" firestore:"endDate"`     // YYYY-MM-DD
	Address          string     `json:"address" firestore:"address"`
	OwnerUID         string     `json:"ownerUid" firestore:"ownerUid"`
	PublishedVersion int        `json:"publishedVersion" firestore:"publishedVersion"`
	PublishedAt      *time.Time `json:"publishedAt,omitempty" firestore:"publishedAt"`
	CreatedAt        time.Time  `json:"createdAt" firestore:"createdAt"`
	UpdatedAt        time.Time  `json:"updatedAt" firestore:"updatedAt"`
}

// Published reports whether attendees can see the event.
func (e *Event) Published() bool { return e.PublishedVersion > 0 }

// Floor is one floor plan image with optional georeferencing.
type Floor struct {
	ID        string        `json:"id" firestore:"-"`
	Name      string        `json:"name" firestore:"name"`
	Order     int           `json:"order" firestore:"order"`
	ImagePath string        `json:"imagePath" firestore:"imagePath"` // Storage object path
	Width     int           `json:"width" firestore:"width"`         // pixels
	Height    int           `json:"height" firestore:"height"`       // pixels
	Georef    *Georeference `json:"georef" firestore:"georef"`
}

// Georeference holds the three control points of a floor and derived values.
type Georeference struct {
	ControlPoints  []geo.ControlPoint `json:"controlPoints" firestore:"controlPoints"`
	MetersPerPixel float64            `json:"metersPerPixel" firestore:"metersPerPixel"`
}

// FeatureType is the kind of map feature.
type FeatureType string

const (
	TypeRoom   FeatureType = "room"
	TypeStand  FeatureType = "stand"
	TypePOI    FeatureType = "poi"
	TypeMarker FeatureType = "marker" // "you are here" QR marker
)

// GeometryKind is the shape of a feature geometry.
type GeometryKind string

const (
	KindPoint   GeometryKind = "point"   // 1 coordinate
	KindRect    GeometryKind = "rect"    // 2 coordinates: opposite corners
	KindPolygon GeometryKind = "polygon" // ≥3 coordinates, implicitly closed
)

// Geometry is a shape in plan pixels.
type Geometry struct {
	Kind   GeometryKind `json:"kind" firestore:"kind"`
	Coords []geo.Point  `json:"coords" firestore:"coords"`
}

// Centroid returns a representative point of the geometry.
func (g Geometry) Centroid() geo.Point {
	var c geo.Point
	for _, p := range g.Coords {
		c.X += p.X
		c.Y += p.Y
	}
	if n := float64(len(g.Coords)); n > 0 {
		c.X /= n
		c.Y /= n
	}
	return c
}

// Feature is a room, stand, POI or QR marker on a floor.
type Feature struct {
	ID             string      `json:"id" firestore:"-"`
	Type           FeatureType `json:"type" firestore:"type"`
	FloorID        string      `json:"floorId" firestore:"floorId"`
	Name           string      `json:"name" firestore:"name"`
	Description    string      `json:"description,omitempty" firestore:"description,omitempty"`
	Geometry       Geometry    `json:"geometry" firestore:"geometry"`
	EntranceNodeID string      `json:"entranceNodeId,omitempty" firestore:"entranceNodeId,omitempty"`
	// Room only.
	Capacity int `json:"capacity,omitempty" firestore:"capacity,omitempty"`
	// Stand only.
	Company     string `json:"company,omitempty" firestore:"company,omitempty"`
	Category    string `json:"category,omitempty" firestore:"category,omitempty"`
	Link        string `json:"link,omitempty" firestore:"link,omitempty"`
	SponsorTier string `json:"sponsorTier,omitempty" firestore:"sponsorTier,omitempty"`
	// POI only.
	PoiKind string `json:"poiKind,omitempty" firestore:"poiKind,omitempty"`
}

// Node is a routing-graph vertex on one floor.
type Node struct {
	ID string  `json:"id" firestore:"id"`
	X  float64 `json:"x" firestore:"x"`
	Y  float64 `json:"y" firestore:"y"`
	// Connector links floors: nodes with the same Connector on different
	// floors are connected (a lift or a staircase).
	Connector     string `json:"connector,omitempty" firestore:"connector,omitempty"`
	ConnectorKind string `json:"connectorKind,omitempty" firestore:"connectorKind,omitempty"` // lift | stairs
}

// Point returns the node position.
func (n Node) Point() geo.Point { return geo.Point{X: n.X, Y: n.Y} }

// Edge is an undirected walkable segment between two nodes on the same floor.
type Edge struct {
	From string `json:"from" firestore:"from"`
	To   string `json:"to" firestore:"to"`
}

// Graph is the walkway graph of one floor (document graphs/{floorId}).
type Graph struct {
	FloorID string `json:"floorId" firestore:"-"`
	Nodes   []Node `json:"nodes" firestore:"nodes"`
	Edges   []Edge `json:"edges" firestore:"edges"`
}

// Map is a complete venue map: the draft or the published version.
type Map struct {
	Floors   []Floor   `json:"floors"`
	Features []Feature `json:"features"`
	Graphs   []Graph   `json:"graphs"`
}

// Floor returns the floor with the given ID, or nil.
func (m *Map) Floor(id string) *Floor {
	for i := range m.Floors {
		if m.Floors[i].ID == id {
			return &m.Floors[i]
		}
	}
	return nil
}

// Graph returns the graph of the given floor, or nil.
func (m *Map) Graph(floorID string) *Graph {
	for i := range m.Graphs {
		if m.Graphs[i].FloorID == floorID {
			return &m.Graphs[i]
		}
	}
	return nil
}

// Normalize replaces nil slices with empty ones so JSON always has arrays.
func (m *Map) Normalize() *Map {
	if m.Floors == nil {
		m.Floors = []Floor{}
	}
	if m.Features == nil {
		m.Features = []Feature{}
	}
	if m.Graphs == nil {
		m.Graphs = []Graph{}
	}
	return m
}
