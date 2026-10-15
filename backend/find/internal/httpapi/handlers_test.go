package httpapi

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/Ilij4n/eho/backend/find/internal/auth"
	"github.com/Ilij4n/eho/backend/find/internal/match"
	"github.com/Ilij4n/eho/backend/find/internal/store"
)

type fakeVerifier struct{}

func (fakeVerifier) Verify(_ context.Context, tok string) (auth.Principal, error) {
	uid, ok := strings.CutPrefix(tok, "uid:")
	if !ok {
		return auth.Principal{}, auth.ErrInvalidToken
	}
	return auth.Principal{UID: uid, Anonymous: true}, nil
}

// fakeMatcher ranks offline but reports its own model and records what it was sent.
type fakeMatcher struct {
	mu    sync.Mutex
	seen  []match.Candidate
	calls int
}

func (f *fakeMatcher) Model() string { return "fake-gemma" }

func (f *fakeMatcher) record(c []match.Candidate) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.seen = append([]match.Candidate(nil), c...)
	f.calls++
}

func (f *fakeMatcher) Recommend(ctx context.Context, me match.Profile, c []match.Candidate, limit int) (match.Result, error) {
	f.record(c)
	r, err := match.Offline{}.Recommend(ctx, me, c, limit)
	r.Model = f.Model()
	return r, err
}

func (f *fakeMatcher) Search(ctx context.Context, prompt string, c []match.Candidate, limit int) (match.Result, error) {
	f.record(c)
	r, err := match.Offline{}.Search(ctx, prompt, c, limit)
	r.Model = f.Model()
	return r, err
}

type fixture struct {
	t  *testing.T
	h  http.Handler
	st *store.MemStore
	m  *fakeMatcher
}

const ev = "/v1/events/ev1"

func newFixture(t *testing.T) *fixture {
	t.Helper()
	st := store.NewMemStore()
	st.PutEvent("ev1", store.Event{Name: "DevFest", PublishedVersion: 1})
	st.PutEvent("draft", store.Event{Name: "Draft"})
	st.PutFeatures("ev1", "Info pult", "Glavna sala")
	m := &fakeMatcher{}
	h := NewHandler(Options{
		Logger:   slog.New(slog.NewTextHandler(io.Discard, nil)),
		Store:    st,
		Verifier: fakeVerifier{},
		Matcher:  m,
		Now:      func() time.Time { return time.Date(2026, 10, 11, 9, 0, 0, 0, time.UTC) },
	})
	return &fixture{t: t, h: h, st: st, m: m}
}

type resp struct {
	code int
	body map[string]any
	raw  string
	hdr  http.Header
}

func (f *fixture) do(uid, method, path string, body any) resp {
	f.t.Helper()
	var r io.Reader
	switch b := body.(type) {
	case nil:
	case string:
		r = strings.NewReader(b)
	default:
		buf, _ := json.Marshal(b)
		r = strings.NewReader(string(buf))
	}
	req := httptest.NewRequest(method, path, r)
	if uid != "" {
		req.Header.Set("Authorization", "Bearer uid:"+uid)
	}
	rec := httptest.NewRecorder()
	f.h.ServeHTTP(rec, req)
	out := resp{code: rec.Code, raw: rec.Body.String(), hdr: rec.Header()}
	_ = json.Unmarshal(rec.Body.Bytes(), &out.body)
	return out
}

func (f *fixture) want(r resp, code int) resp {
	f.t.Helper()
	if r.code != code {
		f.t.Fatalf("status %d, want %d: %s", r.code, code, r.raw)
	}
	return r
}

func (f *fixture) wantErr(r resp, code int, errCode string) {
	f.t.Helper()
	f.want(r, code)
	if r.body["code"] != errCode {
		f.t.Fatalf("code %v, want %s: %s", r.body["code"], errCode, r.raw)
	}
}

