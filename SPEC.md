# VPN God - Project Specification

## Overview

VPN God is a WireGuard-based VPN service consisting of a Go backend API and a native iOS Swift app. Users register, browse available VPN servers, and connect via WireGuard tunnels.

---

## Architecture

```
vpn-god/
├── backend/              # Go API server
│   ├── cmd/
│   │   └── server/       # main.go entrypoint
│   ├── internal/
│   │   ├── api/          # HTTP handlers + router
│   │   ├── auth/         # JWT auth middleware
│   │   ├── models/       # DB models
│   │   ├── store/        # Database layer (Postgres)
│   │   ├── wireguard/    # WireGuard key/config generation
│   │   └── config/       # App config loading
│   ├── migrations/       # SQL migrations
│   ├── go.mod
│   └── Dockerfile
├── ios/                  # Native Swift iOS app
│   └── VPNGod/
│       ├── VPNGod.xcodeproj
│       ├── App/
│       │   ├── VPNGodApp.swift
│       │   └── Info.plist
│       ├── Models/
│       ├── Views/
│       ├── ViewModels/
│       ├── Services/
│       │   ├── APIClient.swift
│       │   ├── AuthService.swift
│       │   └── VPNManager.swift
│       └── Extensions/
├── deploy/               # Deployment configs
│   ├── docker-compose.yml
│   └── wireguard/        # WG server setup scripts
├── Makefile
└── SPEC.md
```

---

## Backend (Go)

### Tech Stack

- **Language:** Go 1.22+
- **Router:** net/http (stdlib, Go 1.22 routing)
- **Database:** PostgreSQL 17
- **Auth:** JWT (access + refresh tokens)
- **WireGuard:** key generation via `golang.zx2c4.com/wireguard/wgctrl`

### Database Schema

#### `users`
| Column       | Type         | Notes                  |
|-------------|-------------|------------------------|
| id          | UUID         | PK                     |
| email       | VARCHAR(255) | unique, not null        |
| password    | TEXT         | bcrypt hash             |
| created_at  | TIMESTAMPTZ  | default now()           |

#### `servers`
| Column       | Type         | Notes                  |
|-------------|-------------|------------------------|
| id          | UUID         | PK                     |
| name        | VARCHAR(100) | e.g. "US East"         |
| country     | VARCHAR(2)   | ISO 3166-1 alpha-2     |
| host        | VARCHAR(255) | server IP/hostname      |
| port        | INT          | WireGuard listen port   |
| public_key  | TEXT         | server's WG public key  |
| is_active   | BOOLEAN      | default true            |
| created_at  | TIMESTAMPTZ  | default now()           |

#### `peers`
| Column       | Type         | Notes                           |
|-------------|-------------|----------------------------------|
| id          | UUID         | PK                               |
| user_id     | UUID         | FK -> users                      |
| server_id   | UUID         | FK -> servers                    |
| private_key | TEXT         | encrypted, client's WG key       |
| public_key  | TEXT         | client's WG public key           |
| assigned_ip | INET         | IP within the WG subnet          |
| created_at  | TIMESTAMPTZ  | default now()                    |

### API Endpoints

All responses are JSON. Auth endpoints return JWT tokens.

#### Auth
```
POST /api/v1/auth/register    { email, password } -> { access_token, refresh_token }
POST /api/v1/auth/login       { email, password } -> { access_token, refresh_token }
POST /api/v1/auth/refresh     { refresh_token }   -> { access_token, refresh_token }
```

#### Servers (requires auth)
```
GET  /api/v1/servers          -> [ { id, name, country, host, is_active } ]
```

#### Connection (requires auth)
```
POST   /api/v1/connect        { server_id }  -> { wg_config }
DELETE /api/v1/connect         -> disconnects / removes peer
```

`POST /connect` does:
1. Generate a WireGuard keypair for the client
2. Assign an IP from the server's subnet
3. Register the peer on the WireGuard server
4. Return a full WireGuard config the iOS app can use

### Config

Environment variables:
```
DATABASE_URL=postgres://...
JWT_SECRET=...
PORT=8080
```

---

## iOS App (Swift)

### Tech Stack

- **Language:** Swift 5.9+
- **Min target:** iOS 17
- **UI:** SwiftUI
- **VPN:** NetworkExtension framework + WireGuard (`wireguard-apple` package)
- **Networking:** URLSession (no third-party deps)
- **Storage:** Keychain (tokens), UserDefaults (preferences)

### Screens

