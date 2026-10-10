package geo

import (
	"errors"
	"math"
)

// LatLng is a WGS84 position in degrees.
type LatLng struct {
	Lat float64 `json:"lat" firestore:"lat"`
	Lng float64 `json:"lng" firestore:"lng"`
}

// ControlPoint ties a plan pixel to a real-world position.
type ControlPoint struct {
	Px     Point  `json:"px" firestore:"px"`
	LatLng LatLng `json:"latLng" firestore:"latLng"`
}

// earthRadius is the WGS84 mean radius in meters (local equirectangular projection).
const earthRadius = 6371008.8

// ErrDegenerate is returned when control points are (nearly) collinear or coincide.
var ErrDegenerate = errors.New("control points are collinear or coincide")

// Georef converts between plan pixels and lat/lng using an affine transform
// fitted to exactly three control points. Lat/lng is first projected to local
// east/north meters around the first control point (equirectangular; accurate
// to well under a pixel over a venue-sized area), then mapped affinely to pixels.
type Georef struct {
	origin LatLng
	cosLat float64
	// pixel -> meters: [e n] = A·[x y] + t
	a, b, c, d, tx, ty float64
	// meters -> pixel (inverse)
	ia, ib, ic, id, itx, ity float64
}

// NewGeoref fits the transform to three control points.
func NewGeoref(cps [3]ControlPoint) (*Georef, error) {
	g := &Georef{origin: cps[0].LatLng, cosLat: math.Cos(cps[0].LatLng.Lat * math.Pi / 180)}
	var px, en [3]Point
	for i, cp := range cps {
		px[i] = cp.Px
		en[i] = g.toMeters(cp.LatLng)
	}
	// Solve for pixel->meters using differences relative to point 0.
	x1, y1 := px[1].X-px[0].X, px[1].Y-px[0].Y
	x2, y2 := px[2].X-px[0].X, px[2].Y-px[0].Y
	det := x1*y2 - x2*y1
	// Pixel triangle must have a meaningful area (> 1 px²·100) and the meter triangle too.
	if math.Abs(det) < 100 {
		return nil, ErrDegenerate
	}
	e1, n1 := en[1].X-en[0].X, en[1].Y-en[0].Y
	e2, n2 := en[2].X-en[0].X, en[2].Y-en[0].Y
	if math.Abs(e1*n2-e2*n1) < 1 { // < 1 m² meter-space area
		return nil, ErrDegenerate
	}
	g.a = (e1*y2 - e2*y1) / det
	g.b = (e2*x1 - e1*x2) / det
	g.c = (n1*y2 - n2*y1) / det
	g.d = (n2*x1 - n1*x2) / det
	g.tx = en[0].X - g.a*px[0].X - g.b*px[0].Y
	g.ty = en[0].Y - g.c*px[0].X - g.d*px[0].Y

	ldet := g.a*g.d - g.b*g.c
	g.ia, g.ib, g.ic, g.id = g.d/ldet, -g.b/ldet, -g.c/ldet, g.a/ldet
	g.itx = -(g.ia*g.tx + g.ib*g.ty)
	g.ity = -(g.ic*g.tx + g.id*g.ty)
	return g, nil
}

func (g *Georef) toMeters(ll LatLng) Point {
	return Point{
		X: (ll.Lng - g.origin.Lng) * math.Pi / 180 * earthRadius * g.cosLat,
		Y: (ll.Lat - g.origin.Lat) * math.Pi / 180 * earthRadius,
	}
}

func (g *Georef) fromMeters(m Point) LatLng {
	return LatLng{
		Lat: g.origin.Lat + m.Y/earthRadius*180/math.Pi,
		Lng: g.origin.Lng + m.X/(earthRadius*g.cosLat)*180/math.Pi,
	}
}

// ToPixel maps a lat/lng to plan pixels.
func (g *Georef) ToPixel(ll LatLng) Point {
	m := g.toMeters(ll)
	return Point{g.ia*m.X + g.ib*m.Y + g.itx, g.ic*m.X + g.id*m.Y + g.ity}
}

// ToLatLng maps plan pixels to lat/lng.
func (g *Georef) ToLatLng(p Point) LatLng {
	return g.fromMeters(Point{g.a*p.X + g.b*p.Y + g.tx, g.c*p.X + g.d*p.Y + g.ty})
}

// MetersPerPixel is the mean scale (square root of the area scale factor).
func (g *Georef) MetersPerPixel() float64 { return math.Sqrt(math.Abs(g.a*g.d - g.b*g.c)) }

// Quality describes how far the fitted transform is from a pure
// rotation+uniform scale. A floor plan should be close to that; large values
// usually mean a misplaced control point.
type Quality struct {
	MetersPerPixel float64 `json:"metersPerPixel"`
	// ScaleMismatchPercent: difference between the x and y axis scales.
	ScaleMismatchPercent float64 `json:"scaleMismatchPercent"`
	// SkewDegrees: deviation of the mapped pixel axes from perpendicular.
	SkewDegrees float64 `json:"skewDegrees"`
	// EstimatedErrorMeters: rough worst-case position error across the plan
	// caused by the non-similarity part of the transform.
	EstimatedErrorMeters float64 `json:"estimatedErrorMeters"`
}

// Quality evaluates the transform for a w×h plan.
func (g *Georef) Quality(w, h int) Quality {
	sx := math.Hypot(g.a, g.c) // meters per pixel along image x
	sy := math.Hypot(g.b, g.d) // along image y
	cosAng := (g.a*g.b + g.c*g.d) / (sx * sy)
	skew := math.Abs(90 - math.Acos(math.Max(-1, math.Min(1, cosAng)))*180/math.Pi)
	mean := (sx + sy) / 2
	mismatch := math.Abs(sx-sy) / mean * 100
	diag := math.Hypot(float64(w), float64(h)) * mean
	errM := diag * (math.Abs(sx-sy)/mean + math.Sin(skew*math.Pi/180)) / 2
	return Quality{
		MetersPerPixel:       g.MetersPerPixel(),
		ScaleMismatchPercent: mismatch,
		SkewDegrees:          skew,
		EstimatedErrorMeters: errM,
	}
}
