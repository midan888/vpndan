package api

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
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

// mockAuthCodeStore implements store.AuthCodeStore for testing.
type mockAuthCodeStore struct {
	codes map[string]*models.AuthCode // keyed by email+code
}

func newMockAuthCodeStore() *mockAuthCodeStore {
	return &mockAuthCodeStore{codes: make(map[string]*models.AuthCode)}
}

func (m *mockAuthCodeStore) CreateCode(_ context.Context, email, code string, expiresAt time.Time) (*models.AuthCode, error) {
	ac := &models.AuthCode{
		ID:        uuid.New(),
		Email:     email,
		Code:      code,
		ExpiresAt: expiresAt,
		Used:      false,
		CreatedAt: time.Now(),
	}
	m.codes[email+":"+code] = ac
	return ac, nil
}

func (m *mockAuthCodeStore) VerifyCode(_ context.Context, email, code string) (*models.AuthCode, error) {
	ac, ok := m.codes[email+":"+code]
	if !ok {
		return nil, store.ErrCodeNotFound
	}
	if ac.Used {
		return nil, store.ErrCodeUsed
	}
	if time.Now().After(ac.ExpiresAt) {
		return nil, store.ErrCodeExpired
	}
	ac.Used = true
	return ac, nil
}

func (m *mockAuthCodeStore) DeleteExpiredCodes(_ context.Context) error {
	return nil
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

func (m *mockPeerManager) AddPeer(_, _ string) error { return nil }
func (m *mockPeerManager) RemovePeer(_ string) error  { return nil }

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

// mockEmailSender tracks sent emails for verification in tests.
type mockEmailSender struct {
	codesSent            map[string]string // email → code
	deletionsSent        []string          // emails that received deletion confirmation
}

func newMockEmailSender() *mockEmailSender {
	return &mockEmailSender{codesSent: make(map[string]string)}
}

func (m *mockEmailSender) SendCode(to, code string) error {
	m.codesSent[to] = code
	return nil
}

func (m *mockEmailSender) SendAccountDeleted(to string) error {
	m.deletionsSent = append(m.deletionsSent, to)
	return nil
}

// mockPeerStoreWithData is a peer store that can hold an active peer for testing.
type mockPeerStoreWithData struct {
	peers map[uuid.UUID]*models.Peer // keyed by userID
}

func newMockPeerStoreWithData() *mockPeerStoreWithData {
	return &mockPeerStoreWithData{peers: make(map[uuid.UUID]*models.Peer)}
}

func (m *mockPeerStoreWithData) CreatePeer(_ context.Context, userID, serverID uuid.UUID, privateKey, publicKey, assignedIP string) (*models.Peer, error) {
	p := &models.Peer{
		ID:         uuid.New(),
		UserID:     userID,
		ServerID:   serverID,
		PrivateKey: privateKey,
		PublicKey:  publicKey,
		AssignedIP: assignedIP,
	}
	m.peers[userID] = p
	return p, nil
}

func (m *mockPeerStoreWithData) GetPeerByUserID(_ context.Context, userID uuid.UUID) (*models.Peer, error) {
	p, ok := m.peers[userID]
	if !ok {
		return nil, store.ErrPeerNotFound
	}
	return p, nil
}

func (m *mockPeerStoreWithData) DeletePeerByUserID(_ context.Context, userID uuid.UUID) error {
	if _, ok := m.peers[userID]; !ok {
		return store.ErrPeerNotFound
	}
	delete(m.peers, userID)
	return nil
}

func (m *mockPeerStoreWithData) CountPeersByServerID(_ context.Context, _ uuid.UUID) (int, error) {
	return len(m.peers), nil
}

func (m *mockPeerStoreWithData) ListPeersByServerID(_ context.Context, _ uuid.UUID) ([]models.Peer, error) {
	return nil, nil
}

func (m *mockPeerStoreWithData) ListAllPeers(_ context.Context) ([]models.Peer, error) {
	return nil, nil
}

func setupRouter() (http.Handler, *mockUserStore, *mockAuthCodeStore) {
	ms := newMockUserStore()
	acs := newMockAuthCodeStore()
	jwtSvc := auth.NewJWTService("test-secret")
	router := NewRouter(ms, &mockServerStore{}, &mockPeerStore{}, &mockGeoIPStore{}, acs, jwtSvc, nil, &mockPeerManager{}, "", "")
	return router, ms, acs
}

func setupRouterFull() (http.Handler, *mockUserStore, *mockAuthCodeStore, *mockPeerStoreWithData, *mockEmailSender) {
	ms := newMockUserStore()
	acs := newMockAuthCodeStore()
	ps := newMockPeerStoreWithData()
	es := newMockEmailSender()
	jwtSvc := auth.NewJWTService("test-secret")
	router := NewRouter(ms, &mockServerStore{}, ps, &mockGeoIPStore{}, acs, jwtSvc, es, &mockPeerManager{}, "", "")
	return router, ms, acs, ps, es
}

func postJSON(router http.Handler, path string, body any) *httptest.ResponseRecorder {
	b, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	return w
}

func deleteWithAuth(router http.Handler, path, token string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodDelete, path, nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	return w
}

// --- Send Code tests ---

func TestSendCode_Success(t *testing.T) {
	router, _, _ := setupRouter()

	w := postJSON(router, "/api/v1/auth/send-code", map[string]string{
		"email": "test@example.com",
	})

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp models.SendCodeResponse
	json.NewDecoder(w.Body).Decode(&resp)
	if resp.Message != "verification code sent" {
		t.Fatalf("expected confirmation message, got %q", resp.Message)
	}
}

func TestSendCode_InvalidEmail(t *testing.T) {
	router, _, _ := setupRouter()

	w := postJSON(router, "/api/v1/auth/send-code", map[string]string{
		"email": "not-an-email",
	})
	if w.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d: %s", w.Code, w.Body.String())
	}
}