1. **Auth** - Login / Register (email + password)
2. **Server List** - List of available servers (country flag, name, status indicator)
3. **Connection** - Big connect/disconnect button, current server, connection status
4. **Settings** - Account info, logout

### App Flow

```
Launch -> Auth Check
  ├── No token -> Auth Screen -> Register/Login -> Server List
  └── Has token -> Server List

Server List -> Tap server -> Connection Screen -> Tap Connect
  1. POST /connect with server_id
  2. Receive WG config
  3. Configure NETunnelProviderManager with WG config
  4. Start VPN tunnel
  5. Show connected state

Disconnect:
  1. Stop VPN tunnel
  2. DELETE /connect
  3. Show disconnected state
```

### Network Extension

The app needs a **Packet Tunnel Provider** extension target for WireGuard:
```
ios/VPNGod/
├── VPNGod/              # Main app target
└── PacketTunnel/        # Network Extension target
    └── PacketTunnelProvider.swift
```

This requires:
- App Group capability (shared config between app + extension)
- Network Extension entitlement
- Personal VPN entitlement

---

## MVP Scope

### In Scope
- User registration & login (email/password)
- JWT auth with refresh tokens
- Server list from API
- Connect to a WireGuard server via the app
- Disconnect from VPN
- Basic server health (is_active flag)

### Out of Scope (future)
- Subscription / payments
- Multiple simultaneous connections
- Kill switch
- Auto-connect on untrusted networks
- Server load balancing / auto-selection
- Admin panel
- Android app
- Usage analytics / bandwidth tracking

---

## User Journeys

### 1. Registration

**Entry:** User opens app for the first time (no stored token).

```
1. App launches -> checks Keychain for access token -> none found
2. App shows Auth screen (Login tab active by default)
3. User taps "Create Account" tab
4. User enters email + password + confirm password
5. Client-side validation:
   - Email format check
   - Password minimum 8 characters
   - Passwords match
6. App calls POST /api/v1/auth/register { email, password }
7. Backend:
   - Validates email format + uniqueness
   - Hashes password with bcrypt
   - Creates user row
   - Generates access token (15 min TTL) + refresh token (30 day TTL)
   - Returns both tokens
8. App stores tokens in Keychain
9. App navigates to Server List screen
```

**Error states:**
- Email already registered -> "An account with this email already exists"
- Invalid email format -> inline validation error
- Password too short -> inline validation error
- Network error -> "Unable to connect. Check your internet connection."

---

### 2. Login

**Entry:** User opens app with no valid token, or after logout.

```
1. App launches -> checks Keychain -> no token or expired access token
2. If refresh token exists: try POST /api/v1/auth/refresh silently
   - Success -> navigate to Server List (skip login screen)
   - Failure -> show Auth screen
3. User enters email + password
4. App calls POST /api/v1/auth/login { email, password }
5. Backend:
   - Looks up user by email
   - Compares bcrypt hash
   - Returns access + refresh tokens
6. App stores tokens in Keychain
7. App navigates to Server List screen
```

**Error states:**
- Wrong email or password -> "Invalid email or password" (no hint about which)
- Account not found -> same generic message (prevent enumeration)
- Network error -> "Unable to connect. Check your internet connection."

---

### 3. Token Refresh (Background)

**Entry:** Any authenticated API call returns 401.

```
1. App makes an authenticated request -> receives 401
2. App calls POST /api/v1/auth/refresh { refresh_token }
3. Backend:
   - Validates refresh token signature + expiry
   - Issues new access + refresh token pair
   - Returns both
4. App stores new tokens in Keychain
5. App retries the original failed request with new access token
6. If refresh also fails (expired/invalid):
   - Clear Keychain
   - Navigate to Auth screen
   - Show "Session expired. Please log in again."
```

---

### 4. Browse Server List

**Entry:** User is authenticated, lands on Server List screen.

```
1. App calls GET /api/v1/servers with auth header
2. Backend returns list of servers: [ { id, name, country, host, is_active } ]
3. App displays servers grouped or sorted by country
   - Each row shows: country flag emoji, server name, status dot (green/gray)
   - Inactive servers shown as grayed out, not tappable
4. User can pull-to-refresh to reload the list
5. User taps an active server -> navigates to Connection screen for that server
```

**Error states:**
- Empty server list -> "No servers available at the moment"
- Network error -> show cached list if available, banner "Unable to refresh"
- 401 -> trigger token refresh flow (Journey 3)

---

### 5. Connect to VPN

**Entry:** User tapped a server from the Server List.

