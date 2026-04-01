package api

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"log"
	"math/big"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"vpn-dan/backend/internal/auth"
	"vpn-dan/backend/internal/email"
	"vpn-dan/backend/internal/models"
	"vpn-dan/backend/internal/store"
	"vpn-dan/backend/internal/wireguard"
)

type AuthHandler struct {
	users     store.UserStore
	peers     store.PeerStore
	servers   store.ServerStore
	authCodes store.AuthCodeStore
	jwt       *auth.JWTService
	email     email.Sender
	wg        wireguard.PeerManager
}

func NewAuthHandler(users store.UserStore, peers store.PeerStore, servers store.ServerStore, authCodes store.AuthCodeStore, jwt *auth.JWTService, emailSender email.Sender, wg wireguard.PeerManager) *AuthHandler {
	return &AuthHandler{users: users, peers: peers, servers: servers, authCodes: authCodes, jwt: jwt, email: emailSender, wg: wg}
}

// Input/Output types for huma

type SendCodeInput struct {
	Body models.SendCodeRequest
}

type SendCodeOutput struct {
	Body models.SendCodeResponse
}

type VerifyCodeInput struct {
	Body models.VerifyCodeRequest
}

type VerifyCodeOutput struct {
	Body models.AuthResponse
}

type RefreshInput struct {
	Body models.RefreshRequest
}

type RefreshOutput struct {
	Body models.AuthResponse
}

func generateCode() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

func (h *AuthHandler) SendCode(ctx context.Context, input *SendCodeInput) (*SendCodeOutput, error) {
	code, err := generateCode()
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	expiresAt := time.Now().Add(10 * time.Minute)

	_, err = h.authCodes.CreateCode(ctx, input.Body.Email, code, expiresAt)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	if h.email != nil {
		if err := h.email.SendCode(input.Body.Email, code); err != nil {
			log.Printf("failed to send email to %s: %v", input.Body.Email, err)
			return nil, huma.Error500InternalServerError("failed to send verification email")
		}
	} else {
		// Dev fallback: log the code
		log.Printf("AUTH CODE for %s: %s", input.Body.Email, code)
	}

	return &SendCodeOutput{Body: models.SendCodeResponse{
		Message: "verification code sent",
	}}, nil
}

func (h *AuthHandler) VerifyCode(ctx context.Context, input *VerifyCodeInput) (*VerifyCodeOutput, error) {
	_, err := h.authCodes.VerifyCode(ctx, input.Body.Email, input.Body.Code)
	if err != nil {
		if errors.Is(err, store.ErrCodeNotFound) || errors.Is(err, store.ErrCodeUsed) {
			return nil, huma.Error401Unauthorized("invalid verification code")
		}
		if errors.Is(err, store.ErrCodeExpired) {
			return nil, huma.Error401Unauthorized("verification code expired")
		}
		return nil, huma.Error500InternalServerError("internal server error")
	}

	// Find or create user
	user, err := h.users.GetUserByEmail(ctx, input.Body.Email)
	if err != nil {
		if errors.Is(err, store.ErrUserNotFound) {
			// Auto-register
			user, err = h.users.CreateUser(ctx, input.Body.Email, "")
			if err != nil {
				return nil, huma.Error500InternalServerError("internal server error")
			}
		} else {
			return nil, huma.Error500InternalServerError("internal server error")
		}
	}

	accessToken, refreshToken, err := h.jwt.GenerateTokenPair(user.ID, user.IsAdmin)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	return &VerifyCodeOutput{Body: models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
	}}, nil
}

func (h *AuthHandler) Refresh(ctx context.Context, input *RefreshInput) (*RefreshOutput, error) {
	userID, err := h.jwt.ValidateRefreshToken(input.Body.RefreshToken)
	if err != nil {
		return nil, huma.Error401Unauthorized("invalid or expired refresh token")
	}

	user, err := h.users.GetUserByID(ctx, userID)
	if err != nil {
		return nil, huma.Error401Unauthorized("invalid or expired refresh token")
	}

	accessToken, refreshToken, err := h.jwt.GenerateTokenPair(userID, user.IsAdmin)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	return &RefreshOutput{Body: models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
	}}, nil
}

// DELETE /api/v1/auth/account

type DeleteAccountInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer access token"`
}

type DeleteAccountOutput struct {
	Body struct {
		Message string `json:"message" doc:"Account deletion confirmation"`
	}
}

func (h *AuthHandler) DeleteAccount(ctx context.Context, input *DeleteAccountInput) (*DeleteAccountOutput, error) {
	userID, err := authenticateRequest(h.jwt, input.Authorization)
	if err != nil {
		return nil, err
	}

	// Get user email before deletion (for confirmation email)
	user, err := h.users.GetUserByID(ctx, userID)
	if err != nil {
		if errors.Is(err, store.ErrUserNotFound) {
			return nil, huma.Error404NotFound("user not found")
		}
		return nil, huma.Error500InternalServerError("internal server error")
	}

	// Remove WireGuard peer if active
	peer, err := h.peers.GetPeerByUserID(ctx, userID)
	if err != nil && !errors.Is(err, store.ErrPeerNotFound) {
		return nil, huma.Error500InternalServerError("internal server error")
	}
	if peer != nil {
		wgManager := h.wg
		if srv, e := h.servers.GetServerByID(ctx, peer.ServerID); e == nil && srv.WGAdminURL != "" {
			wgManager = wireguard.NewHTTPPeerManager(srv.WGAdminURL)
		}
		_ = wgManager.RemovePeer(peer.PublicKey)
		_ = h.peers.DeletePeerByUserID(ctx, userID)
	}

	// Delete user from database
	if err := h.users.DeleteUser(ctx, userID); err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	// Send account deletion confirmation email
	if h.email != nil {
		if err := h.email.SendAccountDeleted(user.Email); err != nil {
			log.Printf("failed to send account deletion email to %s: %v", user.Email, err)
		}
	}

	out := &DeleteAccountOutput{}
	out.Body.Message = "account deleted"
	return out, nil
}
