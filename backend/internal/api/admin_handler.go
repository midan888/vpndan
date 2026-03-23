package api

import (
	"context"
	"errors"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"vpn-dan/backend/internal/auth"
	"vpn-dan/backend/internal/models"
	"vpn-dan/backend/internal/store"
	"vpn-dan/backend/internal/wireguard"
)

type AdminHandler struct {
	users   store.UserStore
	servers store.ServerStore
	peers   store.PeerStore
	jwt     *auth.JWTService
	wg      wireguard.PeerManager
}

func NewAdminHandler(users store.UserStore, servers store.ServerStore, peers store.PeerStore, jwt *auth.JWTService, wg wireguard.PeerManager) *AdminHandler {
	return &AdminHandler{users: users, servers: servers, peers: peers, jwt: jwt, wg: wg}
}

// --- Users ---

type AdminListUsersInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer admin access token"`
}

type AdminListUsersOutput struct {
	Body []models.AdminUserResponse
}

func (h *AdminHandler) ListUsers(ctx context.Context, input *AdminListUsersInput) (*AdminListUsersOutput, error) {
	if _, err := authenticateAdminRequest(h.jwt, input.Authorization); err != nil {
		return nil, err
	}

	users, err := h.users.ListUsers(ctx)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	allPeers, err := h.peers.ListAllPeers(ctx)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	// Build peer lookup by user ID
	peerByUser := make(map[uuid.UUID]*models.Peer)
	for i := range allPeers {
		peerByUser[allPeers[i].UserID] = &allPeers[i]
	}

	// Build server name lookup for connected peers
	serverNames := make(map[uuid.UUID]string)
	for _, p := range allPeers {
		if _, ok := serverNames[p.ServerID]; !ok {
			srv, err := h.servers.GetServerByID(ctx, p.ServerID)
			if err == nil {
				serverNames[p.ServerID] = srv.Name
			}
		}
	}

	resp := make([]models.AdminUserResponse, len(users))
	for i, u := range users {
		resp[i] = models.AdminUserResponse{
			ID:        u.ID,
			Email:     u.Email,
			IsAdmin:   u.IsAdmin,
			CreatedAt: u.CreatedAt,
		}
		if peer, ok := peerByUser[u.ID]; ok {
			resp[i].Peer = &models.PeerSummary{
				ServerID:    peer.ServerID,
				ServerName:  serverNames[peer.ServerID],
				AssignedIP:  peer.AssignedIP,
				ConnectedAt: peer.CreatedAt,
			}
		}
	}

	return &AdminListUsersOutput{Body: resp}, nil
}

type AdminGetUserInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer admin access token"`
	ID            string `path:"id" doc:"User UUID"`
}

type AdminGetUserOutput struct {
	Body models.AdminUserResponse
}

func (h *AdminHandler) GetUser(ctx context.Context, input *AdminGetUserInput) (*AdminGetUserOutput, error) {
	if _, err := authenticateAdminRequest(h.jwt, input.Authorization); err != nil {
		return nil, err
	}

	userID, err := uuid.Parse(input.ID)
	if err != nil {
		return nil, huma.Error400BadRequest("invalid user ID")
	}

	user, err := h.users.GetUserByID(ctx, userID)
	if err != nil {
		if errors.Is(err, store.ErrUserNotFound) {
			return nil, huma.Error404NotFound("user not found")
		}
		return nil, huma.Error500InternalServerError("internal server error")
	}

	resp := models.AdminUserResponse{
		ID:        user.ID,
		Email:     user.Email,
		IsAdmin:   user.IsAdmin,
		CreatedAt: user.CreatedAt,
	}

	peer, err := h.peers.GetPeerByUserID(ctx, userID)
	if err == nil {
		srv, srvErr := h.servers.GetServerByID(ctx, peer.ServerID)
		serverName := ""
		if srvErr == nil {
			serverName = srv.Name
		}
		resp.Peer = &models.PeerSummary{
			ServerID:    peer.ServerID,
			ServerName:  serverName,
			AssignedIP:  peer.AssignedIP,
			ConnectedAt: peer.CreatedAt,
		}
	}

	return &AdminGetUserOutput{Body: resp}, nil
}

type AdminResetPasswordInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer admin access token"`
	ID            string `path:"id" doc:"User UUID"`
	Body          models.ResetPasswordRequest
}

type AdminResetPasswordOutput struct {
	Body struct {
		Message string `json:"message"`
	}
}

