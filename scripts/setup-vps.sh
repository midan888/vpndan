#!/bin/bash
set -euo pipefail

# VPS initial setup script for VPN God
# Run this once on a fresh Ubuntu/Debian Lightsail instance

echo "==> Installing Docker..."
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker

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
SERVER_IP=$(curl -s http://checkip.amazonaws.com)

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

echo "==> Cloning repo..."
mkdir -p /opt/vpn-god
cd /opt/vpn-god
if [ ! -d .git ]; then
    git clone https://github.com/midan888/vpn-god.git .
fi

echo "==> Creating .env file..."
cat > .env <<EOF
POSTGRES_PASSWORD=$(openssl rand -base64 24)
JWT_SECRET=$(openssl rand -base64 32)
EOF

echo ""
echo "============================================"
echo "  Setup complete!"
echo "============================================"
echo ""
echo "Server public IP:  ${SERVER_IP}"
echo "WireGuard port:    51820"
echo "Server public key: ${SERVER_PUBLIC_KEY}"
echo ""
echo "Add these GitHub secrets:"
echo "  VPS_HOST = ${SERVER_IP}"
echo "  VPS_USER = root (or your ssh user)"
echo "  VPS_SSH_KEY = (your SSH private key)"
echo ""
echo "To start the app:"
echo "  cd /opt/vpn-god"
echo "  docker compose -f docker-compose.prod.yml up -d"
echo ""
echo "Then seed the server in the DB:"
echo "  docker compose -f docker-compose.prod.yml exec postgres psql -U postgres vpngod -c \\"
echo "    \"INSERT INTO servers (name, country, host, port, public_key) VALUES ('VPN Server', 'US', '${SERVER_IP}', 51820, '${SERVER_PUBLIC_KEY}');\""
echo "============================================"
