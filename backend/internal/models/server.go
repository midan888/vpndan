package models

import (
	"time"

	"github.com/google/uuid"
)

type Server struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	Name            string     `json:"name" db:"name"`
	Country         string     `json:"country" db:"country"`
	Host            string     `json:"host" db:"host"`
	Port            int        `json:"-" db:"port"`
	PublicKey       string     `json:"-" db:"public_key"`
	IsActive        bool       `json:"is_active" db:"is_active"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	LastHeartbeatAt *time.Time `json:"-" db:"last_heartbeat_at"`
	WGAdminURL      string     `json:"-" db:"wg_admin_url"`
	// Amnezia WireGuard obfuscation parameters
	AWGJc   int   `json:"-" db:"awg_jc"`
	AWGJmin int   `json:"-" db:"awg_jmin"`
	AWGJmax int   `json:"-" db:"awg_jmax"`
	AWGS1   int   `json:"-" db:"awg_s1"`
	AWGS2   int   `json:"-" db:"awg_s2"`
	AWGH1   int64 `json:"-" db:"awg_h1"`
	AWGH2   int64 `json:"-" db:"awg_h2"`
	AWGH3   int64 `json:"-" db:"awg_h3"`
	AWGH4   int64 `json:"-" db:"awg_h4"`
}

type ServerResponse struct {
	ID       uuid.UUID `json:"id" doc:"Server UUID"`
	Name     string    `json:"name" doc:"Server display name"`
	Country  string    `json:"country" doc:"ISO 3166-1 alpha-2 country code"`
	Host     string    `json:"host" doc:"Server IP or hostname"`
	IsActive bool      `json:"is_active" doc:"Whether the server is currently available"`
}