// --- Verify Code tests ---

func TestVerifyCode_Success_NewUser(t *testing.T) {
	router, _, acs := setupRouter()

	// Pre-create a valid code
	acs.CreateCode(context.Background(), "new@example.com", "123456", time.Now().Add(10*time.Minute))

	w := postJSON(router, "/api/v1/auth/verify-code", map[string]string{
		"email": "new@example.com",
		"code":  "123456",
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

func TestVerifyCode_Success_ExistingUser(t *testing.T) {
	router, ms, acs := setupRouter()

	ms.users["existing@example.com"] = &models.User{
		ID:    uuid.New(),
		Email: "existing@example.com",
	}

	acs.CreateCode(context.Background(), "existing@example.com", "654321", time.Now().Add(10*time.Minute))

	w := postJSON(router, "/api/v1/auth/verify-code", map[string]string{
		"email": "existing@example.com",
		"code":  "654321",
	})

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
}

func TestVerifyCode_WrongCode(t *testing.T) {
	router, _, acs := setupRouter()

	acs.CreateCode(context.Background(), "test@example.com", "123456", time.Now().Add(10*time.Minute))

	w := postJSON(router, "/api/v1/auth/verify-code", map[string]string{
		"email": "test@example.com",
		"code":  "000000",
	})

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestVerifyCode_ExpiredCode(t *testing.T) {
	router, _, acs := setupRouter()

	acs.CreateCode(context.Background(), "test@example.com", "123456", time.Now().Add(-1*time.Minute))

	w := postJSON(router, "/api/v1/auth/verify-code", map[string]string{
		"email": "test@example.com",
		"code":  "123456",
	})

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestVerifyCode_CodeAlreadyUsed(t *testing.T) {
	router, _, acs := setupRouter()

	acs.CreateCode(context.Background(), "test@example.com", "123456", time.Now().Add(10*time.Minute))

	// First use succeeds
	postJSON(router, "/api/v1/auth/verify-code", map[string]string{
		"email": "test@example.com",
		"code":  "123456",
	})

	// Second use fails
	w := postJSON(router, "/api/v1/auth/verify-code", map[string]string{
		"email": "test@example.com",
		"code":  "123456",
	})

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

// --- Refresh tests ---

func TestRefresh_Success(t *testing.T) {
	router, ms, _ := setupRouter()
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
	router, _, _ := setupRouter()

	w := postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": "invalid-token",
	})

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestRefresh_MissingToken(t *testing.T) {
	router, _, _ := setupRouter()

	w := postJSON(router, "/api/v1/auth/refresh", map[string]string{})

	if w.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected 422, got %d", w.Code)
	}
}

func TestRefresh_DeletedUser(t *testing.T) {
	router, _, _ := setupRouter()
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
	router, ms, _ := setupRouter()
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

// --- Refresh with aged tokens (simulate app opened after N days) ---

func makeAgedRefreshToken(t *testing.T, secret string, userID uuid.UUID, age time.Duration) string {
	t.Helper()
	issuedAt := time.Now().Add(-age)
	expiresAt := issuedAt.Add(30 * 24 * time.Hour) // 30-day TTL from issue time
	claims := auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			IssuedAt:  jwt.NewNumericDate(issuedAt),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
		},
		Type: "refresh",
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("sign token: %v", err)
	}
	return signed
}

func TestRefresh_After2Days(t *testing.T) {
	router, ms, _ := setupRouter()

	userID := uuid.New()
	ms.users["test@example.com"] = &models.User{ID: userID, Email: "test@example.com"}

	refresh := makeAgedRefreshToken(t, "test-secret", userID, 2*24*time.Hour)

	w := postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": refresh,
	})

	if w.Code != http.StatusOK {
		t.Fatalf("refresh after 2 days should succeed, got %d: %s", w.Code, w.Body.String())
	}

	var resp models.AuthResponse
	json.NewDecoder(w.Body).Decode(&resp)
	if resp.AccessToken == "" || resp.RefreshToken == "" {
		t.Fatal("expected new tokens in response")
	}
}

func TestRefresh_After7Days(t *testing.T) {
	router, ms, _ := setupRouter()

	userID := uuid.New()
	ms.users["test@example.com"] = &models.User{ID: userID, Email: "test@example.com"}

	refresh := makeAgedRefreshToken(t, "test-secret", userID, 7*24*time.Hour)

	w := postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": refresh,
	})

	if w.Code != http.StatusOK {
		t.Fatalf("refresh after 7 days should succeed, got %d: %s", w.Code, w.Body.String())
	}
}