func profile(name, headline string, interests []string, lookingFor string) map[string]any {
	return map[string]any{
		"name": name, "headline": headline, "interests": interests, "lookingFor": lookingFor,
		"visibleInFind": true, "allowContact": true, "shareMeetingSpot": true,
	}
}

// person creates a profile, joins ev1 and returns the person ID.
func (f *fixture) person(uid string, p map[string]any) string {
	f.t.Helper()
	f.want(f.do(uid, "PUT", "/v1/me/profile", p), 200)
	f.want(f.do(uid, "PUT", ev+"/people/me", nil), 204)
	prof, err := f.st.GetProfile(context.Background(), uid)
	if err != nil {
		f.t.Fatal(err)
	}
	return prof.PersonID
}

func (f *fixture) setup() (ana, teo, vuk string) {
	f.person("me", profile("Ana Petrović", "Android dev at Fintio", []string{"Mobile", "AI / ML"}, "People who shipped on-device ML"))
	teo = f.person("teo", profile("Teodora Nikolić", "ML researcher", []string{"AI / ML", "Data"}, "Industry partners for speech models"))
	vuk = f.person("vuk", profile("Vuk Tomić", "CTO, Mreža", []string{"Startups", "Backend", "Hiring"}, "Mobile engineers to hire"))
	p, _ := f.st.GetProfile(context.Background(), "me")
	return p.PersonID, teo, vuk
}

func names(r resp) []string {
	var out []string
	ms, _ := r.body["matches"].([]any)
	for _, m := range ms {
		out = append(out, m.(map[string]any)["person"].(map[string]any)["name"].(string))
	}
	return out
}

func TestHealthz(t *testing.T) {
	f := newFixture(t)
	r := f.want(f.do("", "GET", "/healthz", nil), 200)
	if r.body["status"] != "ok" || r.body["model"] != "fake-gemma" {
		t.Fatal(r.raw)
	}
}

func TestAuthRequired(t *testing.T) {
	f := newFixture(t)
	for _, c := range [][2]string{
		{"GET", "/v1/me/profile"}, {"PUT", "/v1/me/profile"}, {"DELETE", "/v1/me/profile"},
		{"PUT", ev + "/people/me"}, {"DELETE", ev + "/people/me"},
		{"GET", ev + "/people/recommendations"}, {"POST", ev + "/people/search"},
		{"GET", ev + "/people/x"}, {"GET", ev + "/contacts"}, {"POST", ev + "/contacts"},
		{"POST", ev + "/contacts/x/accept"}, {"PUT", ev + "/contacts/x/meeting-spot"}, {"DELETE", ev + "/contacts/x/meeting-spot"},
	} {
		f.wantErr(f.do("", c[0], c[1], nil), 401, "unauthenticated")
	}
	req := httptest.NewRequest("GET", "/v1/me/profile", nil)
	req.Header.Set("Authorization", "Bearer garbage")
	rec := httptest.NewRecorder()
	f.h.ServeHTTP(rec, req)
	if rec.Code != 401 {
		t.Fatal(rec.Code)
	}
}

func TestUnpublishedEvent404(t *testing.T) {
	f := newFixture(t)
	f.want(f.do("me", "PUT", "/v1/me/profile", profile("Ana", "", []string{}, "")), 200)
	for _, e := range []string{"draft", "missing"} {
		f.wantErr(f.do("me", "PUT", "/v1/events/"+e+"/people/me", nil), 404, "not_found")
		f.wantErr(f.do("me", "GET", "/v1/events/"+e+"/people/recommendations", nil), 404, "not_found")
		f.wantErr(f.do("me", "GET", "/v1/events/"+e+"/contacts", nil), 404, "not_found")
	}
}

