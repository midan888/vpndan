package store

import (
	"context"

	"github.com/jmoiron/sqlx"
	"vpn-dan/backend/internal/models"
)

type GeoIPStore interface {
	GetCIDRsByCountry(ctx context.Context, country string) ([]string, error)
	ListAvailableCountries(ctx context.Context) ([]models.AvailableCountry, error)
	BulkInsertCIDRs(ctx context.Context, country string, cidrs []string) error
	DeleteByCountry(ctx context.Context, country string) error
}

type PostgresGeoIPStore struct {
	db *sqlx.DB
}

func NewPostgresGeoIPStore(db *sqlx.DB) *PostgresGeoIPStore {
	return &PostgresGeoIPStore{db: db}
}

func (s *PostgresGeoIPStore) GetCIDRsByCountry(ctx context.Context, country string) ([]string, error) {
	var cidrs []string
	err := s.db.SelectContext(ctx, &cidrs,
		`SELECT cidr::text FROM country_ips WHERE country = $1 ORDER BY cidr`, country)
	if err != nil {
		return nil, err
	}
	return cidrs, nil
}

func (s *PostgresGeoIPStore) ListAvailableCountries(ctx context.Context) ([]models.AvailableCountry, error) {
	var countries []models.AvailableCountry
	err := s.db.SelectContext(ctx, &countries,
		`SELECT country, COUNT(*) as count FROM country_ips GROUP BY country ORDER BY country`)
	if err != nil {
		return nil, err
	}
	return countries, nil
}

func (s *PostgresGeoIPStore) BulkInsertCIDRs(ctx context.Context, country string, cidrs []string) error {
	tx, err := s.db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.PrepareContext(ctx,
		`INSERT INTO country_ips (country, cidr) VALUES ($1, $2::cidr)`)
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, cidr := range cidrs {
		if _, err := stmt.ExecContext(ctx, country, cidr); err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (s *PostgresGeoIPStore) DeleteByCountry(ctx context.Context, country string) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM country_ips WHERE country = $1`, country)
	return err
}
