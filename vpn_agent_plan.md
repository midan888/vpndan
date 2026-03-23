# VPN Dan — Peer Agent Implementation Plan

> Turn every user's machine into a VPN exit node. People install a lightweight agent, donate bandwidth, and everyone on the network can VPN through community peers for free.

---

## 1. Concept

Today VPN Dan routes traffic through **dedicated servers** you control. The agent model adds a second node type — **community peers**. Any user installs a small daemon on their computer (macOS / Linux / Windows); the daemon registers with the backend as an available exit node. When another user wants to connect, the backend can assign them to a community peer instead of (or in addition to) a dedicated server.

**Key properties:**

- Peers are untrusted — all traffic is encrypted end-to-end via WireGuard tunnels
- The backend acts as a **coordination service** (matchmaking, key exchange, health tracking) — no user traffic flows through it
- NAT traversal is handled via a lightweight relay (DERP-style) for peers that can't establish direct connections
- Contribution-based fairness: you must donate to consume

---

## 2. Architecture Overview

```
┌──────────────┐         ┌──────────────────┐         ┌──────────────┐
│  iOS / App   │◄──wg──►│  Peer Agent       │         │  Backend API │
│  (consumer)  │         │  (exit node)      │         │  (coordinator│
└──────┬───────┘         └──────┬────────────┘         └──────┬───────┘
       │                        │                              │
       │   register / heartbeat │                              │
       └────────────────────────┼──────────────────────────────┘
                                │
                         ┌──────┴───────┐
                         │  Relay/DERP   │
                         │  (fallback)   │
                         └──────────────┘
```

**Components:**

| Component | Language | Role |
|-----------|----------|------|
| **Peer Agent** | Go | Daemon that runs on contributor machines; manages local WireGuard interface, registers with backend, responds to health checks |
| **Backend API** (extended) | Go | Matchmaking, peer registry, key exchange, health tracking, bandwidth accounting |
| **Relay Server** | Go | DERP-style UDP relay for NAT-punching failures; lightweight, stateless |
| **iOS App** (extended) | Swift | UI for browsing community peers alongside dedicated servers; connect to peers via same VPN flow |

---

## 3. Database Schema Changes

### New tables

```sql
-- 003_create_nodes.sql
CREATE TABLE nodes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    hostname        VARCHAR(255),
    os              VARCHAR(50),       -- "darwin", "linux", "windows"
    country         VARCHAR(2),        -- ISO 3166-1 alpha-2 (auto-detected via IP geolocation)
    city            VARCHAR(100),
    public_ip       INET NOT NULL,
    wireguard_port  INT NOT NULL,      -- UDP port the agent listens on
    public_key      TEXT NOT NULL,     -- WireGuard public key of the agent
    subnet          CIDR NOT NULL,     -- e.g. 10.1.{node_number}.0/24
    is_online       BOOLEAN DEFAULT FALSE,
    last_heartbeat  TIMESTAMPTZ,
    bandwidth_up    BIGINT DEFAULT 0,  -- bytes donated (lifetime)
    bandwidth_down  BIGINT DEFAULT 0,  -- bytes consumed (lifetime)
    max_peers       INT DEFAULT 3,     -- max simultaneous clients this node accepts
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_nodes_online ON nodes (is_online, country);
CREATE INDEX idx_nodes_user   ON nodes (user_id);

-- 004_create_node_peers.sql
CREATE TABLE node_peers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    node_id         UUID NOT NULL REFERENCES nodes(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_pubkey   TEXT NOT NULL,
    assigned_ip     INET NOT NULL,
    connected_at    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(node_id, user_id)
);

-- 005_add_bandwidth_ledger.sql
CREATE TABLE bandwidth_ledger (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    delta_bytes     BIGINT NOT NULL,    -- positive = donated, negative = consumed
    node_id         UUID REFERENCES nodes(id),
    recorded_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ledger_user ON bandwidth_ledger (user_id);
```

### Changes to existing tables

```sql
-- Add to servers table or unify:
ALTER TABLE servers ADD COLUMN node_type VARCHAR(10) DEFAULT 'server';
-- 'server' = dedicated, 'peer' = community node
```

---

## 4. Peer Agent Design

### 4.1 Agent binary

A single Go binary: `vpndan-agent`

