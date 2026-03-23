package api

import (
	"context"
	"strings"

	"vpn-dan/backend/internal/auth"
	"vpn-dan/backend/internal/models"
	"vpn-dan/backend/internal/store"

	"github.com/danielgtaylor/huma/v2"
)

type GeoIPHandler struct {
	geoip store.GeoIPStore
	jwt   *auth.JWTService
}

func NewGeoIPHandler(geoip store.GeoIPStore, jwt *auth.JWTService) *GeoIPHandler {
	return &GeoIPHandler{geoip: geoip, jwt: jwt}
}

// GET /api/v1/geoip/countries

type ListGeoIPCountriesInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer access token"`
}

type ListGeoIPCountriesOutput struct {
	Body []models.AvailableCountry
}

func (h *GeoIPHandler) ListCountries(ctx context.Context, input *ListGeoIPCountriesInput) (*ListGeoIPCountriesOutput, error) {
	if _, err := authenticateRequest(h.jwt, input.Authorization); err != nil {
		return nil, err
	}

	countries, err := h.geoip.ListAvailableCountries(ctx)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	return &ListGeoIPCountriesOutput{Body: countries}, nil
}

// GET /api/v1/geoip/{country}

type GetCountryCIDRsInput struct {
	Authorization string `header:"Authorization" required:"true" doc:"Bearer access token"`
	Country       string `path:"country" doc:"ISO 3166-1 alpha-2 country code (e.g. US, DE)"`
}

type GetCountryCIDRsOutput struct {
	Body models.CountryCIDRsResponse
}

func (h *GeoIPHandler) GetCountryCIDRs(ctx context.Context, input *GetCountryCIDRsInput) (*GetCountryCIDRsOutput, error) {
	if _, err := authenticateRequest(h.jwt, input.Authorization); err != nil {
		return nil, err
	}

	country := strings.ToUpper(strings.TrimSpace(input.Country))
	if len(country) != 2 {
		return nil, huma.Error400BadRequest("country must be a 2-letter ISO code")
	}

	cidrs, err := h.geoip.GetCIDRsByCountry(ctx, country)
	if err != nil {
		return nil, huma.Error500InternalServerError("internal server error")
	}

	if len(cidrs) == 0 {
		return nil, huma.Error404NotFound("no CIDR data for country: " + country)
	}

	return &GetCountryCIDRsOutput{
		Body: models.CountryCIDRsResponse{
			Country: country,
			CIDRs:   cidrs,
		},
	}, nil
}
