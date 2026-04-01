package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
	"golang.org/x/crypto/bcrypt"
	"vpn-dan/backend/internal/api"
	"vpn-dan/backend/internal/auth"
	"vpn-dan/backend/internal/config"
	"vpn-dan/backend/internal/email"
	"vpn-dan/backend/internal/store"
	"vpn-dan/backend/internal/wireguard"
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

	if err := bootstrapAdmin(db, cfg); err != nil {
		log.Fatalf("failed to bootstrap admin: %v", err)
	}

	userStore := store.NewPostgresUserStore(db)
	serverStore := store.NewPostgresServerStore(db)
	peerStore := store.NewPostgresPeerStore(db)
	geoipStore := store.NewPostgresGeoIPStore(db)
	authCodeStore := store.NewPostgresAuthCodeStore(db)
	jwtService := auth.NewJWTService(cfg.JWTSecret)
	var emailSender email.Sender
	if cfg.ResendAPIKey != "" {
		emailSender = email.NewResendSender(cfg.ResendAPIKey, cfg.EmailFrom)
		log.Printf("email sending enabled via Resend")
	} else {
		log.Printf("WARNING: RESEND_API_KEY not set — email sending disabled, codes will be logged")
		emailSender = nil
	}
	var wgManager wireguard.PeerManager
	if cfg.WireGuardAdminURL != "" {
		log.Printf("using WireGuard admin API at %s", cfg.WireGuardAdminURL)
		wgManager = wireguard.NewHTTPPeerManager(cfg.WireGuardAdminURL)
	} else {
		log.Printf("using local WireGuard interface manager")
		wgManager = wireguard.NewLocalPeerManager("wg0")
	}

	router := api.NewRouter(userStore, serverStore, peerStore, geoipStore, authCodeStore, jwtService, emailSender, wgManager, cfg.CORSOrigin, cfg.NodeSecret)

	// Background: mark servers with no heartbeat for 90s as inactive
	go runStaleServerChecker(serverStore)

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
		`CREATE TABLE IF NOT EXISTS peers (
			id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
			user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
			private_key TEXT NOT NULL,
			public_key  TEXT NOT NULL,
			assigned_ip INET NOT NULL,
			created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
			UNIQUE(user_id)
		)`,
		`CREATE INDEX IF NOT EXISTS idx_peers_user_id ON peers(user_id)`,
		`CREATE INDEX IF NOT EXISTS idx_peers_server_id ON peers(server_id)`,
		`ALTER TABLE servers
			ADD COLUMN IF NOT EXISTS awg_jc   INT NOT NULL DEFAULT 4,
			ADD COLUMN IF NOT EXISTS awg_jmin INT NOT NULL DEFAULT 40,
			ADD COLUMN IF NOT EXISTS awg_jmax INT NOT NULL DEFAULT 70,
			ADD COLUMN IF NOT EXISTS awg_s1   INT NOT NULL DEFAULT 0,
			ADD COLUMN IF NOT EXISTS awg_s2   INT NOT NULL DEFAULT 0,
			ADD COLUMN IF NOT EXISTS awg_h1   BIGINT NOT NULL DEFAULT 1928394756,
			ADD COLUMN IF NOT EXISTS awg_h2   BIGINT NOT NULL DEFAULT 3847291056,
			ADD COLUMN IF NOT EXISTS awg_h3   BIGINT NOT NULL DEFAULT 2938475610,
			ADD COLUMN IF NOT EXISTS awg_h4   BIGINT NOT NULL DEFAULT 1029384756`,
		`ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false`,
		`ALTER TABLE servers ADD COLUMN IF NOT EXISTS last_heartbeat_at TIMESTAMPTZ`,
		`ALTER TABLE servers ADD COLUMN IF NOT EXISTS wg_admin_url TEXT NOT NULL DEFAULT ''`,
		`CREATE UNIQUE INDEX IF NOT EXISTS idx_servers_host ON servers(host)`,
		`CREATE TABLE IF NOT EXISTS country_ips (
			id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
			country    VARCHAR(2) NOT NULL,
			cidr       CIDR NOT NULL,
			created_at TIMESTAMPTZ NOT NULL DEFAULT now()
		)`,
		`CREATE INDEX IF NOT EXISTS idx_country_ips_country ON country_ips(country)`,
		`ALTER TABLE servers ADD COLUMN IF NOT EXISTS ping_port INT NOT NULL DEFAULT 8080`,
		// Passwordless auth: make password nullable, add auth_codes table
		`ALTER TABLE users ALTER COLUMN password DROP NOT NULL`,
		`ALTER TABLE users ALTER COLUMN password SET DEFAULT ''`,
		`CREATE TABLE IF NOT EXISTS auth_codes (
			id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
			email      VARCHAR(255) NOT NULL,
			code       VARCHAR(6) NOT NULL,
			expires_at TIMESTAMPTZ NOT NULL,
			used       BOOLEAN NOT NULL DEFAULT false,
			created_at TIMESTAMPTZ NOT NULL DEFAULT now()
		)`,
		`CREATE INDEX IF NOT EXISTS idx_auth_codes_email ON auth_codes(email)`,
		`CREATE INDEX IF NOT EXISTS idx_auth_codes_expires_at ON auth_codes(expires_at)`,
	}

	for _, m := range migrations {
		if _, err := db.Exec(m); err != nil {
			return err
		}
	}

	return nil
}

func runStaleServerChecker(servers *store.PostgresServerStore) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	for range ticker.C {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		n, err := servers.MarkStaleServersInactive(ctx, 90*time.Second)
		cancel()
		if err != nil {
			log.Printf("stale server check error: %v", err)
		} else if n > 0 {
			log.Printf("marked %d stale server(s) inactive", n)
		}
	}
}

func bootstrapAdmin(db *sqlx.DB, cfg *config.Config) error {
	if cfg.AdminEmail == "" || cfg.AdminPassword == "" {
		return nil
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(cfg.AdminPassword), bcrypt.DefaultCost)
	if err != nil {
		return fmt.Errorf("hash admin password: %w", err)
	}

	_, err = db.Exec(
		`INSERT INTO users (id, email, password, is_admin, created_at)
		 VALUES (uuid_generate_v4(), $1, $2, true, now())
		 ON CONFLICT (email) DO UPDATE SET is_admin = true, password = $2`,
		cfg.AdminEmail, string(hashed),
	)
	if err != nil {
		return fmt.Errorf("bootstrap admin user: %w", err)
	}

	log.Printf("admin user bootstrapped: %s", cfg.AdminEmail)
	return nil
}