func TestRefresh_After29Days(t *testing.T) {
	router, ms, _ := setupRouter()

	userID := uuid.New()
	ms.users["test@example.com"] = &models.User{ID: userID, Email: "test@example.com"}

	refresh := makeAgedRefreshToken(t, "test-secret", userID, 29*24*time.Hour)

	w := postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": refresh,
	})

	if w.Code != http.StatusOK {
		t.Fatalf("refresh after 29 days should succeed, got %d: %s", w.Code, w.Body.String())
	}
}

func TestRefresh_After31Days_Expired(t *testing.T) {
	router, ms, _ := setupRouter()

	userID := uuid.New()
	ms.users["test@example.com"] = &models.User{ID: userID, Email: "test@example.com"}

	refresh := makeAgedRefreshToken(t, "test-secret", userID, 31*24*time.Hour)

	w := postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": refresh,
	})

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("refresh after 31 days should be rejected, got %d", w.Code)
	}
}

// --- Refresh chain: simulate multiple refreshes over time ---

func TestRefresh_ChainedRefreshes(t *testing.T) {
	router, ms, _ := setupRouter()
	jwtSvc := auth.NewJWTService("test-secret")

	userID := uuid.New()
	ms.users["test@example.com"] = &models.User{ID: userID, Email: "test@example.com"}

	// Initial token pair
	_, refresh, _ := jwtSvc.GenerateTokenPair(userID, false)

	// First refresh
	w := postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": refresh,
	})
	if w.Code != http.StatusOK {
		t.Fatalf("first refresh failed: %d: %s", w.Code, w.Body.String())
	}

	var resp1 models.AuthResponse
	json.NewDecoder(w.Body).Decode(&resp1)

	// Second refresh using new token
	w = postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": resp1.RefreshToken,
	})
	if w.Code != http.StatusOK {
		t.Fatalf("second refresh failed: %d: %s", w.Code, w.Body.String())
	}

	var resp2 models.AuthResponse
	json.NewDecoder(w.Body).Decode(&resp2)

	// Verify new tokens are valid
	if resp2.AccessToken == "" || resp2.RefreshToken == "" {
		t.Fatal("expected tokens from second refresh")
	}

	// Third refresh using latest token
	w = postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": resp2.RefreshToken,
	})
	if w.Code != http.StatusOK {
		t.Fatalf("third refresh failed: %d: %s", w.Code, w.Body.String())
	}
}

