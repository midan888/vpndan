#!/bin/bash
set -euo pipefail

# WireGuard setup for VPN God
# Run this once on the VPS to configure WireGuard

echo "==> Installing WireGuard..."
apt-get update
apt-get install -y wireguard

echo "==> Enabling IP forwarding..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

echo "==> Generating WireGuard server keys..."
umask 077
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key

SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private.key)
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public.key)

echo "==> Creating WireGuard config..."
IFACE=$(ip route show default | awk '{print $5}')
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = ${SERVER_PRIVATE_KEY}
Address = 10.0.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${IFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${IFACE} -j MASQUERADE
EOF

systemctl enable --now wg-quick@wg0

echo ""
echo "============================================"
echo "  WireGuard setup complete!"
echo "============================================"
echo ""
echo "Server public key: ${SERVER_PUBLIC_KEY}"
echo "WireGuard port:    51820"
echo ""
echo "Make sure UDP port 51820 is open in your firewall."
echo ""
echo "Seed the server in the DB:"
echo "  cd /root/vpngod"
echo "  docker compose -f docker-compose.prod.yml exec postgres psql -U postgres vpngod -c \\"
echo "    \"INSERT INTO servers (name, country, host, port, public_key) VALUES ('VPN Server', 'US', 'api.vpndan.com', 51820, '${SERVER_PUBLIC_KEY}');\""
echo "============================================"
