package models

import (
	"time"

	"github.com/google/uuid"
)

type Peer struct {
	ID         uuid.UUID `json:"id" db:"id"`
	UserID     uuid.UUID `json:"user_id" db:"user_id"`
	ServerID   uuid.UUID `json:"server_id" db:"server_id"`
	PrivateKey string    `json:"-" db:"private_key"`
	PublicKey  string    `json:"-" db:"public_key"`
	AssignedIP string    `json:"assigned_ip" db:"assigned_ip"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
}

type WireGuardConfig struct {
	InterfacePrivateKey string `json:"interface_private_key" doc:"Client WireGuard private key"`
	InterfaceAddress    string `json:"interface_address" doc:"Assigned IP with subnet mask"`
	InterfaceDNS        string `json:"interface_dns" doc:"DNS server"`
	PeerPublicKey       string `json:"peer_public_key" doc:"Server WireGuard public key"`
	PeerEndpoint        string `json:"peer_endpoint" doc:"Server host:port"`
	PeerAllowedIPs      string `json:"peer_allowed_ips" doc:"Allowed IPs (0.0.0.0/0 for full tunnel)"`
	// Amnezia WireGuard obfuscation parameters
	Jc   int   `json:"jc" doc:"Junk packet count"`
	Jmin int   `json:"jmin" doc:"Junk packet min size"`
	Jmax int   `json:"jmax" doc:"Junk packet max size"`
	S1   int   `json:"s1" doc:"Header shift 1"`
	S2   int   `json:"s2" doc:"Header shift 2"`
	H1   int64 `json:"h1" doc:"Magic byte replacement 1"`
	H2   int64 `json:"h2" doc:"Magic byte replacement 2"`
	H3   int64 `json:"h3" doc:"Magic byte replacement 3"`
	H4   int64 `json:"h4" doc:"Magic byte replacement 4"`
}
