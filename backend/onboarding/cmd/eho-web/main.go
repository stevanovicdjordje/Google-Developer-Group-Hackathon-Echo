// Command eho-web runs the Echo onboarding web app (server-rendered) against
// Firebase Auth, Firestore and Storage, or their local emulators.
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Ilij4n/eho/backend/onboarding/internal/app"
	"github.com/Ilij4n/eho/backend/onboarding/internal/config"
	"github.com/Ilij4n/eho/backend/onboarding/internal/fb"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	cfg := config.Load()
	if cfg.APIKey == "" {
		log.Fatal("FIREBASE_API_KEY is required outside the emulator (the project's Web API key)")
	}
	clients, err := fb.New(ctx, cfg)
	if err != nil {
		log.Fatalf("firebase: %v", err)
	}
	defer clients.Close()

	handler, err := app.New(cfg, app.FirebaseDeps(cfg, clients))
	if err != nil {
		log.Fatalf("app: %v", err)
	}
	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
	go func() {
		log.Printf("eho-web listening on :%s (project %s, firestore emulator %q, auth emulator %q)",
			cfg.Port, cfg.ProjectID, os.Getenv("FIRESTORE_EMULATOR_HOST"), cfg.AuthEmulator)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("listen: %v", err)
		}
	}()
	<-ctx.Done()
	shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdown)
}
