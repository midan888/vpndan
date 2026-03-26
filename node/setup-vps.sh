#!/bin/bash
set -euo pipefail

# Host bootstrap for VPN Dan nodes.
# Run once on a fresh Ubuntu 22.04/24.04 VPS.
#
# This script only installs what MUST live on the host:
#   - Docker (to run the gateway container)
#   - AmneziaWG kernel module (containers share the host kernel)
#   - /dev/net/tun device
#
# Everything else (userspace tools, sysctl, iptables) is handled
# inside the wireguard-gateway container.

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

# ── 3. AmneziaWG kernel module ───────────────────────────────────────────────
# The container has userspace tools (awg, awg-quick), but the kernel module
# must be on the host — containers share the host kernel.
echo "==> Installing AmneziaWG kernel module..."
apt-get install -y software-properties-common
add-apt-repository -y ppa:amnezia/ppa
apt-get update -y
apt-get install -y amneziawg

# Load now and on every boot
modprobe amneziawg
echo "amneziawg" > /etc/modules-load.d/amneziawg.conf

echo "==> AmneziaWG module loaded: $(lsmod | grep amneziawg)"

# ── 4. /dev/net/tun ──────────────────────────────────────────────────────────
echo "==> Ensuring /dev/net/tun exists..."
mkdir -p /dev/net
[ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200

# ── 5. Stop any legacy host WireGuard ────────────────────────────────────────
if systemctl list-unit-files | grep -q '^wg-quick@wg0\.service'; then
  echo "==> Disabling legacy host WireGuard service..."
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
echo "  1. Copy .env to the server (see node/.env.example):"
echo "       API_URL, NODE_SECRET, NODE_NAME, NODE_COUNTRY, NODE_HOST"
echo ""
echo "  2. Deploy the node:"
echo "     cd node && docker compose up -d"
echo ""
echo "  The gateway will automatically register with the"
echo "  central API and send heartbeats every 30s."
echo "============================================"
