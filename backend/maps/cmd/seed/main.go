// Command seed creates a published demo event through the API, against the
// local Firebase emulators. Run `make dev` first, then `make seed`.
//
// It signs up a demo organizer in the Auth emulator, uploads a generated
// floor plan to the Storage emulator and creates ~3 rooms, 15 stands, POIs,
// a walkway graph and 3 "you are here" QR markers via the HTTP API.
package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

const demoEventName = "DevFest Belgrade 2026"

// oldDemoEventName is the demo event's earlier name; a re-seed removes it too.
const oldDemoEventName = "Eho Demo Expo"

type client struct {
	api, authHost, storageHost, bucket, webURL string
	token                                      string
	http                                       *http.Client
}

func main() {
	c := &client{http: &http.Client{Timeout: 20 * time.Second}}
	flag.StringVar(&c.api, "api", "http://localhost:8080", "map API base URL")
	flag.StringVar(&c.authHost, "auth", envOr("FIREBASE_AUTH_EMULATOR_HOST", "127.0.0.1:9099"), "Auth emulator host:port")
	flag.StringVar(&c.storageHost, "storage", strings.TrimPrefix(envOr("STORAGE_EMULATOR_HOST", "127.0.0.1:9199"), "http://"), "Storage emulator host:port")
	flag.StringVar(&c.bucket, "bucket", "demo-eho.appspot.com", "Storage bucket")
	flag.StringVar(&c.webURL, "web", "http://localhost:5000", "web app base URL for printed links")
	email := flag.String("email", "organizer@eho.test", "demo organizer email (emulator only)")
	password := flag.String("password", "eho-demo-123", "demo organizer password (emulator only)")
	flag.Parse()

	if err := c.run(*email, *password); err != nil {
		fmt.Fprintln(os.Stderr, "seed:", err)
		os.Exit(1)
	}
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func (c *client) run(email, password string) error {
	if err := c.signIn(email, password); err != nil {
		return fmt.Errorf("sign in organizer: %w", err)
	}

	// Replace a previous demo event so repeated runs stay tidy.
	var list struct {
		Events []struct{ ID, Name string } `json:"events"`
	}
	if err := c.call("GET", "/v1/events", nil, &list); err != nil {
		return err
	}
	for _, e := range list.Events {
		if e.Name == demoEventName || e.Name == oldDemoEventName {
			if err := c.call("DELETE", "/v1/events/"+e.ID, nil, nil); err != nil {
				return err
			}
		}
	}

	var ev struct{ ID string }
	if err := c.call("POST", "/v1/events", map[string]any{
		"name": demoEventName, "startDate": time.Now().Format(time.DateOnly), "endDate": time.Now().AddDate(0, 0, 1).Format(time.DateOnly),
		"address": "Demo hala, Beograd",
	}, &ev); err != nil {
		return err
	}
	base := "/v1/events/" + ev.ID

	imagePath := "events/" + ev.ID + "/floors/ground.png"
	if err := c.upload(imagePath, drawPlan()); err != nil {
		return fmt.Errorf("upload plan: %w", err)
	}
	var floor struct{ ID string }
	if err := c.call("POST", base+"/floors", map[string]any{"name": "Prizemlje", "order": 0, "imagePath": imagePath}, &floor); err != nil {
		return err
	}
	fbase := base + "/floors/" + floor.ID

	if err := c.call("PUT", fbase+"/graph", graph(), nil); err != nil {
		return err
	}
	if err := c.call("PUT", fbase+"/georef", georef(), nil); err != nil {
		return err
	}

	var markers []string
	for _, f := range features(floor.ID) {
		var out struct{ ID, Type, Name string }
		if err := c.call("POST", base+"/features", f, &out); err != nil {
			return fmt.Errorf("feature %v: %w", f["name"], err)
		}
		if out.Type == "marker" {
			markers = append(markers, fmt.Sprintf("  %-22s %s/e/%s?at=%s", out.Name, c.webURL, ev.ID, out.ID))
		}
	}

	var pub struct {
		PublishedVersion int              `json:"publishedVersion"`
		Warnings         []map[string]any `json:"warnings"`
	}
	if err := c.call("POST", base+"/publish", nil, &pub); err != nil {
		return err
	}

	fmt.Printf("Demo event published (version %d, %d warnings)\n", pub.PublishedVersion, len(pub.Warnings))
	fmt.Printf("  eventId:   %s\n  organizer: %s / %s (emulator only)\n  attendee:  %s/e/%s\nQR markers:\n%s\n",
		ev.ID, email, password, c.webURL, ev.ID, strings.Join(markers, "\n"))
	// Pretend GPS for phones that aren't at this fictional venue (app: --dart-define=DEMO_LOCATION=...).
	fmt.Printf("Demo GPS (app --dart-define=DEMO_LOCATION=...):\n  at the entrance:          %s\n  walk entrance → Glavna sala: %s\n",
		demoLocation(nodes["m40"]), demoLocation(nodes["m40"], nodes["m880"], nodes["r200"]))
	return nil
}

// signIn signs up the organizer in the Auth emulator, or signs in if it exists.
func (c *client) signIn(email, password string) error {
	body := map[string]any{"email": email, "password": password, "returnSecureToken": true}
	for _, op := range []string{"signUp", "signInWithPassword"} {
		u := fmt.Sprintf("http://%s/identitytoolkit.googleapis.com/v1/accounts:%s?key=demo-api-key", c.authHost, op)
		var out struct {
			IDToken string `json:"idToken"`
		}
		err := c.do("POST", u, "", body, &out)
		if err == nil {
			c.token = out.IDToken
			return nil
		}
		if op == "signUp" && strings.Contains(err.Error(), "EMAIL_EXISTS") {
			continue
		}
		return err
	}
	return errors.New("unreachable")
}

// upload stores a PNG through the Storage emulator's Firebase REST API, as the
// organizer, so storage.rules are exercised.
func (c *client) upload(path string, data []byte) error {
	u := fmt.Sprintf("http://%s/v0/b/%s/o?uploadType=media&name=%s", c.storageHost, c.bucket, url.QueryEscape(path))
	req, err := http.NewRequest("POST", u, bytes.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "image/png")
	req.Header.Set("Authorization", "Firebase "+c.token)
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		b, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("status %d: %s", resp.StatusCode, b)
	}
	return nil
}

