// Command api runs the events HTTP API server.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
	_ "time/tzdata" // Europe/Belgrade in the distroless image

	firebase "firebase.google.com/go/v4"

	"github.com/Ilij4n/eho/backend/events/internal/auth"
	"github.com/Ilij4n/eho/backend/events/internal/config"
	"github.com/Ilij4n/eho/backend/events/internal/extract"
	"github.com/Ilij4n/eho/backend/events/internal/httpapi"
	"github.com/Ilij4n/eho/backend/events/internal/store"
)

func main() {
	if err := run(); err != nil {
		slog.Error("fatal", "err", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}
	log := newLogger(cfg.LogLevel)
	slog.SetDefault(log)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// Application Default Credentials in production; the emulator env vars
	// (FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST) locally.
	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: cfg.ProjectID})
	if err != nil {
		return fmt.Errorf("init firebase: %w", err)
	}
	authClient, err := app.Auth(ctx)
	if err != nil {
		return fmt.Errorf("init auth: %w", err)
	}
	fs, err := app.Firestore(ctx)
	if err != nil {
		return fmt.Errorf("init firestore: %w", err)
	}
	defer fs.Close()

	ex := &extract.Extractor{Log: log}
	if cfg.GeminiAPIKey != "" {
		ex.Model = &extract.Gemini{APIKey: cfg.GeminiAPIKey, ModelName: cfg.Model, Thinking: cfg.Thinking, Timeout: cfg.ExtractTimeout}
	} else {
		log.Warn("GEMINI_API_KEY is not set: drafts only from spreadsheets/CSV (no AI)")
	}

	srv := &http.Server{
		Addr: ":" + cfg.Port,
		Handler: httpapi.NewHandler(httpapi.Options{
			Logger:         log,
			AllowedOrigins: cfg.AllowedOrigins,
			Store:          store.NewFirestoreStore(fs),
			Verifier:       auth.FirebaseVerifier{Client: authClient},
			Extractor:      ex,
		}),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       120 * time.Second, // uploads up to 20 MiB from phones
		WriteTimeout:      cfg.ExtractTimeout + 30*time.Second,
		IdleTimeout:       120 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		log.Info("listening", "addr", srv.Addr, "project", cfg.ProjectID, "model", ex.ModelName(),
			"firestoreEmulator", os.Getenv("FIRESTORE_EMULATOR_HOST"),
			"authEmulator", os.Getenv("FIREBASE_AUTH_EMULATOR_HOST"))
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
		close(errCh)
	}()

	select {
	case err := <-errCh:
		return fmt.Errorf("listen: %w", err)
	case <-ctx.Done():
	}

	log.Info("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("shutdown: %w", err)
	}
	return nil
}

func newLogger(level string) *slog.Logger {
	var lvl slog.Level
	if err := lvl.UnmarshalText([]byte(level)); err != nil {
		lvl = slog.LevelInfo
	}
	// JSON logs are parsed by Cloud Logging; "level" maps to severity via ReplaceAttr.
	return slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: lvl,
		ReplaceAttr: func(_ []string, a slog.Attr) slog.Attr {
			switch a.Key {
			case slog.LevelKey:
				a.Key = "severity"
			case slog.MessageKey:
				a.Key = "message"
			}
			return a
		},
	}))
}
