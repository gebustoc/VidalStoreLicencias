#!/bin/bash
# Lanza las máquinas de la capa de datos (Entrega 2, paso 8):
# nat, mq-1, mq-2, mq-3, datos, gestion.
# Requiere haber corrido antes deploy/aws/red.sh.
# Uso: bash deploy/aws/maquinas.sh
export MSYS_NO_PATHCONV=1
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
DIR="$(cd "$(dirname "$0")" && pwd)"
# Git Bash: el AWS CLI de Windows necesita rutas Windows en file://
if command -v cygpath > /dev/null 2>&1; then DIR_WIN=$(cygpath -w "$DIR"); else DIR_WIN="$DIR"; fi
if [ ! -f "$DIR/red-outputs.env" ]; then
  echo "ERROR: no existe $DIR/red-outputs.env. Primero corre: bash deploy/aws/red.sh" >&2
  exit 1
fi
# shellcheck source=red-outputs.env
source "$DIR/red-outputs.env"

AMI_ID=$(aws ssm get-parameter --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' --output text)
echo "AMI (Amazon Linux 2023): $AMI_ID"

lanzar() { # lanzar <nombre> <subnet> <sg> <ip-privada> <user-data> <tipo> [publica]
  local NOMBRE="$1" SUBNET="$2" SG="$3" IP="$4" USERDATA="$5" TIPO="$6" PUBLICA="${7:-no}" ID
  ID=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Name,Values=vidalstore-${NOMBRE}" "Name=instance-state-name,Values=pending,running,stopped" \
    --query 'Reservations[].Instances[0].InstanceId' --output text)
  if [ -n "$ID" ] && [ "$ID" != "None" ]; then
    echo "$NOMBRE ya existe: $ID (se omite)" >&2
    echo "$ID"
    return
  fi
  local EXTRA=()
  [ "$PUBLICA" = "si" ] && EXTRA+=(--associate-public-ip-address)
  aws ec2 run-instances --region "$REGION" --image-id "$AMI_ID" --instance-type "$TIPO" \
    --count 1 --subnet-id "$SUBNET" --security-group-ids "$SG" \
    --private-ip-address "$IP" \
    --iam-instance-profile Name=LabInstanceProfile \
    ${EXTRA[@]+"${EXTRA[@]}"} \
    --user-data "file://$DIR_WIN/$USERDATA" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=vidalstore-${NOMBRE}}]" \
    --query 'Instances[0].InstanceId' --output text
}

echo "== nat (pública, IP fija 10.0.1.10) =="
NAT_ID=$(lanzar nat "$PUB_ID" "$SG_NAT" 10.0.1.10 nat-user-data.sh t3.micro si)
echo "NAT_ID=$NAT_ID"
aws ec2 modify-instance-attribute --region "$REGION" --instance-id "$NAT_ID" --no-source-dest-check

echo "== Ruta privada 0.0.0.0/0 -> nat =="
NAT_ENI=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$NAT_ID" \
  --query 'Reservations[0].Instances[0].NetworkInterfaces[0].NetworkInterfaceId' --output text)
aws ec2 create-route --region "$REGION" --route-table-id "$RT_PRIV" \
  --destination-cidr-block 0.0.0.0/0 --network-interface-id "$NAT_ENI" > /dev/null 2>&1 || \
aws ec2 replace-route --region "$REGION" --route-table-id "$RT_PRIV" \
  --destination-cidr-block 0.0.0.0/0 --network-interface-id "$NAT_ENI" > /dev/null
echo "RT_PRIV=$RT_PRIV -> $NAT_ENI"

echo "== Esperando a que nat quede Online en Session Manager =="
echo "(las privadas descargan Docker y Compose por nat; sin nat lista no pueden)"
NAT_ONLINE=""
for i in $(seq 1 60); do
  ESTADO=$(aws ssm describe-instance-information --region "$REGION" \
    --filters "Key=InstanceIds,Values=$NAT_ID" \
    --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || echo "")
  if [ "$ESTADO" = "Online" ]; then NAT_ONLINE="si"; break; fi
  sleep 10
done
if [ -z "$NAT_ONLINE" ]; then
  echo "AVISO: nat no aparece Online tras 10 minutos; se continúa igualmente," >&2
  echo "pero las privadas pueden fallar al instalar Docker. Revisa nat antes de seguir." >&2
else
  echo "nat Online. Esperando 30 s extra para que ip_forward e iptables asienten..."
  sleep 30
fi

echo "== mq-1, mq-3, datos (datos-a) y mq-2 (datos-b) =="
MQ1_ID=$(lanzar mq-1 "$DAT_A_ID" "$SG_MQ" 10.0.21.11 docker-user-data.sh t3.medium)
MQ2_ID=$(lanzar mq-2 "$DAT_B_ID" "$SG_MQ" 10.0.22.12 docker-user-data.sh t3.medium)
MQ3_ID=$(lanzar mq-3 "$DAT_A_ID" "$SG_MQ" 10.0.21.13 docker-user-data.sh t3.medium)
DATOS_ID=$(lanzar datos "$DAT_A_ID" "$SG_DATOS" 10.0.21.30 docker-user-data.sh t3.small)

echo "== gestion (aplicación, Kafka UI y simulador) =="
GESTION_ID=$(lanzar gestion "$APP_ID" "$SG_GESTION" 10.0.11.20 docker-user-data.sh t3.small)

cat > "$DIR/maquinas-outputs.env" <<EOF
# Generado por maquinas.sh — $(date -u '+%Y-%m-%d %H:%M:%S UTC')
NAT_ID=$NAT_ID
MQ1_ID=$MQ1_ID
MQ2_ID=$MQ2_ID
MQ3_ID=$MQ3_ID
DATOS_ID=$DATOS_ID
GESTION_ID=$GESTION_ID
NAT_ENI=$NAT_ENI
EOF

echo ""
echo "Máquinas lanzadas. Identificadores en deploy/aws/maquinas-outputs.env"
echo "Espera ~2-4 min a que el user data instale Docker antes de entrar por Session Manager."
