package models

import (
	"time"

	"github.com/google/uuid"
)

type AdminUserResponse struct {
	ID        uuid.UUID    `json:"id"`
	Email     string       `json:"email"`
	IsAdmin   bool         `json:"is_admin"`
	CreatedAt time.Time    `json:"created_at"`
	Peer      *PeerSummary `json:"peer"`
}

type PeerSummary struct {
	ServerID   uuid.UUID `json:"server_id"`
	ServerName string    `json:"server_name"`
	AssignedIP string    `json:"assigned_ip"`
	ConnectedAt time.Time `json:"connected_at"`
}

type AdminServerResponse struct {
	ID        uuid.UUID `json:"id"`
	Name      string    `json:"name"`
	Country   string    `json:"country"`
	Host      string    `json:"host"`
	Port      int       `json:"port"`
	PublicKey string    `json:"public_key"`
	IsActive  bool      `json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
	PeerCount int       `json:"peer_count"`
	TxBytes   int64     `json:"tx_bytes"`
	RxBytes   int64     `json:"rx_bytes"`
}

type ServerTrafficResponse struct {
	ServerID uuid.UUID   `json:"server_id"`
	Name     string      `json:"name"`
	Country  string      `json:"country"`
	Host     string      `json:"host"`
	Port     int         `json:"port"`
	IsActive bool        `json:"is_active"`
	TotalRx  int64       `json:"total_rx_bytes"`
	TotalTx  int64       `json:"total_tx_bytes"`
	Peers    []PeerTraffic `json:"peers"`
}

type PeerTraffic struct {
	UserID    uuid.UUID `json:"user_id"`
	Email     string    `json:"email"`
	PublicKey string    `json:"public_key"`
	AssignedIP string   `json:"assigned_ip"`
	RxBytes   int64     `json:"rx_bytes"`
	TxBytes   int64     `json:"tx_bytes"`
}

type CreateServerRequest struct {
	Name      string `json:"name" minLength:"1" doc:"Server display name"`
	Country   string `json:"country" minLength:"2" maxLength:"2" doc:"ISO 3166-1 alpha-2 country code"`
	Host      string `json:"host" minLength:"1" doc:"Server IP or hostname"`
	Port      int    `json:"port" minimum:"1" maximum:"65535" doc:"WireGuard listen port"`
	PublicKey string `json:"public_key" minLength:"1" doc:"Server WireGuard public key"`
}

type ResetPasswordRequest struct {
	NewPassword string `json:"new_password" minLength:"8" doc:"New password for the user"`
}

type UpdateServerRequest struct {
	IsActive *bool `json:"is_active" doc:"Whether the server is active"`
}

// Node agent registration request — sent by node-agent on each VPS.
type NodeRegisterRequest struct {
	Name       string `json:"name" minLength:"1" doc:"Server display name"`
	Country    string `json:"country" minLength:"2" maxLength:"2" doc:"ISO 3166-1 alpha-2 country code"`
	Host       string `json:"host" minLength:"1" doc:"Server public IP or hostname"`
	Port       int    `json:"port" minimum:"1" maximum:"65535" doc:"WireGuard listen port"`
	PublicKey  string `json:"public_key" minLength:"1" doc:"Server WireGuard public key"`
	WGAdminURL string `json:"wg_admin_url" minLength:"1" doc:"WireGuard gateway admin URL reachable from backend"`
	// AWG obfuscation params
	AWGJc   int   `json:"awg_jc" doc:"Junk packet count"`
	AWGJmin int   `json:"awg_jmin" doc:"Junk packet min size"`
	AWGJmax int   `json:"awg_jmax" doc:"Junk packet max size"`
	AWGS1   int   `json:"awg_s1" doc:"Header byte shift 1"`
	AWGS2   int   `json:"awg_s2" doc:"Header byte shift 2"`
	AWGH1   int64 `json:"awg_h1" doc:"DPI defeat byte 1"`
	AWGH2   int64 `json:"awg_h2" doc:"DPI defeat byte 2"`
	AWGH3   int64 `json:"awg_h3" doc:"DPI defeat byte 3"`
	AWGH4   int64 `json:"awg_h4" doc:"DPI defeat byte 4"`
}

type NodeRegisterResponse struct {
	ServerID string `json:"server_id" doc:"UUID of the registered server"`
	Message  string `json:"message"`
}

type NodeHeartbeatRequest struct {
	Host string `json:"host" minLength:"1" doc:"Server public IP (identifies which server)"`
}

type NodeHeartbeatResponse struct {
	Message string `json:"message"`
}
