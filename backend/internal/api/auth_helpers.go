package api

import (
	"strings"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"vpn-dan/backend/internal/auth"
)

func authenticateRequest(jwt *auth.JWTService, authHeader string) (uuid.UUID, error) {
	token, found := strings.CutPrefix(authHeader, "Bearer ")
	if !found {
		return uuid.Nil, huma.Error401Unauthorized("invalid authorization format")
	}

	userID, err := jwt.ValidateAccessToken(token)
	if err != nil {
		return uuid.Nil, huma.Error401Unauthorized("invalid or expired token")
	}

	return userID, nil
}

func authenticateAdminRequest(jwt *auth.JWTService, authHeader string) (uuid.UUID, error) {
	token, found := strings.CutPrefix(authHeader, "Bearer ")
	if !found {
		return uuid.Nil, huma.Error401Unauthorized("invalid authorization format")
	}

	userID, err := jwt.ValidateAdminAccessToken(token)
	if err != nil {
		return uuid.Nil, huma.Error403Forbidden("admin access required")
	}

	return userID, nil
}
