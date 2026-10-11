// Package i18n holds UI texts. All user-facing strings live in a per-locale
// catalog so another language (e.g. English) can be added later by adding a
// catalog and a locale switch; templates only reference keys.
package i18n

import "fmt"

type Bundle struct {
	def      string
	catalogs map[string]map[string]string
}

// New returns a bundle with the built-in catalogs. def is the default locale.
func New(def string) *Bundle {
	return &Bundle{
		def:      def,
		catalogs: map[string]map[string]string{"sr": sr},
	}
}

// T returns the text for key in the default locale. Unknown keys are returned
// as-is so a missing translation is visible instead of blank.
func (b *Bundle) T(key string, args ...any) string {
	s, ok := b.catalogs[b.def][key]
	if !ok {
		return key
	}
	if len(args) > 0 {
		return fmt.Sprintf(s, args...)
	}
	return s
}

// Has reports whether key exists in the default locale.
func (b *Bundle) Has(key string) bool {
	_, ok := b.catalogs[b.def][key]
	return ok
}
