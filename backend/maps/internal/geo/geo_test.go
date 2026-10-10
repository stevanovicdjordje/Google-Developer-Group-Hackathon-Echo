package geo

import (
	"math"
	"testing"
)

func TestIsSimplePolygon(t *testing.T) {
	tests := []struct {
		name string
		pts  []Point
		want bool
	}{
		{"square", []Point{{0, 0}, {10, 0}, {10, 10}, {0, 10}}, true},
		{"square explicitly closed", []Point{{0, 0}, {10, 0}, {10, 10}, {0, 10}, {0, 0}}, true},
		{"bowtie", []Point{{0, 0}, {10, 10}, {10, 0}, {0, 10}}, false},
		{"two points", []Point{{0, 0}, {10, 0}}, false},
		{"collinear", []Point{{0, 0}, {5, 0}, {10, 0}}, false},
		{"concave L", []Point{{0, 0}, {10, 0}, {10, 5}, {5, 5}, {5, 10}, {0, 10}}, true},
		{"touching vertex", []Point{{0, 0}, {10, 0}, {5, 5}, {10, 10}, {0, 10}, {5, 5}}, false},
	}
	for _, tt := range tests {
		if got := IsSimplePolygon(tt.pts); got != tt.want {
			t.Errorf("%s: got %v, want %v", tt.name, got, tt.want)
		}
	}
}

func TestClosestPointOnSegment(t *testing.T) {
	p, tt := ClosestPointOnSegment(Point{0, 0}, Point{10, 0}, Point{4, 3})
	if p != (Point{4, 0}) || tt != 0.4 {
		t.Fatalf("got %v %v", p, tt)
	}
	p, _ = ClosestPointOnSegment(Point{0, 0}, Point{10, 0}, Point{-5, 3})
	if p != (Point{0, 0}) {
		t.Fatalf("got %v", p)
	}
}

// A plan 1000×600 px at 0.05 m/px, rotated 30°, near Belgrade.
func syntheticGeoref(t *testing.T) (*Georef, func(Point) LatLng) {
	t.Helper()
	origin := LatLng{44.8125, 20.4612}
	scale, rot := 0.05, 30*math.Pi/180
	cosLat := math.Cos(origin.Lat * math.Pi / 180)
	truth := func(p Point) LatLng {
		// pixel y points down → north is -y before rotation.
		e := scale * (p.X*math.Cos(rot) + p.Y*math.Sin(rot))
		n := scale * (p.X*math.Sin(rot) - p.Y*math.Cos(rot))
		return LatLng{origin.Lat + n/earthRadius*180/math.Pi, origin.Lng + e/(earthRadius*cosLat)*180/math.Pi}
	}
	var cps [3]ControlPoint
	for i, p := range []Point{{50, 40}, {950, 80}, {500, 560}} {
		cps[i] = ControlPoint{Px: p, LatLng: truth(p)}
	}
	g, err := NewGeoref(cps)
	if err != nil {
		t.Fatal(err)
	}
	return g, truth
}

func TestGeorefRoundTrip(t *testing.T) {
	g, truth := syntheticGeoref(t)
	for _, p := range []Point{{0, 0}, {1000, 600}, {123.4, 456.7}, {500, 300}} {
		got := g.ToPixel(truth(p))
		if d := Dist(got, p); d > 0.5 {
			t.Errorf("ToPixel(%v) off by %.3f px", p, d)
		}
		back := g.ToPixel(g.ToLatLng(p))
		if d := Dist(back, p); d > 1e-6 {
			t.Errorf("round trip %v off by %g px", p, d)
		}
	}
	q := g.Quality(1000, 600)
	if math.Abs(q.MetersPerPixel-0.05) > 1e-4 {
		t.Errorf("MetersPerPixel = %v", q.MetersPerPixel)
	}
	if q.ScaleMismatchPercent > 0.1 || q.SkewDegrees > 0.1 || q.EstimatedErrorMeters > 0.1 {
		t.Errorf("quality = %+v", q)
	}
}

func TestGeorefDegenerate(t *testing.T) {
	cps := [3]ControlPoint{
		{Px: Point{0, 0}, LatLng: LatLng{44.81, 20.46}},
		{Px: Point{100, 0}, LatLng: LatLng{44.81, 20.461}},
		{Px: Point{200, 0}, LatLng: LatLng{44.81, 20.462}},
	}
	if _, err := NewGeoref(cps); err == nil {
		t.Fatal("expected ErrDegenerate")
	}
}

func TestQualityDetectsBadPoint(t *testing.T) {
	_, truth := syntheticGeoref(t)
	pts := []Point{{50, 40}, {950, 80}, {500, 560}}
	var cps [3]ControlPoint
	for i, p := range pts {
		cps[i] = ControlPoint{Px: p, LatLng: truth(p)}
	}
	cps[2].Px.Y -= 120 // organizer clicked the wrong spot
	g, err := NewGeoref(cps)
	if err != nil {
		t.Fatal(err)
	}
	if q := g.Quality(1000, 600); q.EstimatedErrorMeters < 2 {
		t.Errorf("expected large error estimate, got %+v", q)
	}
}
