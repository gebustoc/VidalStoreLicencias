#!/bin/bash
# Crea los topics en el clúster de la nube, desde mq-1.
# Uso en mq-1: sudo SERVICIO=broker BOOTSTRAP=10.0.21.11:9092 sh topics.sh
export MSYS_NO_PATHCONV=1
set -euo pipefail

SERVICIO="${SERVICIO:-broker}"
BOOTSTRAP="${BOOTSTRAP:-10.0.21.11:9092}"
KAFKA_BIN="/opt/kafka/bin"

crear() { # crear <topic> <retención-ms>
  local TOPIC="$1" RETENCION="$2"
  sudo docker exec "vidalstore-mq-${SERVICIO}-1" "$KAFKA_BIN/kafka-topics.sh" \
    --bootstrap-server "$BOOTSTRAP" \
    --create --if-not-exists \
    --topic "$TOPIC" \
    --partitions 3 --replication-factor 3 \
    --config min.insync.replicas=2 \
    --config retention.ms="$RETENCION"
}

echo "Creando topics contra $BOOTSTRAP ..."

# vidalstore.compras · 7 días
crear vidalstore.compras 604800000
crear vidalstore.compras.dlt 604800000
# vidalstore.actividad · 1 día
crear vidalstore.actividad 86400000
crear vidalstore.actividad.dlt 86400000
# vidalstore.catalogo · compactado (grupos de 3)
sudo docker exec "vidalstore-mq-${SERVICIO}-1" "$KAFKA_BIN/kafka-topics.sh" \
  --bootstrap-server "$BOOTSTRAP" \
  --create --if-not-exists \
  --topic vidalstore.catalogo \
  --partitions 3 --replication-factor 3 \
  --config min.insync.replicas=2 \
  --config cleanup.policy=compact

echo ""
echo "Topics actuales:"
sudo docker exec "vidalstore-mq-${SERVICIO}-1" "$KAFKA_BIN/kafka-topics.sh" \
  --bootstrap-server "$BOOTSTRAP" --list
