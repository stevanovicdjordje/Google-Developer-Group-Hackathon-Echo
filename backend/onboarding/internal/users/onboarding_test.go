package users

import (
	"reflect"
	"testing"
)

func TestParseInterests(t *testing.T) {
	cases := []struct {
		name     string
		selected []string
		custom   string
		wantAll  []string
		wantCust []string
		wantErr  string
	}{
		{"three offered", []string{"ai", "web", "data"}, "", []string{"ai", "web", "data"}, nil, ""},
		{"offered plus custom", []string{"ai", "web"}, " Go  jezik , Rust", []string{"ai", "web", "go jezik", "rust"}, []string{"go jezik", "rust"}, ""},
		{"dedupe case-insensitive", []string{"ai", "ai"}, "Rust, rust, RUST", nil, nil, "err.interests_count"},
		{"unknown codes ignored", []string{"ai", "nope", "web"}, "", nil, nil, "err.interests_count"},
		{"too many", []string{"ai", "web", "data", "cloud", "hr", "finance"}, "", nil, nil, "err.interests_count"},
		{"too long custom", []string{"ai", "web"}, "ovo je jedna jako duga tema koja prelazi četrdeset karaktera", nil, nil, "err.interest_len"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			all, cust, err := ParseInterests(c.selected, c.custom)
			if c.wantErr != "" {
				if err == nil || err.Error() != c.wantErr {
					t.Fatalf("err = %v, want %s", err, c.wantErr)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(all, c.wantAll) || !reflect.DeepEqual(cust, c.wantCust) {
				t.Fatalf("got %v / %v, want %v / %v", all, cust, c.wantAll, c.wantCust)
			}
		})
	}
}

func TestGoalAndLanguageValidation(t *testing.T) {
	if !GoalHiring.Valid() || Goal("x").Valid() {
		t.Fatal("goal validation")
	}
	if !ValidLanguage("sr") || ValidLanguage("xx") {
		t.Fatal("language validation")
	}
}
