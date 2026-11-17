#!/bin/bash
set -euo pipefail

REGION="${REGION:-brazilsouth}"
RG="${RG:-rg-vidalstore}"
MI_IP="${MI_IP:-$(curl -s https://api.ipify.org)}"
DNS_LABEL="${DNS_LABEL:-vidalstore-gw-${RG}}"

echo "Region: $REGION | Grupo: $RG | IP SSH permitida: $MI_IP | DNS: $DNS_LABEL"

# Grupo de recursos
az group create -n "$RG" -l "$REGION" -o none

# VNet
if az network vnet show -g "$RG" -n vnet-vidalstore -o none 2>/dev/null; then
  echo "VNet ya existe"
else
  az network vnet create -g "$RG" -n vnet-vidalstore -l "$REGION" \
    --address-prefixes 10.1.0.0/16 \
    --subnet-name publica --subnet-prefixes 10.1.1.0/24 -o none
fi

# Subred privada
if az network vnet subnet show -g "$RG" --vnet-name vnet-vidalstore -n privada -o none 2>/dev/null; then
  echo "Subred privada ya existe"
else
  az network vnet subnet create -g "$RG" --vnet-name vnet-vidalstore \
    -n privada --address-prefixes 10.1.2.0/24 --default-outbound false -o none
fi

# NSG subred publica
az network nsg create -g "$RG" -n nsg-gw -l "$REGION" -o none
az network nsg rule create -g "$RG" --nsg-name nsg-gw -n ssh \
  --priority 100 --access Allow --protocol Tcp \
  --source-address-prefixes "${MI_IP}/32" --destination-port-ranges 22 -o none
az network nsg rule create -g "$RG" --nsg-name nsg-gw -n web \
  --priority 110 --access Allow --protocol Tcp \
  --source-address-prefixes Internet --destination-port-ranges 80 443 -o none
az network nsg rule create -g "$RG" --nsg-name nsg-gw -n nat-bff \
  --priority 120 --access Allow --protocol '*' \
  --source-address-prefixes 10.1.2.0/24 --destination-port-ranges '*' -o none
az network vnet subnet update -g "$RG" --vnet-name vnet-vidalstore \
  -n publica --network-security-group nsg-gw -o none

# NSG subred privada
az network nsg create -g "$RG" -n nsg-bff -l "$REGION" -o none
az network nsg rule create -g "$RG" --nsg-name nsg-bff -n vnet \
  --priority 100 --access Allow --protocol '*' \
  --source-address-prefixes 10.1.0.0/16 --destination-port-ranges '*' -o none
az network vnet subnet update -g "$RG" --vnet-name vnet-vidalstore \
  -n privada --network-security-group nsg-bff -o none

# IP publica estatica
if az network public-ip show -g "$RG" -n ip-gw-azure -o none 2>/dev/null; then
  az network public-ip update -g "$RG" -n ip-gw-azure --dns-name "$DNS_LABEL" -o none
  echo "IP publica ya existe; DNS actualizado"
else
  az network public-ip create -g "$RG" -n ip-gw-azure -l "$REGION" \
    --allocation-method Static --sku Standard --version IPv4 \
    --dns-name "$DNS_LABEL" -o none
fi

# NIC gw-azure
if az network nic show -g "$RG" -n nic-gw-azure -o none 2>/dev/null; then
  az network nic update -g "$RG" -n nic-gw-azure --ip-forwarding true -o none
  echo "NIC gw-azure ya existe; forwarding asegurado"
else
  az network nic create -g "$RG" -n nic-gw-azure -l "$REGION" \
    --vnet-name vnet-vidalstore --subnet publica \
    --private-ip-address 10.1.1.4 --ip-forwarding true \
    --public-ip-address ip-gw-azure -o none
fi

# Tabla de rutas: 0.0.0.0/0 -> 10.1.1.4
az network route-table create -g "$RG" -n rt-privada -l "$REGION" -o none
if az network route-table route show -g "$RG" --route-table-name rt-privada -n default -o none 2>/dev/null; then
  az network route-table route update -g "$RG" --route-table-name rt-privada \
    -n default --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance \
    --next-hop-ip-address 10.1.1.4 -o none
  echo "Ruta default ya existe; actualizada"
else
  az network route-table route create -g "$RG" --route-table-name rt-privada \
    -n default --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance \
    --next-hop-ip-address 10.1.1.4 -o none
fi
az network vnet subnet update -g "$RG" --vnet-name vnet-vidalstore \
  -n privada --route-table rt-privada -o none

echo "Red lista: vnet-vidalstore 10.1.0.0/16 | publica 10.1.1.0/24 | privada 10.1.2.0/24"
