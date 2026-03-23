package store

import (
	"context"
	"database/sql"
	"errors"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	"github.com/lib/pq"
	"vpn-dan/backend/internal/models"
)

type PostgresPeerStore struct {
	db *sqlx.DB
}

func NewPostgresPeerStore(db *sqlx.DB) *PostgresPeerStore {
	return &PostgresPeerStore{db: db}
}

func (s *PostgresPeerStore) CreatePeer(ctx context.Context, userID, serverID uuid.UUID, privateKey, publicKey, assignedIP string) (*models.Peer, error) {
	var peer models.Peer
	err := s.db.QueryRowxContext(ctx,
		`INSERT INTO peers (user_id, server_id, private_key, public_key, assigned_ip)
		 VALUES ($1, $2, $3, $4, $5)
		 RETURNING id, user_id, server_id, private_key, public_key, assigned_ip::TEXT, created_at`,
		userID, serverID, privateKey, publicKey, assignedIP,
	).StructScan(&peer)
	if err != nil {
		var pqErr *pq.Error
		if errors.As(err, &pqErr) && pqErr.Code == "23505" {
			return nil, ErrPeerExists
		}
		return nil, err
	}
	return &peer, nil
}

func (s *PostgresPeerStore) GetPeerByUserID(ctx context.Context, userID uuid.UUID) (*models.Peer, error) {
	var peer models.Peer
	err := s.db.GetContext(ctx, &peer,
		`SELECT id, user_id, server_id, private_key, public_key, assigned_ip::TEXT, created_at FROM peers WHERE user_id = $1`, userID,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrPeerNotFound
		}
		return nil, err
	}
	return &peer, nil
}

func (s *PostgresPeerStore) DeletePeerByUserID(ctx context.Context, userID uuid.UUID) error {
	result, err := s.db.ExecContext(ctx,
		`DELETE FROM peers WHERE user_id = $1`, userID,
	)
	if err != nil {
		return err
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rows == 0 {
		return ErrPeerNotFound
	}
	return nil
}

func (s *PostgresPeerStore) CountPeersByServerID(ctx context.Context, serverID uuid.UUID) (int, error) {
	var count int
	err := s.db.GetContext(ctx, &count,
		`SELECT COUNT(*) FROM peers WHERE server_id = $1`, serverID,
	)
	return count, err
}

func (s *PostgresPeerStore) ListPeersByServerID(ctx context.Context, serverID uuid.UUID) ([]models.Peer, error) {
	var peers []models.Peer
	err := s.db.SelectContext(ctx, &peers,
		`SELECT id, user_id, server_id, private_key, public_key, assigned_ip::TEXT, created_at FROM peers WHERE server_id = $1`, serverID,
	)
	if err != nil {
		return nil, err
	}
	return peers, nil
}

func (s *PostgresPeerStore) ListAllPeers(ctx context.Context) ([]models.Peer, error) {
	var peers []models.Peer
	err := s.db.SelectContext(ctx, &peers,
		`SELECT id, user_id, server_id, private_key, public_key, assigned_ip::TEXT, created_at FROM peers`,
	)
	if err != nil {
		return nil, err
	}
	return peers, nil
}
