package config

import "testing"

func TestLoadDefaults(t *testing.T) {
	t.Setenv("FIREBASE_PROJECT_ID", "demo-eho")
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if cfg.Port != "8080" {
		t.Errorf("Port = %q, want 8080", cfg.Port)
	}
	if cfg.StorageBucket != "demo-eho.appspot.com" {
		t.Errorf("StorageBucket = %q", cfg.StorageBucket)
	}
	if len(cfg.AllowedOrigins) != 2 {
		t.Errorf("AllowedOrigins = %v", cfg.AllowedOrigins)
	}
}

func TestLoadRequiresProject(t *testing.T) {
	t.Setenv("FIREBASE_PROJECT_ID", "")
	t.Setenv("GOOGLE_CLOUD_PROJECT", "")
	if _, err := Load(); err == nil {
		t.Fatal("expected error without project ID")
	}
}
