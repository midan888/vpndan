package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
	"vpn-god/backend/internal/api"
	"vpn-god/backend/internal/auth"
	"vpn-god/backend/internal/config"
	"vpn-god/backend/internal/store"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("failed to load config: %v", err)
	}

	db, err := sqlx.Connect("postgres", cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer db.Close()

	if err := runMigrations(db); err != nil {
		log.Fatalf("failed to run migrations: %v", err)
	}

	userStore := store.NewPostgresUserStore(db)
	serverStore := store.NewPostgresServerStore(db)
	jwtService := auth.NewJWTService(cfg.JWTSecret)

	router := api.NewRouter(userStore, serverStore, jwtService)

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      router,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("server starting on :%s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("shutting down server...")
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("server forced to shutdown: %v", err)
	}
	log.Println("server stopped")
}

func runMigrations(db *sqlx.DB) error {
	migrations := []string{
		`CREATE EXTENSION IF NOT EXISTS "uuid-ossp"`,
		`CREATE TABLE IF NOT EXISTS users (
			id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
			email      VARCHAR(255) UNIQUE NOT NULL,
			password   TEXT NOT NULL,
			created_at TIMESTAMPTZ NOT NULL DEFAULT now()
		)`,
		`CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)`,
		`CREATE TABLE IF NOT EXISTS servers (
			id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
			name       VARCHAR(100) NOT NULL,
			country    VARCHAR(2) NOT NULL,
			host       VARCHAR(255) NOT NULL,
			port       INT NOT NULL DEFAULT 51820,
			public_key TEXT NOT NULL,
			is_active  BOOLEAN NOT NULL DEFAULT true,
			created_at TIMESTAMPTZ NOT NULL DEFAULT now()
		)`,
	}

	for _, m := range migrations {
		if _, err := db.Exec(m); err != nil {
			return err
		}
	}

	return nil
}
