package httpapi

import (
	"testing"
	"time"
)

func TestStats(t *testing.T) {
	a := newAPI(t)
	ev, _, stand, marker := a.routedEvent()
	post := "/v1/events/" + ev + "/stats/events"
	get := "/v1/events/" + ev + "/stats"
	batch := map[string]any{"events": []map[string]any{
		{"type": "qr_scan", "featureId": marker},
		{"type": "search", "query": "  Čačak ", "resultCount": 1},
		{"type": "search", "query": "kafa", "resultCount": 0},
		{"type": "search", "query": "k", "resultCount": 0}, // too short: dropped
		{"type": "feature_view", "featureId": stand},
		{"type": "route", "featureId": stand},
		{"type": "route", "featureId": "gone"},        // not on the map: dropped
		{"type": "feature_view", "featureId": marker}, // markers are scans, not views: dropped
	}}

	// Not published yet: invisible.
	if r := a.do("POST", post, "anon:visitor", batch); r.Code != 404 {
		t.Fatalf("unpublished: %d %s", r.Code, r.Raw)
	}
	a.must(200, a.do("POST", "/v1/events/"+ev+"/publish", org, nil))

	r := a.must(202, a.do("POST", post, "anon:visitor", batch))
	if r.Body["accepted"].(float64) != 5 || r.Body["dropped"].(float64) != 3 {
		t.Fatalf("record = %s", r.Raw)
	}
	a.must(202, a.do("POST", post, "anon:other", map[string]any{"events": []map[string]any{
		{"type": "search", "query": "KAFA", "resultCount": 0},
	}}))

	// Only the owner reads stats.
	if r := a.do("GET", get, "anon:visitor", nil); r.Code != 403 {
		t.Fatalf("attendee read: %d", r.Code)
	}
	r = a.must(200, a.do("GET", get, org, nil))
	totals := r.Body["totals"].(map[string]any)
	if totals["searches"].(float64) != 3 || totals["searchesNoResults"].(float64) != 2 || totals["featureViews"].(float64) != 1 ||
		totals["routes"].(float64) != 1 || totals["qrScans"].(float64) != 1 {
		t.Errorf("totals = %v", totals)
	}
	if days := r.Body["days"].([]any); len(days) != 30 || days[29].(map[string]any)["date"] != time.Now().UTC().Format(time.DateOnly) {
		t.Errorf("days = %v", days)
	}
	noRes := r.Body["topNoResults"].([]any)
	if len(noRes) != 1 || noRes[0].(map[string]any)["query"] != "kafa" || noRes[0].(map[string]any)["count"].(float64) != 2 {
		t.Errorf("topNoResults = %v", noRes)
	}
	if s := r.Body["topSearches"].([]any); len(s) != 2 || s[0].(map[string]any)["query"] != "kafa" || s[1].(map[string]any)["query"] != "čačak" {
		t.Errorf("topSearches = %v", s)
	}
	f := r.Body["topRouteTargets"].([]any)[0].(map[string]any)
	if f["featureId"] != stand || f["name"] != "Čačak Dev" || f["type"] != "stand" || f["count"].(float64) != 1 {
		t.Errorf("topRouteTargets = %v", f)
	}
	if q := r.Body["qrScans"].([]any); len(q) != 1 || q[0].(map[string]any)["name"] != "Ulaz" {
		t.Errorf("qrScans = %v", q)
	}

	// Explicit range without today: nothing.
	r = a.must(200, a.do("GET", get+"?from=2020-01-01&to=2020-01-03", org, nil))
	if len(r.Body["days"].([]any)) != 3 || r.Body["totals"].(map[string]any)["searches"].(float64) != 0 {
		t.Errorf("old range = %s", r.Raw)
	}
	for _, q := range []string{"?from=2020-01-05&to=2020-01-01", "?from=2020-13-01", "?from=2020-01-01&to=2021-06-01"} {
		if r := a.do("GET", get+q, org, nil); r.Code != 422 {
			t.Errorf("GET %s: %d", q, r.Code)
		}
	}
}

func TestStatsValidation(t *testing.T) {
	a := newAPI(t)
	ev, _, stand, _ := a.routedEvent()
	a.must(200, a.do("POST", "/v1/events/"+ev+"/publish", org, nil))
	post := "/v1/events/" + ev + "/stats/events"

	many := make([]map[string]any, 51)
	for i := range many {
		many[i] = map[string]any{"type": "feature_view", "featureId": stand}
	}
	cases := []struct {
		name string
		body any
		code int
	}{
		{"empty", map[string]any{"events": []any{}}, 422},
		{"too many", map[string]any{"events": many}, 422},
		{"unknown type", map[string]any{"events": []map[string]any{{"type": "gps", "featureId": stand}}}, 422},
		{"search without count", map[string]any{"events": []map[string]any{{"type": "search", "query": "kafa"}}}, 422},
		{"view with query", map[string]any{"events": []map[string]any{{"type": "feature_view", "featureId": stand, "query": "x"}}}, 422},
		{"position field", map[string]any{"events": []map[string]any{{"type": "route", "featureId": stand, "point": map[string]any{"x": 1, "y": 2}}}}, 400},
	}
	for _, c := range cases {
		if r := a.do("POST", post, "anon:v", c.body); r.Code != c.code {
			t.Errorf("%s: %d %s", c.name, r.Code, r.Raw)
		}
	}
	if r := a.do("POST", post, "", map[string]any{"events": []any{}}); r.Code != 401 {
		t.Errorf("no token: %d", r.Code)
	}
}

func TestStatsRateLimit(t *testing.T) {
	a := newAPI(t)
	ev, _, stand, _ := a.routedEvent()
	a.must(200, a.do("POST", "/v1/events/"+ev+"/publish", org, nil))
	post := "/v1/events/" + ev + "/stats/events"
	full := make([]map[string]any, maxStatsBatch)
	for i := range full {
		full[i] = map[string]any{"type": "feature_view", "featureId": stand}
	}
	body := map[string]any{"events": full}

	sent := 0
	for sent+maxStatsBatch <= statsBurst {
		a.must(202, a.do("POST", post, "anon:spammer", body))
		sent += maxStatsBatch
	}
	r := a.do("POST", post, "anon:spammer", body)
	if r.Code != 429 || r.Body["code"] != "rate_limited" {
		t.Fatalf("over limit: %d %s", r.Code, r.Raw)
	}
	if h := r.Header.Get("Retry-After"); h == "" || h == "0" {
		t.Errorf("Retry-After = %q", h)
	}
	// Other attendees are not affected.
	a.must(202, a.do("POST", post, "anon:someone", body))

	r = a.must(200, a.do("GET", "/v1/events/"+ev+"/stats", org, nil))
	if got := r.Body["totals"].(map[string]any)["featureViews"].(float64); got != float64(sent+maxStatsBatch) {
		t.Errorf("featureViews = %v, want %d", got, sent+maxStatsBatch)
	}
}
