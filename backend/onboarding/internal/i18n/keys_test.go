package i18n_test

import (
	"fmt"
	"io/fs"
	"regexp"
	"strings"
	"testing"

	webassets "github.com/Ilij4n/eho/backend/onboarding"
	"github.com/Ilij4n/eho/backend/onboarding/internal/events"
	"github.com/Ilij4n/eho/backend/onboarding/internal/i18n"
	"github.com/Ilij4n/eho/backend/onboarding/internal/invitations"
	"github.com/Ilij4n/eho/backend/onboarding/internal/users"
)

// Every literal key used in templates, and every dynamic key built from the
// language/topic/goal lists, must exist in the Serbian catalog.
func TestTemplateKeysExist(t *testing.T) {
	b := i18n.New("sr")
	re := regexp.MustCompile(`\bt "([a-z0-9_.]+)"`)
	err := fs.WalkDir(webassets.FS, "templates", func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(p, ".html") {
			return err
		}
		body, _ := fs.ReadFile(webassets.FS, p)
		for _, m := range re.FindAllStringSubmatch(string(body), -1) {
			if !b.Has(m[1]) {
				t.Errorf("%s: missing i18n key %q", p, m[1])
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	var dynamic []string
	for _, l := range users.Languages {
		dynamic = append(dynamic, "lang."+l)
	}
	for _, x := range users.Topics {
		dynamic = append(dynamic, "topic."+x)
	}
	for _, g := range users.Goals {
		dynamic = append(dynamic, "goal."+string(g))
	}
	for _, code := range []string{"403", "404", "409", "500"} {
		dynamic = append(dynamic, "error."+code)
	}
	for _, st := range events.Statuses {
		dynamic = append(dynamic, "status."+string(st), "group."+string(st))
	}
	for _, k := range []string{"room", "stand", "poi"} {
		dynamic = append(dynamic, "feature."+k)
	}
	for _, st := range invitations.Statuses {
		dynamic = append(dynamic, "inv.status."+string(st))
	}
	for i := 0; i < 7; i++ {
		dynamic = append(dynamic, fmt.Sprintf("weekday.%d", i))
	}
	for _, f := range []string{"saved", "published", "invited", "accepted", "declined", "review", "profile", "deleted"} {
		dynamic = append(dynamic, "flash."+f)
	}
	for _, k := range dynamic {
		if !b.Has(k) {
			t.Errorf("missing i18n key %q", k)
		}
	}
}
