// Package config reads runtime configuration from environment variables.
package config

import (
	"os"
	"strconv"
)

type Config struct {
	Port         string
	DBPath       string
	UploadDir    string
	CookieSecure bool
	BaseURL      string
	MapsAPIKey   string
	// Timezone is used to display and enter event times (stored as UTC).
	Timezone string
}

func Load() Config {
	return Config{
		Port:         env("PORT", "8080"),
		DBPath:       env("EHO_DB_PATH", "./data/eho.db"),
		UploadDir:    env("EHO_UPLOAD_DIR", "./data/uploads"),
		CookieSecure: envBool("EHO_COOKIE_SECURE", false),
		BaseURL:      env("EHO_BASE_URL", "http://localhost:8080"),
		MapsAPIKey:   os.Getenv("GOOGLE_MAPS_API_KEY"),
		Timezone:     env("EHO_TIMEZONE", "Europe/Belgrade"),
	}
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func envBool(key string, def bool) bool {
	v, err := strconv.ParseBool(os.Getenv(key))
	if err != nil {
		return def
	}
	return v
}
