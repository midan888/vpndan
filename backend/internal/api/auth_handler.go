package api

import (
	"context"
	"errors"

	"github.com/danielgtaylor/huma/v2"
	"golang.org/x/crypto/bcrypt"
	"vpn-dan/backend/internal/auth"
	"vpn-dan/backend/internal/models"
	"vpn-dan/backend/internal/store"
)

type AuthHandler struct {
	users store.UserStore
	jwt   *auth.JWTService
}

func NewAuthHandler(users store.UserStore, jwt *auth.JWTService) *AuthHandler {
	return &AuthHandler{users: users, jwt: jwt}
}

// Input/Output types for huma

type RegisterInput struct {
	Body models.RegisterRequest
}

type RegisterOutput struct {
	Body models.AuthResponse
}

type LoginInput struct {
	Body models.LoginRequest
}

type LoginOutput struct {
	Body models.AuthResponse
}

type RefreshInput struct {
	Body models.RefreshRequest
}

type RefreshOutput struct {
	Body models.AuthResponse
}

func (h *AuthHandler) Register(ctx context.Context, input *RegisterInput) (*RegisterOutput, error) {
	hashed, err := bcrypt.GenerateFromPassword([]byte(input.Body.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	user, err := h.users.CreateUser(ctx, input.Body.Email, string(hashed))
	if err != nil {
		if errors.Is(err, store.ErrEmailExists) {
			return nil, huma.Error409Conflict("an account with this email already exists")
		}
		return nil, huma.Error500InternalServerError("internal server error")
	}

	accessToken, refreshToken, err := h.jwt.GenerateTokenPair(user.ID, false)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	return &RegisterOutput{Body: models.AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
	}}, nil
}

func (h *AuthHandler) Login(ctx context.Context, input *LoginInput) (*LoginOutput, error) {
	user, err := h.users.GetUserByEmail(ctx, input.Body.Email)
	if err != nil {
		if errors.Is(err, store.ErrUserNotFound) {
			return nil, huma.Error401Unauthorized("invalid email or password")
		}
		return nil, huma.Error500InternalServerError("internal server error")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(input.Body.Password)); err != nil {
		return nil, huma.Error401Unauthorized("invalid email or password")
	}

	accessToken, refreshToken, err := h.jwt.GenerateTokenPair(user.ID, user.IsAdmin)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	return &LoginOutput{Body: models.AuthResponse{
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

