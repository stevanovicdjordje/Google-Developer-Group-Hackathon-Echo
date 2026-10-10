package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/Ilij4n/eho/backend/maps/internal/auth"
	"github.com/Ilij4n/eho/backend/maps/internal/planimage"
	"github.com/Ilij4n/eho/backend/maps/internal/store"
)

// fakeVerifier accepts tokens "user:<uid>" and "anon:<uid>".
type fakeVerifier struct{}

func (fakeVerifier) Verify(_ context.Context, tok string) (auth.Principal, error) {
	switch {
	case strings.HasPrefix(tok, "user:"):
		return auth.Principal{UID: tok[5:]}, nil
	case strings.HasPrefix(tok, "anon:"):
		return auth.Principal{UID: tok[5:], Anonymous: true}, nil
	}
	return auth.Principal{}, auth.ErrInvalidToken
}

// fakeImages knows image sizes by path suffix: "*.png" → 1000x600, "*.gif" unsupported.
type fakeImages struct{}

func (fakeImages) Dimensions(_ context.Context, path string) (int, int, error) {
	switch {
	case strings.HasSuffix(path, "missing.png"):
		return 0, 0, planimage.ErrNotFound
	case strings.HasSuffix(path, ".png"):
		return 1000, 600, nil
	}
	return 0, 0, planimage.ErrUnsupported
}

type testAPI struct {
	t     *testing.T
	h     http.Handler
	store *store.MemStore
}

func newAPI(t *testing.T) *testAPI {
	ms := store.NewMemStore()
	return &testAPI{t: t, store: ms, h: NewHandler(Options{
		Logger:   slog.New(slog.NewTextHandler(io.Discard, nil)),
		Store:    ms,
		Verifier: fakeVerifier{},
		Images:   fakeImages{},
	})}
}

type resp struct {
	Code   int
	Body   map[string]any
	Raw    string
	Header http.Header
}

func (a *testAPI) do(method, path, token string, body any) resp {
	a.t.Helper()
	var r io.Reader
	switch b := body.(type) {
	case nil:
	case string:
		r = strings.NewReader(b)
	default:
		buf, _ := json.Marshal(b)
		r = bytes.NewReader(buf)
	}
	req := httptest.NewRequest(method, path, r)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	a.h.ServeHTTP(rec, req)
	out := resp{Code: rec.Code, Raw: rec.Body.String(), Header: rec.Header()}
	_ = json.Unmarshal(rec.Body.Bytes(), &out.Body)
	return out
}

func (a *testAPI) must(want int, r resp) resp {
	a.t.Helper()
	if r.Code != want {
		a.t.Fatalf("status = %d, want %d; body = %s", r.Code, want, r.Raw)
	}
	return r
}

const org = "user:org1"

func (a *testAPI) createEvent() string {
	a.t.Helper()
	r := a.must(201, a.do("POST", "/v1/events", org, map[string]any{
		"name": "DevFest Beograd", "startDate": "2026-10-10", "endDate": "2026-10-11", "address": "Sava Centar",
	}))
	return r.Body["id"].(string)
}

func (a *testAPI) createFloor(eventID string) string {
	a.t.Helper()
	r := a.must(201, a.do("POST", "/v1/events/"+eventID+"/floors", org, map[string]any{
		"name": "Prizemlje", "order": 0, "imagePath": "events/" + eventID + "/floors/ground.png",
	}))
	return r.Body["id"].(string)
}

func errorCode(r resp) string { s, _ := r.Body["code"].(string); return s }

func TestAuthRequired(t *testing.T) {
	a := newAPI(t)
	if r := a.do("GET", "/v1/events", "", nil); r.Code != 401 || errorCode(r) != "unauthenticated" {
		t.Fatalf("got %d %s", r.Code, r.Raw)
	}
	if r := a.do("GET", "/v1/events", "garbage", nil); r.Code != 401 {
		t.Fatalf("got %d", r.Code)
	}
}

