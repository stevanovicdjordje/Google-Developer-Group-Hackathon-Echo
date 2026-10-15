package routing

import (
	"container/heap"
	"errors"
	"math"

	"github.com/Ilij4n/eho/backend/maps/internal/geo"
)

// Errors returned by Route.
var (
	ErrUnknownFeature = errors.New("unknown feature")
	ErrUnknownFloor   = errors.New("unknown floor")
	ErrNoWalkway      = errors.New("no walkway on that floor")
	ErrNoRoute        = errors.New("no route between the two places")
)

// Endpoint is where a route starts or ends: a feature (its entrance node, or
// its center snapped onto a walkway) or a point on a floor.
type Endpoint struct {
	FeatureID string
	FloorID   string
	Point     geo.Point
}

// Options tune the search.
type Options struct {
	// Accessible avoids stairs (lifts and walkways only).
	Accessible bool
}

// Leg is a continuous part of a route on one floor.
type Leg struct {
	FloorID string      `json:"floorId"`
	Points  []geo.Point `json:"points"`
	// ArriveBy is how this floor was reached: "" for the first leg, else lift|stairs.
	ArriveBy Move `json:"arriveBy,omitempty"`
}

// Route is the result of a search.
type Route struct {
	Legs            []Leg   `json:"legs"`
	DistanceMeters  float64 `json:"distanceMeters"`
	DurationSeconds float64 `json:"durationSeconds"`
	// DistanceEstimated is true when a walked floor has no georeference, so
	// meters come from DefaultMetersPerPixel.
	DistanceEstimated bool `json:"distanceEstimated"`
}

// virtual node indices used during one search
const (
	vStart = -1
	vGoal  = -2
)

func (g *Graph) resolve(e Endpoint) (snap, error) {
	if e.FeatureID != "" {
		ft, ok := g.features[e.FeatureID]
		if !ok {
			return snap{}, ErrUnknownFeature
		}
		if i, ok := g.index[[2]string{ft.FloorID, ft.EntranceNodeID}]; ok && ft.EntranceNodeID != "" {
			return snap{floor: ft.FloorID, p: g.nodes[i].p, a: i, b: i}, nil
		}
		s, ok := g.snapPoint(ft.FloorID, ft.Geometry.Centroid())
		if !ok {
			return snap{}, ErrNoWalkway
		}
		return s, nil
	}
	if _, ok := g.floors[e.FloorID]; !ok {
		return snap{}, ErrUnknownFloor
	}
	s, ok := g.snapPoint(e.FloorID, e.Point)
	if !ok {
		return snap{}, ErrNoWalkway
	}
	return s, nil
}

// entry arcs from a snapped spot to its edge endpoints (or the node itself)
func (g *Graph) snapArcs(s snap) []arc {
	mpp := g.floors[s.floor].mpp
	if s.a == s.b {
		return []arc{{to: s.a, move: Walk}}
	}
	out := make([]arc, 0, 2)
	for _, i := range []int{s.a, s.b} {
		m := geo.Dist(s.p, g.nodes[i].p) * mpp
		out = append(out, arc{to: i, meters: m, seconds: m / WalkSpeed, move: Walk})
	}
	return out
}

// Route finds the fastest walking route from → to.
func (g *Graph) Route(from, to Endpoint, opt Options) (*Route, error) {
	s, err := g.resolve(from)
	if err != nil {
		return nil, err
	}
	t, err := g.resolve(to)
	if err != nil {
		return nil, err
	}

	// Both on the same edge (or the same node): the straight piece between
	// them may beat any detour through the graph.
	var direct *Route
	if s.floor == t.floor && sameEdge(s, t) {
		m := geo.Dist(s.p, t.p) * g.floors[s.floor].mpp
		direct = &Route{
			Legs:              []Leg{{FloorID: s.floor, Points: dedupe([]geo.Point{s.p, t.p})}},
			DistanceMeters:    m,
			DurationSeconds:   m / WalkSpeed,
			DistanceEstimated: g.floors[s.floor].estimated,
		}
	}

	goalArcs := map[int]arc{}
	for _, a := range g.snapArcs(t) {
		goalArcs[a.to] = a
	}

	n := len(g.nodes)
	dist := make([]float64, n)
	for i := range dist {
		dist[i] = math.Inf(1)
	}
	prev := make([]int, n)
	via := make([]Move, n)
	h := func(i int) float64 { // admissible: straight line at walking speed, same floor only
		if g.nodes[i].floor != t.floor {
			return 0
		}
		return geo.Dist(g.nodes[i].p, t.p) * g.floors[t.floor].mpp / WalkSpeed
	}

	pq := &queue{}
	for _, a := range g.snapArcs(s) {
		if a.seconds < dist[a.to] {
			dist[a.to], prev[a.to], via[a.to] = a.seconds, vStart, Walk
			heap.Push(pq, item{a.to, a.seconds + h(a.to)})
		}
	}
	bestGoal, goalPrev := math.Inf(1), 0
	for pq.Len() > 0 {
		it := heap.Pop(pq).(item)
		u := it.node
		if it.f-h(u) > dist[u]+1e-9 {
			continue // stale entry
		}
		if it.f >= bestGoal {
			break // f is a lower bound: nothing left can reach the goal faster
		}
		if ga, ok := goalArcs[u]; ok && dist[u]+ga.seconds < bestGoal {
			bestGoal, goalPrev = dist[u]+ga.seconds, u
		}
		for _, a := range g.adj[u] {
			if opt.Accessible && a.move == Stairs {
				continue
			}
			if d := dist[u] + a.seconds; d < dist[a.to] {
				dist[a.to], prev[a.to], via[a.to] = d, u, a.move
				heap.Push(pq, item{a.to, d + h(a.to)})
			}
		}
	}

	if math.IsInf(bestGoal, 1) {
		if direct != nil {
			return direct, nil
		}
		return nil, ErrNoRoute
	}
	if direct != nil && direct.DurationSeconds <= bestGoal {
		return direct, nil
	}
	return g.assemble(s, t, goalPrev, prev, via, bestGoal), nil
}