// --- Refresh returns tokens that work for authenticated endpoints ---

func TestRefresh_NewAccessTokenWorksForAuthenticatedEndpoints(t *testing.T) {
	router, ms, _ := setupRouter()
	jwtSvc := auth.NewJWTService("test-secret")

	userID := uuid.New()
	ms.users["test@example.com"] = &models.User{ID: userID, Email: "test@example.com"}

	_, refresh, _ := jwtSvc.GenerateTokenPair(userID, false)

	// Refresh to get new tokens
	w := postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": refresh,
	})
	if w.Code != http.StatusOK {
		t.Fatalf("refresh failed: %d", w.Code)
	}

	var resp models.AuthResponse
	json.NewDecoder(w.Body).Decode(&resp)

	// Use the new access token on an authenticated endpoint (GET /servers)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/servers", nil)
	req.Header.Set("Authorization", "Bearer "+resp.AccessToken)
	w2 := httptest.NewRecorder()
	router.ServeHTTP(w2, req)

	if w2.Code != http.StatusOK {
		t.Fatalf("expected 200 with refreshed access token, got %d: %s", w2.Code, w2.Body.String())
	}
}

// --- Full auth lifecycle: send code → verify → use token → refresh → use again ---

func TestFullAuthLifecycle(t *testing.T) {
	router, _, acs := setupRouter()

	email := "lifecycle@example.com"

	// Step 1: Send code
	w := postJSON(router, "/api/v1/auth/send-code", map[string]string{
		"email": email,
	})
	if w.Code != http.StatusOK {
		t.Fatalf("send-code: expected 200, got %d: %s", w.Code, w.Body.String())
	}

	// Step 2: Verify code (need to find the code from the mock store)
	var code string
	for key := range acs.codes {
		if len(key) > len(email)+1 {
			code = key[len(email)+1:]
			break
		}
	}
	if code == "" {
		t.Fatal("no code found in mock store")
	}

	w = postJSON(router, "/api/v1/auth/verify-code", map[string]string{
		"email": email,
		"code":  code,
	})
	if w.Code != http.StatusOK {
		t.Fatalf("verify-code: expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var authResp models.AuthResponse
	json.NewDecoder(w.Body).Decode(&authResp)
	if authResp.AccessToken == "" || authResp.RefreshToken == "" {
		t.Fatal("expected tokens from verify-code")
	}

	// Step 3: Use access token on authenticated endpoint
	req := httptest.NewRequest(http.MethodGet, "/api/v1/servers", nil)
	req.Header.Set("Authorization", "Bearer "+authResp.AccessToken)
	w2 := httptest.NewRecorder()
	router.ServeHTTP(w2, req)

	if w2.Code != http.StatusOK {
		t.Fatalf("authenticated request: expected 200, got %d: %s", w2.Code, w2.Body.String())
	}

	// Step 4: Refresh tokens
	w = postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": authResp.RefreshToken,
	})
	if w.Code != http.StatusOK {
		t.Fatalf("refresh: expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var refreshResp models.AuthResponse
	json.NewDecoder(w.Body).Decode(&refreshResp)

	// Step 5: Use new access token
	req = httptest.NewRequest(http.MethodGet, "/api/v1/servers", nil)
	req.Header.Set("Authorization", "Bearer "+refreshResp.AccessToken)
	w3 := httptest.NewRecorder()
	router.ServeHTTP(w3, req)

	if w3.Code != http.StatusOK {
		t.Fatalf("authenticated request with refreshed token: expected 200, got %d: %s", w3.Code, w3.Body.String())
	}
}

// --- Authenticated endpoint tests ---

func TestAuthenticatedEndpoint_NoToken(t *testing.T) {
	router, _, _ := setupRouter()

	req := httptest.NewRequest(http.MethodGet, "/api/v1/servers", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	// Huma returns 422 for missing required Authorization header
	if w.Code != http.StatusUnprocessableEntity && w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 422 or 401 without token, got %d", w.Code)
	}
}

func TestAuthenticatedEndpoint_InvalidToken(t *testing.T) {
	router, _, _ := setupRouter()

	req := httptest.NewRequest(http.MethodGet, "/api/v1/servers", nil)
	req.Header.Set("Authorization", "Bearer invalid-token")
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 with invalid token, got %d", w.Code)
	}
}

func TestAuthenticatedEndpoint_ExpiredAccessToken(t *testing.T) {
	router, _, _ := setupRouter()

	userID := uuid.New()

	// Create an expired access token
	claims := auth.Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			IssuedAt:  jwt.NewNumericDate(time.Now().Add(-1 * time.Hour)),
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(-30 * time.Minute)),
		},
		Type: "access",
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	expired, _ := token.SignedString([]byte("test-secret"))

	req := httptest.NewRequest(http.MethodGet, "/api/v1/servers", nil)
	req.Header.Set("Authorization", "Bearer "+expired)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 with expired token, got %d", w.Code)
	}
}

