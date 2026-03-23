package main

import (
	"bufio"
	"context"
	"encoding/binary"
	"fmt"
	"log"
	"math/bits"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
	"vpn-god/backend/internal/config"
)

// RIR delegation-stats URLs (IPv4 allocations per country)
var rirURLs = []string{
	"https://ftp.arin.net/pub/stats/arin/delegated-arin-extended-latest",
	"https://ftp.ripe.net/pub/stats/ripencc/delegated-ripencc-extended-latest",
	"https://ftp.apnic.net/pub/stats/apnic/delegated-apnic-extended-latest",
	"https://ftp.lacnic.net/pub/stats/lacnic/delegated-lacnic-extended-latest",
	"https://ftp.afrinic.net/pub/stats/afrinic/delegated-afrinic-extended-latest",
}

type allocation struct {
	country string
	cidr    string
}

func main() {
	config.LoadEnvFile(".env")

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL environment variable is required")
	}

	// Optional: only seed specific countries (comma-separated, e.g. "US,DE,NL,JP")
	filterCountries := map[string]bool{}
	if f := os.Getenv("COUNTRIES"); f != "" {
		for _, c := range strings.Split(strings.ToUpper(f), ",") {
			filterCountries[strings.TrimSpace(c)] = true
		}
		log.Printf("filtering to countries: %v", filterCountries)
	}

	db, err := sqlx.Connect("postgres", dbURL)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer db.Close()

	ctx := context.Background()
	client := &http.Client{Timeout: 5 * time.Minute}

	var allocs []allocation

	for _, url := range rirURLs {
		log.Printf("fetching %s ...", url)
		parsed, err := fetchAndParse(client, url, filterCountries)
		if err != nil {
			log.Printf("warning: failed to fetch %s: %v", url, err)
			continue
		}
		allocs = append(allocs, parsed...)
		log.Printf("  parsed %d allocations", len(parsed))
	}

	log.Printf("total allocations: %d", len(allocs))

	// Group by country
	byCountry := map[string][]string{}
	for _, a := range allocs {
		byCountry[a.country] = append(byCountry[a.country], a.cidr)
	}

	// Insert into database (delete + insert in same transaction per country)
	for country, cidrs := range byCountry {
		log.Printf("seeding %s: %d CIDRs", country, len(cidrs))

		if err := bulkInsert(ctx, db, country, cidrs); err != nil {
			log.Printf("warning: failed to insert %s: %v", country, err)
			continue
		}
	}

	total := 0
	for _, cidrs := range byCountry {
		total += len(cidrs)
	}
	log.Printf("done! seeded %d countries, %d total CIDRs", len(byCountry), total)
}

func fetchAndParse(client *http.Client, url string, filter map[string]bool) ([]allocation, error) {
	resp, err := client.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	var allocs []allocation
	scanner := bufio.NewScanner(resp.Body)
	for scanner.Scan() {
		line := scanner.Text()

		// Skip comments and headers
		if strings.HasPrefix(line, "#") || strings.HasPrefix(line, "*") {
			continue
		}

		// Format: registry|CC|type|start|value|date|status[|extensions]
		fields := strings.Split(line, "|")
		if len(fields) < 5 {
			continue
		}

		country := fields[1]
		typ := fields[2]
		start := fields[3]
		value := fields[4]

		// Only IPv4 allocations with a valid country code
		if typ != "ipv4" || len(country) != 2 {
			continue
		}

		// Filter if specified
		if len(filter) > 0 && !filter[strings.ToUpper(country)] {
			continue
		}

		// value = number of hosts; decompose into valid CIDRs
		hosts, err := strconv.Atoi(value)
		if err != nil || hosts <= 0 {
			continue
		}

		cidrs := ipRangeToCIDRs(net.ParseIP(start).To4(), uint32(hosts))
		for _, cidr := range cidrs {
			allocs = append(allocs, allocation{
				country: strings.ToUpper(country),
				cidr:    cidr,
			})
		}
	}

	return allocs, scanner.Err()
}

func bulkInsert(ctx context.Context, db *sqlx.DB, country string, cidrs []string) error {
	tx, err := db.BeginTxx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Delete existing data for this country (inside tx so it rolls back on failure)
	if _, err := tx.ExecContext(ctx, `DELETE FROM country_ips WHERE country = $1`, country); err != nil {
		return fmt.Errorf("delete %s: %w", country, err)
	}

	stmt, err := tx.PrepareContext(ctx,
		`INSERT INTO country_ips (country, cidr) VALUES ($1, $2::cidr)`)
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, cidr := range cidrs {
		if _, err := stmt.ExecContext(ctx, country, cidr); err != nil {
			return fmt.Errorf("insert %s %s: %w", country, cidr, err)
		}
	}

	return tx.Commit()
}

// ipRangeToCIDRs decomposes a start IP + host count into valid CIDR blocks.
// RIR allocations aren't always power-of-2 aligned, so a single /N won't work.
func ipRangeToCIDRs(startIP net.IP, count uint32) []string {
	if startIP == nil || count == 0 {
		return nil
	}

	ip := binary.BigEndian.Uint32(startIP)
	var result []string

	for count > 0 {
		// Largest block: limited by trailing zeros of the IP (alignment)
		// and by the remaining host count
		trailingZeros := bits.TrailingZeros32(ip)
		if ip == 0 {
			trailingZeros = 32
		}
		maxSize := uint32(1) << trailingZeros

		// Also limited by remaining count — find largest power of 2 <= count
		size := uint32(1)
		for size*2 <= count && size*2 <= maxSize {
			size *= 2
		}

		prefix := 32 - bits.Len32(size-1)
		if size == 1 {
			prefix = 32
		}

		cidrIP := make(net.IP, 4)
		binary.BigEndian.PutUint32(cidrIP, ip)
		result = append(result, fmt.Sprintf("%s/%d", cidrIP.String(), prefix))

		ip += size
		count -= size
	}

	return result
}
