// Package config loads runtime configuration from environment variables.
package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds all runtime settings of the API server.
type Config struct {
	// Port is the HTTP listen port (Cloud Run sets PORT).
	Port string
	// ProjectID is the Firebase / GCP project ID.
	ProjectID string
	// StorageBucket is the Cloud Storage bucket holding floor-plan images.
	StorageBucket string
	// AllowedOrigins are the CORS origins allowed to call the API.
	// Entries may end with ":*" to allow any port (e.g. "http://localhost:*").
	AllowedOrigins []string
	// LogLevel is one of debug, info, warn, error.
	LogLevel string
	// ShutdownTimeout bounds graceful shutdown.
	ShutdownTimeout time.Duration
}

// Load reads the configuration from the environment and validates it.
func Load() (Config, error) {
	cfg := Config{
		Port:            getenv("PORT", "8080"),
		ProjectID:       getenv("FIREBASE_PROJECT_ID", getenv("GOOGLE_CLOUD_PROJECT", "")),
		StorageBucket:   os.Getenv("STORAGE_BUCKET"),
		AllowedOrigins:  splitList(getenv("ALLOWED_ORIGINS", "http://localhost:*,http://127.0.0.1:*")),
		LogLevel:        getenv("LOG_LEVEL", "info"),
		ShutdownTimeout: 10 * time.Second,
	}
	if v := os.Getenv("SHUTDOWN_TIMEOUT_SECONDS"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n <= 0 {
			return Config{}, fmt.Errorf("SHUTDOWN_TIMEOUT_SECONDS: invalid value %q", v)
		}
		cfg.ShutdownTimeout = time.Duration(n) * time.Second
	}
	if cfg.ProjectID == "" {
		return Config{}, fmt.Errorf("FIREBASE_PROJECT_ID (or GOOGLE_CLOUD_PROJECT) is required")
	}
	if cfg.StorageBucket == "" {
		cfg.StorageBucket = cfg.ProjectID + ".appspot.com"
	}
	return cfg, nil
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func splitList(s string) []string {
	var out []string
	for _, p := range strings.Split(s, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}
