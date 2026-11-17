#!/bin/bash
# Script para crear los topics de Kafka para VidalStore
# Se ejecuta con: sh kafka/topics.sh
# Compatible con Git Bash en Windows (usa MSYS_NO_PATHCONV para evitar conversion de rutas)

export MSYS_NO_PATHCONV=1

BROKER="broker-1:19092"
KAFKA_CMD="/opt/kafka/bin/kafka-topics.sh"

echo "Creando topics de Kafka..."

# Topic: vidalstore.compras
docker compose exec -T broker-1 sh -c "$KAFKA_CMD \
  --bootstrap-server $BROKER \
  --create \
  --if-not-exists \
  --topic vidalstore.compras \
  --partitions 3 \
  --replication-factor 3 \
  --config min.insync.replicas=2 \
  --config retention.ms=604800000"

# Topic: vidalstore.compras.dlt (Dead Letter Topic)
docker compose exec -T broker-1 sh -c "$KAFKA_CMD \
  --bootstrap-server $BROKER \
  --create \
  --if-not-exists \
  --topic vidalstore.compras.dlt \
  --partitions 3 \
  --replication-factor 3 \
  --config min.insync.replicas=2 \
  --config retention.ms=604800000"

# Topic: vidalstore.actividad
docker compose exec -T broker-1 sh -c "$KAFKA_CMD \
  --bootstrap-server $BROKER \
  --create \
  --if-not-exists \
  --topic vidalstore.actividad \
  --partitions 3 \
  --replication-factor 3 \
  --config min.insync.replicas=2 \
  --config retention.ms=604800000"

# Topic: vidalstore.actividad.dlt (Dead Letter Topic)
docker compose exec -T broker-1 sh -c "$KAFKA_CMD \
  --bootstrap-server $BROKER \
  --create \
  --if-not-exists \
  --topic vidalstore.actividad.dlt \
  --partitions 3 \
  --replication-factor 3 \
  --config min.insync.replicas=2 \
  --config retention.ms=604800000"

echo ""
echo "Topics creados. Listando todos los topics:"
docker compose exec -T broker-1 sh -c "$KAFKA_CMD --bootstrap-server $BROKER --list"

echo ""
echo "Para ver detalles de un topic especifico, usar:"
echo "  MSYS_NO_PATHCONV=1 docker compose exec broker-1 sh -c \"/opt/kafka/bin/kafka-topics.sh --bootstrap-server broker-1:19092 --describe --topic vidalstore.compras\""
