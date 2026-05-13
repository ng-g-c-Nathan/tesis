#!/bin/bash
# ===================================================================
# entrypoint-python.sh
# 1) Arranca Flask API en background (puerto 5000)
# 2) Arranca default_generator.py en loop (captura cada 10 min)
# ===================================================================
set -e

cd /app

echo ">>> Esperando 10s para que la red esté lista..."
sleep 10

echo ">>> Iniciando Flask API en puerto 5000..."
python flask_api.py &

echo ">>> Iniciando captura de tráfico en loop (cada 10 minutos)..."
exec python default_generator.py \
    --live \
    --loop \
    --interval 10 \
    --duration 30 \
    --out /app/daily