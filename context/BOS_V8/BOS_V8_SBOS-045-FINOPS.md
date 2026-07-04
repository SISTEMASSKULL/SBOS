# SBOS-045-FINOPS
## Modelo FinOps y Gestion de Costos On-Premise — Estandar HUMAN-DOC
### SKULL · SBOS · V8 Enriquecido · Mayo 2026

---

## 1. FinOps On-Premise vs Cloud

| Cloud FinOps | SBOS On-Premise FinOps |
|---|---|
| ¿Cuanto pagamos por recurso? | ¿Que fraccion del servidor (fijo) consume este namespace? |
| Optimizar = gastar menos en factura | Optimizar = caber en servidor actual sin upgrade |
| Alerta = factura supera umbral | Alerta = proyeccion indica necesidad de upgrade |
| Granularidad = servicio cloud | Granularidad = namespace K8s |

### Formula de costo
```
costo_ns = (cpu_ns/cpu_total + ram_ns/ram_total) / 2 × precio_mensual_vps
```
Parametro `precio_mensual_vps` configurable por instalacion.

### Enriquecimiento Smart Rates: Integracion de tasas en modelo FinOps

Smart Rates (SBOS-Rates-015-CRYPTO-USDT-BLACKRATE) proporciona las tasas de conversion necesarias para el modulo FinOps cuando el VPS se paga en moneda extranjera:

- **Black Rate / Dolar Blue:** Tasa de cambio paralela para calculo de costos en economias con doble cotizacion
- **USDT/Stablecoin Rate:** Tasa de conversion USDT para pagos de infraestructura en cripto
- **Cross Rate:** Tasas cruzadas calculadas automaticamente entre pares de divisas (BOB/USD, ARS/USD, MXN/USD)

El motor de cross rate (SBOS-Rates-011-MOTOR-CROSSRATE) permite que el modulo FinOps calcule costos en la moneda local del cliente usando tasas actualizadas automaticamente desde fuentes oficiales (BCB, bancos) y de mercado (black rate, USDT).

```
costo_ns_usd = (cpu_ns/cpu_total + ram_ns/ram_total) / 2 × precio_mensual_vps_usd
costo_ns_local = costo_ns_usd × [tasa_cambio_del_dia]
```

## 2. Modelo de Costos por Namespace

| Servidor | Namespace | Criticidad | Tipo carga |
|---|---|---|---|
| S01 dataserver | dataserver | Maxima | CPU+RAM (PG, Redis) |
| S02 gatewayserver | gatewayserver | Alta | Red (Kong, NGINX) |
| S03 identityserver | identityserver | Alta | CPU (KC, Wazuh) |
| S04 erpserver | erpserver | Alta | RAM (Tryton) |
| S12 monitorserver | monitoring | Media | Disco (Prometheus, Loki) |
| S14 opsserver | devops | Media | Variable (GitLab CI) |
| S15 aiserver | aiserver | Opcional | GPU/CPU (Ollama) |

### PromQL metricas existentes
```promql
# CPU por namespace (fraccion total)
sum by (namespace) (rate(container_cpu_usage_seconds_total[5m])) / sum(machine_cpu_cores)

# RAM por namespace
sum by (namespace) (container_memory_working_set_bytes) / sum(machine_memory_bytes)

# Disco PVC
sum by (namespace) (kubelet_volume_stats_used_bytes) / sum by (namespace) (kubelet_volume_stats_capacity_bytes)
```

## 3. Dashboard Grafana "FinOps SBOS"

5 paneles en un solo dashboard. Variable: `$precio_vps_mensual_usd`.

| Panel | Tipo | Metrica |
|---|---|---|
| CPU por Namespace Top 5 | timeseries | rate(cpu) / machine_cpu_cores × 100. Umbrales: 50% yellow, 75% red |
| RAM por Namespace Top 5 | timeseries | memory_working_set / machine_memory × 100 |
| Disco PVC % por Namespace | bargauge | volume_used / volume_capacity × 100 |
| Costo Estimado Mensual (tabla) | table | (cpu_frac + ram_frac)/2 × $precio_vps. Sorted desc |
| Proyeccion Costo Fin de Mes | stat | Suma total proyectada en USD |

### Enriquecimiento V5: Dashboard con costo en moneda local

El dashboard FinOps se integra con Smart Rates para mostrar costos tambien en moneda local:

| Panel | Tipo | Metrica |
|---|---|---|
| Costo Estimado Mensual (USD) | table | (cpu_frac + ram_frac)/2 × $precio_vps. Sorted desc |
| Costo Estimado Mensual (Local) | table | Costo USD × tasa de cambio del dia (via Smart Rates API) |
| Tasa de Cambio Aplicada | stat | Tasa BCB / Black Rate / USDT segun configuracion |

