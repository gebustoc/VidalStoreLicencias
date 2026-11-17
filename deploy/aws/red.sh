#!/bin/bash
# Crea la red de AWS para VidalStore (Entrega 2, paso 8)
# Idempotente en lo posible: si un recurso ya existe, lo reutiliza.
# NO crea la ruta privada -> NAT: la agrega maquinas.sh cuando nat existe.
# Uso: bash deploy/aws/red.sh
export MSYS_NO_PATHCONV=1
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
NAME="vidalstore"
VPC_CIDR="10.0.0.0/16"
# Subredes (docs/red.md)
PUB_CIDR="10.0.1.0/24"      # publica · us-east-1a
APP_CIDR="10.0.11.0/24"     # aplicación · us-east-1a
DAT_A_CIDR="10.0.21.0/24"   # datos-a · us-east-1a
DAT_B_CIDR="10.0.22.0/24"   # datos-b · us-east-1b
# IP pública de gw-azure (para la regla 443 del sg-gw). MOCK: reemplazar.
GW_AZURE_IP="${GW_AZURE_IP:-MOCK_IP_PUBLICA_GW_AZURE}"

echo "Región: $REGION"

echo "== VPC =="
VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters "Name=tag:Name,Values=${NAME}-vpc" \
  --query 'Vpcs[0].VpcId' --output text)
if [ "$VPC_ID" = "None" ]; then
  VPC_ID=$(aws ec2 create-vpc --region "$REGION" --cidr-block "$VPC_CIDR" \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${NAME}-vpc}]" \
    --query 'Vpc.VpcId' --output text)
  aws ec2 modify-vpc-attribute --region "$REGION" --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'
  aws ec2 modify-vpc-attribute --region "$REGION" --vpc-id "$VPC_ID" --enable-dns-support '{"Value":true}'
fi
echo "VPC_ID=$VPC_ID"

echo "== Internet Gateway =="
IGW_ID=$(aws ec2 describe-internet-gateways --region "$REGION" --filters "Name=tag:Name,Values=${NAME}-igw" \
  --query 'InternetGateways[0].InternetGatewayId' --output text)
if [ "$IGW_ID" = "None" ]; then
  IGW_ID=$(aws ec2 create-internet-gateway --region "$REGION" \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${NAME}-igw}]" \
    --query 'InternetGateway.InternetGatewayId' --output text)
  aws ec2 attach-internet-gateway --region "$REGION" --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
fi
echo "IGW_ID=$IGW_ID"

crear_subred() { # crear_subred <nombre> <cidr> <az>
  local NOMBRE="$1" CIDR="$2" AZ="$3" ID
  ID=$(aws ec2 describe-subnets --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${NAME}-${NOMBRE}" \
    --query 'Subnets[0].SubnetId' --output text)
  if [ "$ID" = "None" ]; then
    ID=$(aws ec2 create-subnet --region "$REGION" --vpc-id "$VPC_ID" --cidr-block "$CIDR" \
      --availability-zone "$AZ" \
      --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${NAME}-${NOMBRE}}]" \
      --query 'Subnet.SubnetId' --output text)
  fi
  echo "$ID"
}

echo "== Subredes =="
PUB_ID=$(crear_subred publica "$PUB_CIDR" "${REGION}a")
APP_ID=$(crear_subred aplicacion "$APP_CIDR" "${REGION}a")
DAT_A_ID=$(crear_subred datos-a "$DAT_A_CIDR" "${REGION}a")
DAT_B_ID=$(crear_subred datos-b "$DAT_B_CIDR" "${REGION}b")
echo "PUB_ID=$PUB_ID APP_ID=$APP_ID DAT_A_ID=$DAT_A_ID DAT_B_ID=$DAT_B_ID"

echo "== Tablas de rutas =="
crear_rt() { # crear_rt <nombre>
  local NOMBRE="$1" ID
  ID=$(aws ec2 describe-route-tables --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${NAME}-${NOMBRE}" \
    --query 'RouteTables[0].RouteTableId' --output text)
  if [ "$ID" = "None" ]; then
    ID=$(aws ec2 create-route-table --region "$REGION" --vpc-id "$VPC_ID" \
      --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${NAME}-${NOMBRE}}]" \
      --query 'RouteTable.RouteTableId' --output text)
  fi
  echo "$ID"
}
RT_PUB=$(crear_rt publica)
RT_PRIV=$(crear_rt privada)
aws ec2 create-route --region "$REGION" --route-table-id "$RT_PUB" \
  --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" > /dev/null 2>&1 || \
aws ec2 replace-route --region "$REGION" --route-table-id "$RT_PUB" \
  --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" > /dev/null
for S in "$PUB_ID"; do aws ec2 associate-route-table --region "$REGION" --route-table-id "$RT_PUB" --subnet-id "$S" > /dev/null 2>&1 || true; done
for S in "$APP_ID" "$DAT_A_ID" "$DAT_B_ID"; do aws ec2 associate-route-table --region "$REGION" --route-table-id "$RT_PRIV" --subnet-id "$S" > /dev/null 2>&1 || true; done
echo "RT_PUB=$RT_PUB RT_PRIV=$RT_PRIV"
echo "NOTA: la ruta 0.0.0.0/0 -> NAT de la tabla privada la agrega maquinas.sh tras lanzar nat."

