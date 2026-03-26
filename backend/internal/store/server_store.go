package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	"vpn-dan/backend/internal/models"
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
		        last_heartbeat_at, wg_admin_url,
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
		        last_heartbeat_at, wg_admin_url,
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

func (s *PostgresServerStore) ListAllServers(ctx context.Context) ([]models.Server, error) {
	var servers []models.Server
	err := s.db.SelectContext(ctx, &servers,
		`SELECT id, name, country, host, port, public_key, is_active, created_at,
		        last_heartbeat_at, wg_admin_url,
		        awg_jc, awg_jmin, awg_jmax, awg_s1, awg_s2, awg_h1, awg_h2, awg_h3, awg_h4
		 FROM servers ORDER BY country, name`,
	)
	if err != nil {
		return nil, err
	}
	return servers, nil
}

func (s *PostgresServerStore) CreateServer(ctx context.Context, srv *models.Server) (*models.Server, error) {
	srv.ID = uuid.New()
	srv.CreatedAt = time.Now()
	if !srv.IsActive {
		srv.IsActive = true
	}

	_, err := s.db.ExecContext(ctx,
		`INSERT INTO servers (id, name, country, host, port, public_key, is_active, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
		srv.ID, srv.Name, srv.Country, srv.Host, srv.Port, srv.PublicKey, srv.IsActive, srv.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return srv, nil
}

func (s *PostgresServerStore) DeleteServer(ctx context.Context, id uuid.UUID) error {
	result, err := s.db.ExecContext(ctx, `DELETE FROM servers WHERE id = $1`, id)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrServerNotFound
	}
	return nil
}

func (s *PostgresServerStore) UpdateServerStatus(ctx context.Context, id uuid.UUID, isActive bool) error {
	result, err := s.db.ExecContext(ctx, `UPDATE servers SET is_active = $1 WHERE id = $2`, isActive, id)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrServerNotFound
	}
	return nil
}

func (s *PostgresServerStore) UpsertServerByHost(ctx context.Context, srv *models.Server) (*models.Server, error) {
	now := time.Now()
	srv.CreatedAt = now
	if srv.ID == uuid.Nil {
		srv.ID = uuid.New()
	}

	var result models.Server
	err := s.db.QueryRowxContext(ctx,
		`INSERT INTO servers (id, name, country, host, port, public_key, is_active, created_at,
		                      last_heartbeat_at, wg_admin_url,
		                      awg_jc, awg_jmin, awg_jmax, awg_s1, awg_s2,
		                      awg_h1, awg_h2, awg_h3, awg_h4)
		 VALUES ($1, $2, $3, $4, $5, $6, true, $7, $7, $8,
		         $9, $10, $11, $12, $13, $14, $15, $16, $17)
		 ON CONFLICT (host) DO UPDATE SET
		   name = EXCLUDED.name,
		   country = EXCLUDED.country,
		   port = EXCLUDED.port,
		   public_key = EXCLUDED.public_key,
		   is_active = true,
		   last_heartbeat_at = now(),
		   wg_admin_url = EXCLUDED.wg_admin_url,
		   awg_jc = EXCLUDED.awg_jc,
		   awg_jmin = EXCLUDED.awg_jmin,
		   awg_jmax = EXCLUDED.awg_jmax,
		   awg_s1 = EXCLUDED.awg_s1,
		   awg_s2 = EXCLUDED.awg_s2,
		   awg_h1 = EXCLUDED.awg_h1,
		   awg_h2 = EXCLUDED.awg_h2,
		   awg_h3 = EXCLUDED.awg_h3,
		   awg_h4 = EXCLUDED.awg_h4
		 RETURNING id, name, country, host, port, public_key, is_active, created_at,
		           last_heartbeat_at, wg_admin_url,
		           awg_jc, awg_jmin, awg_jmax, awg_s1, awg_s2, awg_h1, awg_h2, awg_h3, awg_h4`,
		srv.ID, srv.Name, srv.Country, srv.Host, srv.Port, srv.PublicKey, now, srv.WGAdminURL,
		srv.AWGJc, srv.AWGJmin, srv.AWGJmax, srv.AWGS1, srv.AWGS2,
		srv.AWGH1, srv.AWGH2, srv.AWGH3, srv.AWGH4,
	).StructScan(&result)
	if err != nil {
		return nil, fmt.Errorf("upsert server: %w", err)
	}
	return &result, nil
}

func (s *PostgresServerStore) UpdateHeartbeat(ctx context.Context, host string) error {
	result, err := s.db.ExecContext(ctx,
		`UPDATE servers SET last_heartbeat_at = now(), is_active = true WHERE host = $1`, host,
	)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrServerNotFound
	}
	return nil
}

func (s *PostgresServerStore) MarkStaleServersInactive(ctx context.Context, staleThreshold time.Duration) (int, error) {
	result, err := s.db.ExecContext(ctx,
		`UPDATE servers SET is_active = false
		 WHERE is_active = true
		   AND last_heartbeat_at IS NOT NULL
		   AND last_heartbeat_at < now() - $1::interval`,
		fmt.Sprintf("%d seconds", int(staleThreshold.Seconds())),
	)
	if err != nil {
		return 0, err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return 0, err
	}
	return int(rows), nil
}