func TestEventCRUDAndOwnership(t *testing.T) {
	a := newAPI(t)
	a.must(403, a.do("POST", "/v1/events", "anon:visitor", map[string]any{"name": "x", "startDate": "2026-10-10", "endDate": "2026-10-10"}))
	r := a.must(422, a.do("POST", "/v1/events", org, map[string]any{"name": "", "startDate": "bad", "endDate": "2026-10-10"}))
	if errorCode(r) != "validation_failed" || len(r.Body["details"].([]any)) < 2 {
		t.Fatalf("details = %s", r.Raw)
	}
	a.must(400, a.do("POST", "/v1/events", org, `{"name":"x","bogus":1}`))

	id := a.createEvent()
	list := a.must(200, a.do("GET", "/v1/events", org, nil))
	if n := len(list.Body["events"].([]any)); n != 1 {
		t.Fatalf("list len = %d", n)
	}
	if n := len(a.must(200, a.do("GET", "/v1/events", "user:other", nil)).Body["events"].([]any)); n != 0 {
		t.Fatalf("other user sees %d events", n)
	}

	upd := a.must(200, a.do("PATCH", "/v1/events/"+id, org, map[string]any{"name": "DevFest 2026"}))
	if upd.Body["name"] != "DevFest 2026" || upd.Body["address"] != "Sava Centar" {
		t.Fatalf("patch did not merge: %s", upd.Raw)
	}
	a.must(403, a.do("PATCH", "/v1/events/"+id, "user:other", map[string]any{"name": "hijack"}))
	a.must(404, a.do("GET", "/v1/events/"+id, "anon:visitor", nil)) // unpublished
	a.must(404, a.do("GET", "/v1/events/nope", org, nil))

	a.must(204, a.do("DELETE", "/v1/events/"+id, org, nil))
	a.must(404, a.do("GET", "/v1/events/"+id, org, nil))
}

func TestFloorsAndGeoref(t *testing.T) {
	a := newAPI(t)
	id := a.createEvent()
	base := "/v1/events/" + id + "/floors"

	for _, path := range []string{"events/other/floors/a.png", "events/" + id + "/floors/sub/a.png", "events/" + id + "/floors/missing.png", "events/" + id + "/floors/a.gif"} {
		r := a.do("POST", base, org, map[string]any{"name": "P", "imagePath": path})
		if r.Code != 422 {
			t.Errorf("imagePath %q: status %d", path, r.Code)
		}
	}
	a.must(403, a.do("POST", base, "user:other", map[string]any{"name": "P", "imagePath": "events/" + id + "/floors/a.png"}))

	fid := a.createFloor(id)
	draft := a.must(200, a.do("GET", "/v1/events/"+id+"/draft", org, nil))
	floor := draft.Body["floors"].([]any)[0].(map[string]any)
	if floor["width"] != 1000.0 || floor["height"] != 600.0 {
		t.Fatalf("dimensions not read: %v", floor)
	}

	cps := []map[string]any{
		{"px": map[string]any{"x": 0, "y": 0}, "latLng": map[string]any{"lat": 44.8125, "lng": 20.4612}},
		{"px": map[string]any{"x": 1000, "y": 0}, "latLng": map[string]any{"lat": 44.8125, "lng": 20.4618}},
		{"px": map[string]any{"x": 0, "y": 600}, "latLng": map[string]any{"lat": 44.8122, "lng": 20.4612}},
	}
	g := a.must(200, a.do("PUT", base+"/"+fid+"/georef", org, map[string]any{"controlPoints": cps}))
	if q := g.Body["quality"].(map[string]any); q["metersPerPixel"].(float64) <= 0 {
		t.Fatalf("quality = %v", q)
	}
	a.must(422, a.do("PUT", base+"/"+fid+"/georef", org, map[string]any{"controlPoints": cps[:2]}))
	a.must(204, a.do("DELETE", base+"/"+fid+"/georef", org, nil))
	a.must(404, a.do("PUT", base+"/nope/georef", org, map[string]any{"controlPoints": cps}))

	a.must(200, a.do("PATCH", base+"/"+fid, org, map[string]any{"name": "Sprat 0", "order": 1}))
}

