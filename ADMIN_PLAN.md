# Admin Area Specification — VPN Dan

## Context

The project currently has no admin capabilities — all users are equal, there's no way to manage users or servers through the API, and no visibility into traffic. This plan adds an admin area with backend API endpoints and a React SPA frontend for auth, user management, server management, and traffic stats.

---

## Design Decisions

- **Admin = user with `is_admin` flag** — no separate table or auth flow. Admin logs in via the same `/auth/login` endpoint, receives a JWT with an `is_admin` claim.
- **All admin routes under `/api/v1/admin/`** — protected by admin middleware that checks both token validity and admin claim.
- **Traffic stats via on-demand `wg show`** — no periodic polling or storage in phase 1. Historical traffic table deferred to future phase.
- **Admin bootstrap via env vars** — `ADMIN_EMAIL` + `ADMIN_PASSWORD` create/promote admin on startup (idempotent).
- **Admin frontend** — React SPA (Vite + Tailwind CSS) in `/admin`, served as its own service with its own Dockerfile + container. Talks to backend API via `VITE_API_URL` env var.

---

## Phase 1: Foundation (Admin Auth)

### Database
- Add migration: `ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false`
- Add admin bootstrap in `main.go`: if `ADMIN_EMAIL` + `ADMIN_PASSWORD` env vars set, upsert user with `is_admin = true`

### Files to modify

**`backend/internal/models/user.go`**
- Add `IsAdmin bool` field to `User` struct (`json:"is_admin" db:"is_admin"`)

**`backend/internal/auth/jwt.go`**
- Add `IsAdmin bool` to `Claims` struct
- Change `GenerateTokenPair(userID uuid.UUID, isAdmin bool)` — embed admin flag in both tokens
- Add `ValidateAdminAccessToken(token) (uuid.UUID, error)` — validates token + checks `is_admin == true`

**`backend/internal/api/auth_handler.go`**
- Update all `GenerateTokenPair` call sites to pass `user.IsAdmin`
- `Register`: pass `false`
- `Login`: pass `user.IsAdmin` (fetched from DB)
- `Refresh`: pass `user.IsAdmin` (already fetched from DB)

**`backend/internal/api/auth_helpers.go`**
- Add `authenticateAdminRequest(jwt, authHeader) (uuid.UUID, error)` — returns 403 if not admin

**`backend/internal/store/user_store.go`**
- Update all SELECT queries to include `is_admin` column

**`backend/internal/store/store.go`**
- Add to `UserStore`: `UpdatePassword(ctx, id, hashedPassword) error`, `SetAdmin(ctx, id, isAdmin) error`

**`backend/internal/config/config.go`**
- Add `AdminEmail`, `AdminPassword` optional fields

**`backend/cmd/server/main.go`**
- Add `is_admin` migration to `runMigrations()`
- Add admin bootstrap logic after migrations

---

## Phase 2: Users Dashboard

### New store methods

`UserStore` additions:
- `ListUsers(ctx) ([]User, error)`
- `DeleteUser(ctx, id) error`

`PeerStore` additions:
- `ListAllPeers(ctx) ([]Peer, error)`

### New files

**`backend/internal/models/admin.go`** — admin-specific request/response types

**`backend/internal/api/admin_handler.go`** — `AdminHandler` struct with all admin handlers

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/admin/users` | List all users with active connection info |
| GET | `/api/v1/admin/users/{id}` | Get single user detail |
| POST | `/api/v1/admin/users/{id}/reset-password` | Reset user password |
| DELETE | `/api/v1/admin/users/{id}` | Delete user (cleanup WG peer first) |

#### GET /api/v1/admin/users
```json
// Response 200
[
  {
    "id": "uuid",
    "email": "user@example.com",
    "is_admin": false,
    "created_at": "2025-01-01T00:00:00Z",
    "peer": {
      "server_id": "uuid",
      "server_name": "Frankfurt 1",
      "assigned_ip": "10.0.0.2",
      "connected_at": "2025-06-01T12:00:00Z"
    }
  }
]
```

Implementation: Single SQL query with LEFT JOIN peers + servers to get connection info.

```sql
SELECT u.id, u.email, u.is_admin, u.created_at,
       p.server_id, p.assigned_ip, p.created_at AS connected_at,
       s.name AS server_name
