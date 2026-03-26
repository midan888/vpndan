package config

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

type Config struct {
	DatabaseURL       string
	JWTSecret         string
	Port              string
	WireGuardAdminURL string
	AdminEmail        string
	AdminPassword     string
	CORSOrigin        string
	NodeSecret        string
}

func Load() (*Config, error) {
	LoadEnvFile(".env")

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		return nil, fmt.Errorf("JWT_SECRET is required")
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	return &Config{
		DatabaseURL:       dbURL,
		JWTSecret:         jwtSecret,
		Port:              port,
		WireGuardAdminURL: os.Getenv("WIREGUARD_ADMIN_URL"),
		AdminEmail:        os.Getenv("ADMIN_EMAIL"),
		AdminPassword:     os.Getenv("ADMIN_PASSWORD"),
		CORSOrigin:        os.Getenv("CORS_ORIGIN"),
		NodeSecret:        os.Getenv("NODE_SECRET"),
	}, nil
}

// LoadEnvFile reads a .env file and sets any variables not already in the environment.
func LoadEnvFile(path string) {
	f, err := os.Open(path)
	if err != nil {
		return // missing .env is fine, just use real env vars
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}

		key = strings.TrimSpace(key)
		value = strings.TrimSpace(value)
		value = strings.Trim(value, `"'`)

		// Don't override existing env vars
		if os.Getenv(key) == "" {
			os.Setenv(key, value)
		}
	}
}
