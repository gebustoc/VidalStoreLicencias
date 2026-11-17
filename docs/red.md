# Red de VidalStore · AWS y Azure

Diseño de las dos nubes. Las IP privadas son fijas porque los brokers de Kafka anuncian su dirección: si cambian al reiniciar, los clientes no los encuentran. En AWS nadie tiene el puerto 22 abierto: se entra por Session Manager; en Azure, el SSH va restringido por NSG a la IP de quien despliega.

## AWS · VPC 10.0.0.0/16 · us-east-1

```
PÚBLICA · 10.0.1.0/24 · us-east-1a
  gw-aws · 10.0.1.20 · Elastic IP · Caddy y gateway (E3) · sg-gw
  nat    · 10.0.1.10 · salida de las privadas · sg-nat
APLICACIÓN · 10.0.11.0/24 · us-east-1a
  servicios · 10.0.11.10 · catálogo · licencias · eventos (E3) · sg-servicios
  gestion   · 10.0.11.20 · Kafka UI y simulador · sg-gestion
DATOS-A · 10.0.21.0/24 · us-east-1a
  mq-1   · 10.0.21.11 · controller + broker · sg-mq
  mq-3   · 10.0.21.13 · controller + broker · sg-mq
  datos  · 10.0.21.30 · Postgres 18 · sg-datos
DATOS-B · 10.0.22.0/24 · us-east-1b
  mq-2   · 10.0.22.12 · controller + broker · sg-mq
```

- Aplicación y datos son subredes privadas: no reciben nada de internet y salen por `nat` (ruta `0.0.0.0/0 → interfaz de nat` en la tabla privada).
- La subred pública tiene ruta `0.0.0.0/0 → Internet Gateway`.
- `mq-2` va en `us-east-1b` para que una falla de zona no se lleve las tres `mq`.
- CloudFront no está permitido en el Learner Lab (`AccessDenied`): el HTTPS de AWS lo da Caddy en `gw-aws` (E3).
- En la E2 se levantan `nat`, `mq-1..3`, `datos` y `gestion`. `gw-aws` y `servicios` esperan a la E3.

### Tamaños (con justificación)

| Máquina | Tipo | Justificación |
|---|---|---|
| nat | t3.micro | Solo enmascara y reenvía paquetes; sin carga de CPU sostenida |
| mq-1..3 | t3.medium | Kafka KRaft (controller+broker) necesita heap y page cache; t3.small se queda corto con 3 brokers |
| datos | t3.small | Postgres con carga de escritura de eventos; 2 vCPU / 2 GB alcanzan para el dataset |
| gestion | t3.small | Kafka UI + simulador en contenedores; sin estado propio |
| servicios | t3.medium (E3) | Tres servicios Nest en contenedores |
| gw-aws | t3.micro (E3) | Solo Caddy y el gateway enrutando |

## Reglas de entrada (AWS)

Ninguna abre el 22. Cada regla nombra otro grupo como origen, salvo las dos de `sg-gw`.

| Grupo | Puerto | Origen | Para qué |
|---|---|---|---|
| sg-gw | 80 | 0.0.0.0/0 | Desafío HTTP de Let's Encrypt (E3) |
| sg-gw | 443 | `191.232.214.179/32` (gw-azure) | Tráfico de `gw-azure` hacia `gw-aws` |
| sg-nat | todos | 10.0.11.0/24, 10.0.21.0/24, 10.0.22.0/24 | Salida de las subredes privadas |
| sg-servicios | 3000, 3001, 3010, 3020, 4200, 8080 | sg-gw | Servicios detrás del gateway |
| sg-gestion | (sin entradas) | — | Kafka UI vía túnel de Session Manager; nunca directo |
| sg-mq | 9092, 9093, 4369, 5672, 15672, 25672 | sg-mq | Inter-broker, quorum de controllers, clúster RabbitMQ (4369 epmd, 25672 distribución Erlang) |
| sg-mq | 9092, 5672, 15672 | sg-servicios, sg-gestion | Productores/consumidores y simulador |
| sg-datos | 5432 | sg-servicios, sg-gestion | Postgres |

