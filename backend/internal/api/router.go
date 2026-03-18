package api

import (
	"net/http"

	"vpn-god/backend/internal/auth"
	"vpn-god/backend/internal/store"
	"vpn-god/backend/internal/wireguard"

	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humago"
)

func NewRouter(users store.UserStore, servers store.ServerStore, peers store.PeerStore, jwtService *auth.JWTService, wg wireguard.PeerManager) http.Handler {
	mux := http.NewServeMux()

	humaAPI := humago.New(mux, huma.DefaultConfig("VPN God API", "1.0.0"))

	authHandler := NewAuthHandler(users, jwtService)

	huma.Register(humaAPI, huma.Operation{
		Method:        http.MethodPost,
		Path:          "/api/v1/auth/register",
		OperationID:   "register",
		Summary:       "Register a new user",
		Tags:          []string{"Auth"},
		DefaultStatus: http.StatusCreated,
	}, authHandler.Register)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodPost,
		Path:        "/api/v1/auth/login",
		OperationID: "login",
		Summary:     "Log in with email and password",
		Tags:        []string{"Auth"},
	}, authHandler.Login)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodPost,
		Path:        "/api/v1/auth/refresh",
		OperationID: "refresh-token",
		Summary:     "Refresh access token",
		Tags:        []string{"Auth"},
	}, authHandler.Refresh)

	serverHandler := NewServerHandler(servers, jwtService)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodGet,
		Path:        "/api/v1/servers",
		OperationID: "list-servers",
		Summary:     "List available VPN servers",
		Tags:        []string{"Servers"},
		Security:    []map[string][]string{{"bearer": {}}},
	}, serverHandler.ListServers)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodGet,
		Path:        "/api/v1/servers/{id}",
		OperationID: "get-server",
		Summary:     "Get Server By ID",
		Tags:        []string{"Servers"},
		Security:    []map[string][]string{{"bearer": {}}},
	}, serverHandler.GetServer)

	connectHandler := NewConnectHandler(peers, servers, jwtService, wg)

	huma.Register(humaAPI, huma.Operation{
		Method:        http.MethodPost,
		Path:          "/api/v1/connect",
		OperationID:   "connect",
		Summary:       "Connect to a VPN server",
		Tags:          []string{"Connection"},
		Security:      []map[string][]string{{"bearer": {}}},
		DefaultStatus: http.StatusCreated,
	}, connectHandler.Connect)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodDelete,
		Path:        "/api/v1/connect",
		OperationID: "disconnect",
		Summary:     "Disconnect from VPN server",
		Tags:        []string{"Connection"},
		Security:    []map[string][]string{{"bearer": {}}},
	}, connectHandler.Disconnect)

	return mux
}
