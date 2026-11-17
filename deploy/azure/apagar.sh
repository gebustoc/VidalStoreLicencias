#!/bin/bash
set -euo pipefail

REGION="${REGION:-brazilsouth}"
RG="${RG:-rg-vidalstore}"

for vm in gw-azure bff; do
  if az vm show -g "$RG" -n "$vm" -o none 2>/dev/null; then
    az vm deallocate -g "$RG" -n "$vm" -o none
    echo "$vm desasignada (o ya lo estaba)"
  else
    echo "$vm no existe; omitida"
  fi
done

echo "Desasignadas las que existen: gw-azure y bff ($RG)"