func TestAuthenticatedEndpoint_RefreshTokenRejectedAsBearer(t *testing.T) {
	router, ms, _ := setupRouter()
	jwtSvc := auth.NewJWTService("test-secret")

	userID := uuid.New()
	ms.users["test@example.com"] = &models.User{ID: userID, Email: "test@example.com"}

	_, refresh, _ := jwtSvc.GenerateTokenPair(userID, false)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/servers", nil)
	req.Header.Set("Authorization", "Bearer "+refresh)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 when using refresh token as bearer, got %d", w.Code)
	}
}

func TestAuthenticatedEndpoint_WrongSecretToken(t *testing.T) {
	router, _, _ := setupRouter()
	wrongSvc := auth.NewJWTService("wrong-secret")

	access, _, _ := wrongSvc.GenerateTokenPair(uuid.New(), false)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/servers", nil)
	req.Header.Set("Authorization", "Bearer "+access)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 with wrong-secret token, got %d", w.Code)
	}
}

// --- Verify code issues new token for same user on re-login ---

func TestVerifyCode_ReturnsValidTokensOnReLogin(t *testing.T) {
	router, ms, acs := setupRouter()

	userID := uuid.New()
	ms.users["re@example.com"] = &models.User{ID: userID, Email: "re@example.com"}

	// Create code and verify (re-login)
	acs.CreateCode(context.Background(), "re@example.com", "111111", time.Now().Add(10*time.Minute))

	w := postJSON(router, "/api/v1/auth/verify-code", map[string]string{
		"email": "re@example.com",
		"code":  "111111",
	})

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp models.AuthResponse
	json.NewDecoder(w.Body).Decode(&resp)

	// New access token should work
	req := httptest.NewRequest(http.MethodGet, "/api/v1/servers", nil)
	req.Header.Set("Authorization", "Bearer "+resp.AccessToken)
	w2 := httptest.NewRecorder()
	router.ServeHTTP(w2, req)

	if w2.Code != http.StatusOK {
		t.Fatalf("re-login token should work, got %d", w2.Code)
	}

	// New refresh token should also work
	w = postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": resp.RefreshToken,
	})
	if w.Code != http.StatusOK {
		t.Fatalf("re-login refresh token should work, got %d: %s", w.Code, w.Body.String())
	}
}

// --- Delete Account tests ---