## 4. Alertas FinOps en Alertmanager

```yaml
- name: sbos.finops
  rules:
    - alert: NamespaceCPUSpikeHigh
      expr: sum by (namespace) (rate(container_cpu_usage_seconds_total[5m]))
            / scalar(sum(machine_cpu_cores)) > 0.25
      for: 1h
      labels: { severity: medium, channel: sbos-finops }
      annotations:
        summary: "Namespace {{ $labels.namespace }} consume > 25% CPU > 1h"

    - alert: FinOpsCostProjectionHigh
      expr: sum(...) * sbos_vps_monthly_cost_usd > sbos_finops_cost_threshold_usd
      for: 30m
      labels: { severity: medium, channel: sbos-finops }
```

Metricas config (post-instalacion):
```yaml
- record: sbos_vps_monthly_cost_usd
  expr: "150"    # Costo real mensual VPS del cliente
- record: sbos_finops_cost_threshold_usd
  expr: "180"    # 120% del costo base
```

## 5. VPA (Vertical Pod Autoscaler)

Modo `Off`: solo recomendaciones, no aplica cambios automaticos. Revision mensual.

### Excluidos del VPA
| Componente | Razón |
|---|---|
| PostgreSQL | Recursos sobredimensionados deliberadamente. Reducir = degradacion |
| Keycloak | Picos autenticacion impredecibles |
| Redis | Dataset en memoria — reducir = evictions |
| Prometheus | RAM proporcional a metricas |

### Revision mensual
```bash
kubectl get vpa -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,CPU:.status...target.cpu,MEM:.status...target.memory'
# Diferencia > 30% → evaluar ajuste. < 10% → ignorar (ruido).
```

## 6. Hardware Minimo

### Nodo unico
| Recurso | Minimo | Recomendado |
|---|---|---|
| CPU | 16 vCPUs | 32 vCPUs |
| RAM | 32 GB | 64 GB |
| Disco OS | 50 GB SSD | 100 GB SSD |
| Disco datos | 500 GB SSD | 1 TB SSD |
| Red | 100 Mbps | 1 Gbps |
| aiserver (opcional) | +8 vCPUs +16GB | +GPU dedicada |

### Comparativa costo on-premise vs cloud

| Config | On-Premise | Cloud equiv. | Ahorro anual |
|---|---|---|---|
| Nodo unico min (16v, 32GB) | $80-120/mes | $280-400/mes | $2,400-3,360 |
| Nodo unico rec (32v, 64GB) | $150-200/mes | $560-800/mes | $4,920-7,200 |
| Horizontal (5 nodos) | $250-350/mes | $800-1,200/mes | $6,600-10,200 |

Ahorro incluye eliminacion de licencias software (stack 100% libre).

### Enriquecimiento Smart Rates: Costo en economia local

Smart Rates permite que la comparativa de costos se exprese en moneda local del cliente usando las tasas del dia. Para Bolivia (BOB), Argentina (ARS), Mexico (MXN), Colombia (COP), las tasas se obtienen automaticamente del motor de cross rate y se presentan en el dashboard FinOps junto a los valores en USD.

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1 Modelo | SBOS-028 v1.0 | §1 (diferencia cloud vs on-premise, formula, modos) |
| §2 Namespaces | SBOS-028 v1.0 | §2 (tabla namespaces, PromQL) |
| §3 Dashboard | SBOS-028 v1.0 | §3 (5 paneles Grafana con JSON specs) |
| §4 Alertas | SBOS-028 v1.0 | §4 (YAML Alertmanager + metricas config) |
| §5 VPA | SBOS-028 v1.0 | §5 (modo Off, exclusiones, revision mensual) |
| §6 Hardware | SBOS-028 v1.0 | §6 (minimos nodo unico/horizontal + comparativa costo) |

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Aportacion |
|---|---|---|
| V5 | /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-028-FinOps-v1_0.md | Dashboard con costo en moneda local |
| Smart Rates | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Rates/context/SBOS-Rates-015-CRYPTO-USDT-BLACKRATE.md | Black rate, USDT/stablecoin para calculo de costos en economias con doble cotizacion |
| Smart Rates | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Rates/context/SBOS-Rates-011-MOTOR-CROSSRATE.md | Motor de cross rate para conversion automatica de costos a moneda local |
| Correlacion V8 | Integracion FinOps + Smart Rates | Costos en moneda local usando tasas del dia, dashboard bilingue USD/local |

---

_SKULL · SBOS · SBOS-045-FINOPS · V8 Enriquecido · Mayo 2026_
