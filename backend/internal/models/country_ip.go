package models

import (
	"time"

	"github.com/google/uuid"
)

type CountryIP struct {
	ID        uuid.UUID `json:"id" db:"id"`
	Country   string    `json:"country" db:"country"`
	CIDR      string    `json:"cidr" db:"cidr"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

type CountryCIDRsResponse struct {
	Country string   `json:"country" doc:"ISO 3166-1 alpha-2 country code"`
	CIDRs   []string `json:"cidrs" doc:"List of CIDR ranges for this country"`
}

type AvailableCountry struct {
	Country string `json:"country" doc:"ISO 3166-1 alpha-2 country code"`
	Count   int    `json:"count" doc:"Number of CIDR ranges"`
}