func (h *AdminHandler) ResetPassword(ctx context.Context, input *AdminResetPasswordInput) (*AdminResetPasswordOutput, error) {
	if _, err := authenticateAdminRequest(h.jwt, input.Authorization); err != nil {
		return nil, err
	}

	userID, err := uuid.Parse(input.ID)
	if err != nil {
		return nil, huma.Error400BadRequest("invalid user ID")
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(input.Body.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	if err := h.users.UpdatePassword(ctx, userID, string(hashed)); err != nil {
		if errors.Is(err, store.ErrUserNotFound) {
			return nil, huma.Error404NotFound("user not found")
		}
		return nil, huma.Error500InternalServerError("internal server error")
	}

	out := &AdminResetPasswordOutput{}
	out.Body.Message = "password updated"
	return out, nil
}

type AdminDeleteUserInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer admin access token"`
	ID            string `path:"id" doc:"User UUID"`
}

type AdminDeleteUserOutput struct {
	Body struct {
		Message string `json:"message"`
	}
}

func (h *AdminHandler) DeleteUser(ctx context.Context, input *AdminDeleteUserInput) (*AdminDeleteUserOutput, error) {
	if _, err := authenticateAdminRequest(h.jwt, input.Authorization); err != nil {
		return nil, err
	}

	userID, err := uuid.Parse(input.ID)
	if err != nil {
		return nil, huma.Error400BadRequest("invalid user ID")
	}

	// Clean up WireGuard peer if user has an active connection
	peer, err := h.peers.GetPeerByUserID(ctx, userID)
	if err == nil {
		_ = h.wg.RemovePeer(peer.PublicKey)
	}

	if err := h.users.DeleteUser(ctx, userID); err != nil {
		if errors.Is(err, store.ErrUserNotFound) {
			return nil, huma.Error404NotFound("user not found")
		}
		return nil, huma.Error500InternalServerError("internal server error")
	}

	out := &AdminDeleteUserOutput{}
	out.Body.Message = "user deleted"
	return out, nil
}

// --- Servers ---

type AdminListServersInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer admin access token"`
}

type AdminListServersOutput struct {
	Body []models.AdminServerResponse
}

func (h *AdminHandler) ListServers(ctx context.Context, input *AdminListServersInput) (*AdminListServersOutput, error) {
	if _, err := authenticateAdminRequest(h.jwt, input.Authorization); err != nil {
		return nil, err
	}

	servers, err := h.servers.ListAllServers(ctx)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	// Get transfer stats (best-effort)
	var stats []wireguard.TransferStat
	if ts, ok := h.wg.(wireguard.TransferStatsProvider); ok {
		stats, _ = ts.GetTransferStats()
	}
	statsByKey := make(map[string]*wireguard.TransferStat)
	for i := range stats {
		statsByKey[stats[i].PublicKey] = &stats[i]
	}

	resp := make([]models.AdminServerResponse, len(servers))
	for i, s := range servers {
		peerCount, _ := h.peers.CountPeersByServerID(ctx, s.ID)

		var txTotal, rxTotal int64
		peers, _ := h.peers.ListPeersByServerID(ctx, s.ID)
		for _, p := range peers {
			if st, ok := statsByKey[p.PublicKey]; ok {
				txTotal += st.TxBytes
				rxTotal += st.RxBytes
			}
		}

		resp[i] = models.AdminServerResponse{
			ID:        s.ID,
			Name:      s.Name,
			Country:   s.Country,
			Host:      s.Host,
			Port:      s.Port,
			PublicKey: s.PublicKey,
			IsActive:  s.IsActive,
			CreatedAt: s.CreatedAt,
			PeerCount: peerCount,
			TxBytes:   txTotal,
			RxBytes:   rxTotal,
		}
	}

	return &AdminListServersOutput{Body: resp}, nil
}

type AdminGetServerInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer admin access token"`
	ID            string `path:"id" doc:"Server UUID"`
}

type AdminGetServerOutput struct {
	Body models.ServerTrafficResponse
}

