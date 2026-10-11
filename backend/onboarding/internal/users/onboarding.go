package users

import (
	"strings"
	"unicode/utf8"
)

// Language is a caption language offered during onboarding. The label is the
// i18n key "lang.<Code>".
var Languages = []string{"sr", "en", "de", "fr", "es", "it", "ru", "hu"}

// Topics are the offered interest topics; labels are "topic.<code>".
var Topics = []string{
	"ai", "web", "mobile", "cloud", "security", "data", "design",
	"product", "startup", "marketing", "hr", "finance", "sustainability", "health",
}

const (
	MinInterests    = 3
	MaxInterests    = 5
	MaxInterestLen  = 40
	maxCustomInputs = 20
)

func ValidLanguage(code string) bool { return contains(Languages, code) }

func contains(list []string, v string) bool {
	for _, s := range list {
		if s == v {
			return true
		}
	}
	return false
}

// InterestError is an i18n key describing why an interest selection is invalid.
type InterestError string

func (e InterestError) Error() string { return string(e) }

// ParseInterests merges offered topics (codes) with a comma-separated free-text
// field. It returns the combined list and the subset that was free text.
// Duplicates (case-insensitive) are dropped; 3-5 interests are required.
func ParseInterests(selected []string, customRaw string) (all, custom []string, err error) {
	seen := map[string]bool{}
	for _, s := range selected {
		if contains(Topics, s) && !seen[s] {
			seen[s] = true
			all = append(all, s)
		}
	}
	parts := strings.Split(customRaw, ",")
	if len(parts) > maxCustomInputs {
		parts = parts[:maxCustomInputs]
	}
	for _, p := range parts {
		p = strings.Join(strings.Fields(p), " ")
		if p == "" {
			continue
		}
		if utf8.RuneCountInString(p) > MaxInterestLen {
			return nil, nil, InterestError("err.interest_len")
		}
		key := strings.ToLower(p)
		if seen[key] {
			continue
		}
		seen[key] = true
		all = append(all, key)
		custom = append(custom, key)
	}
	if len(all) < MinInterests || len(all) > MaxInterests {
		return nil, nil, InterestError("err.interests_count")
	}
	return all, custom, nil
}
