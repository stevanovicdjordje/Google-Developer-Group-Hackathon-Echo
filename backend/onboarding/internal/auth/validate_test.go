package auth

import "testing"

func TestValidEmail(t *testing.T) {
	ok := []string{"ana@primer.rs", "a.b+c@sub.example.com"}
	bad := []string{"", "ana", "ana@", "ana@primer", "Ana <ana@primer.rs>", "a b@primer.rs"}
	for _, e := range ok {
		if !ValidEmail(e) {
			t.Errorf("ValidEmail(%q) = false, want true", e)
		}
	}
	for _, e := range bad {
		if ValidEmail(e) {
			t.Errorf("ValidEmail(%q) = true, want false", e)
		}
	}
}

func TestNormalizeWebsite(t *testing.T) {
	cases := []struct {
		in, want string
		ok       bool
	}{
		{"", "", true},
		{"primer.rs", "https://primer.rs", true},
		{"http://primer.rs/x", "http://primer.rs/x", true},
		{"javascript:alert(1)", "", false},
		{"ftp://primer.rs", "", false},
		{"localhost", "", false},
	}
	for _, c := range cases {
		got, ok := normalizeWebsite(c.in)
		if got != c.want || ok != c.ok {
			t.Errorf("normalizeWebsite(%q) = %q,%v want %q,%v", c.in, got, ok, c.want, c.ok)
		}
	}
}

func TestCheckPassword(t *testing.T) {
	cases := []struct {
		pw, confirm, field, key string
	}{
		{"short", "short", "password", "err.password_short"},
		{string(make([]byte, 73)), "", "password", "err.password_long"},
		{"longenough", "different", "password_confirm", "err.password_mismatch"},
		{"longenough", "longenough", "", ""},
	}
	for _, c := range cases {
		f := FieldErrors{}
		checkPassword(f, c.pw, c.confirm)
		if c.field == "" {
			if !f.Empty() {
				t.Errorf("unexpected errors %v", f)
			}
			continue
		}
		if f[c.field] != c.key {
			t.Errorf("pw=%q: got %v, want %s=%s", c.pw, f, c.field, c.key)
		}
	}
}

func TestPasswordHash(t *testing.T) {
	h, err := HashPassword("tajna-lozinka")
	if err != nil {
		t.Fatal(err)
	}
	if !CheckPassword(h, "tajna-lozinka") || CheckPassword(h, "pogresna") {
		t.Fatal("bcrypt round-trip failed")
	}
}
