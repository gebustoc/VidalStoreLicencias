#!/bin/bash
# User data de nat: NAT por instancia con iptables.
# Las DOS líneas -F son obligatorias: el iptables que trae
# Amazon Linux rechaza el tráfico reenviado.
# OJO: en t3.nano yum/dnf son Killed por falta de memoria;
# usar t3.micro o más y NO instalar paquetes aquí si ya existe iptables.
# Las reglas se aplican al arrancar y quedan persistentes en
# /usr/local/bin/vidalstore-nat.sh + vidalstore-nat.service:
# si la instancia se reinicia, el NAT vuelve solo (las privadas se quedan sin salida).
set -euxo pipefail

# iptables ya viene en Amazon Linux 2023; solo instalarlo si faltara
if ! command -v iptables > /dev/null 2>&1; then
  yum install -y iptables-nft || dnf install -y iptables-nft || true
fi

echo 1 > /proc/sys/net/ipv4/ip_forward
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

cat > /usr/local/bin/vidalstore-nat.sh <<'EOF'
#!/bin/bash
# Reaplica el NAT tras un reinicio de la instancia. Idempotente.
set -euo pipefail
echo 1 > /proc/sys/net/ipv4/ip_forward
IFACE=$(ip route | awk '/^default/ {print $5; exit}')
iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
iptables -F FORWARD
iptables -P FORWARD ACCEPT
EOF
chmod +x /usr/local/bin/vidalstore-nat.sh

cat > /etc/systemd/system/vidalstore-nat.service <<'EOF'
[Unit]
Description=VidalStore NAT (MASQUERADE + FORWARD)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vidalstore-nat.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vidalstore-nat.service
/usr/local/bin/vidalstore-nat.sh
