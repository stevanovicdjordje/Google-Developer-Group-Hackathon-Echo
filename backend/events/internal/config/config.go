// Package config loads runtime configuration from environment variables.
package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds all runtime settings of the events service.
type Config struct {
	// Port is the HTTP listen port (Cloud Run sets PORT).
	Port string
	// ProjectID is the Firebase / GCP project ID.
	ProjectID string
	// AllowedOrigins are the CORS origins allowed to call the API.
	// Entries may end with ":*" to allow any port (e.g. "http://localhost:*").
	AllowedOrigins []string
	// GeminiAPIKey enables AI extraction. Empty means spreadsheets/CSV only.
	GeminiAPIKey string
	// Model is the extraction model on the Gemini API
	// (docs/decisions/feature-events-ai.md).
	Model string
	// Thinking is the thinking level sent with Model; empty sends none.
	Thinking string
	// ExtractTimeout bounds one extraction, retries included.
	ExtractTimeout time.Duration
	// LogLevel is one of debug, info, warn, error.
	LogLevel string
	// ShutdownTimeout bounds graceful shutdown.
	ShutdownTimeout time.Duration
}

// Load reads the configuration from the environment and validates it.
func Load() (Config, error) {
	cfg := Config{
		Port:            getenv("PORT", "8084"),
		ProjectID:       getenv("FIREBASE_PROJECT_ID", getenv("GOOGLE_CLOUD_PROJECT", "")),
		AllowedOrigins:  splitList(getenv("ALLOWED_ORIGINS", "http://localhost:*,http://127.0.0.1:*")),
		GeminiAPIKey:    strings.TrimSpace(os.Getenv("GEMINI_API_KEY")),
		Model:           getenv("AI_MODEL", "gemini-3-flash-preview"),
		ExtractTimeout:  60 * time.Second,
		LogLevel:        getenv("LOG_LEVEL", "info"),
		ShutdownTimeout: 10 * time.Second,
	}
	if strings.HasPrefix(cfg.Model, "gemma") {
		cfg.Thinking = getenv("AI_THINKING", "minimal")
	} else {
		cfg.Thinking = getenv("AI_THINKING", "low")
	}
	if v := os.Getenv("EXTRACT_TIMEOUT_SECONDS"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n <= 0 {
			return Config{}, fmt.Errorf("EXTRACT_TIMEOUT_SECONDS: invalid value %q", v)
		}
		cfg.ExtractTimeout = time.Duration(n) * time.Second
	}
	if cfg.ProjectID == "" {
		return Config{}, fmt.Errorf("FIREBASE_PROJECT_ID (or GOOGLE_CLOUD_PROJECT) is required")
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
