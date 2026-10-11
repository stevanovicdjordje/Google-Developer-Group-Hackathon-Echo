package httpx

import (
	"bytes"
	"fmt"
	"html/template"
	"io/fs"
	"log"
	"net/http"
	"net/url"
	"path"
	"strings"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/i18n"
)

// View is the data passed to every page template.
type View struct {
	Title     string
	Principal *Principal
	CSRF      string
	Errors    map[string]string // field -> i18n key; "_form" for form-level errors
	Form      url.Values        // submitted values to re-populate forms
	Flash     string            // i18n key of a one-off notice
	BodyClass string
	Data      any
}

// Renderer renders server-side pages: one template set per page, each
// combined with templates/layout.html and templates/partials/*.html.
type Renderer struct {
	pages map[string]*template.Template
}

// Funcs returns the template helpers. loc is the display time zone.
func Funcs(bundle *i18n.Bundle, loc *time.Location) template.FuncMap {
	asTime := func(v any) (time.Time, bool) {
		switch t := v.(type) {
		case time.Time:
			return t, !t.IsZero()
		case *time.Time:
			if t == nil {
				return time.Time{}, false
			}
			return *t, !t.IsZero()
		}
		return time.Time{}, false
	}
	format := func(layout string) func(any) string {
		return func(v any) string {
			t, ok := asTime(v)
			if !ok {
				return "—"
			}
			return t.In(loc).Format(layout)
		}
	}
	return template.FuncMap{
		"t": bundle.T,
		"has": func(list []string, v string) bool {
			for _, s := range list {
				if s == v {
					return true
				}
			}
			return false
		},
		"add": func(a, b int) int { return a + b },
		"seq": func(from, to int) []int {
			var out []int
			for i := from; i <= to; i++ {
				out = append(out, i)
			}
			return out
		},
		"date":  format("02.01.2006. 15:04"),
		"day":   format("02.01.2006."),
		"clock": format("15:04"),
		"weekday": func(v any) string {
			t, ok := asTime(v)
			if !ok {
				return ""
			}
			return bundle.T(fmt.Sprintf("weekday.%d", t.In(loc).Weekday()))
		},
		"dtlocal": func(v any) string {
			t, ok := asTime(v)
			if !ok {
				return ""
			}
			return t.In(loc).Format("2006-01-02T15:04")
		},
		"rating": FormatRating,
		"pct":    func(f float64) string { return fmt.Sprintf("%.0f%%", f*100) },
		"num":    func(f float64) string { return fmt.Sprintf("%.2f", f) },
		"coord": func(p *float64) string {
			if p == nil {
				return ""
			}
			return fmt.Sprintf("%.6f", *p)
		},
		"join": strings.Join,
		"mul":  func(a, b float64) float64 { return a * b },
		"div": func(a, b float64) float64 {
			if b == 0 {
				return 0
			}
			return a / b
		},
		"float": func(i int) float64 { return float64(i) },
	}
}

// FormatRating renders an average like "4,3" (Serbian decimal comma).
func FormatRating(f float64) string {
	return strings.Replace(fmt.Sprintf("%.1f", f), ".", ",", 1)
}

// NewRenderer parses every page under templates/ together with the layout and partials.
func NewRenderer(fsys fs.FS, bundle *i18n.Bundle, loc *time.Location) (*Renderer, error) {
	funcs := Funcs(bundle, loc)
	base := template.New("layout").Funcs(funcs)
	layout, err := fs.ReadFile(fsys, "templates/layout.html")
	if err != nil {
		return nil, err
	}
	if _, err := base.Parse(string(layout)); err != nil {
		return nil, err
	}
	partials, _ := fs.Glob(fsys, "templates/partials/*.html")
	for _, p := range partials {
		body, err := fs.ReadFile(fsys, p)
		if err != nil {
			return nil, err
		}
		if _, err := base.Parse(string(body)); err != nil {
			return nil, fmt.Errorf("%s: %w", p, err)
		}
	}
	r := &Renderer{pages: map[string]*template.Template{}}
	err = fs.WalkDir(fsys, "templates", func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(p, ".html") ||
			path.Base(p) == "layout.html" || strings.HasPrefix(p, "templates/partials/") {
			return err
		}
		body, err := fs.ReadFile(fsys, p)
		if err != nil {
			return err
		}
		name := strings.TrimSuffix(strings.TrimPrefix(p, "templates/"), ".html")
		t, err := base.Clone()
		if err != nil {
			return err
		}
		if _, err := t.Parse(string(body)); err != nil {
			return fmt.Errorf("%s: %w", p, err)
		}
		r.pages[name] = t
		return nil
	})
	return r, err
}

// Page renders the named page (e.g. "auth/login") with the given status.
func (rd *Renderer) Page(w http.ResponseWriter, req *http.Request, status int, name string, v View) {
	t, ok := rd.pages[name]
	if !ok {
		log.Printf("render: unknown page %q", name)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	v.Principal = PrincipalFrom(req.Context())
	v.CSRF = CSRFToken(req.Context())
	if v.Errors == nil {
		v.Errors = map[string]string{}
	}
	if v.Form == nil {
		v.Form = url.Values{}
	}
	if v.Flash == "" {
		v.Flash = flashKey(req.URL.Query().Get("ok"))
	}
	var buf bytes.Buffer
	if err := t.ExecuteTemplate(&buf, "layout", v); err != nil {
		log.Printf("render %s: %v", name, err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(status)
	_, _ = buf.WriteTo(w)
}

// flashKey maps a short ?ok= code from a redirect to an i18n key. Only known
// codes are accepted so the query string cannot inject arbitrary text keys.
func flashKey(code string) string {
	switch code {
	case "saved", "published", "invited", "accepted", "declined", "review", "profile", "deleted":
		return "flash." + code
	}
	return ""
}

func (rd *Renderer) Error(w http.ResponseWriter, req *http.Request, status int, titleKey string) {
	rd.Page(w, req, status, "error", View{Title: titleKey, Data: status})
}