FROM users u
LEFT JOIN peers p ON p.user_id = u.id
LEFT JOIN servers s ON s.id = p.server_id
ORDER BY u.created_at DESC
```

#### POST /api/v1/admin/users/{id}/reset-password
```json
// Request
{ "new_password": "newpassword123" }
// Response 200
{ "message": "password updated" }
```

Implementation: bcrypt hash new password, call `UpdatePassword`.

#### DELETE /api/v1/admin/users/{id}
Before deleting: if user has active peer, remove from WireGuard via `wg.RemovePeer`, then delete user (CASCADE handles DB peer row).

---

## Phase 3: Servers Dashboard

### New store methods

`ServerStore` additions:
- `ListAllServers(ctx) ([]Server, error)` — includes inactive servers
- `CreateServer(ctx, server) (*Server, error)`
- `DeleteServer(ctx, id) error`
- `UpdateServerStatus(ctx, id, isActive) error`

`PeerStore` additions:
- `ListPeersByServerID(ctx, serverID) ([]Peer, error)`

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/admin/servers` | List all servers with peer counts + traffic |
| GET | `/api/v1/admin/servers/{id}` | Server detail with per-peer traffic breakdown |
| POST | `/api/v1/admin/servers` | Add new server |
| DELETE | `/api/v1/admin/servers/{id}` | Delete server (cleanup WG peers first) |
| PATCH | `/api/v1/admin/servers/{id}` | Toggle active/inactive |

#### GET /api/v1/admin/servers
```json
// Response 200
[
  {
    "id": "uuid",
    "name": "Frankfurt 1",
    "country": "DE",
    "host": "1.2.3.4",
    "port": 51820,
    "public_key": "abc...",
    "is_active": true,
    "created_at": "2025-01-01T00:00:00Z",
    "peer_count": 12,
    "tx_bytes": 1073741824,
    "rx_bytes": 536870912
  }
]
```

Implementation: Query all servers with `COUNT(peers)` via GROUP BY. Cross-reference with live WG transfer stats (phase 4).

#### GET /api/v1/admin/servers/{id}
```json
// Response 200
{
  "server_id": "uuid",
  "name": "Frankfurt 1",
  "total_rx_bytes": 536870912,
  "total_tx_bytes": 1073741824,
  "peers": [
    {
      "user_id": "uuid",
      "email": "user@example.com",
      "public_key": "abc...",
      "rx_bytes": 134217728,
      "tx_bytes": 268435456
    }
  ]
}
```

#### POST /api/v1/admin/servers
```json
// Request
{
  "name": "Frankfurt 1",
  "country": "DE",
  "host": "1.2.3.4",
  "port": 51820,
  "public_key": "abc..."
}
// Response 201 — full server object
```

#### DELETE /api/v1/admin/servers/{id}
Before deleting: iterate all peers on this server, call `wg.RemovePeer` for each, then delete server (CASCADE handles DB peer rows).

#### PATCH /api/v1/admin/servers/{id}
```json
// Request
{ "is_active": false }
// Response 200
{ "message": "server updated" }
```

---

## Phase 4: Traffic Stats

### WireGuard interface changes

**`backend/internal/wireguard/manager.go`**

Add to `PeerManager` interface:
```go
GetTransferStats() ([]TransferStat, error)
```

```go
type TransferStat struct {
    PublicKey string
    RxBytes  int64
    TxBytes  int64
}
```

**LocalPeerManager**: Run `wg show wg0 transfer`, parse tab-separated output (`<pubkey>\t<rx>\t<tx>` per line).

**HTTPPeerManager**: `GET {baseURL}/transfer` — expects JSON array from gateway.

### Wire into admin handlers
- `ListServers`: aggregate transfer stats per server by matching peer public keys
- `GetServer`: include per-peer transfer breakdown
- If WG stats unavailable (e.g., local dev), return zeros gracefully — don't fail the request

---

## Phase 5: Admin Frontend (React SPA)

### Tech Stack
- **React 18** with TypeScript
- **Vite** for build tooling
- **Tailwind CSS** for styling
- **React Router v6** for client-side routing
- **No state management library** — React context + `useState`/`useEffect` is sufficient for this scope
- **No component library** — custom components with Tailwind

### Project Structure