```
vpndan-agent/
├── cmd/
│   └── agent/
│       └── main.go          # CLI entry point
├── internal/
│   ├── config/
│   │   └── config.go        # Agent config (API URL, auth token, port, max peers)
│   ├── registration/
│   │   └── register.go      # Register node with backend, get subnet assignment
│   ├── heartbeat/
│   │   └── heartbeat.go     # Periodic heartbeat + bandwidth reporting
│   ├── tunnel/
│   │   └── wireguard.go     # Manage local wg interface (add/remove client peers)
│   ├── nat/
│   │   └── stun.go          # STUN-based NAT type detection
│   └── api/
│       └── client.go        # HTTP client for backend API
└── go.mod
```

### 4.2 Agent lifecycle

```
1. INSTALL & AUTH
   - User downloads binary (or `brew install vpndan-agent`)
   - Runs `vpndan-agent login` → opens browser for OAuth or prompts email/password
   - Stores JWT tokens in OS keychain / config file

2. REGISTER
   - Agent generates WireGuard keypair (stored locally)
   - Detects public IP (via STUN or backend echo endpoint)
   - POST /api/v1/nodes/register { public_key, wireguard_port, os, hostname }
   - Backend assigns a subnet (e.g., 10.1.42.0/24), returns node_id
   - Agent creates WireGuard interface: `wg0` with 10.1.42.1/24

3. HEARTBEAT (every 30s)
   - POST /api/v1/nodes/heartbeat { node_id, bandwidth_up, bandwidth_down, peer_count }
   - Backend updates last_heartbeat, is_online
   - If backend returns new peer assignments → agent adds WireGuard peers
   - If backend returns peer removals → agent removes WireGuard peers

4. PEER MANAGEMENT (event-driven via heartbeat response or WebSocket)
   - On new client assigned:
     `wg set wg0 peer <client_pubkey> allowed-ips <assigned_ip>/32`
   - On client disconnected:
     `wg set wg0 peer <client_pubkey> remove`

5. SHUTDOWN
   - Agent sends POST /api/v1/nodes/offline { node_id }
   - Tears down WireGuard interface
   - Backend marks node as offline, disconnects active peers
```

### 4.3 NAT traversal strategy

| NAT Type | Strategy |
|----------|----------|
| **No NAT** (public IP) | Direct WireGuard connection |
| **Full cone NAT** | STUN-assisted hole punching |
| **Symmetric NAT** | Route through relay server |

- Agent runs STUN check on startup to determine NAT type
- Reports NAT type to backend
- Backend uses this info during matchmaking (prefer direct-capable nodes)
- Relay server acts as a UDP forwarder for worst-case scenarios

### 4.4 Platform support

| Platform | WireGuard Method | Privileges |
|----------|-----------------|------------|
| **Linux** | `wg` CLI or wireguard-go userspace | Root or CAP_NET_ADMIN |
| **macOS** | wireguard-go userspace (utun) | Root for tun device |
| **Windows** | WireGuard Windows service | Admin |

Use wireguard-go as the default userspace implementation to avoid kernel module dependencies. Fall back to `wg` CLI if kernel module is available (better performance on Linux).

---

## 5. Backend API Extensions

### New endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/nodes/register` | Bearer | Register machine as a peer node |
| POST | `/api/v1/nodes/heartbeat` | Bearer | Heartbeat + bandwidth report |
| POST | `/api/v1/nodes/offline` | Bearer | Mark node as going offline |
| GET | `/api/v1/nodes` | Bearer | List available community nodes (for consumers) |
| GET | `/api/v1/nodes/{id}` | Bearer | Get node details |
| POST | `/api/v1/nodes/connect` | Bearer | Request connection to a community node |
| DELETE | `/api/v1/nodes/connect` | Bearer | Disconnect from community node |
| GET | `/api/v1/bandwidth` | Bearer | Get user's bandwidth balance |

### New backend packages

```
backend/internal/
├── nodestore/          # NodeStore interface + Postgres impl
│   └── store.go
├── matchmaker/         # Peer selection algorithm
│   └── matchmaker.go
├── bandwidth/          # Bandwidth accounting & fairness
│   └── tracker.go
└── geoip/              # IP → country/city lookup
    └── geoip.go
```

### Matchmaking algorithm

When a consumer requests a peer connection:

