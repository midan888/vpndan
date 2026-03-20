#!/bin/bash
set -euo pipefail

# Host bootstrap for VPN God.
# This prepares the VPS for the containerized WireGuard gateway.

echo "==> Applying host sysctl settings..."
cat > /etc/sysctl.d/99-vpngod.conf <<'EOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.src_valid_mark=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.eth0.rp_filter=0
EOF
sysctl -p /etc/sysctl.d/99-vpngod.conf

echo "==> Disabling any legacy host WireGuard service..."
if systemctl list-unit-files | grep -q '^wg-quick@wg0\.service'; then
  systemctl stop wg-quick@wg0 || true
  systemctl disable wg-quick@wg0 || true
fi

echo "==> Ensuring WireGuard config directory exists..."
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

echo ""
echo "============================================"
echo "  VPS bootstrap complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Deploy the stack:"
echo "     cd /root/vpngod && docker compose -f docker-compose.prod.yml up -d"
echo ""
echo "  2. Read the WireGuard gateway public key:"
echo "     docker compose -f docker-compose.prod.yml exec wireguard cat /config/server_public.key"
echo ""
echo "  3. Seed or update the server row in Postgres:"
echo "     docker compose -f docker-compose.prod.yml exec postgres psql -U postgres vpngod -c \\"
echo "       \"INSERT INTO servers (name, country, host, port, public_key) VALUES ('VPN Server', 'US', 'YOUR_VPS_IP_OR_HOST', 51820, 'SERVER_PUBLIC_KEY') ON CONFLICT DO NOTHING;\""
echo ""
echo "  4. If the row already exists, run UPDATE instead of INSERT."
echo "============================================"