echo "== Grupos de seguridad (sin puerto 22 en ninguno) =="
crear_sg() { # crear_sg <nombre> <descripción>
  local NOMBRE="$1" DESC="$2" ID
  ID=$(aws ec2 describe-security-groups --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=${NAME}-${NOMBRE}" \
    --query 'SecurityGroups[0].GroupId' --output text)
  if [ "$ID" = "None" ]; then
    ID=$(aws ec2 create-security-group --region "$REGION" --group-name "${NAME}-${NOMBRE}" \
      --description "$DESC" --vpc-id "$VPC_ID" --query 'GroupId' --output text)
  fi
  echo "$ID"
}
SG_GW=$(crear_sg gw "gw-aws: 80 internet (desafio Lets Encrypt), 443 solo desde gw-azure")
SG_NAT=$(crear_sg nat "nat: salida de las subredes privadas")
SG_SERVICIOS=$(crear_sg servicios "servicios: catalogo, licencias, eventos")
SG_GESTION=$(crear_sg gestion "gestion: Kafka UI y simulador, sin entrada")
SG_MQ=$(crear_sg mq "mq: Kafka y RabbitMQ entre nodos y desde app/gestion")
SG_DATOS=$(crear_sg datos "datos: Postgres desde app y gestion")
echo "SG_GW=$SG_GW SG_NAT=$SG_NAT SG_SERVICIOS=$SG_SERVICIOS SG_GESTION=$SG_GESTION SG_MQ=$SG_MQ SG_DATOS=$SG_DATOS"

regla_in() { # regla_in <sg> <proto> <puerto-o-rango> <origen-sg-o-cidr>
  local SG="$1" PROTO="$2" PORT="$3" SRC="$4"
  if [[ "$SRC" == sg-* ]]; then
    aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG" \
      --protocol "$PROTO" --port "$PORT" --source-group "$SRC" > /dev/null 2>&1 || true
  else
    aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG" \
      --protocol "$PROTO" --port "$PORT" --cidr "$SRC" > /dev/null 2>&1 || true
  fi
}

# sg-gw: 80 abierto a internet (desafio Lets Encrypt), 443 solo desde gw-azure
regla_in "$SG_GW" tcp 80 0.0.0.0/0
if [ "$GW_AZURE_IP" != "MOCK_IP_PUBLICA_GW_AZURE" ]; then
  regla_in "$SG_GW" tcp 443 "${GW_AZURE_IP}/32"
else
  echo "AVISO: GW_AZURE_IP sin definir (MOCK); la regla 443/gw-azure se omite. Exporta GW_AZURE_IP=<ip> y reejecuta."
fi
# sg-nat: solo tráfico desde las subredes privadas
for CIDR in "$APP_CIDR" "$DAT_A_CIDR" "$DAT_B_CIDR"; do regla_in "$SG_NAT" -1 -1 "$CIDR"; done
# sg-servicios: puertos de los servicios solo desde sg-gw
for P in 3000 3001 3010 3020 4200 8080; do regla_in "$SG_SERVICIOS" tcp "$P" "$SG_GW"; done
# sg-gestion: sin reglas de entrada (se entra por Session Manager y túnel)
# sg-mq: Kafka y RabbitMQ desde sí mismo, servicios y gestión
# 4369 = epmd y 25672 = distribución Erlang: sin ellos RabbitMQ no forma clúster
for P in 9092 9093 4369 5672 15672 25672; do regla_in "$SG_MQ" tcp "$P" "$SG_MQ"; done
for P in 9092 5672 15672; do regla_in "$SG_MQ" tcp "$P" "$SG_SERVICIOS"; done
for P in 9092 5672 15672; do regla_in "$SG_MQ" tcp "$P" "$SG_GESTION"; done
# sg-datos: Postgres desde servicios y gestión
regla_in "$SG_DATOS" tcp 5432 "$SG_SERVICIOS"
regla_in "$SG_DATOS" tcp 5432 "$SG_GESTION"

cat > "$(dirname "$0")/red-outputs.env" <<EOF
# Generado por red.sh — $(date -u '+%Y-%m-%d %H:%M:%S UTC')
VPC_ID=$VPC_ID
IGW_ID=$IGW_ID
PUB_ID=$PUB_ID
APP_ID=$APP_ID
DAT_A_ID=$DAT_A_ID
DAT_B_ID=$DAT_B_ID
RT_PUB=$RT_PUB
RT_PRIV=$RT_PRIV
SG_GW=$SG_GW
SG_NAT=$SG_NAT
SG_SERVICIOS=$SG_SERVICIOS
SG_GESTION=$SG_GESTION
SG_MQ=$SG_MQ
SG_DATOS=$SG_DATOS
EOF

echo ""
echo "Red creada. Identificadores guardados en deploy/aws/red-outputs.env"
