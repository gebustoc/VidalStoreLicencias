#!/bin/bash
# Crea gw-azure y bff. Requiere que red.sh haya corrido antes.
set -euo pipefail

REGION="${REGION:-brazilsouth}"
RG="${RG:-rg-vidalstore}"
GW_SIZE="${GW_SIZE:-Standard_D2as_v4}"
BFF_SIZE="${BFF_SIZE:-Standard_D2as_v4}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/vidalstore-azure.pub}"
ADMIN_USER="${ADMIN_USER:-azureuser}"
SHUTDOWN_TIME="${SHUTDOWN_TIME:-0000}"  # hora UTC de apagado automatico
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "No existe la llave publica: $SSH_KEY_PATH" >&2
  exit 1
fi

echo "Region: $REGION | Grupo: $RG | gw: $GW_SIZE | bff: $BFF_SIZE | usuario: $ADMIN_USER"

# gw-azure
if az vm show -g "$RG" -n gw-azure -o none 2>/dev/null; then
  echo "VM gw-azure ya existe"
else
  az vm create -g "$RG" -n gw-azure -l "$REGION" \
    --nics nic-gw-azure \
    --size "$GW_SIZE" \
    --image Ubuntu2204 \
    --admin-username "$ADMIN_USER" \
    --ssh-key-values "@$SSH_KEY_PATH" \
    --custom-data "$SCRIPT_DIR/gw-azure-cloud-init.yaml" -o none
fi

# NIC de bff
if az network nic show -g "$RG" -n nic-bff -o none 2>/dev/null; then
  echo "NIC bff ya existe"
else
  az network nic create -g "$RG" -n nic-bff -l "$REGION" \
    --vnet-name vnet-vidalstore --subnet privada \
    --private-ip-address 10.1.2.4 \
    --network-security-group nsg-bff -o none
fi

# bff
if az vm show -g "$RG" -n bff -o none 2>/dev/null; then
  echo "VM bff ya existe"
else
  az vm create -g "$RG" -n bff -l "$REGION" \
    --nics nic-bff \
    --size "$BFF_SIZE" \
    --image Ubuntu2204 \
    --admin-username "$ADMIN_USER" \
    --ssh-key-values "@$SSH_KEY_PATH" -o none
fi

# Apagado automatico (hora UTC)
if ! az vm auto-shutdown --help > /dev/null 2>&1; then
  echo "Aviso: 'az vm auto-shutdown' no disponible; usa deploy/azure/apagar.sh para desasignar."
else
  az vm auto-shutdown -g "$RG" -n gw-azure --time "$SHUTDOWN_TIME" -o none || true
  az vm auto-shutdown -g "$RG" -n bff --time "$SHUTDOWN_TIME" -o none || true
fi

echo "VMs listas: gw-azure (10.1.1.4) y bff (10.1.2.4, sin IP publica)"
