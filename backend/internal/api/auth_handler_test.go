package api

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"vpn-dan/backend/internal/auth"
	"vpn-dan/backend/internal/models"
	"vpn-dan/backend/internal/store"
)

// mockUserStore implements store.UserStore for testing.
type mockUserStore struct {
	users map[string]*models.User
}

func newMockUserStore() *mockUserStore {
	return &mockUserStore{users: make(map[string]*models.User)}
}

func (m *mockUserStore) CreateUser(_ context.Context, email, hashedPassword string) (*models.User, error) {
	if _, exists := m.users[email]; exists {
		return nil, store.ErrEmailExists
	}
	user := &models.User{
		ID:       uuid.New(),
		Email:    email,
		Password: hashedPassword,
	}
	m.users[email] = user
	return user, nil
}

func (m *mockUserStore) GetUserByEmail(_ context.Context, email string) (*models.User, error) {
	user, ok := m.users[email]
	if !ok {
		return nil, store.ErrUserNotFound
	}
	return user, nil
}

func (m *mockUserStore) GetUserByID(_ context.Context, id uuid.UUID) (*models.User, error) {
	for _, user := range m.users {
		if user.ID == id {
			return user, nil
		}
	}
	return nil, store.ErrUserNotFound
}

func (m *mockUserStore) ListUsers(_ context.Context) ([]models.User, error) {
	var users []models.User
	for _, u := range m.users {
		users = append(users, *u)
	}
	return users, nil
}

func (m *mockUserStore) UpdatePassword(_ context.Context, id uuid.UUID, hashedPassword string) error {
	for _, u := range m.users {
		if u.ID == id {
			u.Password = hashedPassword
			return nil
		}
	}
	return store.ErrUserNotFound
}

func (m *mockUserStore) DeleteUser(_ context.Context, id uuid.UUID) error {
	for email, u := range m.users {
		if u.ID == id {
			delete(m.users, email)
			return nil
		}
	}
	return store.ErrUserNotFound
}

func (m *mockUserStore) SetAdmin(_ context.Context, id uuid.UUID, isAdmin bool) error {
	for _, u := range m.users {
		if u.ID == id {
			u.IsAdmin = isAdmin
			return nil
		}
	}
	return store.ErrUserNotFound
}

type mockServerStore struct{}

func (m *mockServerStore) ListActiveServers(_ context.Context) ([]models.Server, error) {
	return nil, nil
}

func (m *mockServerStore) GetServerByID(_ context.Context, _ uuid.UUID) (*models.Server, error) {
	return nil, store.ErrServerNotFound
}

func (m *mockServerStore) ListAllServers(_ context.Context) ([]models.Server, error) {
	return nil, nil
}

func (m *mockServerStore) CreateServer(_ context.Context, s *models.Server) (*models.Server, error) {
	return s, nil
}

func (m *mockServerStore) DeleteServer(_ context.Context, _ uuid.UUID) error {
	return store.ErrServerNotFound
}

func (m *mockServerStore) UpdateServerStatus(_ context.Context, _ uuid.UUID, _ bool) error {
	return store.ErrServerNotFound
}

func (m *mockServerStore) UpsertServerByHost(_ context.Context, s *models.Server) (*models.Server, error) {
	return s, nil
}

func (m *mockServerStore) UpdateHeartbeat(_ context.Context, _ string) error {
	return nil
}

func (m *mockServerStore) MarkStaleServersInactive(_ context.Context, _ time.Duration) (int, error) {
	return 0, nil
}

type mockGeoIPStore struct{}

func (m *mockGeoIPStore) GetCIDRsByCountry(_ context.Context, _ string) ([]string, error) {
	return nil, nil
}

func (m *mockGeoIPStore) ListAvailableCountries(_ context.Context) ([]models.AvailableCountry, error) {
	return nil, nil
}

func (m *mockGeoIPStore) BulkInsertCIDRs(_ context.Context, _ string, _ []string) error {
	return nil
}

func (m *mockGeoIPStore) DeleteByCountry(_ context.Context, _ string) error {
	return nil
}

type mockPeerManager struct{}

func (m *mockPeerManager) AddPeer(_, _ string) error    { return nil }
func (m *mockPeerManager) RemovePeer(_ string) error     { return nil }

type mockPeerStore struct{}

func (m *mockPeerStore) CreatePeer(_ context.Context, _, _ uuid.UUID, _, _, _ string) (*models.Peer, error) {
	return nil, nil
}
func (m *mockPeerStore) GetPeerByUserID(_ context.Context, _ uuid.UUID) (*models.Peer, error) {
	return nil, store.ErrPeerNotFound
}
func (m *mockPeerStore) DeletePeerByUserID(_ context.Context, _ uuid.UUID) error {
	return store.ErrPeerNotFound
}
func (m *mockPeerStore) CountPeersByServerID(_ context.Context, _ uuid.UUID) (int, error) {
	return 0, nil
}

func (m *mockPeerStore) ListPeersByServerID(_ context.Context, _ uuid.UUID) ([]models.Peer, error) {
	return nil, nil
}

func (m *mockPeerStore) ListAllPeers(_ context.Context) ([]models.Peer, error) {
	return nil, nil
}

func setupRouter() (http.Handler, *mockUserStore) {
	ms := newMockUserStore()
	jwtSvc := auth.NewJWTService("test-secret")
	router := NewRouter(ms, &mockServerStore{}, &mockPeerStore{}, &mockGeoIPStore{}, jwtSvc, &mockPeerManager{}, "", "")
	return router, ms
}

