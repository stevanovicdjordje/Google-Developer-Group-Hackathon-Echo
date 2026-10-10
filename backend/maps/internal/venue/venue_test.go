package venue

import (
	"errors"
	"testing"

	"github.com/Ilij4n/eho/backend/maps/internal/geo"
)

var floor = &Floor{ID: "f1", Name: "Prizemlje", ImagePath: "events/e/floors/f1.png", Width: 1000, Height: 600}

func pt(x, y float64) geo.Point { return geo.Point{X: x, Y: y} }

func fieldErrs(err error) map[string]bool {
	var v ValidationError
	out := map[string]bool{}
	if errors.As(err, &v) {
		for _, e := range v {
			out[e.Field] = true
		}
	}
	return out
}

func TestValidateEvent(t *testing.T) {
	ok := &Event{Name: "DevFest", StartDate: "2026-10-10", EndDate: "2026-10-11"}
	if err := ValidateEvent(ok); err != nil {
		t.Fatal(err)
	}
	bad := &Event{Name: " ", StartDate: "10.10.2026", EndDate: "2026-10-09"}
	errs := fieldErrs(ValidateEvent(bad))
	for _, f := range []string{"name", "startDate"} {
		if !errs[f] {
			t.Errorf("expected error on %s, got %v", f, errs)
		}
	}
	if err := ValidateEvent(&Event{Name: "x", StartDate: "2026-10-11", EndDate: "2026-10-10"}); !fieldErrs(err)["endDate"] {
		t.Errorf("expected endDate error, got %v", err)
	}
}

func TestValidateFeature(t *testing.T) {
	tests := []struct {
		name    string
		ft      Feature
		wantErr string // field name, "" for valid
	}{
		{"stand point", Feature{Type: TypeStand, Name: "Gold", Geometry: Geometry{KindPoint, []geo.Point{pt(10, 10)}}, SponsorTier: "gold"}, ""},
		{"room polygon", Feature{Type: TypeRoom, Name: "Sala A", Geometry: Geometry{KindPolygon, []geo.Point{pt(0, 0), pt(100, 0), pt(100, 100)}}}, ""},
		{"room as point", Feature{Type: TypeRoom, Name: "Sala A", Geometry: Geometry{KindPoint, []geo.Point{pt(1, 1)}}}, "geometry.kind"},
		{"out of bounds", Feature{Type: TypeStand, Name: "S", Geometry: Geometry{KindPoint, []geo.Point{pt(1001, 10)}}}, "geometry.coords[0]"},
		{"bowtie", Feature{Type: TypeRoom, Name: "S", Geometry: Geometry{KindPolygon, []geo.Point{pt(0, 0), pt(10, 10), pt(10, 0), pt(0, 10)}}}, "geometry.coords"},
		{"flat rect", Feature{Type: TypeStand, Name: "S", Geometry: Geometry{KindRect, []geo.Point{pt(0, 5), pt(10, 5)}}}, "geometry.coords"},
		{"bad tier", Feature{Type: TypeStand, Name: "S", Geometry: Geometry{KindPoint, []geo.Point{pt(1, 1)}}, SponsorTier: "platinum"}, "sponsorTier"},
		{"poi without kind", Feature{Type: TypePOI, Name: "WC", Geometry: Geometry{KindPoint, []geo.Point{pt(1, 1)}}}, "poiKind"},
		{"bad link", Feature{Type: TypeStand, Name: "S", Geometry: Geometry{KindPoint, []geo.Point{pt(1, 1)}}, Link: "javascript:alert(1)"}, "link"},
		{"unknown type", Feature{Type: "booth", Name: "S", Geometry: Geometry{KindPoint, []geo.Point{pt(1, 1)}}}, "type"},
	}
	for _, tt := range tests {
		err := ValidateFeature(&tt.ft, floor)
		if tt.wantErr == "" {
			if err != nil {
				t.Errorf("%s: unexpected %v", tt.name, err)
			}
			continue
		}
		if !fieldErrs(err)[tt.wantErr] {
			t.Errorf("%s: want error on %s, got %v", tt.name, tt.wantErr, err)
		}
	}
}

func TestValidateGraph(t *testing.T) {
	g := &Graph{
		Nodes: []Node{{ID: "a", X: 1, Y: 1}, {ID: "a", X: 2, Y: 2}, {ID: "c", X: 5000, Y: 1}, {ID: "l", X: 3, Y: 3, Connector: "lift1"}},
		Edges: []Edge{{"a", "zzz"}, {"a", "a"}},
	}
	errs := fieldErrs(ValidateGraph(g, floor))
	for _, f := range []string{"nodes[1].id", "nodes[2]", "nodes[3].connectorKind", "edges[0]", "edges[1]"} {
		if !errs[f] {
			t.Errorf("expected error on %s, got %v", f, errs)
		}
	}
}

