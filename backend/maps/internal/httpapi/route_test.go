package httpapi

import "testing"

// routedEvent publishes: a — b — c walkway, a stand at c, a QR marker at a.
func (a *testAPI) routedEvent() (eventID, floorID, standID, markerID string) {
	a.t.Helper()
	eventID = a.createEvent()
	floorID = a.createFloor(eventID)
	base := "/v1/events/" + eventID
	a.must(200, a.do("PUT", base+"/floors/"+floorID+"/graph", org, map[string]any{
		"nodes": []map[string]any{{"id": "a", "x": 100, "y": 300}, {"id": "b", "x": 500, "y": 300}, {"id": "c", "x": 500, "y": 100}},
		"edges": []map[string]any{{"from": "a", "to": "b"}, {"from": "b", "to": "c"}},
	}))
	standID = a.must(201, a.do("POST", base+"/features", org, map[string]any{
		"type": "stand", "floorId": floorID, "name": "Čačak Dev", "entranceNodeId": "c",
		"geometry": map[string]any{"kind": "point", "coords": []map[string]any{{"x": 500, "y": 80}}},
	})).Body["id"].(string)
	markerID = a.must(201, a.do("POST", base+"/features", org, map[string]any{
		"type": "marker", "floorId": floorID, "name": "Ulaz", "entranceNodeId": "a",
		"geometry": map[string]any{"kind": "point", "coords": []map[string]any{{"x": 90, "y": 300}}},
	})).Body["id"].(string)
	return
}

func TestRoute(t *testing.T) {
	a := newAPI(t)
	ev, floor, stand, marker := a.routedEvent()
	path := "/v1/events/" + ev + "/route"
	body := map[string]any{"from": map[string]any{"featureId": marker}, "to": map[string]any{"featureId": stand}}

	// Not published yet: invisible, like getEvent.
	if r := a.do("POST", path, "anon:visitor", body); r.Code != 404 {
		t.Fatalf("unpublished: %d %s", r.Code, r.Raw)
	}
	a.must(200, a.do("POST", "/v1/events/"+ev+"/publish", org, nil))

	r := a.must(200, a.do("POST", path, "anon:visitor", body))
	if r.Body["publishedVersion"].(float64) != 1 || r.Body["distanceEstimated"] != true {
		t.Errorf("body = %s", r.Raw)
	}
	legs := r.Body["legs"].([]any)
	pts := legs[0].(map[string]any)["points"].([]any)
	if len(legs) != 1 || len(pts) != 3 {
		t.Fatalf("legs = %v", legs)
	}
	// 400 + 200 px at 0.05 m/px.
	if d := r.Body["distanceMeters"].(float64); d < 29.99 || d > 30.01 {
		t.Errorf("distanceMeters = %v, want 30", d)
	}

	// A point on the floor works as a start too.
	a.must(200, a.do("POST", path, "anon:visitor", map[string]any{
		"from": map[string]any{"floorId": floor, "point": map[string]any{"x": 300, "y": 320}},
		"to":   map[string]any{"featureId": stand},
	}))

	cases := []struct {
		name string
		body any
		code int
		err  string
	}{
		{"both forms", map[string]any{"from": map[string]any{"featureId": marker, "floorId": floor}, "to": map[string]any{"featureId": stand}}, 422, "validation_failed"},
		{"neither", map[string]any{"from": map[string]any{}, "to": map[string]any{"featureId": stand}}, 422, "validation_failed"},
		{"unknown feature", map[string]any{"from": map[string]any{"featureId": "nope"}, "to": map[string]any{"featureId": stand}}, 422, "validation_failed"},
		{"unknown field", `{"from":{"featureId":"x"},"to":{"featureId":"y"},"speed":3}`, 400, "invalid_json"},
	}
	for _, tc := range cases {
		if r := a.do("POST", path, "anon:visitor", tc.body); r.Code != tc.code || errorCode(r) != tc.err {
			t.Errorf("%s: %d %s", tc.name, r.Code, r.Raw)
		}
	}
	if r := a.do("POST", path, "", body); r.Code != 401 {
		t.Errorf("no token: %d", r.Code)
	}
}

func TestRouteFollowsANewPublish(t *testing.T) {
	a := newAPI(t)
	ev, floor, stand, marker := a.routedEvent()
	base := "/v1/events/" + ev
	a.must(200, a.do("POST", base+"/publish", org, nil))
	body := map[string]any{"from": map[string]any{"featureId": marker}, "to": map[string]any{"featureId": stand}}
	a.must(200, a.do("POST", base+"/route", "anon:v", body)) // fills the cache

	// Cut the walkway and republish: the cached graph must not be used.
	a.must(200, a.do("PUT", base+"/floors/"+floor+"/graph", org, map[string]any{
		"nodes": []map[string]any{{"id": "a", "x": 100, "y": 300}, {"id": "b", "x": 500, "y": 300}, {"id": "c", "x": 500, "y": 100}},
		"edges": []map[string]any{{"from": "a", "to": "b"}},
	}))
	a.must(200, a.do("POST", base+"/publish", org, nil))
	if r := a.do("POST", base+"/route", "anon:v", body); r.Code != 422 || errorCode(r) != "no_route" {
		t.Fatalf("after republish: %d %s", r.Code, r.Raw)
	}
}