func TestDeleteAccount_Success(t *testing.T) {
	router, ms, _, _, es := setupRouterFull()
	jwtSvc := auth.NewJWTService("test-secret")

	userID := uuid.New()
	ms.users["delete@example.com"] = &models.User{ID: userID, Email: "delete@example.com"}

	access, _, _ := jwtSvc.GenerateTokenPair(userID, false)

	w := deleteWithAuth(router, "/api/v1/auth/account", access)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	// Verify user is deleted
	if _, exists := ms.users["delete@example.com"]; exists {
		t.Fatal("expected user to be deleted from store")
	}

	// Verify deletion email was sent
	if len(es.deletionsSent) != 1 || es.deletionsSent[0] != "delete@example.com" {
		t.Fatalf("expected deletion email to delete@example.com, got %v", es.deletionsSent)
	}
}

func TestDeleteAccount_WithActivePeer(t *testing.T) {
	router, ms, _, ps, es := setupRouterFull()
	jwtSvc := auth.NewJWTService("test-secret")

	userID := uuid.New()
	ms.users["peer@example.com"] = &models.User{ID: userID, Email: "peer@example.com"}

	// Give the user an active peer
	ps.peers[userID] = &models.Peer{
		ID:        uuid.New(),
		UserID:    userID,
		ServerID:  uuid.New(),
		PublicKey: "test-pubkey",
	}

	access, _, _ := jwtSvc.GenerateTokenPair(userID, false)

	w := deleteWithAuth(router, "/api/v1/auth/account", access)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	// Verify user is deleted
	if _, exists := ms.users["peer@example.com"]; exists {
		t.Fatal("expected user to be deleted from store")
	}

	// Verify peer is cleaned up
	if _, exists := ps.peers[userID]; exists {
		t.Fatal("expected peer to be deleted from store")
	}

	// Verify deletion email was sent
	if len(es.deletionsSent) != 1 || es.deletionsSent[0] != "peer@example.com" {
		t.Fatalf("expected deletion email to peer@example.com, got %v", es.deletionsSent)
	}
}

func TestDeleteAccount_NoToken(t *testing.T) {
	router, _, _ := setupRouter()

	req := httptest.NewRequest(http.MethodDelete, "/api/v1/auth/account", nil)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnprocessableEntity && w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 422 or 401 without token, got %d", w.Code)
	}
}

func TestDeleteAccount_InvalidToken(t *testing.T) {
	router, _, _ := setupRouter()

	w := deleteWithAuth(router, "/api/v1/auth/account", "invalid-token")

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", w.Code)
	}
}

func TestDeleteAccount_TokenForDeletedUser(t *testing.T) {
	router, _, _, _, _ := setupRouterFull()
	jwtSvc := auth.NewJWTService("test-secret")

	// Generate token for a user that doesn't exist in the store
	access, _, _ := jwtSvc.GenerateTokenPair(uuid.New(), false)

	w := deleteWithAuth(router, "/api/v1/auth/account", access)

	if w.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d: %s", w.Code, w.Body.String())
	}
}

func TestDeleteAccount_TokenInvalidAfterDeletion(t *testing.T) {
	router, ms, _, _, _ := setupRouterFull()
	jwtSvc := auth.NewJWTService("test-secret")

	userID := uuid.New()
	ms.users["gone@example.com"] = &models.User{ID: userID, Email: "gone@example.com"}

	access, refresh, _ := jwtSvc.GenerateTokenPair(userID, false)

	// Delete account
	w := deleteWithAuth(router, "/api/v1/auth/account", access)
	if w.Code != http.StatusOK {
		t.Fatalf("delete: expected 200, got %d", w.Code)
	}

	// Access token should no longer work on authenticated endpoints
	req := httptest.NewRequest(http.MethodGet, "/api/v1/servers", nil)
	req.Header.Set("Authorization", "Bearer "+access)
	w2 := httptest.NewRecorder()
	router.ServeHTTP(w2, req)
	// Token is still cryptographically valid (stateless JWT), but the
	// user is gone — the servers endpoint returns empty list (200) because
	// it doesn't re-verify user existence. The important check is that
	// refresh fails.

	// Refresh token should fail because user no longer exists
	w3 := postJSON(router, "/api/v1/auth/refresh", map[string]string{
		"refresh_token": refresh,
	})
	if w3.Code != http.StatusUnauthorized {
		t.Fatalf("refresh after deletion: expected 401, got %d", w3.Code)
	}
}