func TestProfileCRUDAndValidation(t *testing.T) {
	f := newFixture(t)
	f.wantErr(f.do("me", "GET", "/v1/me/profile", nil), 404, "not_found")

	p := profile("  Ana Petrović ", "Android dev at Fintio", []string{"Mobile", " AI / ML", "mobile", "MOBILE"}, "On-device ML")
	p["updatedAt"] = "2020-01-01T00:00:00Z" // the fixture carries it; ignored
	r := f.want(f.do("me", "PUT", "/v1/me/profile", p), 200)
	if r.body["name"] != "Ana Petrović" || r.body["updatedAt"] != "2026-10-11T09:00:00Z" {
		t.Fatal(r.raw)
	}
	if in := r.body["interests"].([]any); len(in) != 2 || in[1] != "AI / ML" {
		t.Fatalf("interests %v", in)
	}
	if _, ok := r.body["personId"]; ok {
		t.Fatal("personId leaked")
	}
	first, _ := f.st.GetProfile(context.Background(), "me")
	if len(first.PersonID) != 16 {
		t.Fatalf("person ID %q", first.PersonID)
	}

	p["visibleInFind"] = false
	f.want(f.do("me", "PUT", "/v1/me/profile", p), 200)
	r = f.want(f.do("me", "GET", "/v1/me/profile", nil), 200)
	if r.body["visibleInFind"] != false {
		t.Fatal(r.raw)
	}
	again, _ := f.st.GetProfile(context.Background(), "me")
	if again.PersonID != first.PersonID {
		t.Fatal("person ID changed on save")
	}

	f.wantErr(f.do("me", "PUT", "/v1/me/profile", "{nope"), 400, "invalid_json")
	r = f.do("me", "PUT", "/v1/me/profile", map[string]any{
		"name": " ", "headline": strings.Repeat("h", 101), "interests": []string{"", strings.Repeat("i", 31), "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k"},
		"lookingFor": strings.Repeat("l", 201), "visibleInFind": true,
	})
	f.wantErr(r, 422, "validation_failed")
	fields := map[string]bool{}
	for _, d := range r.body["details"].([]any) {
		fields[d.(map[string]any)["field"].(string)] = true
	}
	for _, want := range []string{"name", "headline", "interests[0]", "interests[1]", "interests", "lookingFor", "allowContact", "shareMeetingSpot"} {
		if !fields[want] {
			t.Errorf("missing field error %s in %v", want, fields)
		}
	}
	if fields["visibleInFind"] {
		t.Error("visibleInFind was given")
	}
}

func TestJoinNeedsProfileAndNotPresent(t *testing.T) {
	f := newFixture(t)
	f.wantErr(f.do("me", "PUT", ev+"/people/me", nil), 409, "profile_required")
	f.want(f.do("me", "PUT", "/v1/me/profile", profile("Ana", "", []string{}, "")), 200)
	f.wantErr(f.do("me", "GET", ev+"/people/recommendations", nil), 409, "not_present")
	f.wantErr(f.do("me", "POST", ev+"/people/search", map[string]any{"prompt": "mobile"}), 409, "not_present")
	f.wantErr(f.do("me", "GET", ev+"/contacts", nil), 409, "not_present")
	f.want(f.do("me", "PUT", ev+"/people/me", nil), 204)
	f.want(f.do("me", "PUT", ev+"/people/me", nil), 204) // idempotent
	f.want(f.do("me", "GET", ev+"/people/recommendations", nil), 200)
	f.want(f.do("me", "DELETE", ev+"/people/me", nil), 204)
	f.want(f.do("me", "DELETE", ev+"/people/me", nil), 204)
	f.wantErr(f.do("me", "GET", ev+"/people/recommendations", nil), 409, "not_present")
}

