package api

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"vpn-god/backend/internal/auth"
	"vpn-god/backend/internal/models"
	"vpn-god/backend/internal/store"
	"vpn-god/backend/internal/wireguard"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
)

type ConnectHandler struct {
	peers   store.PeerStore
	servers store.ServerStore
	jwt     *auth.JWTService
	wg      wireguard.PeerManager
}

func NewConnectHandler(peers store.PeerStore, servers store.ServerStore, jwt *auth.JWTService, wg wireguard.PeerManager) *ConnectHandler {
	return &ConnectHandler{peers: peers, servers: servers, jwt: jwt, wg: wg}
}

// POST /api/v1/connect

type ConnectInput struct {
	Authorization string    `header:"Authorization" required:"true" doc:"Bearer access token"`
	Body          struct {
		ServerID uuid.UUID `json:"server_id" required:"true" doc:"ID of the server to connect to"`
	}
}

type ConnectOutput struct {
	Body models.WireGuardConfig
}

func (h *ConnectHandler) Connect(ctx context.Context, input *ConnectInput) (*ConnectOutput, error) {
	userID, err := authenticateRequest(h.jwt, input.Authorization)
	if err != nil {
		return nil, err
	}

	// If user already has an active connection, clean it up first
	existingPeer, err := h.peers.GetPeerByUserID(ctx, userID)
	if err != nil && !errors.Is(err, store.ErrPeerNotFound) {
		return nil, huma.Error500InternalServerError("internal server error")
	}
	if existingPeer != nil {
		_ = h.wg.RemovePeer(existingPeer.PublicKey)
		if err := h.peers.DeletePeerByUserID(ctx, userID); err != nil {
			return nil, huma.Error500InternalServerError("internal server error")
		}
	}

	// Validate server exists and is active
	server, err := h.servers.GetServerByID(ctx, input.Body.ServerID)
	if err != nil {
		if errors.Is(err, store.ErrServerNotFound) {
			return nil, huma.Error404NotFound("server not found")
		}
		return nil, huma.Error500InternalServerError("internal server error")
	}
	if !server.IsActive {
		return nil, huma.Error400BadRequest("server is not available")
	}

	// Generate WireGuard keypair for the client
	keyPair, err := wireguard.GenerateKeyPair()
	if err != nil {
		return nil, huma.Error500InternalServerError("failed to generate keys")
	}

	// Assign an IP from the server's subnet (10.0.0.0/24)
	// Reserve .1 for the server, assign .2+ to clients
	peerCount, err := h.peers.CountPeersByServerID(ctx, server.ID)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}
	clientIP := fmt.Sprintf("10.0.0.%d", peerCount+2)
	if peerCount+2 > 254 {
		return nil, huma.Error503ServiceUnavailable("server is full")
	}

	// Store peer in database
	peer, err := h.peers.CreatePeer(ctx, userID, server.ID, keyPair.PrivateKey, keyPair.PublicKey, clientIP)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	// Register peer on the WireGuard interface
	if err := h.wg.AddPeer(keyPair.PublicKey, clientIP); err != nil {
		// Rollback: remove the peer from DB since WireGuard rejected it
		_ = h.peers.DeletePeerByUserID(ctx, userID)
		return nil, huma.Error500InternalServerError("failed to configure VPN tunnel")
	}

	// Build WireGuard config for the client
	// Strip CIDR suffix from Postgres INET (e.g. "10.0.0.2/32" → "10.0.0.2")
	ip, _, _ := strings.Cut(peer.AssignedIP, "/")
	config := models.WireGuardConfig{
		InterfacePrivateKey: peer.PrivateKey,
		InterfaceAddress:    fmt.Sprintf("%s/32", ip),
		InterfaceDNS:        "1.1.1.1",
		PeerPublicKey:       server.PublicKey,
		PeerEndpoint:        fmt.Sprintf("%s:%d", server.Host, server.Port),
		PeerAllowedIPs:      "0.0.0.0/0",
		Jc:                  server.AWGJc,
		Jmin:                server.AWGJmin,
		Jmax:                server.AWGJmax,
		S1:                  server.AWGS1,
		S2:                  server.AWGS2,
		H1:                  server.AWGH1,
		H2:                  server.AWGH2,
		H3:                  server.AWGH3,
		H4:                  server.AWGH4,
	}

	return &ConnectOutput{Body: config}, nil
}

// DELETE /api/v1/connect

type DisconnectInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer access token"`
}

type DisconnectOutput struct {
	Body struct {
		Message string `json:"message" doc:"Disconnection confirmation"`
	}
}

func (h *ConnectHandler) Disconnect(ctx context.Context, input *DisconnectInput) (*DisconnectOutput, error) {
	userID, err := authenticateRequest(h.jwt, input.Authorization)
	if err != nil {
		return nil, err
	}

	// Get the peer so we know its public key for WireGuard removal
	peer, err := h.peers.GetPeerByUserID(ctx, userID)
	if err != nil {
		if errors.Is(err, store.ErrPeerNotFound) {
			return nil, huma.Error404NotFound("no active connection")
		}
		return nil, huma.Error500InternalServerError("internal server error")
	}

	// Remove peer from WireGuard interface
	if err := h.wg.RemovePeer(peer.PublicKey); err != nil {
		return nil, huma.Error500InternalServerError("failed to remove VPN tunnel")
	}

	// Delete peer from database
	if err := h.peers.DeletePeerByUserID(ctx, userID); err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	out := &DisconnectOutput{}
	out.Body.Message = "disconnected"
	return out, nil
}
