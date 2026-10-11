package events

import (
	"fmt"
	"sort"
	"strings"
)

// Read-only view of the published venue map that backend/maps writes
// (events/{eventId}/published/map/{floors,features}). Organizers edit the
// map in the Flutter map editor; this module only draws it.

type Point struct {
	X float64 `firestore:"x"`
	Y float64 `firestore:"y"`
}

type Geometry struct {
	Kind   string  `firestore:"kind"` // point | rect | polygon
	Coords []Point `firestore:"coords"`
}

type Feature struct {
	ID          string   `firestore:"-"`
	Type        string   `firestore:"type"` // room | stand | poi | marker
	FloorID     string   `firestore:"floorId"`
	Name        string   `firestore:"name"`
	Description string   `firestore:"description"`
	Geometry    Geometry `firestore:"geometry"`
}

type Floor struct {
	ID        string `firestore:"-"`
	Name      string `firestore:"name"`
	Order     int    `firestore:"order"`
	ImagePath string `firestore:"imagePath"`
	Width     int    `firestore:"width"`
	Height    int    `firestore:"height"`
}

type Map struct {
	Floors   []Floor
	Features []Feature
}

func (m Map) Empty() bool { return len(m.Floors) == 0 }

// Floor returns the floor with the given ID.
func (m Map) Floor(id string) (Floor, bool) {
	for _, f := range m.Floors {
		if f.ID == id {
			return f, true
		}
	}
	return Floor{}, false
}

// RoomNames lists room names (the halls sessions can be placed in).
func (m Map) RoomNames() []string {
	var out []string
	for _, f := range m.Features {
		if f.Type == "room" && f.Name != "" && !containsFold(out, f.Name) {
			out = append(out, f.Name)
		}
	}
	sort.Strings(out)
	return out
}

// Feature returns the feature with the given ID.
func (m Map) Feature(id string) (Feature, bool) {
	for _, f := range m.Features {
		if f.ID == id {
			return f, true
		}
	}
	return Feature{}, false
}

// Shape is a feature in floor pixels, ready for the SVG template.
type Shape struct {
	FeatureID string
	Name      string
	Type      string
	Kind      string // rect | polygon | point
	X, Y      float64
	W, H      float64
	Points    string // polygon "x,y x,y …"
	CX, CY    float64
	R         float64
	// ShowLabel is false when the name wouldn't fit inside the shape; the
	// name is then only in the tooltip (<title>).
	ShowLabel bool
}

type FloorView struct {
	Floor    Floor
	ImageURL string
	Shapes   []Shape
	FontSize float64
}

// PlanView is the data for the "venue_svg" partial.
type PlanView struct {
	EventID string
	Floors  []FloorView
	// LinkBase, when set, makes each feature a link to LinkBase + feature ID.
	LinkBase string
	Selected string
}

// NewPlanView converts the published map to SVG shapes, one view per floor.
// QR markers are not shown.
func NewPlanView(eventID string, m Map, linkBase, selected string) PlanView {
	pv := PlanView{EventID: eventID, LinkBase: linkBase, Selected: selected}
	floors := append([]Floor(nil), m.Floors...)
	sort.SliceStable(floors, func(i, j int) bool { return floors[i].Order < floors[j].Order })
	for _, fl := range floors {
		fv := FloorView{Floor: fl, ImageURL: fmt.Sprintf("/events/%s/floors/%s/image", eventID, fl.ID),
			FontSize: float64(fl.Width) / 70}
		for _, f := range m.Features {
			if f.FloorID != fl.ID || f.Type == "marker" || len(f.Geometry.Coords) == 0 {
				continue
			}
			sh := Shape{FeatureID: f.ID, Name: f.Name, Type: f.Type, Kind: f.Geometry.Kind}
			c := f.Geometry.Coords
			switch f.Geometry.Kind {
			case "rect":
				if len(c) < 2 {
					continue
				}
				sh.X, sh.Y = min(c[0].X, c[1].X), min(c[0].Y, c[1].Y)
				sh.W, sh.H = abs(c[1].X-c[0].X), abs(c[1].Y-c[0].Y)
				sh.CX, sh.CY = sh.X+sh.W/2, sh.Y+sh.H/2
			case "polygon":
				var pts []string
				for _, p := range c {
					pts = append(pts, fmt.Sprintf("%.1f,%.1f", p.X, p.Y))
					sh.CX += p.X
					sh.CY += p.Y
				}
				sh.Points = strings.Join(pts, " ")
				sh.CX /= float64(len(c))
				sh.CY /= float64(len(c))
			default:
				sh.Kind = "point"
				sh.CX, sh.CY = c[0].X, c[0].Y
				sh.R = float64(fl.Width) / 110
			}
			if sh.Kind != "point" {
				width := sh.W
				if sh.Kind == "polygon" {
					minX, maxX := c[0].X, c[0].X
					for _, p := range c {
						minX, maxX = min(minX, p.X), max(maxX, p.X)
					}
					width = maxX - minX
				}
				// Rough text width: 0.6 em per character.
				sh.ShowLabel = float64(len([]rune(f.Name)))*fv.FontSize*0.6 <= width
			}
			fv.Shapes = append(fv.Shapes, sh)
		}
		pv.Floors = append(pv.Floors, fv)
	}
	return pv
}

func abs(f float64) float64 {
	if f < 0 {
		return -f
	}
	return f
}
