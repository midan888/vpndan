package store

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	"vpn-dan/backend/internal/models"
)

type PostgresUserStore struct {
	db *sqlx.DB
}

func NewPostgresUserStore(db *sqlx.DB) *PostgresUserStore {
	return &PostgresUserStore{db: db}
}

func (s *PostgresUserStore) CreateUser(ctx context.Context, email, hashedPassword string) (*models.User, error) {
	user := &models.User{
		ID:        uuid.New(),
		Email:     email,
		Password:  hashedPassword,
		CreatedAt: time.Now(),
	}

	_, err := s.db.ExecContext(ctx,
		`INSERT INTO users (id, email, password, created_at) VALUES ($1, $2, $3, $4)`,
		user.ID, user.Email, user.Password, user.CreatedAt,
	)
	if err != nil {
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "23505") {
			return nil, ErrEmailExists
		}
		return nil, err
	}

	return user, nil
}

func (s *PostgresUserStore) GetUserByEmail(ctx context.Context, email string) (*models.User, error) {
	var user models.User
	err := s.db.GetContext(ctx, &user, `SELECT id, email, password, is_admin, created_at FROM users WHERE email = $1`, email)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &user, nil
}

func (s *PostgresUserStore) GetUserByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	var user models.User
	err := s.db.GetContext(ctx, &user, `SELECT id, email, password, is_admin, created_at FROM users WHERE id = $1`, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return &user, nil
}

func (s *PostgresUserStore) ListUsers(ctx context.Context) ([]models.User, error) {
	var users []models.User
	err := s.db.SelectContext(ctx, &users, `SELECT id, email, is_admin, created_at FROM users ORDER BY created_at DESC`)
	if err != nil {
		return nil, err
	}
	return users, nil
}

func (s *PostgresUserStore) UpdatePassword(ctx context.Context, id uuid.UUID, hashedPassword string) error {
	result, err := s.db.ExecContext(ctx, `UPDATE users SET password = $1 WHERE id = $2`, hashedPassword, id)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrUserNotFound
	}
	return nil
}

func (s *PostgresUserStore) DeleteUser(ctx context.Context, id uuid.UUID) error {
	result, err := s.db.ExecContext(ctx, `DELETE FROM users WHERE id = $1`, id)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrUserNotFound
	}
	return nil
}

func (s *PostgresUserStore) SetAdmin(ctx context.Context, id uuid.UUID, isAdmin bool) error {
	result, err := s.db.ExecContext(ctx, `UPDATE users SET is_admin = $1 WHERE id = $2`, isAdmin, id)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrUserNotFound
	}
	return nil
}
