#!/bin/bash
# ===================================================================
# entrypoint.sh
# 1) Genera la PKI (CA, servidor, DH, ta.key) si no existe
# 2) Habilita IP forwarding + NAT para los clientes VPN
# 3) Arranca OpenVPN en background
# 4) Arranca Spring Boot en foreground (para que Docker lo vea)
# ===================================================================
set -e

PKI_DIR="/etc/openvpn/pki"
EASYRSA="/usr/share/easy-rsa/easyrsa"

# -------------------------------------------------------------------
# PASO 1: Generar PKI si no existe (primera vez o volumen vacío)
# -------------------------------------------------------------------
if [ ! -f "$PKI_DIR/ca.crt" ]; then
    echo ">>> PKI no encontrada — generando certificados automáticamente..."

    # Easy-RSA no puede hacer init-pki sobre un volumen montado por Docker.
    TMP_PKI="/tmp/easyrsa-pki"
    mkdir -p "$TMP_PKI"

    cd /usr/share/easy-rsa
    export EASYRSA_PKI="$TMP_PKI"
    export EASYRSA_BATCH=1                  # Sin preguntas interactivas
    export EASYRSA_REQ_CN="OpenVPN-CA"
    export EASYRSA_ALGO="ec"               # ECDSA — más rápido que RSA
    export EASYRSA_CURVE="prime256v1"
    export EASYRSA_CA_EXPIRE=3650          # CA válida 10 años
    export EASYRSA_CERT_EXPIRE=825         # Certs válidos ~2 años

    $EASYRSA init-pki
    $EASYRSA build-ca nopass               # CA sin passphrase
    $EASYRSA build-server-full server nopass
    $EASYRSA gen-dh                        # Diffie-Hellman params

    # Copiar todo al volumen persistente
    cp -r "$TMP_PKI"/. "$PKI_DIR/"
    rm -rf "$TMP_PKI"

    # TLS-Auth key (capa HMAC extra) — directamente en el volumen
    openvpn --genkey secret "$PKI_DIR/ta.key"

    echo ">>> PKI generada correctamente en $PKI_DIR"
else
    echo ">>> PKI existente encontrada — saltando generación."
fi

# -------------------------------------------------------------------
# PASO 2: IP Forwarding + NAT (necesario para rutear tráfico VPN)
# -------------------------------------------------------------------
echo ">>> Habilitando IP forwarding..."
sysctl -w net.ipv4.ip_forward=1 || echo "WARN: ip_forward ya activo via compose"

# Detectar la interfaz de salida automáticamente
IFACE=$(ip route | grep '^default' | awk '{print $5}' | head -1)
echo ">>> Interfaz de salida detectada: $IFACE"

# Regla NAT: el tráfico de la subred VPN (10.8.0.0/16) sale con la IP del host
iptables -t nat -A POSTROUTING -s 10.8.0.0/16 -o "$IFACE" -j MASQUERADE 2>/dev/null || \
    echo "WARN: iptables NAT ya configurado o no disponible"

# -------------------------------------------------------------------
# PASO 3: Arrancar OpenVPN en background
# -------------------------------------------------------------------
echo ">>> Iniciando OpenVPN..."
openvpn \
    --config  /etc/openvpn/server.conf \
    --status  /etc/openvpn/openvpn-status.log 10 \
    --writepid /etc/openvpn/openvpn.pid \
    --daemon

# Pequeña espera para que OpenVPN escriba su PID antes de que Spring arranque
sleep 2

if [ -f /etc/openvpn/openvpn.pid ]; then
    PID=$(cat /etc/openvpn/openvpn.pid)
    echo ">>> OpenVPN corriendo con PID $PID"
else
    echo "WARN: OpenVPN puede no haber arrancado — revisa los logs con 'docker logs'"
fi

# -------------------------------------------------------------------
# PASO 4: Arrancar Spring Boot (foreground — Docker lo monitorea)
# -------------------------------------------------------------------
echo ">>> Iniciando Spring Boot..."
exec java -jar /app/app.jar