package models

import (
	"time"

	"github.com/google/uuid"
)

type User struct {
	ID        uuid.UUID `json:"id" gorm:"type:uuid;primaryKey;default:uuid_generate_v4()"`
	Email     string    `json:"email" gorm:"type:varchar(255);uniqueIndex"`
	Password  string    `json:"-" gorm:"type:text;not null"`
	CreatedAt time.Time `json:"created_at" gorm:"autoCreateTime"`
}

type RegisterRequest struct {
	Email    string `json:"email" doc:"User email address" format:"email" minLength:"1"`
	Password string `json:"password" doc:"User password" minLength:"8"`
}

type LoginRequest struct {
	Email    string `json:"email" doc:"User email address" minLength:"1"`
	Password string `json:"password" doc:"User password" minLength:"1"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" doc:"Refresh token" minLength:"1"`
}

type AuthResponse struct {
	AccessToken  string `json:"access_token" doc:"JWT access token (15 min TTL)"`
	RefreshToken string `json:"refresh_token" doc:"JWT refresh token (30 day TTL)"`
}