func TestHiddenPerson404(t *testing.T) {
	f := newFixture(t)
	_, teo, _ := f.setup()
	f.want(f.do("me", "GET", ev+"/people/"+teo, nil), 200)
	hidden := profile("Teodora Nikolić", "ML researcher", []string{"AI / ML"}, "x")
	hidden["visibleInFind"] = false
	f.want(f.do("teo", "PUT", "/v1/me/profile", hidden), 200)
	f.wantErr(f.do("me", "GET", ev+"/people/"+teo, nil), 404, "not_found")
	f.wantErr(f.do("me", "POST", ev+"/contacts", map[string]any{"personId": teo}), 404, "not_found")
	f.wantErr(f.do("me", "GET", ev+"/people/unknown", nil), 404, "not_found")
	// Present at another event only: not visible here.
	f.st.PutEvent("ev2", store.Event{PublishedVersion: 1})
	f.want(f.do("x", "PUT", "/v1/me/profile", profile("X", "", []string{}, "")), 200)
	f.want(f.do("x", "PUT", "/v1/events/ev2/people/me", nil), 204)
	px, _ := f.st.GetProfile(context.Background(), "x")
	f.wantErr(f.do("me", "GET", ev+"/people/"+px.PersonID, nil), 404, "not_found")
}

func TestGetPerson(t *testing.T) {
	f := newFixture(t)
	_, teo, _ := f.setup()
	r := f.want(f.do("me", "GET", ev+"/people/"+teo, nil), 200)
	if r.body["id"] != teo || r.body["name"] != "Teodora Nikolić" || r.body["allowContact"] != true || r.body["contactState"] != "none" {
		t.Fatal(r.raw)
	}
	for _, k := range []string{"visibleInFind", "uid", "shareMeetingSpot"} {
		if _, ok := r.body[k]; ok {
			t.Fatalf("%s leaked: %s", k, r.raw)
		}
	}
}

func TestRecommendationsExcludeCallerAndHidden(t *testing.T) {
	f := newFixture(t)
	f.setup()
	hidden := profile("Hidden Person", "Android dev", []string{"Mobile", "AI / ML"}, "on-device ML")
	hidden["visibleInFind"] = false
	f.person("hid", hidden)
	r := f.want(f.do("me", "GET", ev+"/people/recommendations", nil), 200)
	got := names(r)
	if len(got) != 2 || got[0] != "Teodora Nikolić" || got[1] != "Vuk Tomić" || r.body["model"] != "fake-gemma" {
		t.Fatalf("got %v: %s", got, r.raw)
	}
	for _, c := range f.m.seen {
		if c.Name == "Ana Petrović" || c.Name == "Hidden Person" {
			t.Fatalf("matcher saw %s", c.Name)
		}
	}
	m := r.body["matches"].([]any)[0].(map[string]any)
	if why := m["why"].(string); why == "" || len(why) > 240*4 {
		t.Fatalf("why %q", why)
	}
	r = f.want(f.do("me", "GET", ev+"/people/recommendations?limit=1", nil), 200)
	if len(names(r)) != 1 {
		t.Fatal(r.raw)
	}
	r = f.want(f.do("me", "GET", ev+"/people/recommendations?limit=99", nil), 200)
	if len(names(r)) != 2 {
		t.Fatal(r.raw)
	}
	// Nobody else visible: empty list.
	f2 := newFixture(t)
	f2.person("me", profile("Solo", "", []string{}, ""))
	r = f2.want(f2.do("me", "GET", ev+"/people/recommendations", nil), 200)
	if ms := r.body["matches"].([]any); len(ms) != 0 {
		t.Fatal(r.raw)
	}
}

func TestSearch(t *testing.T) {
	f := newFixture(t)
	f.setup()
	r := f.want(f.do("me", "POST", ev+"/people/search", map[string]any{"prompt": "someone hiring mobile engineers"}), 200)
	if got := names(r); len(got) != 1 || got[0] != "Vuk Tomić" {
		t.Fatalf("got %v: %s", got, r.raw)
	}
	r = f.want(f.do("me", "POST", ev+"/people/search", map[string]any{"prompt": "underwater basket weaving"}), 200)
	if len(names(r)) != 0 {
		t.Fatal(r.raw)
	}
	f.wantErr(f.do("me", "POST", ev+"/people/search", map[string]any{"prompt": " x "}), 422, "validation_failed")
	f.wantErr(f.do("me", "POST", ev+"/people/search", map[string]any{"prompt": strings.Repeat("x", 301)}), 422, "validation_failed")
	f.wantErr(f.do("me", "POST", ev+"/people/search", map[string]any{}), 422, "validation_failed")
	f.wantErr(f.do("me", "POST", ev+"/people/search", "["), 400, "invalid_json")
}

