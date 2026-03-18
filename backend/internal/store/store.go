package store

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"vpn-god/backend/internal/models"
)

var (
	ErrUserNotFound   = errors.New("user not found")
	ErrEmailExists    = errors.New("email already exists")
	ErrServerNotFound = errors.New("server not found")
	ErrPeerNotFound   = errors.New("peer not found")
	ErrPeerExists     = errors.New("user already has an active connection")
)

type UserStore interface {
	CreateUser(ctx context.Context, email, hashedPassword string) (*models.User, error)
	GetUserByEmail(ctx context.Context, email string) (*models.User, error)
	GetUserByID(ctx context.Context, id uuid.UUID) (*models.User, error)
}

type ServerStore interface {
	ListActiveServers(ctx context.Context) ([]models.Server, error)
	GetServerByID(ctx context.Context, id uuid.UUID) (*models.Server, error)
}

type PeerStore interface {
	CreatePeer(ctx context.Context, userID, serverID uuid.UUID, privateKey, publicKey, assignedIP string) (*models.Peer, error)
	GetPeerByUserID(ctx context.Context, userID uuid.UUID) (*models.Peer, error)
	DeletePeerByUserID(ctx context.Context, userID uuid.UUID) error
	CountPeersByServerID(ctx context.Context, serverID uuid.UUID) (int, error)
}
