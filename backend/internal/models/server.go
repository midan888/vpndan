package models

import (
	"time"

	"github.com/google/uuid"
)

type Server struct {
	ID        uuid.UUID `json:"id" gorm:"type:uuid;primaryKey;default:uuid_generate_v4()"`
	Name      string    `json:"name" gorm:"type:varchar(100);not null"`
	Country   string    `json:"country" gorm:"type:varchar(2);not null"`
	Host      string    `json:"host" gorm:"type:varchar(255);not null"`
	Port      int       `json:"-" gorm:"type:int;not null;default:51820"`
	PublicKey string    `json:"-" gorm:"type:text;not null"`
	IsActive  bool      `json:"is_active" gorm:"not null;default:true"`
	CreatedAt time.Time `json:"created_at" gorm:"autoCreateTime"`
}

type ServerResponse struct {
	ID       uuid.UUID `json:"id" doc:"Server UUID"`
	Name     string    `json:"name" doc:"Server display name"`
	Country  string    `json:"country" doc:"ISO 3166-1 alpha-2 country code"`
	Host     string    `json:"host" doc:"Server IP or hostname"`
	IsActive bool      `json:"is_active" doc:"Whether the server is currently available"`
}
