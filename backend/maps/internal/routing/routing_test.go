package routing

import (
	"errors"
	"fmt"
	"math"
	"math/rand"
	"testing"
	"time"

	"github.com/Ilij4n/eho/backend/maps/internal/geo"
	"github.com/Ilij4n/eho/backend/maps/internal/venue"
)

func pt(x, y float64) geo.Point { return geo.Point{X: x, Y: y} }

func near(a, b float64) bool { return math.Abs(a-b) < 1e-6 }

// corridor: a(0,0) — b(100,0) — c(200,0), and b — d(100,100) to a stand.
func corridorMap() *venue.Map {
	return &venue.Map{
		Floors: []venue.Floor{{ID: "f1", Width: 300, Height: 200}},
		Features: []venue.Feature{
			{ID: "stand", Type: venue.TypeStand, FloorID: "f1", EntranceNodeID: "d",
				Geometry: venue.Geometry{Kind: venue.KindPoint, Coords: []geo.Point{pt(100, 120)}}},
			{ID: "noEntrance", Type: venue.TypeStand, FloorID: "f1",
				Geometry: venue.Geometry{Kind: venue.KindPoint, Coords: []geo.Point{pt(190, 30)}}},
		},
		Graphs: []venue.Graph{{
			FloorID: "f1",
			Nodes: []venue.Node{
				{ID: "a", X: 0, Y: 0}, {ID: "b", X: 100, Y: 0}, {ID: "c", X: 200, Y: 0}, {ID: "d", X: 100, Y: 100},
			},
			Edges: []venue.Edge{{From: "a", To: "b"}, {From: "b", To: "c"}, {From: "b", To: "d"}},
		}},
	}
}

func TestRouteSnapsAPointAndEndsAtTheEntrance(t *testing.T) {
	g := Build(corridorMap())
	r, err := g.Route(Endpoint{FloorID: "f1", Point: pt(50, 10)}, Endpoint{FeatureID: "stand"}, Options{})
	if err != nil {
		t.Fatal(err)
	}
	want := []geo.Point{pt(50, 0), pt(100, 0), pt(100, 100)}
	if len(r.Legs) != 1 || fmt.Sprint(r.Legs[0].Points) != fmt.Sprint(want) {
		t.Fatalf("legs = %+v, want one leg %v", r.Legs, want)
	}
	if !near(r.DistanceMeters, 150*DefaultMetersPerPixel) || !r.DistanceEstimated {
		t.Errorf("distance = %v (estimated %v), want %v estimated", r.DistanceMeters, r.DistanceEstimated, 150*DefaultMetersPerPixel)
	}
	if !near(r.DurationSeconds, r.DistanceMeters/WalkSpeed) {
		t.Errorf("duration = %v, want %v", r.DurationSeconds, r.DistanceMeters/WalkSpeed)
	}
}

func TestRouteOnOneEdgeIsAStraightLine(t *testing.T) {
	g := Build(corridorMap())
	r, err := g.Route(Endpoint{FloorID: "f1", Point: pt(120, 5)}, Endpoint{FloorID: "f1", Point: pt(180, -5)}, Options{})
	if err != nil {
		t.Fatal(err)
	}
	if got := fmt.Sprint(r.Legs[0].Points); got != fmt.Sprint([]geo.Point{pt(120, 0), pt(180, 0)}) {
		t.Errorf("points = %s", got)
	}
}

func TestFeatureWithoutEntranceSnapsItsCenter(t *testing.T) {
	g := Build(corridorMap())
	r, err := g.Route(Endpoint{FeatureID: "stand"}, Endpoint{FeatureID: "noEntrance"}, Options{})
	if err != nil {
		t.Fatal(err)
	}
	pts := r.Legs[0].Points
	if last := pts[len(pts)-1]; last != pt(190, 0) {
		t.Errorf("ends at %v, want the walkway spot (190,0)", last)
	}
}

func twoFloorMap() *venue.Map {
	return &venue.Map{
		Floors: []venue.Floor{
			{ID: "g", Order: 0, Width: 200, Height: 200, Georef: &venue.Georeference{MetersPerPixel: 0.1}},
			{ID: "u", Order: 1, Width: 200, Height: 200, Georef: &venue.Georeference{MetersPerPixel: 0.1}},
		},
		Features: []venue.Feature{
			{ID: "start", Type: venue.TypeMarker, FloorID: "g", EntranceNodeID: "x",
				Geometry: venue.Geometry{Kind: venue.KindPoint, Coords: []geo.Point{pt(0, 0)}}},
			{ID: "goal", Type: venue.TypeStand, FloorID: "u", EntranceNodeID: "y",
				Geometry: venue.Geometry{Kind: venue.KindPoint, Coords: []geo.Point{pt(50, 50)}}},
		},
		Graphs: []venue.Graph{
			{FloorID: "g", Nodes: []venue.Node{
				{ID: "x", X: 0, Y: 0},
				{ID: "L", X: 100, Y: 0, Connector: "lift1", ConnectorKind: "lift"},
				{ID: "S", X: 0, Y: 100, Connector: "st1", ConnectorKind: "stairs"},
			}, Edges: []venue.Edge{{From: "x", To: "L"}, {From: "x", To: "S"}}},
			{FloorID: "u", Nodes: []venue.Node{
				{ID: "L", X: 100, Y: 0, Connector: "lift1", ConnectorKind: "lift"},
				{ID: "S", X: 0, Y: 100, Connector: "st1", ConnectorKind: "stairs"},
				{ID: "y", X: 50, Y: 50},
			}, Edges: []venue.Edge{{From: "L", To: "y"}, {From: "S", To: "y"}}},
		},
	}
}

