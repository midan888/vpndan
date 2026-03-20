#!/bin/bash
set -euo pipefail

# WireGuard setup for VPN God
# Run this once on the VPS to configure WireGuard

echo "==> Installing WireGuard..."
apt-get update
apt-get install -y wireguard

echo "==> Enabling IP forwarding..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
echo "net.ipv4.conf.all.src_valid_mark=1" >> /etc/sysctl.d/99-wireguard.conf
echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.d/99-wireguard.conf
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.d/99-wireguard.conf
echo "net.ipv4.conf.eth0.rp_filter=0" >> /etc/sysctl.d/99-wireguard.conf
echo "net.ipv4.conf.wg0.rp_filter=0" >> /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

echo "==> Ensuring WireGuard server keys exist..."
umask 077
if [[ ! -f /etc/wireguard/server_private.key || ! -f /etc/wireguard/server_public.key ]]; then
  wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
else
  echo "Existing WireGuard keys found, reusing them."
fi

SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private.key)
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public.key)

echo "==> Creating WireGuard config..."
IFACE=$(ip -4 route show default | awk '{print $5; exit}')
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = ${SERVER_PRIVATE_KEY}
Address = 10.0.0.1/24
ListenPort = 51820
# Allow traffic from VPN clients out to the internet, and allow reply traffic back in.
# On Docker hosts, insert these at the top so they run before DOCKER-FORWARD policy.
PostUp = iptables -I FORWARD 1 -i wg0 -o ${IFACE} -j ACCEPT; iptables -I FORWARD 1 -i ${IFACE} -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -I POSTROUTING 1 -s 10.0.0.0/24 -o ${IFACE} -j MASQUERADE; iptables -t mangle -I FORWARD 1 -o ${IFACE} -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
PostDown = iptables -D FORWARD -i wg0 -o ${IFACE} -j ACCEPT; iptables -D FORWARD -i ${IFACE} -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -t nat -D POSTROUTING -s 10.0.0.0/24 -o ${IFACE} -j MASQUERADE; iptables -t mangle -D FORWARD -o ${IFACE} -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
EOF

systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

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
