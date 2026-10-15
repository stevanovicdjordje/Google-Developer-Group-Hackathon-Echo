// Command api runs the Eho HTTP API server.
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

	"cloud.google.com/go/storage"
	firebase "firebase.google.com/go/v4"

	"github.com/Ilij4n/eho/backend/maps/internal/auth"
	"github.com/Ilij4n/eho/backend/maps/internal/config"
	"github.com/Ilij4n/eho/backend/maps/internal/httpapi"
	"github.com/Ilij4n/eho/backend/maps/internal/planimage"
	"github.com/Ilij4n/eho/backend/maps/internal/stats"
	"github.com/Ilij4n/eho/backend/maps/internal/store"
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
	// (FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST, STORAGE_EMULATOR_HOST) locally.
	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: cfg.ProjectID, StorageBucket: cfg.StorageBucket})
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
	gcs, err := storage.NewClient(ctx)
	if err != nil {
		return fmt.Errorf("init storage: %w", err)
	}
	defer gcs.Close()

	st := store.NewFirestoreStore(fs)
	// Attendee stats are buffered and written every 10 s, and once more on shutdown.
	agg := stats.NewAggregator(st, log)
	aggDone := make(chan struct{})
	aggCtx, stopAgg := context.WithCancel(context.Background())
	go func() {
		agg.Run(aggCtx, 10*time.Second, 5*time.Second)
		close(aggDone)
	}()
	defer func() {
		stopAgg()
		<-aggDone
	}()

	srv := &http.Server{
		Addr: ":" + cfg.Port,
		Handler: httpapi.NewHandler(httpapi.Options{
			Logger:         log,
			AllowedOrigins: cfg.AllowedOrigins,
			Store:          st,
			Verifier:       auth.FirebaseVerifier{Client: authClient},
			Images:         planimage.GCSInspector{Bucket: gcs.Bucket(cfg.StorageBucket)},
			Stats:          agg,
		}),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		log.Info("listening", "addr", srv.Addr, "project", cfg.ProjectID,
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
