package httpapi

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
)

func newTestHandler() http.Handler {
	return NewHandler(Options{
		Logger:         slog.New(slog.NewTextHandler(io.Discard, nil)),
		AllowedOrigins: []string{"http://localhost:*", "https://eho.web.app"},
	})
}

func TestHealthz(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	var body map[string]string
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil || body["status"] != "ok" {
		t.Fatalf("body = %v, err = %v", body, err)
	}
}

func TestNotFoundUsesErrorFormat(t *testing.T) {
	rec := httptest.NewRecorder()
	newTestHandler().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/nope", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d", rec.Code)
	}
	var e APIError
	if err := json.NewDecoder(rec.Body).Decode(&e); err != nil || e.Code != "not_found" {
		t.Fatalf("body = %+v, err = %v", e, err)
	}
}

func TestCORS(t *testing.T) {
	tests := []struct {
		origin string
		want   bool
	}{
		{"http://localhost:5000", true},
		{"https://eho.web.app", true},
		{"http://localhost.evil.com:80", false},
		{"https://evil.com", false},
	}
	for _, tt := range tests {
		req := httptest.NewRequest(http.MethodOptions, "/healthz", nil)
		req.Header.Set("Origin", tt.origin)
		req.Header.Set("Access-Control-Request-Method", "GET")
		rec := httptest.NewRecorder()
		newTestHandler().ServeHTTP(rec, req)
		got := rec.Header().Get("Access-Control-Allow-Origin") == tt.origin
		if got != tt.want {
			t.Errorf("origin %q allowed = %v, want %v", tt.origin, got, tt.want)
		}
		if rec.Code != http.StatusNoContent {
			t.Errorf("preflight status = %d", rec.Code)
		}
	}
}

func TestRecover(t *testing.T) {
	h := withRecover(slog.New(slog.NewTextHandler(io.Discard, nil)), http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic("boom")
	}))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/", nil))
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d", rec.Code)
	}
}
