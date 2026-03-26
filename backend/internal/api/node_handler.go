package api

import (
	"context"
	"strings"

	"github.com/danielgtaylor/huma/v2"
	"vpn-dan/backend/internal/models"
	"vpn-dan/backend/internal/store"
)

type NodeHandler struct {
	servers    store.ServerStore
	nodeSecret string
}

func NewNodeHandler(servers store.ServerStore, nodeSecret string) *NodeHandler {
	return &NodeHandler{servers: servers, nodeSecret: nodeSecret}
}

func (h *NodeHandler) authenticateNode(authHeader string) error {
	if h.nodeSecret == "" {
		return huma.Error503ServiceUnavailable("node registration is not configured")
	}
	token := strings.TrimPrefix(authHeader, "Bearer ")
	if token == "" || token == authHeader || token != h.nodeSecret {
		return huma.Error401Unauthorized("invalid node secret")
	}
	return nil
}

// POST /api/v1/nodes/register

type NodeRegisterInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer <NODE_SECRET>"`
	Body          models.NodeRegisterRequest
}

type NodeRegisterOutput struct {
	Body models.NodeRegisterResponse
}

func (h *NodeHandler) Register(ctx context.Context, input *NodeRegisterInput) (*NodeRegisterOutput, error) {
	if err := h.authenticateNode(input.Authorization); err != nil {
		return nil, err
	}

	srv := &models.Server{
		Name:       input.Body.Name,
		Country:    input.Body.Country,
		Host:       input.Body.Host,
		Port:       input.Body.Port,
		PublicKey:  input.Body.PublicKey,
		WGAdminURL: input.Body.WGAdminURL,
		AWGJc:     input.Body.AWGJc,
		AWGJmin:   input.Body.AWGJmin,
		AWGJmax:   input.Body.AWGJmax,
		AWGS1:     input.Body.AWGS1,
		AWGS2:     input.Body.AWGS2,
		AWGH1:     input.Body.AWGH1,
		AWGH2:     input.Body.AWGH2,
		AWGH3:     input.Body.AWGH3,
		AWGH4:     input.Body.AWGH4,
	}

	created, err := h.servers.UpsertServerByHost(ctx, srv)
	if err != nil {
		return nil, huma.Error500InternalServerError("failed to register server")
	}

	return &NodeRegisterOutput{Body: models.NodeRegisterResponse{
		ServerID: created.ID.String(),
		Message:  "server registered",
	}}, nil
}

// POST /api/v1/nodes/heartbeat

type NodeHeartbeatInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer <NODE_SECRET>"`
	Body          models.NodeHeartbeatRequest
}

type NodeHeartbeatOutput struct {
	Body models.NodeHeartbeatResponse
}

func (h *NodeHandler) Heartbeat(ctx context.Context, input *NodeHeartbeatInput) (*NodeHeartbeatOutput, error) {
	if err := h.authenticateNode(input.Authorization); err != nil {
		return nil, err
	}

	if err := h.servers.UpdateHeartbeat(ctx, input.Body.Host); err != nil {
		return nil, huma.Error404NotFound("server not found — register first")
	}

	return &NodeHeartbeatOutput{Body: models.NodeHeartbeatResponse{
		Message: "heartbeat received",
	}}, nil
}
