package models

import (
	"time"

	"github.com/google/uuid"
)

type Server struct {
	ID        uuid.UUID `json:"id" db:"id"`
	Name      string    `json:"name" db:"name"`
	Country   string    `json:"country" db:"country"`
	Host      string    `json:"host" db:"host"`
	Port      int       `json:"-" db:"port"`
	PublicKey string    `json:"-" db:"public_key"`
	IsActive  bool      `json:"is_active" db:"is_active"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

type ServerResponse struct {
	ID       uuid.UUID `json:"id" doc:"Server UUID"`
	Name     string    `json:"name" doc:"Server display name"`
	Country  string    `json:"country" doc:"ISO 3166-1 alpha-2 country code"`
	Host     string    `json:"host" doc:"Server IP or hostname"`
	IsActive bool      `json:"is_active" doc:"Whether the server is currently available"`
}
