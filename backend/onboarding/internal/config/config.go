// Package config reads runtime configuration from environment variables.
package config

import (
	"os"
	"strconv"
)

type Config struct {
	Port         string
	CookieSecure bool
	BaseURL      string
	MapsAPIKey   string
	// Timezone is used to display and enter event times (stored as UTC).
	Timezone string
	// Lang is the UI language: en (default, product-ui-language) or sr.
	Lang string

	// Firebase. The Admin SDKs honor FIRESTORE_EMULATOR_HOST,
	// FIREBASE_AUTH_EMULATOR_HOST and STORAGE_EMULATOR_HOST themselves.
	ProjectID     string
	APIKey        string // Web API key, used for email/password sign-in over REST
	StorageBucket string
	AuthEmulator  string // FIREBASE_AUTH_EMULATOR_HOST, also used for the REST sign-in

	// AppURL is the Flutter app (attendee app and organizer map editor).
	AppURL string
}

func Load() Config {
	c := Config{
		Port:          env("PORT", "8085"),
		CookieSecure:  envBool("EHO_COOKIE_SECURE", false),
		BaseURL:       env("EHO_BASE_URL", "http://localhost:8085"),
		Lang:          env("EHO_LANG", "en"),
		MapsAPIKey:    os.Getenv("GOOGLE_MAPS_API_KEY"),
		Timezone:      env("EHO_TIMEZONE", "Europe/Belgrade"),
		ProjectID:     env("FIREBASE_PROJECT_ID", "demo-eho"),
		APIKey:        os.Getenv("FIREBASE_API_KEY"),
		StorageBucket: os.Getenv("STORAGE_BUCKET"),
		AuthEmulator:  os.Getenv("FIREBASE_AUTH_EMULATOR_HOST"),
		AppURL:        env("EHO_APP_URL", "http://localhost:5050"),
	}
	if c.StorageBucket == "" {
		// Same default as backend/maps.
		c.StorageBucket = c.ProjectID + ".appspot.com"
	}
	if c.APIKey == "" && c.AuthEmulator != "" {
		// The Auth emulator accepts any key.
		c.APIKey = "emulator-key"
	}
	return c
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
