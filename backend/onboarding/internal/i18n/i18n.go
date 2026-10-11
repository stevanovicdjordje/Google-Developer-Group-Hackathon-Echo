// Package i18n holds UI texts. All user-facing strings live in a per-locale
// catalog (en, sr); templates only reference keys. The language comes from
// EHO_LANG (default English, per product-ui-language).
package i18n

import (
	"fmt"
	"strings"
)

var catalogs = map[string]map[string]string{"en": en, "sr": sr}

// Languages lists the supported UI languages.
var Languages = []string{"en", "sr"}

type Bundle struct {
	lang string
}

// New returns a bundle for lang; unknown languages fall back to English.
func New(lang string) *Bundle {
	if _, ok := catalogs[lang]; !ok {
		lang = "en"
	}
	return &Bundle{lang: lang}
}

func (b *Bundle) Lang() string { return b.lang }

// T returns the text for key. Missing keys fall back to the other catalog
// and finally to the key itself, so a gap is visible instead of blank.
func (b *Bundle) T(key string, args ...any) string {
	s, ok := catalogs[b.lang][key]
	if !ok {
		if s, ok = catalogs["en"][key]; !ok {
			return key
		}
	}
	if len(args) > 0 {
		return fmt.Sprintf(s, args...)
	}
	return s
}

// Has reports whether key exists in this bundle's language.
func (b *Bundle) Has(key string) bool {
	_, ok := catalogs[b.lang][key]
	return ok
}

// Rating formats an average like "4.3" (en) or "4,3" (sr).
func (b *Bundle) Rating(f float64) string {
	return strings.Replace(fmt.Sprintf("%.1f", f), ".", b.T("fmt.decimal"), 1)
}

// Money formats an amount in cents, e.g. "€2.99" (en) or "2,99 €" (sr).
func (b *Bundle) Money(cents int) string {
	n := fmt.Sprintf("%d%s%02d", cents/100, b.T("fmt.decimal"), cents%100)
	return b.T("fmt.price", n)
}

// Keys returns every key of a language (tests).
func Keys(lang string) []string {
	var out []string
	for k := range catalogs[lang] {
		out = append(out, k)
	}
	return out
}
