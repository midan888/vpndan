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
}