```
admin/
├── Dockerfile
├── nginx.conf              # serves built SPA, proxies /api to backend
├── package.json
├── vite.config.ts
├── tailwind.config.js
├── tsconfig.json
├── index.html
├── .env.example            # VITE_API_URL=http://localhost:8080
└── src/
    ├── main.tsx
    ├── App.tsx              # router setup, auth guard
    ├── api/
    │   └── client.ts        # fetch wrapper: base URL, auth header, 401 redirect, token refresh
    ├── context/
    │   └── AuthContext.tsx   # stores JWT tokens, provides login/logout, exposes isAuthenticated
    ├── pages/
    │   ├── LoginPage.tsx
    │   ├── UsersPage.tsx
    │   ├── UserDetailPage.tsx
    │   ├── ServersPage.tsx
    │   └── ServerDetailPage.tsx
    ├── components/
    │   ├── Layout.tsx        # sidebar nav + top bar + content area
    │   ├── Sidebar.tsx       # nav links: Users, Servers
    │   ├── ProtectedRoute.tsx # redirects to /login if not authenticated
    │   ├── UsersTable.tsx
    │   ├── ServersTable.tsx
    │   ├── ResetPasswordModal.tsx
    │   ├── AddServerModal.tsx
    │   ├── ConfirmModal.tsx  # generic "are you sure?" for delete actions
    │   ├── StatusBadge.tsx   # green/red dot for active/inactive, connected/disconnected
    │   └── TrafficDisplay.tsx # formats bytes → KB/MB/GB
    └── types/
        └── index.ts          # TypeScript interfaces matching API responses
```

### Routing

| Route | Page | Description |
|-------|------|-------------|
| `/login` | LoginPage | Email + password form |
| `/` | redirect → `/users` | Default after login |
| `/users` | UsersPage | Users table with connection status |
| `/users/:id` | UserDetailPage | User detail + reset password |
| `/servers` | ServersPage | Servers table with peer counts + traffic |
| `/servers/:id` | ServerDetailPage | Server detail with per-peer traffic |

### Pages Detail

#### LoginPage
- Clean centered card with email + password inputs
- Calls `POST /api/v1/auth/login`, checks that the returned token has admin claim
- On success: stores tokens in `localStorage`, redirects to `/users`
- On failure: shows error message (invalid credentials / not an admin)
- No "register" link — admins are bootstrapped via env vars

#### UsersPage
- **Header**: "Users" title + total count
- **Table columns**: Email, Status (connected/disconnected), Server (if connected), IP (if connected), Created, Actions
- **Status**: green badge "Connected to {server_name}" or gray "Disconnected"
- **Actions**: "Reset Password" button → opens modal, "Delete" button → confirm modal
- **Reset Password Modal**: single input for new password, submit calls `POST /api/v1/admin/users/{id}/reset-password`
- **Delete**: confirm modal, on confirm calls `DELETE /api/v1/admin/users/{id}`, removes row from table
- Data: fetched from `GET /api/v1/admin/users`

#### UserDetailPage
- Shows user info (email, created date, admin status)
- If connected: shows server name, assigned IP, connected since
- Reset password button + delete button (same modals as table)
- Data: fetched from `GET /api/v1/admin/users/{id}`

#### ServersPage
- **Header**: "Servers" title + "Add Server" button
- **Table columns**: Name, Country, Host, Status (active/inactive), Peers, Traffic (RX/TX), Actions
- **Traffic**: formatted as human-readable (e.g., "1.2 GB / 540 MB")
- **Actions**: "Toggle Active" button, "Delete" button → confirm modal
- **Add Server Modal**: form with fields — name, country (2-letter), host, port, public key. Submit calls `POST /api/v1/admin/servers`
- **Delete**: confirm modal warns "This will disconnect N active peers", calls `DELETE /api/v1/admin/servers/{id}`
- Data: fetched from `GET /api/v1/admin/servers`

#### ServerDetailPage
- Server info card: name, country, host:port, public key, status, created date
- Traffic summary: total RX + TX
- **Peers table**: Email, Public Key, Assigned IP, RX, TX
- Toggle active/delete buttons
- Data: fetched from `GET /api/v1/admin/servers/{id}`

### API Client (`src/api/client.ts`)