func (c *client) call(method, path string, body, out any) error {
	return c.do(method, c.api+path, "Bearer "+c.token, body, out)
}

func (c *client) do(method, u, authz string, body, out any) error {
	var r io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return err
		}
		r = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, u, r)
	if err != nil {
		return err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if authz != "" {
		req.Header.Set("Authorization", authz)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("%s %s: %w", method, u, err)
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 300 {
		return fmt.Errorf("%s %s: status %d: %s", method, u, resp.StatusCode, b)
	}
	if out != nil && len(b) > 0 {
		return json.Unmarshal(b, out)
	}
	return nil
}

// ---- demo venue (1200×800 px, 0.05 m/px ≈ 60×40 m) ----

const planW, planH = 1200, 800

type pt struct{ x, y float64 }

var nodes = map[string]pt{
	"m40": {40, 400}, "m320": {320, 400}, "m880": {880, 400}, "m1160": {1160, 400},
	"m390": {390, 400}, "m470": {470, 400}, "m550": {550, 400}, "m630": {630, 400}, "m710": {710, 400}, "m790": {790, 400},
	"l200": {320, 200}, "l620": {320, 620}, "r200": {880, 200}, "r620": {880, 620},
	"b470": {470, 620}, "b630": {630, 620}, "b790": {790, 620},
}

var edges = [][2]string{
	{"m40", "m320"}, {"m320", "m390"}, {"m390", "m470"}, {"m470", "m550"}, {"m550", "m630"}, {"m630", "m710"},
	{"m710", "m790"}, {"m790", "m880"}, {"m880", "m1160"},
	{"l200", "m320"}, {"m320", "l620"}, {"r200", "m880"}, {"m880", "r620"},
	{"l620", "b470"}, {"b470", "b630"}, {"b630", "b790"}, {"b790", "r620"},
}

func graph() map[string]any {
	var ns, es []map[string]any
	for id, p := range nodes {
		ns = append(ns, map[string]any{"id": id, "x": p.x, "y": p.y})
	}
	for _, e := range edges {
		es = append(es, map[string]any{"from": e[0], "to": e[1]})
	}
	return map[string]any{"nodes": ns, "edges": es}
}

// georef places the plan at a fictional spot in Belgrade, north-up, 0.05 m/px.
func georef() map[string]any {
	cp := func(x, y float64) map[string]any {
		lat, lng := latLngAt(x, y)
		return map[string]any{"px": map[string]any{"x": x, "y": y}, "latLng": map[string]any{"lat": lat, "lng": lng}}
	}
	return map[string]any{"controlPoints": []any{cp(0, 0), cp(planW, 0), cp(0, planH)}}
}

// latLngAt is where plan pixel (x, y) lies under georef.
func latLngAt(x, y float64) (lat, lng float64) {
	const lat0, lng0, mpp = 44.8000, 20.4000, 0.05
	return lat0 - y*mpp/111320.0, lng0 + x*mpp/(111320.0*0.7096) // cos(44.8°)
}

// demoLocation renders plan points as a DEMO_LOCATION value for the app
// (mobile#14): one point stands still, several are walked along.
func demoLocation(pts ...pt) string {
	parts := make([]string, len(pts))
	for i, p := range pts {
		lat, lng := latLngAt(p.x, p.y)
		parts[i] = fmt.Sprintf("%.6f,%.6f", lat, lng)
	}
	return strings.Join(parts, ";")
}

func rect(x0, y0, x1, y1 float64) map[string]any {
	return map[string]any{"kind": "rect", "coords": []any{map[string]any{"x": x0, "y": y0}, map[string]any{"x": x1, "y": y1}}}
}

func point(x, y float64) map[string]any {
	return map[string]any{"kind": "point", "coords": []any{map[string]any{"x": x, "y": y}}}
}

var hallC = []pt{{920, 40}, {1160, 40}, {1160, 360}, {1040, 360}, {920, 300}}

func features(floorID string) []map[string]any {
	f := func(m map[string]any) map[string]any { m["floorId"] = floorID; return m }
	poly := []any{}
	for _, p := range hallC {
		poly = append(poly, map[string]any{"x": p.x, "y": p.y})
	}
	out := []map[string]any{
		f(map[string]any{"type": "room", "name": "Sala A", "description": "Predavanja: AI i ML", "capacity": 150, "geometry": rect(40, 40, 280, 360), "entranceNodeId": "l200"}),
		f(map[string]any{"type": "room", "name": "Sala B", "description": "Radionice", "capacity": 60, "geometry": rect(40, 440, 280, 760), "entranceNodeId": "l620"}),
		f(map[string]any{"type": "room", "name": "Glavna sala", "description": "Keynote i panel", "capacity": 400, "geometry": map[string]any{"kind": "polygon", "coords": poly}, "entranceNodeId": "r200"}),
		f(map[string]any{"type": "poi", "name": "Ulaz", "poiKind": "entrance", "geometry": point(40, 400), "entranceNodeId": "m40"}),
		f(map[string]any{"type": "poi", "name": "Toalet", "poiKind": "toilet", "geometry": point(1120, 440), "entranceNodeId": "m1160"}),
		f(map[string]any{"type": "poi", "name": "Info pult", "poiKind": "info", "geometry": point(630, 560), "entranceNodeId": "b630"}),
		f(map[string]any{"type": "poi", "name": "Hrana i piće", "poiKind": "food", "geometry": point(1040, 620), "entranceNodeId": "r620"}),
		f(map[string]any{"type": "marker", "name": "Ulaz (QR)", "geometry": point(70, 380), "entranceNodeId": "m40"}),
		f(map[string]any{"type": "marker", "name": "Centralni hodnik (QR)", "geometry": point(630, 390), "entranceNodeId": "m630"}),
		f(map[string]any{"type": "marker", "name": "Kod hrane (QR)", "geometry": point(900, 640), "entranceNodeId": "r620"}),
	}
	type stand struct {
		name, company, category, tier string
	}
	stands := []stand{
		{"Neuro Lab", "Primer AI d.o.o.", "AI", "gold"}, {"Oblak 9", "Primer Cloud", "Cloud", "silver"},
		{"Mobilni kutak", "Primer Mobile", "Mobile", ""}, {"Štit", "Primer Security", "Bezbednost", "bronze"},
		{"Startap ulica", "Primer Inkubator", "Startup", ""}, {"Data most", "Primer Data", "AI", "silver"},
		{"Čačak Dev", "Primer Čačak", "Mobile", ""}, {"Robo ruka", "Primer Robotika", "Robotika", "gold"},
		{"Zeleni kod", "Primer Green", "Startup", ""}, {"Kvant", "Primer Quantum", "Istraživanje", "bronze"},
		{"Igraonica", "Primer Games", "Igre", ""}, {"Fintek", "Primer Pay", "Fintech", "silver"},
		{"Učionica", "Primer Edu", "Obrazovanje", ""}, {"Zdravlje+", "Primer Health", "Zdravstvo", ""},
		{"Otvoreni kod", "Primer OSS", "Open source", "bronze"},
	}
	i := 0
	add := func(x, y0, y1 float64, node string) {
		s := stands[i]
		i++
		m := map[string]any{"type": "stand", "name": s.name, "company": s.company, "category": s.category,
			"description": "Demo štand " + s.company, "geometry": rect(x-30, y0, x+30, y1), "entranceNodeId": node,
			"link": "https://example.com/" + strings.ToLower(strings.ReplaceAll(s.company, " ", "-"))}
		if s.tier != "" {
			m["sponsorTier"] = s.tier
		}
		out = append(out, f(m))
	}
	for _, x := range []float64{390, 470, 550, 630, 710, 790} {
		add(x, 330, 380, fmt.Sprintf("m%.0f", x))
		add(x, 420, 470, fmt.Sprintf("m%.0f", x))
	}
	for _, x := range []float64{470, 630, 790} {
		add(x, 640, 700, fmt.Sprintf("b%.0f", x))
	}
	return out
}

// drawPlan renders a simple floor plan PNG matching the features above.
func drawPlan() []byte {
	img := image.NewRGBA(image.Rect(0, 0, planW, planH))
	fill := func(x0, y0, x1, y1 int, c color.RGBA) {
		for y := y0; y < y1; y++ {
			for x := x0; x < x1; x++ {
				img.SetRGBA(x, y, c)
			}
		}
	}
	box := func(x0, y0, x1, y1 int, bg, border color.RGBA) {
		fill(x0, y0, x1, y1, border)
		fill(x0+3, y0+3, x1-3, y1-3, bg)
	}
	white := color.RGBA{250, 250, 247, 255}
	corridor := color.RGBA{226, 226, 222, 255}
	wall := color.RGBA{70, 70, 80, 255}
	room := color.RGBA{214, 230, 245, 255}
	standC := color.RGBA{252, 228, 196, 255}

	fill(0, 0, planW, planH, white)
	box(10, 10, planW-10, planH-10, white, wall) // outer wall
	fill(20, 375, 1180, 425, corridor)          // main corridor
	fill(295, 180, 345, 640, corridor)          // left corridor
	fill(855, 180, 905, 640, corridor)          // right corridor
	fill(295, 595, 905, 645, corridor)          // bottom corridor
	box(40, 40, 280, 360, room, wall)           // Sala A
	box(40, 440, 280, 760, room, wall)          // Sala B

	// Glavna sala polygon (scanline fill + outline).
	for y := 40; y < 360; y++ {
		for x := 920; x < 1160; x++ {
			if inPoly(float64(x)+.5, float64(y)+.5, hallC) {
				img.SetRGBA(x, y, room)
			}
		}
	}
	for i := range hallC {
		a, b := hallC[i], hallC[(i+1)%len(hallC)]
		for t := 0.0; t <= 1; t += 0.001 {
			x, y := int(a.x+(b.x-a.x)*t), int(a.y+(b.y-a.y)*t)
			fill(x-1, y-1, x+2, y+2, wall)
		}
	}
	for _, x := range []int{390, 470, 550, 630, 710, 790} {
		box(x-30, 330, x+30, 380, standC, wall)
		box(x-30, 420, x+30, 470, standC, wall)
	}
	for _, x := range []int{470, 630, 790} {
		box(x-30, 640, x+30, 700, standC, wall)
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		panic(err)
	}
	return buf.Bytes()
}

func inPoly(x, y float64, poly []pt) bool {
	in := false
	for i, j := 0, len(poly)-1; i < len(poly); j, i = i, i+1 {
		a, b := poly[i], poly[j]
		if (a.y > y) != (b.y > y) && x < (b.x-a.x)*(y-a.y)/(b.y-a.y)+a.x {
			in = !in
		}
	}
	return in
}
