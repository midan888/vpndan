package store

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"vpn-dan/backend/internal/models"
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
	ListUsers(ctx context.Context) ([]models.User, error)
	UpdatePassword(ctx context.Context, id uuid.UUID, hashedPassword string) error
	DeleteUser(ctx context.Context, id uuid.UUID) error
	SetAdmin(ctx context.Context, id uuid.UUID, isAdmin bool) error
}

type ServerStore interface {
	ListActiveServers(ctx context.Context) ([]models.Server, error)
	GetServerByID(ctx context.Context, id uuid.UUID) (*models.Server, error)
	ListAllServers(ctx context.Context) ([]models.Server, error)
	CreateServer(ctx context.Context, s *models.Server) (*models.Server, error)
	DeleteServer(ctx context.Context, id uuid.UUID) error
	UpdateServerStatus(ctx context.Context, id uuid.UUID, isActive bool) error
	UpsertServerByHost(ctx context.Context, s *models.Server) (*models.Server, error)
	UpdateHeartbeat(ctx context.Context, host string) error
	MarkStaleServersInactive(ctx context.Context, staleThreshold time.Duration) (int, error)
}

type PeerStore interface {
	CreatePeer(ctx context.Context, userID, serverID uuid.UUID, privateKey, publicKey, assignedIP string) (*models.Peer, error)
	GetPeerByUserID(ctx context.Context, userID uuid.UUID) (*models.Peer, error)
	DeletePeerByUserID(ctx context.Context, userID uuid.UUID) error
	CountPeersByServerID(ctx context.Context, serverID uuid.UUID) (int, error)
	ListPeersByServerID(ctx context.Context, serverID uuid.UUID) ([]models.Peer, error)
	ListAllPeers(ctx context.Context) ([]models.Peer, error)
}