func TestValidateGeoref(t *testing.T) {
	cps := []geo.ControlPoint{
		{Px: pt(0, 0), LatLng: geo.LatLng{Lat: 44.8125, Lng: 20.4612}},
		{Px: pt(1000, 0), LatLng: geo.LatLng{Lat: 44.8125, Lng: 20.4618}},
		{Px: pt(0, 600), LatLng: geo.LatLng{Lat: 44.8122, Lng: 20.4612}},
	}
	if _, err := ValidateGeoref(cps, floor); err != nil {
		t.Fatal(err)
	}
	if _, err := ValidateGeoref(cps[:2], floor); err == nil {
		t.Fatal("expected error for 2 points")
	}
	cps[1].Px = pt(2000, 0)
	if !fieldErrs(mustErr(ValidateGeoref(cps, floor)))["controlPoints[1].px"] {
		t.Fatal("expected out-of-bounds error")
	}
}

func mustErr(_ *geo.Georef, err error) error { return err }

func twoFloorMap() *Map {
	f2 := *floor
	f2.ID, f2.Name = "f2", "Sprat 1"
	return &Map{
		Floors: []Floor{*floor, f2},
		Graphs: []Graph{
			{FloorID: "f1", Nodes: []Node{{ID: "a", X: 10, Y: 10}, {ID: "b", X: 100, Y: 10}, {ID: "lift", X: 200, Y: 10, Connector: "L", ConnectorKind: "lift"}, {ID: "island", X: 500, Y: 500}},
				Edges: []Edge{{"a", "b"}, {"b", "lift"}}},
			{FloorID: "f2", Nodes: []Node{{ID: "lift", X: 200, Y: 10, Connector: "L", ConnectorKind: "lift"}, {ID: "c", X: 300, Y: 10}},
				Edges: []Edge{{"lift", "c"}}},
		},
		Features: []Feature{
			{ID: "s1", Type: TypeStand, FloorID: "f1", Name: "S1", Geometry: Geometry{KindPoint, []geo.Point{pt(10, 20)}}, EntranceNodeID: "a"},
			{ID: "s2", Type: TypeStand, FloorID: "f2", Name: "S2", Geometry: Geometry{KindPoint, []geo.Point{pt(300, 20)}}, EntranceNodeID: "c"},
		},
	}
}

func TestCheckPublishOK(t *testing.T) {
	errs, warns := CheckPublish(twoFloorMap())
	if len(errs) != 0 || len(warns) != 0 {
		t.Fatalf("errs=%v warns=%v", errs, warns)
	}
}

func TestCheckPublishIssues(t *testing.T) {
	m := twoFloorMap()
	m.Features = append(m.Features,
		Feature{ID: "s3", Type: TypeStand, FloorID: "f1", Name: "Island", Geometry: Geometry{KindPoint, []geo.Point{pt(500, 510)}}, EntranceNodeID: "island"},
		Feature{ID: "s4", Type: TypeStand, FloorID: "f1", Name: "NoEntrance", Geometry: Geometry{KindPoint, []geo.Point{pt(5, 5)}}},
		Feature{ID: "s5", Type: TypeStand, FloorID: "f1", Name: "Ghost", Geometry: Geometry{KindPoint, []geo.Point{pt(5, 5)}}, EntranceNodeID: "nope"},
		Feature{ID: "s6", Type: TypeStand, FloorID: "gone", Name: "Orphan", Geometry: Geometry{KindPoint, []geo.Point{pt(5, 5)}}},
	)
	errs, warns := CheckPublish(m)
	codes := map[string]string{}
	for _, i := range append(errs, warns...) {
		codes[i.FeatureID] = i.Code
	}
	want := map[string]string{"s3": "unreachable", "s4": "no_entrance", "s5": "unknown_entrance", "s6": "invalid_feature"}
	for id, code := range want {
		if codes[id] != code {
			t.Errorf("%s: got %q, want %q (errs=%v warns=%v)", id, codes[id], code, errs, warns)
		}
	}
	if len(errs) != 2 {
		t.Errorf("want 2 blocking errors, got %v", errs)
	}
}

func TestCheckPublishEmpty(t *testing.T) {
	errs, _ := CheckPublish(&Map{})
	if len(errs) != 1 || errs[0].Code != "no_floors" {
		t.Fatalf("errs = %v", errs)
	}
}