## Azure · VNet 10.1.0.0/16 · brazilsouth

Dos subredes. Una pública con salida directa y una privada sin salida propia: todo lo externo pasa por `gw-azure`. La región es `brazilsouth`: Azure for Students solo permite algunas regiones y los B de referencia (`B2ats_v2`, `B2als_v2`) no se pueden crear ahí con esta suscripción (`az vm list-skus` no los lista y los intentos devuelven `SkuNotAvailable`); la cuota disponible es DASv4 (4 vCPUs en dos máquinas de 2/2).

| Subred | Rango | Salida a internet |
|---|---|---|
| pública | 10.1.1.0/24 | Directo, por la IP pública de `gw-azure` |
| privada | 10.1.2.0/24 | Solo por `gw-azure` (tabla de rutas `rt-privada`, `--default-outbound false`) |

```
PÚBLICA · 10.1.1.0/24
  gw-azure · 10.1.1.4 · IP pública estática + DNS vidalstore-gw-rg-vidalstore.brazilsouth.cloudapp.azure.com (191.232.214.179) · NAT (DOCKER-USER) · Standard_D2as_v4
PRIVADA · 10.1.2.0/24
  bff · 10.1.2.4 · sin IP pública · sale por gw-azure · Standard_D2as_v4
```

| Máquina | Tipo | Justificación |
|---|---|---|
| gw-azure | Standard_D2as_v4 (2 vCPU, 8 GB) | Es lo único creable en brazilsouth con esta suscripción; Caddy, el frontend y el gateway no piden más, y hace de NAT de la privada |
| bff | Standard_D2as_v4 (2 vCPU, 8 GB) | BFF de NestJS; no hace falta más. Sale solo por `gw-azure` |

### Reglas de entrada (Azure)

| NSG | Puerto | Origen | Para qué |
|---|---|---|---|
| nsg-gw | 22 | `186.189.72.170/32` (quien despliega) | SSH solo desde esa IP |
| nsg-gw | 80 y 443 | Internet | La web y el desafío de Let's Encrypt |
| nsg-gw | todos | 10.1.2.0/24 | El NAT de `bff` |
| nsg-bff | todos | 10.1.0.0/16 | Solo la VNet |

### Ruta de la privada

| Ruta | Destino | Next hop |
|---|---|---|
| default | 0.0.0.0/0 | VirtualAppliance 10.1.1.4 |

Detalles que conviene saber:

- `nic-gw-azure` tiene IP forwarding activado; `nic-bff` solo ve tráfico de la VNet.
- El cloud-init de `gw-azure` activa `ip_forward`, instala Docker y deja `MASQUERADE` para `10.1.0.0/16` con `DOCKER-USER` en `ACCEPT`.
- La privada se creó con `--default-outbound false`: sin esa opción tendría salida propia y el NAT no se probaría nunca.
- `red.sh` y `maquinas.sh` de `deploy/azure/` recrean todo desde cero; `red.sh` es idempotente e incluye la regla `nat-bff` (sin ella la privada descartaba el tráfico aunque la ruta apuntara a `gw-azure`).
- `gw-azure-cloud-init.yaml` no admite caracteres no ASCII: cloud-init lo descarta entero sin avisar.
- Apagado: `az vm deallocate` vía `deploy/azure/apagar.sh` (una VM desasignada no cobra cómputo; al encender vuelven nombre, IP pública estática, etiquetas DNS y reglas de NAT).

## Evidencias

- AWS: `docs/despliegue.md` (salidas de consola/CLI) e `informe.pdf` (capturas).
- Azure: `docs/despliegue.md` (secciones 6 a 10: salida por gw-azure, rutas, VM desasignadas, rutas efectivas del NIC de `bff` y presupuesto).