```typescript
// Thin fetch wrapper
const API_URL = import.meta.env.VITE_API_URL;

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const token = localStorage.getItem('access_token');
  const res = await fetch(`${API_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token && { Authorization: `Bearer ${token}` }),
      ...options?.headers,
    },
  });

  if (res.status === 401) {
    // try refresh, if that fails redirect to /login
  }

  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export const api = {
  login: (email: string, password: string) =>
    request<AuthResponse>('/api/v1/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) }),

  listUsers: () => request<AdminUserResponse[]>('/api/v1/admin/users'),
  getUser: (id: string) => request<AdminUserResponse>(`/api/v1/admin/users/${id}`),
  resetPassword: (id: string, newPassword: string) =>
    request('/api/v1/admin/users/${id}/reset-password', { method: 'POST', body: JSON.stringify({ new_password: newPassword }) }),
  deleteUser: (id: string) => request(`/api/v1/admin/users/${id}`, { method: 'DELETE' }),

  listServers: () => request<AdminServerResponse[]>('/api/v1/admin/servers'),
  getServer: (id: string) => request<ServerTrafficResponse>(`/api/v1/admin/servers/${id}`),
  createServer: (data: CreateServerRequest) =>
    request('/api/v1/admin/servers', { method: 'POST', body: JSON.stringify(data) }),
  deleteServer: (id: string) => request(`/api/v1/admin/servers/${id}`, { method: 'DELETE' }),
  updateServer: (id: string, data: { is_active: boolean }) =>
    request(`/api/v1/admin/servers/${id}`, { method: 'PATCH', body: JSON.stringify(data) }),
};
```

### Auth Context (`src/context/AuthContext.tsx`)

- Stores `accessToken` and `refreshToken` in `localStorage`
- Provides `login(email, password)`, `logout()`, `isAuthenticated`
- On login: decodes JWT to verify `is_admin` claim — if not admin, throws error
- On logout: clears tokens, redirects to `/login`
- Token refresh: intercept 401 → call `/api/v1/auth/refresh` → retry original request → if refresh fails, logout

### Visual Design

- **Color palette**: Dark sidebar (slate-800/900), white content area, blue primary buttons, red for destructive actions
- **Layout**: Fixed sidebar (240px) on left, scrollable content area on right
- **Typography**: system font stack (Inter/SF Pro if available)
- **Tables**: Striped rows, hover highlight, sticky header
- **Modals**: centered overlay with backdrop blur
- **Responsive**: not required — admin is desktop-only

### Deployment

Hosted at `admin.vpndan.com`. Caddy already handles TLS and proxying for the project (`api.vpndan.com`, `db.vpndan.com`), so the admin SPA uses the same pattern — Caddy serves the built static files and proxies API calls to the backend. No nginx needed.

**Dockerfile** (multi-stage):
```dockerfile
# Build stage
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

# Serve stage — lightweight static file server
FROM caddy:2-alpine
COPY Caddyfile.admin /etc/caddy/Caddyfile
COPY --from=build /app/dist /srv
```

**`admin/Caddyfile.admin`** (internal, only serves files inside the container):
```
:80 {
    root * /srv
    try_files {path} /index.html
    file_server
}
```

**Caddyfile** update (project root — the main reverse proxy):
```
admin.vpndan.com {
    handle /api/* {
        reverse_proxy backend:8080
    }
    handle {
        reverse_proxy admin:80
    }
}
```

This means:
- `admin.vpndan.com` → Caddy routes `/api/*` to the backend, everything else to the admin SPA container
- The admin SPA calls API via relative URLs (`/api/v1/...`) — same origin, no CORS needed in production
- `VITE_API_URL` is empty string at build time (relative URLs)

**docker-compose.prod.yml** addition:
```yaml
admin:
  build:
    context: ./admin
    args:
      VITE_API_URL: ""
  restart: unless-stopped
  depends_on:
    - backend
```

No `ports` mapping needed — Caddy proxies to it via Docker network.

### CORS

- **Production**: same origin (`admin.vpndan.com` → Caddy → backend), no CORS needed
- **Development**: backend at `:8080`, admin at `:5173` — backend needs CORS middleware

Add a simple CORS middleware in `backend/internal/api/router.go` that checks `CORS_ORIGIN` env var (only set in dev):
- `Access-Control-Allow-Origin: http://localhost:5173`
- `Access-Control-Allow-Headers: Content-Type, Authorization`
- `Access-Control-Allow-Methods: GET, POST, PATCH, DELETE, OPTIONS`
- Handle preflight `OPTIONS` requests

### Implementation Order

Phase 5 is split into sub-steps:

1. **Scaffold** — `npm create vite@latest admin -- --template react-ts`, install Tailwind, set up project structure
2. **Auth** — AuthContext, API client, LoginPage, ProtectedRoute
3. **Layout** — Layout + Sidebar components, routing setup
4. **Users pages** — UsersPage (table + modals), UserDetailPage
5. **Servers pages** — ServersPage (table + modals), ServerDetailPage
6. **Deployment** — Dockerfile, nginx.conf, add to docker-compose.prod.yml
7. **CORS** — Add dev CORS middleware to backend

---

## Phase 6 (Future): Historical Traffic

Deferred. Would add:
- `traffic_snapshots` table (peer_id, server_id, user_id, rx_bytes, tx_bytes, recorded_at)
- Background goroutine polling `GetTransferStats()` every N minutes
- `GET /api/v1/admin/servers/{id}/traffic?from=&to=` for historical queries

---

## Files Summary

### Backend

| File | Action | Phase |
|------|--------|-------|
| `backend/cmd/server/main.go` | Add migration + admin bootstrap | 1 |
| `backend/internal/config/config.go` | Add admin env vars + CORS_ORIGIN | 1, 5 |
| `backend/internal/models/user.go` | Add `IsAdmin` field | 1 |
| `backend/internal/auth/jwt.go` | Add admin claim + validation | 1 |
| `backend/internal/api/auth_handler.go` | Update token generation calls | 1 |
| `backend/internal/api/auth_helpers.go` | Add admin auth helper | 1 |
| `backend/internal/store/store.go` | Extend all 3 interfaces | 1-3 |
| `backend/internal/store/user_store.go` | Add `is_admin` to queries + new methods | 1-2 |
| `backend/internal/store/server_store.go` | Add CRUD methods | 3 |
| `backend/internal/store/peer_store.go` | Add list/delete by server | 3 |
| `backend/internal/models/admin.go` | **New** — admin DTOs | 2 |
| `backend/internal/api/admin_handler.go` | **New** — all admin handlers | 2-3 |
| `backend/internal/api/router.go` | Register admin routes + CORS middleware | 2-3, 5 |
| `backend/internal/wireguard/manager.go` | Add `GetTransferStats` | 4 |

### Frontend (`admin/`)

| File | Action | Phase |
|------|--------|-------|
| `admin/package.json` | **New** — project config | 5 |
| `admin/vite.config.ts` | **New** — Vite config | 5 |
| `admin/tailwind.config.js` | **New** — Tailwind config | 5 |
| `admin/index.html` | **New** — SPA entry | 5 |
| `admin/src/main.tsx` | **New** — React entry | 5 |
| `admin/src/App.tsx` | **New** — router + auth guard | 5 |
| `admin/src/api/client.ts` | **New** — API client | 5 |
| `admin/src/context/AuthContext.tsx` | **New** — JWT auth state | 5 |
| `admin/src/types/index.ts` | **New** — TypeScript interfaces | 5 |
| `admin/src/components/Layout.tsx` | **New** — sidebar layout | 5 |
| `admin/src/components/Sidebar.tsx` | **New** — navigation | 5 |
| `admin/src/components/ProtectedRoute.tsx` | **New** — auth guard | 5 |
| `admin/src/components/UsersTable.tsx` | **New** — users table | 5 |
| `admin/src/components/ServersTable.tsx` | **New** — servers table | 5 |
| `admin/src/components/ResetPasswordModal.tsx` | **New** — password reset form | 5 |
| `admin/src/components/AddServerModal.tsx` | **New** — add server form | 5 |
| `admin/src/components/ConfirmModal.tsx` | **New** — delete confirmation | 5 |
| `admin/src/components/StatusBadge.tsx` | **New** — active/connected indicator | 5 |
| `admin/src/components/TrafficDisplay.tsx` | **New** — bytes formatter | 5 |
| `admin/src/pages/LoginPage.tsx` | **New** — login form | 5 |
| `admin/src/pages/UsersPage.tsx` | **New** — users dashboard | 5 |
| `admin/src/pages/UserDetailPage.tsx` | **New** — user detail | 5 |
| `admin/src/pages/ServersPage.tsx` | **New** — servers dashboard | 5 |
| `admin/src/pages/ServerDetailPage.tsx` | **New** — server detail + traffic | 5 |
| `admin/Dockerfile` | **New** — multi-stage build | 5 |
| `admin/Caddyfile.admin` | **New** — internal SPA file server | 5 |
| `Caddyfile` | Add `admin.vpndan.com` block | 5 |
| `docker-compose.prod.yml` | Add admin service | 5 |

## Verification

1. **Phase 1**: Run `go test ./...` — existing tests pass. Manually test login returns `is_admin` in token claims. Bootstrap creates admin user on startup.
2. **Phase 2**: `curl` admin user endpoints with admin JWT — list users, reset password, delete user. Verify non-admin JWT gets 403.
3. **Phase 3**: `curl` admin server endpoints — create, list, delete, toggle. Verify cascade cleanup of WG peers on server delete.
4. **Phase 4**: On a machine with WG running, verify `GET /admin/servers` and `GET /admin/servers/{id}` return traffic data. On local dev without WG, verify graceful fallback to zeros.
5. **Phase 5**: Run `npm run dev` in `/admin`, verify login flow, users table loads, servers table loads, add/delete/toggle all work through the UI. Run `npm run build` to verify production build succeeds.
6. **All backend phases**: Write table-driven tests with mock stores following existing test patterns.