// sameEdge reports whether both spots lie on one walkway edge (a node counts
// as lying on every edge it ends).
func sameEdge(s, t snap) bool {
	switch {
	case s.a == s.b && t.a == t.b:
		return s.a == t.a
	case s.a == s.b:
		return s.a == t.a || s.a == t.b
	case t.a == t.b:
		return t.a == s.a || t.a == s.b
	}
	return min(s.a, s.b) == min(t.a, t.b) && max(s.a, s.b) == max(t.a, t.b)
}

// assemble walks prev pointers back from the goal and splits by floor.
func (g *Graph) assemble(s, t snap, last int, prev []int, via []Move, seconds float64) *Route {
	var chain []int
	for i := last; i != vStart; i = prev[i] {
		chain = append(chain, i)
	}
	for l, r := 0, len(chain)-1; l < r; l, r = l+1, r-1 {
		chain[l], chain[r] = chain[r], chain[l]
	}

	r := &Route{DurationSeconds: seconds}
	leg := Leg{FloorID: s.floor, Points: []geo.Point{s.p}}
	estimated := map[string]bool{}
	prevPoint, prevFloor := s.p, s.floor
	for _, i := range chain {
		nd := g.nodes[i]
		if nd.floor != prevFloor {
			r.Legs = append(r.Legs, leg)
			leg = Leg{FloorID: nd.floor, ArriveBy: via[i]}
		} else {
			r.DistanceMeters += geo.Dist(prevPoint, nd.p) * g.floors[nd.floor].mpp
			estimated[nd.floor] = true
		}
		leg.Points = append(leg.Points, nd.p)
		prevPoint, prevFloor = nd.p, nd.floor
	}
	r.DistanceMeters += geo.Dist(prevPoint, t.p) * g.floors[t.floor].mpp
	estimated[t.floor] = true
	leg.Points = append(leg.Points, t.p)
	r.Legs = append(r.Legs, leg)
	for i := range r.Legs {
		r.Legs[i].Points = dedupe(r.Legs[i].Points)
	}
	for f := range estimated {
		if g.floors[f].estimated {
			r.DistanceEstimated = true
		}
	}
	return r
}

// dedupe drops consecutive duplicate points (snaps that land on nodes) and
// middle points of straight runs, so a corridor is one segment.
func dedupe(pts []geo.Point) []geo.Point {
	out := pts[:0:0]
	for _, p := range pts {
		if len(out) > 0 && geo.Dist(out[len(out)-1], p) <= 1e-9 {
			continue
		}
		if n := len(out); n >= 2 && straight(out[n-2], out[n-1], p) {
			out[n-1] = p
			continue
		}
		out = append(out, p)
	}
	return out
}

// straight reports whether b lies on the segment a→c (same direction, no turn).
func straight(a, b, c geo.Point) bool {
	cross := (b.X-a.X)*(c.Y-a.Y) - (b.Y-a.Y)*(c.X-a.X)
	dot := (b.X-a.X)*(c.X-b.X) + (b.Y-a.Y)*(c.Y-b.Y)
	return math.Abs(cross) <= 1e-6*geo.Dist(a, c)*geo.Dist(a, c)+1e-9 && dot > 0
}

type item struct {
	node int
	f    float64
}

type queue []item

func (q queue) Len() int           { return len(q) }
func (q queue) Less(i, j int) bool { return q[i].f < q[j].f }
func (q queue) Swap(i, j int)      { q[i], q[j] = q[j], q[i] }
func (q *queue) Push(x any)        { *q = append(*q, x.(item)) }
func (q *queue) Pop() any {
	old := *q
	it := old[len(old)-1]
	*q = old[:len(old)-1]
	return it
}
