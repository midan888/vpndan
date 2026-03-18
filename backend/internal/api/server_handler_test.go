package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
	"vpn-god/backend/internal/auth"
	"vpn-god/backend/internal/models"
	"vpn-god/backend/internal/store"
)

type fullMockServerStore struct {
	servers map[uuid.UUID]*models.Server
}

func newFullMockServerStore() *fullMockServerStore {
	return &fullMockServerStore{servers: make(map[uuid.UUID]*models.Server)}
}

func (m *fullMockServerStore) ListActiveServers(_ context.Context) ([]models.Server, error) {
	var result []models.Server
	for _, s := range m.servers {
		if s.IsActive {
			result = append(result, *s)
		}
	}
	return result, nil
}

func (m *fullMockServerStore) GetServerByID(_ context.Context, id uuid.UUID) (*models.Server, error) {
	s, ok := m.servers[id]
	if !ok {
		return nil, store.ErrServerNotFound
	}
	return s, nil
}

func setupServerRouter() (http.Handler, *fullMockServerStore, *auth.JWTService) {
	ms := newMockUserStore()
	ss := newFullMockServerStore()
	jwtSvc := auth.NewJWTService("test-secret")
	router := NewRouter(ms, ss, jwtSvc)
	return router, ss, jwtSvc
}

func getWithAuth(router http.Handler, path, token string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodGet, path, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	return w
}

func TestGetServer_Success(t *testing.T) {
	router, ss, jwtSvc := setupServerRouter()

	serverID := uuid.New()
	ss.servers[serverID] = &models.Server{
		ID:       serverID,
		Name:     "US East",
		Country:  "US",
		Host:     "203.0.113.1",
		Port:     51820,
		IsActive: true,
	}

	access, _, _ := jwtSvc.GenerateTokenPair(uuid.New())
	w := getWithAuth(router, "/api/v1/servers/"+serverID.String(), access)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp models.ServerResponse
	json.NewDecoder(w.Body).Decode(&resp)
	if resp.ID != serverID {
		t.Fatalf("expected server ID %s, got %s", serverID, resp.ID)
	}
	if resp.Name != "US East" {
		t.Fatalf("expected name 'US East', got %q", resp.Name)
	}
}

func TestGetServer_NotFound(t *testing.T) {
	router, _, jwtSvc := setupServerRouter()

	access, _, _ := jwtSvc.GenerateTokenPair(uuid.New())
	w := getWithAuth(router, "/api/v1/servers/"+uuid.New().String(), access)

	if w.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d: %s", w.Code, w.Body.String())
	}
}

func TestGetServer_InvalidID(t *testing.T) {
	router, _, jwtSvc := setupServerRouter()

	access, _, _ := jwtSvc.GenerateTokenPair(uuid.New())
	w := getWithAuth(router, "/api/v1/servers/not-a-uuid", access)

	if w.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d: %s", w.Code, w.Body.String())
	}
}

func TestGetServer_NoAuth(t *testing.T) {
	router, _, _ := setupServerRouter()

	req := httptest.NewRequest(http.MethodGet, "/api/v1/servers/"+uuid.New().String(), nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d: %s", w.Code, w.Body.String())
	}
}

func TestGetServer_InvalidToken(t *testing.T) {
	router, _, _ := setupServerRouter()

	w := getWithAuth(router, "/api/v1/servers/"+uuid.New().String(), "invalid-token")

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d: %s", w.Code, w.Body.String())
	}
}