1. Filter online nodes with `current_peers < max_peers`
2. Prefer nodes in the **same region** (lower latency) or **requested country**
3. Prefer nodes with **direct NAT** (no relay needed)
4. Prefer nodes with **higher uptime** (more reliable)
5. Exclude the consumer's own node (can't VPN through yourself)
6. Return the best match; consumer gets WireGuard config to connect

### Connect-to-peer flow

```
Consumer App                    Backend                         Peer Agent
     │                            │                                │
     │ POST /nodes/connect        │                                │
     │  { node_id }               │                                │
     │ ─────────────────────────► │                                │
     │                            │  Generate client keypair       │
     │                            │  Assign IP from node's subnet  │
     │                            │  Store in node_peers            │
     │                            │                                │
     │                            │  (next heartbeat or push)      │
     │                            │ ──────────────────────────────►│
     │                            │  "add peer: pubkey, ip"        │
     │                            │                                │
     │                            │                                │ wg set wg0 peer ...
     │                            │                                │
     │  ◄──── WireGuardConfig ────│                                │
     │  (client privkey,          │                                │
     │   node endpoint,           │                                │
     │   node pubkey,             │                                │
     │   assigned IP)             │                                │
     │                            │                                │
     │ ═══════ WireGuard Tunnel ══════════════════════════════════ │
```

---

## 6. Bandwidth Fairness System

### Rules

- Every user starts with a **seed balance** (e.g., 500 MB) so they can use the network before contributing
- Running the agent **earns bandwidth credits** at a 1:1 ratio (1 byte forwarded = 1 byte earned)
- Connecting as a consumer **spends bandwidth credits**
- Balance = total donated − total consumed + seed
- Users with zero or negative balance are deprioritized (slower matchmaking, not blocked entirely)
- Dedicated servers (owned by VPN Dan) are unrestricted for paying users (future monetization)

### Implementation

- Agent reports `bytes_forwarded` each heartbeat
- Backend logs to `bandwidth_ledger`
- Consumer's usage tracked via `node_peers` session + periodic bandwidth snapshots
- `/api/v1/bandwidth` returns `{ donated, consumed, balance }`

---

## 7. iOS App Changes

### UI additions

1. **Server list** — add a "Community" section showing peer nodes alongside dedicated servers
   - Show: country flag, city, latency ping, online status, peer count/max
   - Badge: "Community" vs "Premium" (dedicated)
2. **Agent status** (future) — if user also runs agent on Mac, show contribution stats
3. **Bandwidth balance** — show donated/consumed/balance in Settings

### API client additions

- `getNodes()` → `GET /api/v1/nodes`
- `connectToNode(nodeId)` → `POST /api/v1/nodes/connect`
- `disconnectFromNode()` → `DELETE /api/v1/nodes/connect`
- `getBandwidth()` → `GET /api/v1/bandwidth`

### VPNManager changes

- Unified connect flow: same WireGuard config structure whether connecting to server or peer
- Add reconnect-on-peer-offline logic (if peer goes down, auto-switch to another peer or dedicated server)

---

## 8. Relay Server

A minimal UDP relay for peers behind symmetric NAT.

```
relay/
├── cmd/
│   └── relay/
│       └── main.go
├── internal/
│   └── relay/
│       └── forwarder.go    # UDP packet forwarding between registered peers
└── go.mod
```

- Peers that can't establish direct connections register a relay session via the backend
- Relay forwards encrypted WireGuard UDP packets between consumer ↔ peer
- Stateless beyond session mapping; no access to cleartext traffic
- Deploy 1-2 relay servers in major regions (US, EU)

---

## 9. Security Considerations

| Concern | Mitigation |
|---------|------------|
| **Peer sees traffic** | All traffic is WireGuard-encrypted; peer only sees encrypted packets. DNS queries should use DoH/DoT to prevent DNS-based snooping |
| **Malicious peer** | Peer can only forward or drop packets — can't inject or modify (WireGuard's authenticated encryption). At worst: availability degradation |
| **Peer identity** | Peers must authenticate with JWT to register; abuse → ban user |
| **IP spoofing** | WireGuard's cryptokey routing prevents peers from spoofing source IPs |
| **Legal liability** | Terms of Service must clearly state exit node operators accept responsibility. Display prominent warnings during agent setup |
| **Abuse (torrenting, illegal traffic)** | Rate limiting, bandwidth caps per peer, ability to report/block abusive consumers |