func (h *AdminHandler) GetServer(ctx context.Context, input *AdminGetServerInput) (*AdminGetServerOutput, error) {
	if _, err := authenticateAdminRequest(h.jwt, input.Authorization); err != nil {
		return nil, err
	}

	serverID, err := uuid.Parse(input.ID)
	if err != nil {
		return nil, huma.Error400BadRequest("invalid server ID")
	}

	srv, err := h.servers.GetServerByID(ctx, serverID)
	if err != nil {
		if errors.Is(err, store.ErrServerNotFound) {
			return nil, huma.Error404NotFound("server not found")
		}
		return nil, huma.Error500InternalServerError("internal server error")
	}

	peers, err := h.peers.ListPeersByServerID(ctx, serverID)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	// Get transfer stats (best-effort)
	var stats []wireguard.TransferStat
	if ts, ok := h.wg.(wireguard.TransferStatsProvider); ok {
		stats, _ = ts.GetTransferStats()
	}
	statsByKey := make(map[string]*wireguard.TransferStat)
	for i := range stats {
		statsByKey[stats[i].PublicKey] = &stats[i]
	}

	// Build user email lookup
	userEmails := make(map[uuid.UUID]string)
	for _, p := range peers {
		if _, ok := userEmails[p.UserID]; !ok {
			u, err := h.users.GetUserByID(ctx, p.UserID)
			if err == nil {
				userEmails[p.UserID] = u.Email
			}
		}
	}

	var totalRx, totalTx int64
	peerTraffic := make([]models.PeerTraffic, len(peers))
	for i, p := range peers {
		var rx, tx int64
		if st, ok := statsByKey[p.PublicKey]; ok {
			rx = st.RxBytes
			tx = st.TxBytes
		}
		totalRx += rx
		totalTx += tx

		peerTraffic[i] = models.PeerTraffic{
			UserID:     p.UserID,
			Email:      userEmails[p.UserID],
			PublicKey:  p.PublicKey,
			AssignedIP: p.AssignedIP,
			RxBytes:    rx,
			TxBytes:    tx,
		}
	}

	return &AdminGetServerOutput{Body: models.ServerTrafficResponse{
		ServerID: srv.ID,
		Name:     srv.Name,
		Country:  srv.Country,
		Host:     srv.Host,
		Port:     srv.Port,
		IsActive: srv.IsActive,
		TotalRx:  totalRx,
		TotalTx:  totalTx,
		Peers:    peerTraffic,
	}}, nil
}

type AdminCreateServerInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer admin access token"`
	Body          models.CreateServerRequest
}

type AdminCreateServerOutput struct {
	Body models.AdminServerResponse
}

func (h *AdminHandler) CreateServer(ctx context.Context, input *AdminCreateServerInput) (*AdminCreateServerOutput, error) {
	if _, err := authenticateAdminRequest(h.jwt, input.Authorization); err != nil {
		return nil, err
	}

	srv := &models.Server{
		Name:      input.Body.Name,
		Country:   input.Body.Country,
		Host:      input.Body.Host,
		Port:      input.Body.Port,
		PublicKey: input.Body.PublicKey,
	}

	created, err := h.servers.CreateServer(ctx, srv)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	return &AdminCreateServerOutput{Body: models.AdminServerResponse{
		ID:        created.ID,
		Name:      created.Name,
		Country:   created.Country,
		Host:      created.Host,
		Port:      created.Port,
		PublicKey: created.PublicKey,
		IsActive:  created.IsActive,
		CreatedAt: created.CreatedAt,
	}}, nil
}

type AdminDeleteServerInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer admin access token"`
	ID            string `path:"id" doc:"Server UUID"`
}

type AdminDeleteServerOutput struct {
	Body struct {
		Message string `json:"message"`
	}
}

func (h *AdminHandler) DeleteServer(ctx context.Context, input *AdminDeleteServerInput) (*AdminDeleteServerOutput, error) {
	if _, err := authenticateAdminRequest(h.jwt, input.Authorization); err != nil {
		return nil, err
	}

	serverID, err := uuid.Parse(input.ID)
	if err != nil {
		return nil, huma.Error400BadRequest("invalid server ID")
	}

	// Remove all WireGuard peers connected to this server
	peers, _ := h.peers.ListPeersByServerID(ctx, serverID)
	for _, p := range peers {
		_ = h.wg.RemovePeer(p.PublicKey)
	}

	if err := h.servers.DeleteServer(ctx, serverID); err != nil {
		if errors.Is(err, store.ErrServerNotFound) {
			return nil, huma.Error404NotFound("server not found")
		}
		return nil, huma.Error500InternalServerError("internal server error")
	}

	out := &AdminDeleteServerOutput{}
	out.Body.Message = "server deleted"
	return out, nil
}

type AdminUpdateServerInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer admin access token"`
	ID            string `path:"id" doc:"Server UUID"`
	Body          models.UpdateServerRequest
}

type AdminUpdateServerOutput struct {
	Body struct {
		Message string `json:"message"`
	}
}

func (h *AdminHandler) UpdateServer(ctx context.Context, input *AdminUpdateServerInput) (*AdminUpdateServerOutput, error) {
	if _, err := authenticateAdminRequest(h.jwt, input.Authorization); err != nil {
		return nil, err
	}

	serverID, err := uuid.Parse(input.ID)
	if err != nil {
		return nil, huma.Error400BadRequest("invalid server ID")
	}

	if input.Body.IsActive == nil {
		return nil, huma.Error400BadRequest("is_active is required")
	}

	if err := h.servers.UpdateServerStatus(ctx, serverID, *input.Body.IsActive); err != nil {
		if errors.Is(err, store.ErrServerNotFound) {
			return nil, huma.Error404NotFound("server not found")
		}
		return nil, huma.Error500InternalServerError("internal server error")
	}

	out := &AdminUpdateServerOutput{}
	out.Body.Message = "server updated"
	return out, nil
}
