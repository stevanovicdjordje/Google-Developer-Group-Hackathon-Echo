// Package routing finds walking routes on a published venue map: one graph
// over all floors (walkways plus lifts/stairs between floors), A* by walking
// time, and snapping of arbitrary plan points onto the nearest walkway.
package routing

import (
	"math"
	"sort"

	"github.com/Ilij4n/eho/backend/maps/internal/geo"
	"github.com/Ilij4n/eho/backend/maps/internal/venue"
)

// Walking model. Costs are seconds, so lifts and stairs compare with walking.
const (
	WalkSpeed = 1.2 // m/s, a relaxed indoor pace
	// DefaultMetersPerPixel is used on floors without georeferencing
	// (≈ a 1000 px wide plan of a 50 m hall); distances are then estimates.
	DefaultMetersPerPixel = 0.05
	LiftBaseSeconds       = 30 // waiting + doors
	LiftPerFloorSeconds   = 5
	StairsPerFloorSeconds = 15
)

// Move is how a route step is taken.
type Move string

const (
	Walk   Move = "walk"
	Lift   Move = "lift"
	Stairs Move = "stairs"
)

type node struct {
	floor string
	id    string
	p     geo.Point
}

type arc struct {
	to      int
	seconds float64
	meters  float64
	move    Move
}

type segment struct{ a, b int }

type floorInfo struct {
	order     int
	mpp       float64
	estimated bool // no georeference: meters are an estimate
}

// Graph is the routing graph of one published map. It is immutable after
// Build and safe for concurrent use.
type Graph struct {
	nodes    []node
	index    map[[2]string]int // {floorID, nodeID} → node
	adj      [][]arc
	segments map[string][]segment // walkway edges per floor, for snapping
	floors   map[string]floorInfo
	features map[string]venue.Feature
}

// Build turns a (validated, published) map into a routing graph. Edges with
// unknown nodes are skipped; publish validation already reports them.
func Build(m *venue.Map) *Graph {
	g := &Graph{
		index:    map[[2]string]int{},
		segments: map[string][]segment{},
		floors:   map[string]floorInfo{},
		features: map[string]venue.Feature{},
	}
	for _, f := range m.Floors {
		fi := floorInfo{order: f.Order, mpp: DefaultMetersPerPixel, estimated: true}
		if f.Georef != nil && f.Georef.MetersPerPixel > 0 {
			fi.mpp, fi.estimated = f.Georef.MetersPerPixel, false
		}
		g.floors[f.ID] = fi
	}
	for _, ft := range m.Features {
		g.features[ft.ID] = ft
	}

	connectors := map[string][]int{}
	connectorKind := map[string]Move{}
	for _, gr := range m.Graphs {
		if _, ok := g.floors[gr.FloorID]; !ok {
			continue // graph of a deleted floor
		}
		for _, n := range gr.Nodes {
			i := len(g.nodes)
			g.nodes = append(g.nodes, node{floor: gr.FloorID, id: n.ID, p: n.Point()})
			g.adj = append(g.adj, nil)
			g.index[[2]string{gr.FloorID, n.ID}] = i
			if n.Connector != "" {
				connectors[n.Connector] = append(connectors[n.Connector], i)
				if n.ConnectorKind == string(Lift) {
					connectorKind[n.Connector] = Lift
				} else if connectorKind[n.Connector] == "" {
					connectorKind[n.Connector] = Stairs
				}
			}
		}
		for _, e := range gr.Edges {
			a, okA := g.index[[2]string{gr.FloorID, e.From}]
			b, okB := g.index[[2]string{gr.FloorID, e.To}]
			if !okA || !okB || a == b {
				continue
			}
			meters := geo.Dist(g.nodes[a].p, g.nodes[b].p) * g.floors[gr.FloorID].mpp
			g.addArc(a, b, meters, meters/WalkSpeed, Walk)
			g.segments[gr.FloorID] = append(g.segments[gr.FloorID], segment{a, b})
		}
	}

	// Lifts and stairs: every pair of same-connector nodes on different floors.
	names := make([]string, 0, len(connectors))
	for c := range connectors {
		names = append(names, c)
	}
	sort.Strings(names) // deterministic arc order → deterministic routes
	for _, c := range names {
		ids := connectors[c]
		for x := 0; x < len(ids); x++ {
			for y := x + 1; y < len(ids); y++ {
				a, b := ids[x], ids[y]
				fa, fb := g.nodes[a].floor, g.nodes[b].floor
				if fa == fb {
					continue
				}
				levels := math.Abs(float64(g.floors[fa].order - g.floors[fb].order))
				if levels == 0 {
					levels = 1
				}
				move := connectorKind[c]
				secs := StairsPerFloorSeconds * levels
				if move == Lift {
					secs = LiftBaseSeconds + LiftPerFloorSeconds*levels
				}
				g.addArc(a, b, 0, secs, move)
			}
		}
	}
	return g
}

func (g *Graph) addArc(a, b int, meters, seconds float64, move Move) {
	g.adj[a] = append(g.adj[a], arc{to: b, seconds: seconds, meters: meters, move: move})
	g.adj[b] = append(g.adj[b], arc{to: a, seconds: seconds, meters: meters, move: move})
}

// NodeCount is the number of walkway nodes on all floors.
func (g *Graph) NodeCount() int { return len(g.nodes) }

// snap is where a point joins the graph: a node, or a spot on an edge.
type snap struct {
	floor string
	p     geo.Point // the point on the walkway
	a, b  int       // edge endpoints; a == b when snapped onto a node
	t     float64   // position along a→b (0..1)
}

// snapPoint finds the closest spot on any walkway of the floor.
func (g *Graph) snapPoint(floor string, p geo.Point) (snap, bool) {
	best, bestD := snap{}, math.Inf(1)
	for _, s := range g.segments[floor] {
		a, b := g.nodes[s.a].p, g.nodes[s.b].p
		t := projectT(a, b, p)
		q := geo.Point{X: a.X + (b.X-a.X)*t, Y: a.Y + (b.Y-a.Y)*t}
		if d := geo.Dist(p, q); d < bestD {
			best, bestD = snap{floor: floor, p: q, a: s.a, b: s.b, t: t}, d
		}
	}
	if math.IsInf(bestD, 1) {
		// No edges on the floor: fall back to the nearest isolated node.
		for i, n := range g.nodes {
			if n.floor != floor {
				continue
			}
			if d := geo.Dist(p, n.p); d < bestD {
				best, bestD = snap{floor: floor, p: n.p, a: i, b: i}, d
			}
		}
	}
	if math.IsInf(bestD, 1) {
		return snap{}, false
	}
	switch {
	case best.t <= 0:
		best.b, best.t, best.p = best.a, 0, g.nodes[best.a].p
	case best.t >= 1:
		best.a, best.t, best.p = best.b, 0, g.nodes[best.b].p
	}
	return best, true
}

func projectT(a, b, p geo.Point) float64 {
	dx, dy := b.X-a.X, b.Y-a.Y
	l2 := dx*dx + dy*dy
	if l2 == 0 {
		return 0
	}
	return math.Max(0, math.Min(1, ((p.X-a.X)*dx+(p.Y-a.Y)*dy)/l2))
}