```
1. Connection screen shows:
   - Server name + country flag
   - Large connect button (disconnected state)
   - Status label: "Disconnected"
2. User taps Connect
3. App calls POST /api/v1/connect { server_id } with auth header
4. Backend:
   - Generates WireGuard keypair for this client
   - Allocates next available IP in the server's subnet
   - Creates peer row in DB
   - Registers peer on the actual WireGuard server (via API/SSH)
   - Returns WireGuard client config:
     {
       client_private_key,
       client_address,       // e.g. "10.0.0.5/32"
       server_public_key,
       server_endpoint,      // e.g. "203.0.113.1:51820"
       dns: "1.1.1.1",
       allowed_ips: "0.0.0.0/0"  // route all traffic
     }
5. App configures NETunnelProviderManager:
   - Sets WireGuard config as protocol configuration
   - Saves to system VPN preferences (iOS shows VPN permission prompt on first use)
6. App starts the VPN tunnel
7. iOS shows VPN icon in status bar
8. Connection screen updates:
   - Button changes to "Disconnect"
   - Status: "Connected"
   - Shows assigned IP and connected server info
```

**Error states:**
- Server full / no IPs available -> "Server is at capacity. Try another server."
- Server went offline between list and connect -> "Server unavailable. Please select another."
- iOS VPN permission denied by user -> "VPN permission is required. Go to Settings > VPN to enable."
- Tunnel fails to start -> "Connection failed. Please try again."
- Network error during /connect call -> "Unable to connect. Check your internet connection."

---

### 6. Disconnect from VPN

**Entry:** User is connected to a VPN server.

```
1. User taps Disconnect on Connection screen
2. App stops the VPN tunnel via NETunnelProviderManager
3. App calls DELETE /api/v1/connect with auth header
4. Backend:
   - Removes peer from WireGuard server
   - Deletes peer row from DB
5. Connection screen updates:
   - Button changes back to "Connect"
   - Status: "Disconnected"
6. iOS removes VPN icon from status bar
```

**Error states:**
- DELETE /connect fails (network) -> tunnel is already stopped locally, show warning "Cleanup incomplete, will retry" and retry on next app open
- Already disconnected -> no-op, just update UI

---

### 7. Switch Server

**Entry:** User is connected and wants to change servers.

```
1. User taps back/server list while connected
2. Server List shows current server highlighted with "Connected" badge
3. User taps a different server
4. App shows confirmation: "Switch to {new server}? This will disconnect from {current server}."
5. User confirms
6. App disconnects (Journey 6)
7. App connects to new server (Journey 5)
```

---

### 8. App Backgrounding / Resume

**Entry:** User leaves the app or returns to it.

```
Background:
1. VPN tunnel continues running (managed by NetworkExtension, independent of app process)
2. No action needed from app

Resume:
1. App checks tunnel status via NETunnelProviderManager
2. Updates UI to reflect actual connection state (connected/disconnected)
3. If connected, shows correct server info
4. If token expired during background, triggers refresh (Journey 3)
```

---

### 9. Logout

**Entry:** User taps Logout in Settings.

```
1. User navigates to Settings screen
2. User taps Logout
3. If VPN is connected:
   - App disconnects first (Journey 6)
4. App clears Keychain (access + refresh tokens)
5. App clears any cached data
6. App navigates to Auth screen
```

---

### 10. First-Time VPN Permission

**Entry:** User connects for the very first time on this device.

```
1. User taps Connect (Journey 5, step 5)
2. App calls NETunnelProviderManager.saveToPreferences()
3. iOS shows system alert: "VPNGod Would Like to Add VPN Configurations"
4. User taps "Allow"
5. iOS may prompt for Face ID / passcode
6. VPN profile is saved, tunnel starts
7. Subsequent connections skip this prompt
```

**If user taps "Don't Allow":**
- Connection aborts
- App shows message: "VPN permission is required to connect. You can enable it in Settings > General > VPN & Device Management."
- Connect button remains in disconnected state

---

## Development Order

1. **Backend: Auth** - DB setup, user model, register/login/refresh endpoints
2. **Backend: Servers** - Server model, seed data, list endpoint
3. **Backend: Connect** - WireGuard key gen, peer management, connect/disconnect endpoints
4. **iOS: Project setup** - Xcode project, SwiftUI skeleton, API client
5. **iOS: Auth** - Login/register screens, token storage
6. **iOS: Server list** - Fetch and display servers
7. **iOS: VPN connection** - NetworkExtension integration, WireGuard tunnel
8. **Deploy: WireGuard server** - Setup script for a VPN server node
