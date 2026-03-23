# CLAUDE.md — VPN God

## Project Overview

WireGuard-based VPN app with a Go backend and native iOS (Swift/SwiftUI) client. Monorepo structure: `/backend` (Go API server) and `/ios` (SwiftUI app with NetworkExtension tunnel).

## Key Documents

- **SPEC.md** — Full product spec: API contracts, database schema, user journeys, error states. Read this when implementing a new endpoint or user-facing flow.
- **REDESIGN_PLAN.md** — UI/UX redesign plan: design system specs, screen-by-screen layouts, animation details, and phased implementation checklist. Read this when building or modifying iOS UI.

## Quick Reference

### Build & Run

```bash
# Backend (local)
docker compose up postgres
cd backend && air                    # hot reload via .air.toml
# OR: go run ./cmd/server

# Backend (production)
docker compose -f docker-compose.prod.yml up -d

# Backend tests
cd backend && go test ./... -v

# iOS
cd ios/VPNGod && xcodegen generate   # regenerate .xcodeproj from project.yml
open VPNGod.xcodeproj                # build & run in Xcode
```

### Required Environment Variables (backend)

- `DATABASE_URL` — Postgres connection string
- `JWT_SECRET` — HMAC signing key for JWT tokens
- `PORT` — HTTP listen port (default 8080)

## Architecture

### Backend (`/backend`)

- **Go 1.25**, stdlib `net/http` router + **Huma v2** (OpenAPI)
- **PostgreSQL 17** via `sqlx` + `lib/pq`
- **JWT auth**: access token (15min) + refresh token (30 days), HS256
- **WireGuard**: key generation via `wgctrl`, peer management via `wg` CLI
- Entry point: `cmd/server/main.go`
- Packages: `internal/api`, `internal/auth`, `internal/models`, `internal/store`, `internal/wireguard`, `internal/config`
- Migrations: `/migrations/*.sql` — run automatically at startup
- Tests: table-driven, in `*_test.go` alongside source files

**API routes** (all under `/api/v1`):
| Method | Path | Auth |
|--------|------|------|
| POST | /auth/register | No |
| POST | /auth/login | No |
| POST | /auth/refresh | No |
| GET | /servers | Bearer |
| GET | /servers/{id} | Bearer |
| POST | /connect | Bearer |
| DELETE | /connect | Bearer |

**Handler pattern**: Huma input/output structs → handler func → store interface. Dependencies injected via constructor (`NewAuthHandler(store, jwt)`).

### iOS App (`/ios/VPNGod`)

- **Swift 5.9+**, **SwiftUI**, **iOS 17+**
- **XcodeGen** (`project.yml`) generates the Xcode project — edit `project.yml`, not `.xcodeproj`
- Two targets: `VPNGod` (main app) + `PacketTunnel` (Network Extension)
- Bundle: `com.vpngod.VPNGod`, App Group: `group.com.vpngod.VPNGod`

**Key services** (all in `Services/`):
- `APIClient` (actor) — URLSession networking, auto 401→refresh→retry
- `AuthService` (@Observable) — login/register/logout, Keychain token storage
- `VPNManager` (@Observable) — NETunnelProviderManager, tunnel lifecycle
- `KeychainService` — secure token storage
- `FavoritesService` — favorite servers (UserDefaults)

**UI pattern**: MVVM with `@Observable` (iOS 17). `@MainActor` on all ViewModels/services touching UI.

**Design system** (`DesignSystem/`): Colors (navy bg, violet primary, cyan accent), Typography (SF Pro), Spacing (8pt grid), reusable components (GradientButton, GlassCard, ServerRow, etc.).

## Code Conventions

### Go
- When adding a new environment variable, always add it to `backend/.env.example` with a comment and sensible default
- Explicit error returns; wrap with `fmt.Errorf("context: %w", err)`
- Interfaces for store layer (`UserStore`, `ServerStore`, `PeerStore`)
- Context passed through all DB operations
- Table-driven tests
- No ORM — raw SQL via sqlx

### Swift
- `async/await` for all async work (no completion handlers)
- `@Observable` + `@MainActor` (not ObservableObject/Combine)
- camelCase functions/properties, PascalCase types
- Typed errors via `APIError` enum
- No external dependencies — all native frameworks

## Deployment

- **CI/CD**: GitHub Actions (`.github/workflows/deploy.yml`) — build Docker image → push to ghcr.io → SSH deploy to VPS
- **Docker**: multi-stage Go build (alpine), production uses `network_mode: host` + `CAP_NET_ADMIN`
- **VPS setup**: `scripts/setup-vps.sh` — installs Docker, WireGuard, configures `wg0` interface (10.0.0.0/24)
- **GitHub secrets needed**: `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`

## Database Schema

- `users` (id UUID, email, password bcrypt, created_at)
- `servers` (id UUID, name, country, host, port, public_key, is_active, created_at)
- `peers` (id UUID, user_id FK, server_id FK, private_key, public_key, assigned_ip, created_at) — unique per user

## WireGuard Flow

1. Client POST `/connect` with `server_id`
2. Backend generates keypair, assigns IP from 10.0.0.0/24 (clients get .2–.254)
3. Backend runs `wg set wg0 peer <pubkey> allowed-ips <ip>/32`
4. Returns config (client private key, assigned IP, server endpoint, server public key)
5. iOS configures NETunnelProviderManager with WireGuard config
6. Disconnect: `wg set wg0 peer <pubkey> remove`, delete peer from DB

## Common Pitfalls

- Always edit `project.yml` for iOS project changes, then run `xcodegen generate` — never edit `.xcodeproj` directly
- Backend requires `CAP_NET_ADMIN` to manage WireGuard peers — local dev without WireGuard will fail on connect/disconnect
- The PacketTunnel extension and main app share data via App Groups — keep bundle IDs and group IDs in sync
- JWT token type claim ("access"/"refresh") prevents token confusion attacks — maintain this distinction
- One peer per user constraint (UNIQUE on user_id) — disconnect old before connecting to new server
