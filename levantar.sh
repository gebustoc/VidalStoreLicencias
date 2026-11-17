#!/bin/bash
# Script para levantar VidalStore con Kafka
# Ejecutar con: sh levantar.sh

# Previene que Git Bash en Windows convierta rutas Unix a rutas Windows
export MSYS_NO_PATHCONV=1
echo "======================================"
echo "  VidalStore - Iniciando con Kafka"
echo "======================================"
echo ""

# Verificar que Docker esté corriendo
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker no está corriendo. Por favor inicia Docker Desktop."
    exit 1
fi

echo "Docker se está corriendo 🥵"
echo ""

# Clonar los repositorios faltantes del proyecto
echo "Verificando repositorios del proyecto..."
mkdir -p repos

if [ ! -d "repos/VidalStoreBff" ]; then
    echo "Clonando VidalStoreBff..."
    git clone "https://github.com/gebustoc/VidalStoreBff.git" "repos/VidalStoreBff" || exit 1
fi

if [ ! -d "repos/VidalStoreGateway" ]; then
    echo "Clonando VidalStoreGateway..."
    git clone "https://github.com/gebustoc/VidalStoreGateway.git" "repos/VidalStoreGateway" || exit 1
fi

if [ ! -d "repos/VidalStoreFront" ]; then
    echo "Clonando VidalStoreFront..."
    git clone "https://github.com/gebustoc/VidalStoreFront.git" "repos/VidalStoreFront" || exit 1
fi

if [ ! -d "repos/VidalStoreAdmin" ]; then
    echo "Clonando VidalStoreAdmin..."
    git clone "https://github.com/gebustoc/VidalStoreAdmin.git" "repos/VidalStoreAdmin" || exit 1
fi

if [ ! -d "repos/VidalStoreEventos" ]; then
    echo "Clonando VidalStoreEventos..."
    git clone "https://github.com/gebustoc/VidalStoreEventos.git" "repos/VidalStoreEventos" || exit 1
fi

echo "Repositorios listos"
echo ""

# Levantar los servicios
echo "Levantando servicios con docker compose..."
docker compose up -d --wait

if [ $? -ne 0 ]; then
    echo "Error al levantar los servicios"
    exit 1
fi

echo ""
echo "Servicios levantados correctamente"
echo ""

# Esperar un momento para que Kafka esté completamente listo
echo "Esperando a que Kafka esté completamente listo..."
sleep 5

# Crear los topics de Kafka
echo ""
echo "Creando topics de Kafka..."
sh kafka/topics.sh

if [ $? -ne 0 ]; then
    echo "Advertencia: Hubo un problema al crear los topics, pero el sistema puede seguir funcionando"
fi

echo ""
echo "======================================"
echo "    Sistema levantado correctamente"
echo "======================================"
echo ""
echo "    Servicios disponibles:"
echo "  - Frontend:        http://localhost:4200"
echo "  - Admin:           http://localhost:4300"
echo "  - Gateway:         http://localhost:8080"
echo "  - BFF:             http://localhost:3002"
echo "  - Backend Juegos:  http://localhost:3000"
echo "  - Backend Licenses: http://localhost:3001"
echo "  - Eventos:         http://localhost:3010"
echo "  - Kafka UI:        http://localhost:8085"
echo "  - RabbitMQ:        http://localhost:15672"
echo ""
echo "   Para ver logs: docker compose logs -f [servicio]"
echo "   Para detener: docker compose down"
echo ""