func TestFeaturesGraphAndPublish(t *testing.T) {
	a := newAPI(t)
	id := a.createEvent()
	ev := "/v1/events/" + id

	// Publishing an empty map is blocked.
	r := a.must(422, a.do("POST", ev+"/publish", org, nil))
	if errorCode(r) != "publish_blocked" {
		t.Fatalf("got %s", r.Raw)
	}

	fid := a.createFloor(id)
	a.must(422, a.do("PUT", ev+"/floors/"+fid+"/graph", org, map[string]any{
		"nodes": []any{map[string]any{"id": "a", "x": 1, "y": 1}}, "edges": []any{map[string]any{"from": "a", "to": "b"}},
	}))
	a.must(200, a.do("PUT", ev+"/floors/"+fid+"/graph", org, map[string]any{
		"nodes": []any{
			map[string]any{"id": "a", "x": 100, "y": 100},
			map[string]any{"id": "b", "x": 400, "y": 100},
			map[string]any{"id": "island", "x": 900, "y": 500},
		},
		"edges": []any{map[string]any{"from": "a", "to": "b"}},
	}))

	stand := func(name, node string) map[string]any {
		return map[string]any{
			"type": "stand", "floorId": fid, "name": name, "company": "Acme", "category": "AI", "sponsorTier": "gold",
			"geometry":       map[string]any{"kind": "rect", "coords": []any{map[string]any{"x": 380, "y": 120}, map[string]any{"x": 420, "y": 160}}},
			"entranceNodeId": node,
		}
	}
	a.must(422, a.do("POST", ev+"/features", org, stand("Ghost", "zzz")))
	bad := stand("Bad", "a")
	bad["geometry"] = map[string]any{"kind": "polygon", "coords": []any{map[string]any{"x": 0, "y": 0}}}
	a.must(422, a.do("POST", ev+"/features", org, bad))

	s1 := a.must(201, a.do("POST", ev+"/features", org, stand("Acme", "b"))).Body["id"].(string)
	a.must(201, a.do("POST", ev+"/features", org, stand("Island", "island")))
	room := map[string]any{
		"type": "room", "floorId": fid, "name": "Sala A", "capacity": 200, "entranceNodeId": "a",
		"geometry": map[string]any{"kind": "polygon", "coords": []any{
			map[string]any{"x": 10, "y": 10}, map[string]any{"x": 200, "y": 10}, map[string]any{"x": 200, "y": 90}, map[string]any{"x": 10, "y": 90},
		}},
	}
	a.must(201, a.do("POST", ev+"/features", org, room))

	upd := a.must(200, a.do("PATCH", ev+"/features/"+s1, org, map[string]any{"description": "Robots"}))
	if upd.Body["description"] != "Robots" || upd.Body["company"] != "Acme" {
		t.Fatalf("patch did not merge: %s", upd.Raw)
	}
	a.must(422, a.do("PATCH", ev+"/features/"+s1, org, map[string]any{"sponsorTier": "diamond"}))
	a.must(404, a.do("PATCH", ev+"/features/nope", org, map[string]any{"name": "x"}))

	pub := a.must(200, a.do("POST", ev+"/publish", org, nil))
	if pub.Body["publishedVersion"] != 1.0 {
		t.Fatalf("publish = %s", pub.Raw)
	}
	warns := pub.Body["warnings"].([]any)
	if len(warns) != 1 || warns[0].(map[string]any)["code"] != "unreachable" {
		t.Fatalf("warnings = %v", warns)
	}

	// Attendees see the published event, without the owner's uid.
	vis := a.must(200, a.do("GET", ev, "anon:visitor", nil))
	if _, has := vis.Body["ownerUid"]; has && vis.Body["ownerUid"] != "" {
		t.Fatalf("ownerUid leaked: %s", vis.Raw)
	}
	a.must(403, a.do("GET", ev+"/draft", "anon:visitor", nil))
	a.must(403, a.do("POST", ev+"/publish", "anon:visitor", nil))

	// Draft edits don't touch the published map until the next publish.
	a.must(204, a.do("DELETE", ev+"/features/"+s1, org, nil))
	a.must(404, a.do("DELETE", ev+"/features/"+s1, org, nil))
	m, v, err := a.store.GetPublished(context.Background(), id)
	if err != nil || v != 1 || len(m.Features) != 3 {
		t.Fatalf("published v=%d features=%d err=%v", v, len(m.Features), err)
	}
	a.must(200, a.do("POST", ev+"/publish", org, nil))
	m, v, _ = a.store.GetPublished(context.Background(), id)
	if v != 2 || len(m.Features) != 2 {
		t.Fatalf("after republish v=%d features=%d", v, len(m.Features))
	}

	// Deleting a floor removes its features and graph.
	a.must(204, a.do("DELETE", ev+"/floors/"+fid, org, nil))
	d := a.must(200, a.do("GET", ev+"/draft", org, nil))
	if len(d.Body["features"].([]any)) != 0 || len(d.Body["graphs"].([]any)) != 0 {
		t.Fatalf("cascade failed: %s", d.Raw)
	}
}

func TestBodyTooLarge(t *testing.T) {
	a := newAPI(t)
	big := `{"name":"` + strings.Repeat("x", maxBodyBytes+1) + `"}`
	a.must(413, a.do("POST", "/v1/events", org, big))
}
