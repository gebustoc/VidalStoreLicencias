#!/bin/bash
# User data de las máquinas de aplicación/datos: instala Docker y Compose.
# Las máquinas privadas descargan por NAT; sin nat arriba no hay ni internet ni Session Manager.
# OJO: Amazon Linux 2023 trae Docker en sus repos, pero NO Docker Compose:
# el plugin se instala a mano descargándolo de GitHub a cli-plugins.
set -euxo pipefail

reintentar() { # reintentar <intentos> <comando...>
  local intentos="$1" n=0
  shift
  until "$@"; do
    n=$((n + 1))
    if [ "$n" -ge "$intentos" ]; then
      echo "FALLO tras $intentos intentos: $*" >&2
      return 1
    fi
    echo "Intento $n falló; reintentando en 15 s..." >&2
    sleep 15
  done
}

# AL2023 ya trae curl-minimal (provee `curl`): instalar el paquete `curl`
# entra en conflicto y aborta la transacción. Solo se instala docker.
if command -v dnf > /dev/null 2>&1; then
  reintentar 3 dnf install -y docker
else
  reintentar 3 yum install -y docker
fi

systemctl enable --now docker
usermod -aG docker ec2-user || true

# Docker Compose (plugin) instalado manualmente
COMPOSE_VERSION="${COMPOSE_VERSION:-v2.32.4}"
PLUGIN_DIR=/usr/local/lib/docker/cli-plugins
mkdir -p "$PLUGIN_DIR"
reintentar 5 curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o "$PLUGIN_DIR/docker-compose"
chmod +x "$PLUGIN_DIR/docker-compose"

docker --version
docker compose version
