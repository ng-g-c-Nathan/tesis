#!/bin/bash
# ===================================================================
# setup-ap.sh
# Levanta el Access Point WiFi y enruta el tráfico de los dispositivos
# conectados a través de OpenVPN (tun0).
#
# Uso: sudo bash setup-ap.sh
# ===================================================================
set -e

IFACE_WIFI="wlx90de800944b6"   # Tarjeta WiFi USB
IFACE_VPN="tun0"                # Interfaz OpenVPN
AP_IP="10.9.0.1"               # IP del servidor en la red WiFi

echo ">>> Levantando interfaz WiFi..."
ip link set "$IFACE_WIFI" up
ip addr flush dev "$IFACE_WIFI"
ip addr add "$AP_IP/24" dev "$IFACE_WIFI"

echo ">>> Habilitando IP forwarding..."
sysctl -w net.ipv4.ip_forward=1

echo ">>> Configurando NAT — tráfico WiFi sale por tun0 (OpenVPN)..."
# Limpiar reglas anteriores
iptables -t nat -D POSTROUTING -s 10.9.0.0/24 -o "$IFACE_VPN" -j MASQUERADE 2>/dev/null || true
iptables -D FORWARD -i "$IFACE_WIFI" -o "$IFACE_VPN" -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i "$IFACE_VPN" -o "$IFACE_WIFI" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true

# Agregar reglas nuevas
iptables -t nat -A POSTROUTING -s 10.9.0.0/24 -o "$IFACE_VPN" -j MASQUERADE
iptables -A FORWARD -i "$IFACE_WIFI" -o "$IFACE_VPN" -j ACCEPT
iptables -A FORWARD -i "$IFACE_VPN" -o "$IFACE_WIFI" -m state --state RELATED,ESTABLISHED -j ACCEPT

echo ">>> Deteniendo servicios previos si existen..."
systemctl stop hostapd 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true
pkill hostapd  2>/dev/null || true
pkill dnsmasq  2>/dev/null || true
sleep 1

echo ">>> Copiando configuraciones..."
cp "$(dirname "$0")/hostapd.conf"  /etc/hostapd/hostapd.conf
cp "$(dirname "$0")/dnsmasq.conf"  /etc/dnsmasq.conf

echo ">>> Arrancando dnsmasq (DHCP)..."
dnsmasq --conf-file=/etc/dnsmasq.conf

echo ">>> Arrancando hostapd (AP WiFi)..."
hostapd /etc/hostapd/hostapd.conf &

echo ""
echo "✓ Access Point activo"
echo "  SSID     : Vpn"
echo "  Password  : RemixCli123"
echo "  IP servidor: $AP_IP"
echo "  Rango DHCP : 10.9.0.100 - 10.9.0.200"
echo "  Tráfico enrutado por: $IFACE_VPN (OpenVPN)"
echo ""
echo "Presiona Ctrl+C para detener."

# Esperar — hostapd corre en background, mantenemos el script vivo
wait