func TestContactFlow(t *testing.T) {
	f := newFixture(t)
	ana, teo, _ := f.setup()
	f.wantErr(f.do("me", "POST", ev+"/contacts", map[string]any{}), 422, "validation_failed")
	f.wantErr(f.do("me", "POST", ev+"/contacts", map[string]any{"personId": ana}), 422, "validation_failed")

	r := f.want(f.do("me", "POST", ev+"/contacts", map[string]any{"personId": teo}), 200)
	if r.body["state"] != "requested" || r.body["createdAt"] != "2026-10-11T09:00:00Z" || r.body["person"].(map[string]any)["id"] != teo {
		t.Fatal(r.raw)
	}
	if _, ok := r.body["meetingSpot"]; ok {
		t.Fatal(r.raw)
	}
	// Idempotent.
	f.want(f.do("me", "POST", ev+"/contacts", map[string]any{"personId": teo}), 200)
	if r := f.do("me", "GET", ev+"/people/"+teo, nil); r.body["contactState"] != "requested" {
		t.Fatal(r.raw)
	}
	// Teo sees it as incoming.
	if r := f.do("teo", "GET", ev+"/people/"+ana, nil); r.body["contactState"] != "incoming" {
		t.Fatal(r.raw)
	}
	r = f.want(f.do("teo", "GET", ev+"/contacts", nil), 200)
	cs := r.body["contacts"].([]any)
	if len(cs) != 1 || cs[0].(map[string]any)["state"] != "incoming" || cs[0].(map[string]any)["person"].(map[string]any)["name"] != "Ana Petrović" {
		t.Fatal(r.raw)
	}
	// The requester can't accept their own request.
	f.wantErr(f.do("me", "POST", ev+"/contacts/"+teo+"/accept", nil), 404, "not_found")
	r = f.want(f.do("teo", "POST", ev+"/contacts/"+ana+"/accept", nil), 200)
	if r.body["state"] != "accepted" {
		t.Fatal(r.raw)
	}
	f.want(f.do("teo", "POST", ev+"/contacts/"+ana+"/accept", nil), 200) // already accepted
	if r := f.do("me", "GET", ev+"/people/"+teo, nil); r.body["contactState"] != "accepted" {
		t.Fatal(r.raw)
	}
}

func TestIncomingRequestAcceptsViaRequest(t *testing.T) {
	f := newFixture(t)
	ana, teo, _ := f.setup()
	f.want(f.do("teo", "POST", ev+"/contacts", map[string]any{"personId": ana}), 200)
	r := f.want(f.do("me", "POST", ev+"/contacts", map[string]any{"personId": teo}), 200)
	if r.body["state"] != "accepted" {
		t.Fatal(r.raw)
	}
}

func TestAcceptWithoutRequest404(t *testing.T) {
	f := newFixture(t)
	_, _, vuk := f.setup()
	f.wantErr(f.do("me", "POST", ev+"/contacts/"+vuk+"/accept", nil), 404, "not_found")
}

func TestDemoAutoAccept(t *testing.T) {
	f := newFixture(t)
	f.setup()
	demo := f.person("demo-attendee-01", profile("Demo Person", "Designer", []string{"Design"}, "x"))
	f.st.SetDemo("demo-attendee-01", true)
	r := f.want(f.do("me", "POST", ev+"/contacts", map[string]any{"personId": demo}), 200)
	if r.body["state"] != "accepted" {
		t.Fatal(r.raw)
	}
}

