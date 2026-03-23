package api

import (
	"net/http"

	"vpn-god/backend/internal/auth"
	"vpn-god/backend/internal/store"
	"vpn-god/backend/internal/wireguard"

	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humago"
)

func NewRouter(users store.UserStore, servers store.ServerStore, peers store.PeerStore, geoip store.GeoIPStore, jwtService *auth.JWTService, wg wireguard.PeerManager, corsOrigin string) http.Handler {
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

	// Admin routes
	adminHandler := NewAdminHandler(users, servers, peers, jwtService, wg)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodGet,
		Path:        "/api/v1/admin/users",
		OperationID: "admin-list-users",
		Summary:     "List all users with connection status",
		Tags:        []string{"Admin"},
		Security:    []map[string][]string{{"bearer": {}}},
	}, adminHandler.ListUsers)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodGet,
		Path:        "/api/v1/admin/users/{id}",
		OperationID: "admin-get-user",
		Summary:     "Get user details",
		Tags:        []string{"Admin"},
		Security:    []map[string][]string{{"bearer": {}}},
	}, adminHandler.GetUser)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodPost,
		Path:        "/api/v1/admin/users/{id}/reset-password",
		OperationID: "admin-reset-password",
		Summary:     "Reset a user's password",
		Tags:        []string{"Admin"},
		Security:    []map[string][]string{{"bearer": {}}},
	}, adminHandler.ResetPassword)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodDelete,
		Path:        "/api/v1/admin/users/{id}",
		OperationID: "admin-delete-user",
		Summary:     "Delete a user",
		Tags:        []string{"Admin"},
		Security:    []map[string][]string{{"bearer": {}}},
	}, adminHandler.DeleteUser)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodGet,
		Path:        "/api/v1/admin/servers",
		OperationID: "admin-list-servers",
		Summary:     "List all servers with peer counts and traffic",
		Tags:        []string{"Admin"},
		Security:    []map[string][]string{{"bearer": {}}},
	}, adminHandler.ListServers)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodGet,
		Path:        "/api/v1/admin/servers/{id}",
		OperationID: "admin-get-server",
		Summary:     "Get server details with per-peer traffic",
		Tags:        []string{"Admin"},
		Security:    []map[string][]string{{"bearer": {}}},
	}, adminHandler.GetServer)

	huma.Register(humaAPI, huma.Operation{
		Method:        http.MethodPost,
		Path:          "/api/v1/admin/servers",
		OperationID:   "admin-create-server",
		Summary:       "Add a new server",
		Tags:          []string{"Admin"},
		Security:      []map[string][]string{{"bearer": {}}},
		DefaultStatus: http.StatusCreated,
	}, adminHandler.CreateServer)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodDelete,
		Path:        "/api/v1/admin/servers/{id}",
		OperationID: "admin-delete-server",
		Summary:     "Delete a server",
		Tags:        []string{"Admin"},
		Security:    []map[string][]string{{"bearer": {}}},
	}, adminHandler.DeleteServer)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodPatch,
		Path:        "/api/v1/admin/servers/{id}",
		OperationID: "admin-update-server",
		Summary:     "Update server status",
		Tags:        []string{"Admin"},
		Security:    []map[string][]string{{"bearer": {}}},
	}, adminHandler.UpdateServer)

	// GeoIP routes
	geoipHandler := NewGeoIPHandler(geoip, jwtService)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodGet,
		Path:        "/api/v1/geoip/countries",
		OperationID: "list-geoip-countries",
		Summary:     "List countries with available CIDR data",
		Tags:        []string{"GeoIP"},
		Security:    []map[string][]string{{"bearer": {}}},
	}, geoipHandler.ListCountries)

	huma.Register(humaAPI, huma.Operation{
		Method:      http.MethodGet,
		Path:        "/api/v1/geoip/{country}",
		OperationID: "get-country-cidrs",
		Summary:     "Get CIDR ranges for a country",
		Tags:        []string{"GeoIP"},
		Security:    []map[string][]string{{"bearer": {}}},
	}, geoipHandler.GetCountryCIDRs)

	// CORS middleware (only active when CORS_ORIGIN is set, i.e. dev)
	if corsOrigin != "" {
		return corsMiddleware(mux, corsOrigin)
	}

	return mux
}

func corsMiddleware(next http.Handler, origin string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", origin)
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}