---

## 10. Implementation Phases

### Phase 1: Backend Foundation (1-2 weeks)
- [ ] Add `nodes`, `node_peers`, `bandwidth_ledger` tables (migrations 003-005)
- [ ] Implement `NodeStore` interface and Postgres implementation
- [ ] Add node API endpoints: register, heartbeat, offline, list, connect, disconnect
- [ ] Add GeoIP lookup (MaxMind GeoLite2 or ip-api.com)
- [ ] Basic matchmaking (online + has capacity + region preference)
- [ ] Bandwidth tracking and `/bandwidth` endpoint
- [ ] Tests for all new endpoints and store methods

### Phase 2: Agent MVP (1-2 weeks)
- [ ] Agent binary scaffolding with CLI (cobra or stdlib flags)
- [ ] Login flow (email/password → JWT, stored in config file)
- [ ] Node registration with backend
- [ ] WireGuard interface management via wireguard-go
- [ ] Heartbeat loop (30s interval)
- [ ] Peer add/remove based on heartbeat response
- [ ] STUN-based NAT detection
- [ ] Graceful shutdown with offline notification
- [ ] Systemd unit file (Linux) + launchd plist (macOS) for auto-start
- [ ] Build & release pipeline (goreleaser: Linux amd64/arm64, macOS amd64/arm64, Windows amd64)

### Phase 3: Integration & iOS (1 week)
- [ ] Extend iOS `APIClient` with node endpoints
- [ ] Add "Community Nodes" section to server list UI
- [ ] Unified connect flow (server or node → same VPNManager path)
- [ ] Bandwidth balance display in Settings
- [ ] Auto-reconnect on peer offline

### Phase 4: Relay Server (1 week)
- [ ] UDP relay implementation
- [ ] Relay session management via backend
- [ ] Agent: detect NAT type, request relay when needed
- [ ] Deploy relay servers (1 US, 1 EU)

### Phase 5: Hardening & Polish (1-2 weeks)
- [ ] Rate limiting and abuse prevention
- [ ] Agent auto-update mechanism
- [ ] Monitoring and alerting (node health dashboard)
- [ ] Legal: ToS update for exit node operators
- [ ] Installer scripts / Homebrew formula
- [ ] Documentation: how to install, configure, and run the agent
- [ ] Load testing with simulated peers

---

## 11. File Structure (Final)

```
vpn-god/
├── backend/                    # Existing backend (extended)
│   ├── cmd/server/
│   ├── internal/
│   │   ├── api/               # + node_handler.go, bandwidth_handler.go
│   │   ├── store/             # + node_store.go, bandwidth_store.go
│   │   ├── matchmaker/        # NEW
│   │   ├── geoip/             # NEW
│   │   └── ...
│   └── migrations/            # + 003, 004, 005
├── agent/                      # NEW — peer agent
│   ├── cmd/agent/
│   ├── internal/
│   │   ├── config/
│   │   ├── registration/
│   │   ├── heartbeat/
│   │   ├── tunnel/
│   │   ├── nat/
│   │   └── api/
│   ├── go.mod
│   └── Makefile
├── relay/                      # NEW — UDP relay server
│   ├── cmd/relay/
│   ├── internal/relay/
│   └── go.mod
├── ios/VPNDan/                 # Existing iOS app (extended)
├── scripts/
│   ├── setup-vps.sh
│   └── install-agent.sh       # NEW — one-liner agent installer
└── docker-compose.prod.yml    # + relay service
```

---

## 12. Open Questions

1. **WebSocket vs polling?** — Heartbeat polling is simpler but adds latency for peer assignment. WebSocket gives instant peer push but adds complexity. Start with polling, upgrade later.
2. **Incentive model** — Pure bandwidth credits or introduce a token/points system? Keep it simple (bandwidth credits) for v1.
3. **Desktop app?** — Should the agent have a GUI (tray icon) or stay CLI-only? Recommend CLI-only for v1, add tray app later.
4. **IPv6?** — Support dual-stack or v4-only for now? Start with v4-only in the WireGuard tunnels.
5. **Multi-hop?** — Route through multiple peers for extra privacy? Out of scope for v1 but architecturally possible.