func TestContactNotAllowed(t *testing.T) {
	f := newFixture(t)
	ana, teo, _ := f.setup()
	closed := profile("Teodora Nikolić", "ML researcher", []string{"AI / ML"}, "x")
	closed["allowContact"] = false
	f.want(f.do("teo", "PUT", "/v1/me/profile", closed), 200)
	if r := f.do("me", "GET", ev+"/people/"+teo, nil); r.body["allowContact"] != false {
		t.Fatal(r.raw)
	}
	f.wantErr(f.do("me", "POST", ev+"/contacts", map[string]any{"personId": teo}), 403, "contact_not_allowed")
	// Their own request to the caller can still be accepted.
	f.want(f.do("teo", "POST", ev+"/contacts", map[string]any{"personId": ana}), 200)
	r := f.want(f.do("me", "POST", ev+"/contacts", map[string]any{"personId": teo}), 200)
	if r.body["state"] != "accepted" {
		t.Fatal(r.raw)
	}
}

func TestMeetingSpotRules(t *testing.T) {
	f := newFixture(t)
	ana, teo, _ := f.setup()
	spot := ev + "/contacts/" + teo + "/meeting-spot"

	// No contact / not accepted yet.
	f.wantErr(f.do("me", "PUT", spot, map[string]any{"place": "Info pult"}), 403, "meeting_spot_not_allowed")
	f.want(f.do("me", "POST", ev+"/contacts", map[string]any{"personId": teo}), 200)
	f.wantErr(f.do("me", "PUT", spot, map[string]any{"place": "Info pult"}), 403, "meeting_spot_not_allowed")
	f.want(f.do("me", "DELETE", spot, nil), 200) // clearing nothing is fine
	f.want(f.do("teo", "POST", ev+"/contacts/"+ana+"/accept", nil), 200)

	// Validation and unknown place.
	f.wantErr(f.do("me", "PUT", spot, map[string]any{"place": " "}), 422, "validation_failed")
	f.wantErr(f.do("me", "PUT", spot, map[string]any{"place": strings.Repeat("p", 81)}), 422, "validation_failed")
	f.wantErr(f.do("me", "PUT", spot, map[string]any{"place": "Mars"}), 422, "validation_failed")

	// Case-insensitive match, stored in the map's spelling.
	r := f.want(f.do("me", "PUT", spot, map[string]any{"place": "  info PULT "}), 200)
	ms, _ := r.body["meetingSpot"].(map[string]any)
	if ms["place"] != "Info pult" || ms["setByMe"] != true || ms["updatedAt"] != "2026-10-11T09:00:00Z" || r.body["state"] != "accepted" {
		t.Fatal(r.raw)
	}
	r = f.want(f.do("teo", "GET", ev+"/contacts", nil), 200)
	ms = r.body["contacts"].([]any)[0].(map[string]any)["meetingSpot"].(map[string]any)
	if ms["place"] != "Info pult" || ms["setByMe"] != false {
		t.Fatal(r.raw)
	}

	// One side turns shareMeetingSpot off: hidden on both sides, new spots refused.
	off := profile("Teodora Nikolić", "ML researcher", []string{"AI / ML", "Data"}, "x")
	off["shareMeetingSpot"] = false
	f.want(f.do("teo", "PUT", "/v1/me/profile", off), 200)
	r = f.want(f.do("me", "GET", ev+"/contacts", nil), 200)
	if _, ok := r.body["contacts"].([]any)[0].(map[string]any)["meetingSpot"]; ok {
		t.Fatal(r.raw)
	}
	f.wantErr(f.do("me", "PUT", spot, map[string]any{"place": "Glavna sala"}), 403, "meeting_spot_not_allowed")
	off["shareMeetingSpot"] = true
	f.want(f.do("teo", "PUT", "/v1/me/profile", off), 200)

	r = f.want(f.do("teo", "PUT", ev+"/contacts/"+ana+"/meeting-spot", map[string]any{"place": "glavna sala"}), 200)
	if r.body["meetingSpot"].(map[string]any)["place"] != "Glavna sala" {
		t.Fatal(r.raw)
	}
	if _, ok := r.body["meetingSpot"].(map[string]any)["time"]; ok {
		t.Fatal("no time given, none expected: " + r.raw)
	}

	// Optional time of day.
	f.wantErr(f.do("me", "PUT", spot, map[string]any{"place": "Info pult", "time": "25:00"}), 422, "validation_failed")
	f.wantErr(f.do("me", "PUT", spot, map[string]any{"place": "Info pult", "time": "3pm"}), 422, "validation_failed")
	r = f.want(f.do("me", "PUT", spot, map[string]any{"place": "Info pult", "time": "15:20"}), 200)
	if r.body["meetingSpot"].(map[string]any)["time"] != "15:20" {
		t.Fatal(r.raw)
	}
	r = f.want(f.do("teo", "GET", ev+"/contacts", nil), 200)
	if r.body["contacts"].([]any)[0].(map[string]any)["meetingSpot"].(map[string]any)["time"] != "15:20" {
		t.Fatal(r.raw)
	}

	r = f.want(f.do("me", "DELETE", spot, nil), 200)
	if _, ok := r.body["meetingSpot"]; ok {
		t.Fatal(r.raw)
	}
}

