#!/bin/bash
# ===================================================================
# entrypoint-python.sh
# Arranca default_generator.py en modo loop (captura cada 10 min).
# Los CSVs se escriben en /app/daily, que es un volumen compartido
# con el servicio spring-vpn para que el scoring los pueda leer.
# ===================================================================
set -e

cd /app

echo ">>> Esperando 10s para que la red del contenedor esté lista..."
sleep 10

echo ">>> Iniciando captura de tráfico en loop (cada 10 minutos)..."
exec python default_generator.py \
    --live \
    --loop \
    --interval 10 \
    --duration 30 \
    --out /app/daily
