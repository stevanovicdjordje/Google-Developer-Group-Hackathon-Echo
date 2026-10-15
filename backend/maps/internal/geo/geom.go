// Package geo holds plan-space geometry (pixel coordinates) and the
// georeferencing transform between plan pixels and WGS84 lat/lng.
package geo

import "math"

// Point is a position on a floor plan in image pixels (x right, y down).
type Point struct {
	X float64 `json:"x" firestore:"x"`
	Y float64 `json:"y" firestore:"y"`
}

// Dist returns the Euclidean distance between a and b.
func Dist(a, b Point) float64 { return math.Hypot(a.X-b.X, a.Y-b.Y) }

// InBounds reports whether p lies within a w×h image.
func InBounds(p Point, w, h int) bool {
	return p.X >= 0 && p.Y >= 0 && p.X <= float64(w) && p.Y <= float64(h) &&
		!math.IsNaN(p.X) && !math.IsNaN(p.Y)
}

// cross returns the z component of (b-a)×(c-a).
func cross(a, b, c Point) float64 {
	return (b.X-a.X)*(c.Y-a.Y) - (b.Y-a.Y)*(c.X-a.X)
}

const eps = 1e-9

func sign(v float64) int {
	switch {
	case v > eps:
		return 1
	case v < -eps:
		return -1
	}
	return 0
}

func onSegment(a, b, p Point) bool {
	return math.Min(a.X, b.X)-eps <= p.X && p.X <= math.Max(a.X, b.X)+eps &&
		math.Min(a.Y, b.Y)-eps <= p.Y && p.Y <= math.Max(a.Y, b.Y)+eps
}

// SegmentsIntersect reports whether segments ab and cd share at least one point.
func SegmentsIntersect(a, b, c, d Point) bool {
	d1, d2 := sign(cross(c, d, a)), sign(cross(c, d, b))
	d3, d4 := sign(cross(a, b, c)), sign(cross(a, b, d))
	if d1*d2 < 0 && d3*d4 < 0 {
		return true
	}
	return (d1 == 0 && onSegment(c, d, a)) || (d2 == 0 && onSegment(c, d, b)) ||
		(d3 == 0 && onSegment(a, b, c)) || (d4 == 0 && onSegment(a, b, d))
}

// PolygonArea returns the signed area of the (implicitly closed) polygon.
func PolygonArea(pts []Point) float64 {
	var s float64
	for i := range pts {
		j := (i + 1) % len(pts)
		s += pts[i].X*pts[j].Y - pts[j].X*pts[i].Y
	}
	return s / 2
}

// IsSimplePolygon reports whether pts (implicitly closed: the last vertex
// connects back to the first) forms a simple polygon: at least 3 vertices,
// non-zero area and no self-intersections. A duplicated closing vertex
// (last == first) is tolerated.
func IsSimplePolygon(pts []Point) bool {
	if n := len(pts); n >= 2 && pts[0] == pts[n-1] {
		pts = pts[:n-1]
	}
	n := len(pts)
	if n < 3 || math.Abs(PolygonArea(pts)) < eps {
		return false
	}
	for i := 0; i < n; i++ {
		a, b := pts[i], pts[(i+1)%n]
		if a == b {
			return false
		}
		for j := i + 1; j < n; j++ {
			// Skip edges sharing a vertex with edge i.
			if j == i+1 || (i == 0 && j == n-1) {
				continue
			}
			if SegmentsIntersect(a, b, pts[j], pts[(j+1)%n]) {
				return false
			}
		}
	}
	return true
}

// ClosestPointOnSegment returns the point on segment ab closest to p and the
// parameter t in [0,1] along ab.
func ClosestPointOnSegment(a, b, p Point) (Point, float64) {
	dx, dy := b.X-a.X, b.Y-a.Y
	l2 := dx*dx + dy*dy
	if l2 == 0 {
		return a, 0
	}
	t := ((p.X-a.X)*dx + (p.Y-a.Y)*dy) / l2
	t = math.Max(0, math.Min(1, t))
	return Point{a.X + t*dx, a.Y + t*dy}, t
}