func TestDeleteMeetingSpotNoContact(t *testing.T) {
	f := newFixture(t)
	_, _, vuk := f.setup()
	f.wantErr(f.do("me", "DELETE", ev+"/contacts/"+vuk+"/meeting-spot", nil), 404, "not_found")
}

func TestDeleteProfileCleansUp(t *testing.T) {
	f := newFixture(t)
	ana, teo, _ := f.setup()
	f.want(f.do("me", "POST", ev+"/contacts", map[string]any{"personId": teo}), 200)
	f.want(f.do("me", "DELETE", "/v1/me/profile", nil), 204)
	f.want(f.do("me", "DELETE", "/v1/me/profile", nil), 204)
	f.wantErr(f.do("me", "GET", "/v1/me/profile", nil), 404, "not_found")
	f.wantErr(f.do("teo", "GET", ev+"/people/"+ana, nil), 404, "not_found")
	if ok, _ := f.st.IsPresent(context.Background(), "ev1", "me"); ok {
		t.Fatal("still present")
	}
	if cs, _ := f.st.Contacts(context.Background(), "ev1", "teo"); len(cs) != 0 {
		t.Fatalf("contacts left: %v", cs)
	}
	r := f.want(f.do("teo", "GET", ev+"/contacts", nil), 200)
	if len(r.body["contacts"].([]any)) != 0 {
		t.Fatal(r.raw)
	}
}

func TestRateLimit(t *testing.T) {
	f := newFixture(t)
	f.setup()
	var last resp
	for i := 0; i < 25; i++ {
		last = f.do("me", "GET", ev+"/people/recommendations", nil)
		if last.code == 429 {
			if i != 20 {
				t.Fatalf("limited after %d requests", i)
			}
			break
		}
	}
	f.wantErr(last, 429, "rate_limited")
	if last.hdr.Get("Retry-After") == "" {
		t.Fatal("no Retry-After")
	}
	// Search shares the budget; other users don't.
	f.wantErr(f.do("me", "POST", ev+"/people/search", map[string]any{"prompt": "mobile"}), 429, "rate_limited")
	f.want(f.do("teo", "GET", ev+"/people/recommendations", nil), 200)
}

func TestCORS(t *testing.T) {
	st := store.NewMemStore()
	h := NewHandler(Options{Logger: slog.New(slog.NewTextHandler(io.Discard, nil)), Store: st, Verifier: fakeVerifier{}, Matcher: match.Offline{}, AllowedOrigins: []string{"http://localhost:*"}})
	req := httptest.NewRequest("OPTIONS", "/v1/me/profile", nil)
	req.Header.Set("Origin", "http://localhost:5173")
	req.Header.Set("Access-Control-Request-Method", "PUT")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != 204 || rec.Header().Get("Access-Control-Allow-Origin") != "http://localhost:5173" {
		t.Fatal(rec.Code, rec.Header())
	}
}
