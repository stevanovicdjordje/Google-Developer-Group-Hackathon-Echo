// Package config loads runtime configuration from environment variables.
package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds all runtime settings of the Find service.
type Config struct {
	// Port is the HTTP listen port (Cloud Run sets PORT).
	Port string
	// ProjectID is the Firebase / GCP project ID.
	ProjectID string
	// AllowedOrigins are the CORS origins allowed to call the API.
	// Entries may end with ":*" to allow any port (e.g. "http://localhost:*").
	AllowedOrigins []string
	// GeminiAPIKey enables the Gemma model through the Gemini API. Empty means
	// offline (overlap) ranking.
	GeminiAPIKey string
	// Model is the Gemma model name on the Gemini API.
	Model string
	// Thinking is the Gemma thinking level ("minimal" = off); empty sends none.
	Thinking string
	// AITimeout bounds one model call.
	AITimeout time.Duration
	// LogLevel is one of debug, info, warn, error.
	LogLevel string
	// ShutdownTimeout bounds graceful shutdown.
	ShutdownTimeout time.Duration
}

// Load reads the configuration from the environment and validates it.
func Load() (Config, error) {
	cfg := Config{
		Port:            getenv("PORT", "8083"),
		ProjectID:       getenv("FIREBASE_PROJECT_ID", getenv("GOOGLE_CLOUD_PROJECT", "")),
		AllowedOrigins:  splitList(getenv("ALLOWED_ORIGINS", "http://localhost:*,http://127.0.0.1:*")),
		GeminiAPIKey:    strings.TrimSpace(os.Getenv("GEMINI_API_KEY")),
		Model:           getenv("GEMMA_MODEL", "gemma-4-26b-a4b-it"),
		Thinking:        getenv("GEMMA_THINKING", "minimal"),
		AITimeout:       20 * time.Second,
		LogLevel:        getenv("LOG_LEVEL", "info"),
		ShutdownTimeout: 10 * time.Second,
	}
	if v := os.Getenv("AI_TIMEOUT_SECONDS"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n <= 0 {
			return Config{}, fmt.Errorf("AI_TIMEOUT_SECONDS: invalid value %q", v)
		}
		cfg.AITimeout = time.Duration(n) * time.Second
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
