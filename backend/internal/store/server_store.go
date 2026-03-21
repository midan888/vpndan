package store

import (
	"context"
	"database/sql"
	"errors"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	"vpn-god/backend/internal/models"
)

type PostgresServerStore struct {
	db *sqlx.DB
}

func NewPostgresServerStore(db *sqlx.DB) *PostgresServerStore {
	return &PostgresServerStore{db: db}
}

func (s *PostgresServerStore) ListActiveServers(ctx context.Context) ([]models.Server, error) {
	var servers []models.Server
	err := s.db.SelectContext(ctx, &servers,
		`SELECT id, name, country, host, port, public_key, is_active, created_at,
		        awg_jc, awg_jmin, awg_jmax, awg_s1, awg_s2, awg_h1, awg_h2, awg_h3, awg_h4
		 FROM servers WHERE is_active = true ORDER BY country, name`,
	)
	if err != nil {
		return nil, err
	}
	return servers, nil
}

func (s *PostgresServerStore) GetServerByID(ctx context.Context, id uuid.UUID) (*models.Server, error) {
	var srv models.Server
	err := s.db.GetContext(ctx, &srv,
		`SELECT id, name, country, host, port, public_key, is_active, created_at,
		        awg_jc, awg_jmin, awg_jmax, awg_s1, awg_s2, awg_h1, awg_h2, awg_h3, awg_h4
		 FROM servers WHERE id = $1`, id,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrServerNotFound
		}
		return nil, err
	}
	return &srv, nil
}
