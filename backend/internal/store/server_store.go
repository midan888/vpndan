package store

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"vpn-god/backend/internal/models"
)

type PostgresServerStore struct {
	db *gorm.DB
}

func NewPostgresServerStore(db *gorm.DB) *PostgresServerStore {
	return &PostgresServerStore{db: db}
}

func (s *PostgresServerStore) ListActiveServers(ctx context.Context) ([]models.Server, error) {
	var servers []models.Server
	if err := s.db.WithContext(ctx).Where("is_active = ?", true).Order("country, name").Find(&servers).Error; err != nil {
		return nil, err
	}
	return servers, nil
}

func (s *PostgresServerStore) GetServerByID(ctx context.Context, id uuid.UUID) (*models.Server, error) {
	var srv models.Server
	if err := s.db.WithContext(ctx).First(&srv, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrServerNotFound
		}
		return nil, err
	}
	return &srv, nil
}
