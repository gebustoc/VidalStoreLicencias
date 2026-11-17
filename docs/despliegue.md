# Despliegue · Evidencia de las redes (Entrega 2, paso 10)

Salidas en texto de los comandos pedidos. Los de AWS se corren en el equipo
(1 y 2) y en `mq-1` por Session Manager, dentro del contenedor del broker
(3 a 5). Los de Azure, en el equipo de quien la aloja.


## AWS

### 1 · Las máquinas y sus IP (las privadas sin IP pública)

```
  $ aws ec2 describe-instances --output table --query \
    "Reservations[].Instances[].[Tags[?Key=='Name'].Value|[0],PrivateIpAddress]"


--------------------------------------
|          DescribeInstances         |
+---------------------+--------------+
|  vidalstore-gestion |  10.0.11.20  |
|  vidalstore-mq-2    |  10.0.22.12  |
|  vidalstore-nat     |  10.0.1.10   |
|  vidalstore-mq-3    |  10.0.21.13  |
|  vidalstore-datos   |  10.0.21.30  |
|  vidalstore-mq-1    |  10.0.21.11  |
+---------------------+--------------+
```

### 2 · Nadie abre el puerto 22 (debe responder lista vacía)

```
$ aws ec2 describe-security-groups \
  --filters Name=ip-permission.from-port,Values=22 \
  --query "SecurityGroups[].GroupName"


[]
```

### 3 · Quorum de KRaft: CurrentVoters con 1, 2 y 3

```
$ K="sudo docker exec vidalstore-mq-broker-1 /opt/kafka/bin"
$ $K/kafka-metadata-quorum.sh --bootstrap-server 10.0.21.11:9092 describe --status


ClusterId:              JOgB0339AJpY-LcIPfDCJw
LeaderId:               1
LeaderEpoch:            1
HighWatermark:          8392
MaxFollowerLag:         0
MaxFollowerLagTimeMs:   0
CurrentVoters:          [{"id": 1, "endpoints": ["CONTROLLER://10.0.21.11:9093"]}, {"id": 2, "endpoints": ["CONTROLLER://10.0.22.12:9093"]}, {"id": 3, "endpoints": ["CONTROLLER://10.0.21.13:9093"]}]
CurrentObservers:       []
```

### 4 · vidalstore.compras: 3 particiones con ISR de 3

```
$ $K/kafka-topics.sh --bootstrap-server 10.0.21.11:9092 \
  --describe --topic vidalstore.compras


Topic: vidalstore.compras       TopicId: D49I5ul1Q2ONHle7ejFujw PartitionCount: 3       ReplicationFactor: 3    Configs: min.insync.replicas=2,retention.ms=604800000
        Topic: vidalstore.compras       Partition: 0    Leader: 3       Replicas: 3,1,2 Isr: 3,1,2      Elr:    LastKnownElr: 
        Topic: vidalstore.compras       Partition: 1    Leader: 1       Replicas: 1,2,3 Isr: 1,2,3      Elr:    LastKnownElr: 
        Topic: vidalstore.compras       Partition: 2    Leader: 2       Replicas: 2,3,1 Isr: 2,3,1      Elr:    LastKnownElr: 
```

### 5 · vidalstore.actividad: offsets 1751, 520 y 768

```
$ $K/kafka-get-offsets.sh --bootstrap-server 10.0.21.11:9092 \
  --topic vidalstore.actividad


NO OLVIDAR Q ESTO SE SACA UNA VEZ EJECUTADO EL SIMULADOR xd
```

## Azure

(Las tres primeras salidas van por ProxyJump sobre `gw-azure`: `ssh -i ~/.ssh/vidalstore-azure -J azureuser@191.232.214.179 azureuser@10.1.2.4`.)

### 6 · La salida de bff es la IP pública de gw-azure (en bff, por ProxyJump)

```
$ ssh -i ~/.ssh/vidalstore-azure -J azureuser@191.232.214.179 azureuser@10.1.2.4
$ curl -s https://api.ipify.org
191.232.214.179
$ curl -sI https://ghcr.io | head -1
HTTP/2 405
```

La IP es la pública de `gw-azure` (191.232.214.179). El `HTTP/2 405` confirma que la privada alcanza internet (GHCR) a través del NAT.

### 7 · La ruta de la subred privada apunta a gw-azure

```
$ az network route-table route list -g rg-vidalstore --route-table-name rt-privada -o table
AddressPrefix    HasBgpOverride    Name     NextHopIpAddress    NextHopType       ProvisioningState    ResourceGroup
---------------  ----------------  -------  ------------------  ----------------  -------------------  ---------------
0.0.0.0/0        False             default  10.1.1.4            VirtualAppliance  Succeeded            rg-vidalstore
```

### 8 · Las dos máquinas, desasignadas al entregar

```
$ az vm list -g rg-vidalstore --show-details --query "[].[name,privateIps,powerState]" -o table
Name       PrivateIps   PowerState
---------  -----------  --------------
bff        10.1.2.4     VM deallocated
gw-azure   10.1.1.4     VM deallocated
```

### 9 · La ruta efectiva del NIC de `bff` lo confirma

La ruta por defecto de internet figura `Invalid`; la única activa pasa por el gateway. La privada se creó con `--default-outbound false`: sin esa opción tendría salida propia y el NAT no haría nada.

```
$ az network nic show-effective-route-table -g rg-vidalstore -n nic-bff -o table
Source    State    Address Prefix    Next Hop Type      Next Hop IP
-------  -------  ----------------  -----------------  ------------
Default  Active   10.1.0.0/16       VnetLocal
Default  Invalid  0.0.0.0/0         Internet
User     Active   0.0.0.0/0         VirtualAppliance  10.1.1.4
```

### 10 · Presupuesto mensual de la suscripción

```
$ az consumption budget list -o table
Amount    Category    ETag               Name               TimeGrain
------    --------    -----------------  -----------------  ---------
20.0      Cost        "1dd72f23100b69e"  vidalstore-limite  Monthly
```

En el portal figura el mismo presupuesto (20,00 USD al mes, vigente hasta el 2026-12-31). `nsg-gw` abre SSH solo para el integrante que despliega (`186.189.72.170/32`), HTTP/HTTPS abierto a internet (80/443) y el tráfico de la privada desde `10.1.2.0/24`.

## Cómo recrear o verificar (Azure)

- `deploy/azure/red.sh` crea la red completa: grupo, VNet, subredes, NSG, IP pública estática, NIC con ip-forwarding y tabla de rutas. Es idempotente.
- `deploy/azure/maquinas.sh` crea las dos VMs; exige la llave en `~/.ssh/vidalstore-azure.pub`.
- `deploy/azure/encender.sh` y `deploy/azure/apagar.sh` encienden y desasignan las máquinas.
- `gw-azure-cloud-init.yaml` deja la máquina con Docker, `ip_forward=1` y NAT (`MASQUERADE`, `DOCKER-USER` en `ACCEPT`). No se admiten caracteres no ASCII: cloud-init lo descarta completo.
- `red.sh` incluye la regla `nat-bff`. Antes de tenerla, la tabla de rutas apuntaba a `gw-azure` pero el tráfico de la privada era descartado; la privada no salía.
- Tamaños `Standard_D2as_v4`: los tipos B de referencia no existen en `brazilsouth` con esta suscripción (`az vm list-skus` no los lista; los intentos devuelven `SkuNotAvailable`). DASv4 tiene cuota de 4 vCPUs, justo para 2 máquinas de 2.