func postJSON(router http.Handler, path string, body any) *httptest.ResponseRecorder {
	b, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	return w
}

// --- Register tests ---

func TestRegister_Success(t *testing.T) {
	router, _ := setupRouter()

	w := postJSON(router, "/api/v1/auth/register", map[string]string{
		"email":    "test@example.com",
		"password": "password123",
	})

	if w.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", w.Code, w.Body.String())
	}

	var resp models.AuthResponse
	json.NewDecoder(w.Body).Decode(&resp)
	if resp.AccessToken == "" || resp.RefreshToken == "" {
		t.Fatal("expected tokens in response")
	}
}

func TestRegister_DuplicateEmail(t *testing.T) {
	router, _ := setupRouter()

	body := map[string]string{"email": "test@example.com", "password": "password123"}
	postJSON(router, "/api/v1/auth/register", body)

	w := postJSON(router, "/api/v1/auth/register", body)
	if w.Code != http.StatusConflict {
		t.Fatalf("expected 409, got %d", w.Code)
	}
}

func TestRegister_InvalidEmail(t *testing.T) {
	router, _ := setupRouter()

	w := postJSON(router, "/api/v1/auth/register", map[string]string{
		"email":    "not-an-email",
		"password": "password123",
	})
	if w.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d: %s", w.Code, w.Body.String())
	}
}

func TestRegister_ShortPassword(t *testing.T) {
	router, _ := setupRouter()

	w := postJSON(router, "/api/v1/auth/register", map[string]string{
		"email":    "test@example.com",
		"password": "short",
	})
	if w.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d: %s", w.Code, w.Body.String())
	}
}

func TestRegister_InvalidBody(t *testing.T) {
	router, _ := setupRouter()

	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/register", bytes.NewReader([]byte("not json")))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", w.Code)
	}
}

// --- Login tests ---

func TestLogin_Success(t *testing.T) {
	router, ms := setupRouter()

	hashed, _ := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.MinCost)
	ms.users["test@example.com"] = &models.User{
		ID:       uuid.New(),
		Email:    "test@example.com",
		Password: string(hashed),
	}

	w := postJSON(router, "/api/v1/auth/login", map[string]string{
		"email":    "test@example.com",
		"password": "password123",
	})

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp models.AuthResponse
	json.NewDecoder(w.Body).Decode(&resp)
	if resp.AccessToken == "" || resp.RefreshToken == "" {
		t.Fatal("expected tokens in response")
	}
}

func TestLogin_WrongPassword(t *testing.T) {
	router, ms := setupRouter()

	hashed, _ := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.MinCost)
	ms.users["test@example.com"] = &models.User{
		ID:       uuid.New(),
		Email:    "test@example.com",
		Password: string(hashed),
	}

	w := postJSON(router, "/api/v1/auth/login", map[string]string{
		"email":    "test@example.com",
		"password": "wrongpassword",
	})

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestLogin_UserNotFound(t *testing.T) {
	router, _ := setupRouter()

	w := postJSON(router, "/api/v1/auth/login", map[string]string{
		"email":    "nobody@example.com",
		"password": "password123",
	})

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestLogin_GenericErrorMessage(t *testing.T) {
	router, _ := setupRouter()

	w := postJSON(router, "/api/v1/auth/login", map[string]string{
		"email":    "nobody@example.com",
		"password": "password123",
	})

	var resp struct {
		Detail string `json:"detail"`
	}
	json.NewDecoder(w.Body).Decode(&resp)
	if resp.Detail != "invalid email or password" {
		t.Fatalf("expected generic error message, got %q", resp.Detail)
	}
}

// --- Refresh tests ---

func TestRefresh_Success(t *testing.T) {
	router, ms := setupRouter()
	jwtSvc := auth.NewJWTService("test-secret")

	userID := uuid.New()
	ms.users["test@example.com"] = &models.User{
		ID:    userID,
		Email: "test@example.com",
	}

	_, refresh, _ := jwtSvc.GenerateTokenPair(userID, false)

	w := postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": refresh,
	})

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp models.AuthResponse
	json.NewDecoder(w.Body).Decode(&resp)
	if resp.AccessToken == "" || resp.RefreshToken == "" {
		t.Fatal("expected tokens in response")
	}
}

func TestRefresh_InvalidToken(t *testing.T) {
	router, _ := setupRouter()

	w := postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": "invalid-token",
	})

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestRefresh_MissingToken(t *testing.T) {
	router, _ := setupRouter()

	w := postJSON(router, "/api/v1/auth/refresh", map[string]string{})

	if w.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d", w.Code)
	}
}

func TestRefresh_DeletedUser(t *testing.T) {
	router, _ := setupRouter()
	jwtSvc := auth.NewJWTService("test-secret")

	_, refresh, _ := jwtSvc.GenerateTokenPair(uuid.New(), false)

	w := postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": refresh,
	})

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestRefresh_AccessTokenRejected(t *testing.T) {
	router, ms := setupRouter()
	jwtSvc := auth.NewJWTService("test-secret")

	userID := uuid.New()
	ms.users["test@example.com"] = &models.User{ID: userID, Email: "test@example.com"}

	access, _, _ := jwtSvc.GenerateTokenPair(userID, false)

	w := postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": access,
	})

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}