func TestMultiFloorPrefersStairsUnlessAccessible(t *testing.T) {
	g := Build(twoFloorMap())
	r, err := g.Route(Endpoint{FeatureID: "start"}, Endpoint{FeatureID: "goal"}, Options{})
	if err != nil {
		t.Fatal(err)
	}
	if len(r.Legs) != 2 || r.Legs[0].FloorID != "g" || r.Legs[1].FloorID != "u" || r.Legs[1].ArriveBy != Stairs {
		t.Fatalf("legs = %+v, want g → u by stairs", r.Legs)
	}
	walk := (100 + math.Hypot(50, 50)) * 0.1
	if !near(r.DistanceMeters, walk) || r.DistanceEstimated {
		t.Errorf("distance = %v (estimated %v), want %v exact", r.DistanceMeters, r.DistanceEstimated, walk)
	}
	if !near(r.DurationSeconds, walk/WalkSpeed+StairsPerFloorSeconds) {
		t.Errorf("duration = %v", r.DurationSeconds)
	}

	r, err = g.Route(Endpoint{FeatureID: "start"}, Endpoint{FeatureID: "goal"}, Options{Accessible: true})
	if err != nil {
		t.Fatal(err)
	}
	if r.Legs[1].ArriveBy != Lift {
		t.Errorf("accessible route arrives by %q, want lift", r.Legs[1].ArriveBy)
	}
}

func TestErrors(t *testing.T) {
	m := corridorMap()
	m.Floors = append(m.Floors, venue.Floor{ID: "empty", Width: 10, Height: 10})
	m.Graphs = append(m.Graphs, venue.Graph{FloorID: "f2", Nodes: []venue.Node{{ID: "z", X: 1, Y: 1}}})
	m.Floors = append(m.Floors, venue.Floor{ID: "f2", Width: 10, Height: 10})
	m.Features = append(m.Features, venue.Feature{ID: "island", Type: venue.TypeStand, FloorID: "f2", EntranceNodeID: "z",
		Geometry: venue.Geometry{Kind: venue.KindPoint, Coords: []geo.Point{pt(1, 1)}}})
	g := Build(m)

	cases := []struct {
		name     string
		from, to Endpoint
		want     error
	}{
		{"unknown feature", Endpoint{FeatureID: "nope"}, Endpoint{FeatureID: "stand"}, ErrUnknownFeature},
		{"unknown floor", Endpoint{FloorID: "nope"}, Endpoint{FeatureID: "stand"}, ErrUnknownFloor},
		{"floor without walkways", Endpoint{FloorID: "empty", Point: pt(1, 1)}, Endpoint{FeatureID: "stand"}, ErrNoWalkway},
		{"disconnected", Endpoint{FeatureID: "stand"}, Endpoint{FeatureID: "island"}, ErrNoRoute},
	}
	for _, tc := range cases {
		if _, err := g.Route(tc.from, tc.to, Options{}); !errors.Is(err, tc.want) {
			t.Errorf("%s: err = %v, want %v", tc.name, err, tc.want)
		}
	}
}

// gridMap is a w×h walkway grid (10 px spacing) with some edges removed,
// plus a second floor joined by a lift and stairs.
func gridMap(w, h int, seed int64) *venue.Map {
	rnd := rand.New(rand.NewSource(seed))
	m := &venue.Map{}
	for f, floor := range []string{"g", "u"} {
		m.Floors = append(m.Floors, venue.Floor{ID: floor, Order: f, Width: w * 10, Height: h * 10})
		gr := venue.Graph{FloorID: floor}
		id := func(x, y int) string { return fmt.Sprintf("%d-%d", x, y) }
		for y := 0; y < h; y++ {
			for x := 0; x < w; x++ {
				n := venue.Node{ID: id(x, y), X: float64(x * 10), Y: float64(y * 10)}
				switch {
				case x == w/2 && y == h/2:
					n.Connector, n.ConnectorKind = "lift", "lift"
				case x == 0 && y == h-1:
					n.Connector, n.ConnectorKind = "stairs", "stairs"
				}
				gr.Nodes = append(gr.Nodes, n)
				if x > 0 && rnd.Float64() > 0.15 {
					gr.Edges = append(gr.Edges, venue.Edge{From: id(x-1, y), To: id(x, y)})
				}
				if y > 0 && rnd.Float64() > 0.15 {
					gr.Edges = append(gr.Edges, venue.Edge{From: id(x, y-1), To: id(x, y)})
				}
			}
		}
		m.Graphs = append(m.Graphs, gr)
	}
	return m
}

