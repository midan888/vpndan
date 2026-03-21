#!/bin/bash
set -euo pipefail

# Host bootstrap for VPN God.
# Run once on a fresh Ubuntu 22.04/24.04 VPS.

# ── 1. System updates ────────────────────────────────────────────────────────
echo "==> Updating system packages..."
apt-get update -y
apt-get upgrade -y

# ── 2. Docker ────────────────────────────────────────────────────────────────
echo "==> Installing Docker..."
apt-get install -y ca-certificates curl gnupg lsb-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker

# ── 3. AmneziaWG kernel module + tools ──────────────────────────────────────
echo "==> Installing AmneziaWG..."
apt-get install -y software-properties-common
add-apt-repository -y ppa:amnezia/ppa
apt-get update -y
apt-get install -y amneziawg amneziawg-tools

# Load module now and on every boot
modprobe amneziawg
echo "amneziawg" > /etc/modules-load.d/amneziawg.conf

echo "==> AmneziaWG module loaded: $(lsmod | grep amneziawg)"

# ── 4. Host sysctl ───────────────────────────────────────────────────────────
echo "==> Applying sysctl settings..."
cat > /etc/sysctl.d/99-vpngod.conf <<'EOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.src_valid_mark=1
EOF
sysctl -p /etc/sysctl.d/99-vpngod.conf

# ── 5. /dev/net/tun ──────────────────────────────────────────────────────────
echo "==> Ensuring /dev/net/tun exists..."
mkdir -p /dev/net
[ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200

# ── 6. Stop any legacy host WireGuard ────────────────────────────────────────
echo "==> Disabling any legacy host WireGuard service..."
if systemctl list-unit-files | grep -q '^wg-quick@wg0\.service'; then
  systemctl stop wg-quick@wg0 || true
  systemctl disable wg-quick@wg0 || true
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  VPS bootstrap complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Copy your .env file to the server with JWT_SECRET and POSTGRES_PASSWORD set"
echo ""
echo "  2. Deploy the stack:"
echo "     cd /root/vpngod && docker compose -f docker-compose.prod.yml up -d"
echo ""
echo "  3. Read the AmneziaWG gateway public key:"
echo "     docker compose -f docker-compose.prod.yml exec wireguard cat /config/server_public.key"
echo ""
echo "  4. Seed the server row in Postgres:"
echo "     docker compose -f docker-compose.prod.yml exec postgres psql -U postgres vpngod -c \\"
echo "       \"INSERT INTO servers (name, country, host, port, public_key) VALUES ('VPN Server', 'US', 'YOUR_VPS_IP', 51820, 'SERVER_PUBLIC_KEY') ON CONFLICT DO NOTHING;\""
echo ""
echo "  5. If the row already exists, update AWG params to match your .env:"
echo "     docker compose -f docker-compose.prod.yml exec postgres psql -U postgres vpngod -c \\"
echo "       \"UPDATE servers SET public_key='SERVER_PUBLIC_KEY' WHERE host='YOUR_VPS_IP';\""
echo "============================================"