// dijkstra is a plain reference search between two nodes (no heuristic).
func dijkstra(g *Graph, from, to int) float64 {
	dist := make([]float64, len(g.nodes))
	done := make([]bool, len(g.nodes))
	for i := range dist {
		dist[i] = math.Inf(1)
	}
	dist[from] = 0
	for {
		u, best := -1, math.Inf(1)
		for i, d := range dist {
			if !done[i] && d < best {
				u, best = i, d
			}
		}
		if u < 0 || u == to {
			return dist[to]
		}
		done[u] = true
		for _, a := range g.adj[u] {
			if d := dist[u] + a.seconds; d < dist[a.to] {
				dist[a.to] = d
			}
		}
	}
}

func TestAStarMatchesDijkstra(t *testing.T) {
	for seed := int64(1); seed <= 5; seed++ {
		g := Build(gridMap(15, 12, seed))
		rnd := rand.New(rand.NewSource(seed))
		for k := 0; k < 20; k++ {
			a, b := rnd.Intn(g.NodeCount()), rnd.Intn(g.NodeCount())
			na, nb := g.nodes[a], g.nodes[b]
			want := dijkstra(g, a, b)
			r, err := g.Route(Endpoint{FloorID: na.floor, Point: na.p}, Endpoint{FloorID: nb.floor, Point: nb.p}, Options{})
			if math.IsInf(want, 1) {
				if !errors.Is(err, ErrNoRoute) {
					t.Fatalf("seed %d: %v→%v err = %v, want ErrNoRoute", seed, na, nb, err)
				}
				continue
			}
			if err != nil {
				t.Fatalf("seed %d: %v→%v: %v", seed, na, nb, err)
			}
			if !near(r.DurationSeconds, want) {
				t.Fatalf("seed %d: %v→%v duration %v, Dijkstra %v", seed, na, nb, r.DurationSeconds, want)
			}
		}
	}
}

// Phase 5 target: < 100 ms for a few thousand nodes.
func TestRouteIsFastOnALargeMap(t *testing.T) {
	g := Build(gridMap(50, 50, 7)) // 5000 nodes over two floors
	from := Endpoint{FloorID: "g", Point: pt(0, 0)}
	to := Endpoint{FloorID: "u", Point: pt(490, 490)}
	start := time.Now()
	if _, err := g.Route(from, to, Options{}); err != nil {
		t.Fatal(err)
	}
	if d := time.Since(start); d > 100*time.Millisecond {
		t.Errorf("route took %v, want < 100 ms", d)
	}
}

func BenchmarkRoute5000Nodes(b *testing.B) {
	g := Build(gridMap(50, 50, 7))
	from := Endpoint{FloorID: "g", Point: pt(3, 2)}
	to := Endpoint{FloorID: "u", Point: pt(487, 491)}
	b.ReportAllocs()
	for b.Loop() {
		if _, err := g.Route(from, to, Options{}); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkBuild5000Nodes(b *testing.B) {
	m := gridMap(50, 50, 7)
	for b.Loop() {
		Build(m)
	}
}

func TestCacheBuildsOncePerVersion(t *testing.T) {
	c := NewCache(2)
	loads := 0
	load := func(v int) func() (*venue.Map, int, error) {
		return func() (*venue.Map, int, error) { loads++; return corridorMap(), v, nil }
	}
	for i := 0; i < 3; i++ {
		if _, err := c.Get("e1", 1, load(1)); err != nil {
			t.Fatal(err)
		}
	}
	if loads != 1 {
		t.Fatalf("loads = %d, want 1", loads)
	}
	c.Get("e1", 2, load(2)) // new publish → rebuild
	c.Get("e2", 1, load(1))
	c.Get("e1", 2, load(2)) // e1 used more recently than e2
	c.Get("e3", 1, load(1)) // evicts e2
	c.Get("e1", 2, load(2))
	if loads != 4 {
		t.Errorf("loads = %d, want 4 (e1 v1, e1 v2, e2, e3)", loads)
	}
}

func TestStraightRunsBecomeOneSegment(t *testing.T) {
	pts := dedupe([]geo.Point{pt(0, 0), pt(10, 0), pt(10, 0), pt(20, 0), pt(30, 0), pt(30, 10), pt(30, 0)})
	want := []geo.Point{pt(0, 0), pt(30, 0), pt(30, 10), pt(30, 0)}
	if fmt.Sprint(pts) != fmt.Sprint(want) {
		t.Errorf("dedupe = %v, want %v (U-turns keep their point)", pts, want)
	}
}
