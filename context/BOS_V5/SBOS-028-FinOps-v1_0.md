# SBOS-028 — Modelo FinOps y Gestión de Costos de Infraestructura
## Dashboard, alertas y modelo de costos on-premise para SBOS

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-028
**Versión:** 1.0
**Estado:** ACTIVO
**Documento nuevo**
**Clasificación:** Gestión Económica — FinOps On-Premise
**Complementa:** SBOS-016 (servidores lógicos y namespaces), SBOS-024 (alertas existentes)

---

## Tabla de Contenidos

1. [FinOps on-premise: el modelo de SBOS](#sbos)
2. [Modelo de costos por namespace K8s](#2-modelo-de-costos-por-namespace-k8s)
3. [Dashboard Grafana "FinOps SBOS"](#sbos)
4. [Alertas FinOps en Alertmanager](#4-alertas-finops-en-alertmanager)
5. [Optimización activa con VPA](#5-optimización-activa-con-vpa)
6. [Hardware mínimo recomendado](#6-hardware-mínimo-recomendado)
7. [Registro de cambios](#7-registro-de-cambios)

---

## 1. FinOps on-premise: el modelo de SBOS

### 1.1 Diferencia con el FinOps en cloud

El FinOps convencional (AWS Cost Explorer, GCP Billing, Azure Cost Management) opera sobre un modelo de pago por uso: cada llamada API, cada GB almacenado, cada hora de VM tienen un precio facturado por el proveedor cloud.

SBOS opera en **infraestructura on-premise soberana**: el cliente paga un monto fijo mensual por su VPS o servidor físico, independientemente del uso. No hay factura por evento.

En este modelo, "costo" significa algo diferente:

| Cloud FinOps | SBOS On-Premise FinOps |
|-------------|------------------------|
| ¿Cuánto pagamos por este recurso? | ¿Qué fracción del servidor (fijo) consume este namespace? |
| Optimizar = gastar menos en la factura cloud | Optimizar = caber en el servidor actual sin necesitar uno más grande |
| Alerta de costo = factura supera umbral | Alerta de costo = proyección indica que necesitamos upgrade de hardware |
| Granularidad = por servicio cloud | Granularidad = por namespace K8s del servidor lógico |

### 1.2 El "costo" en SBOS

El costo real de SBOS para el cliente es el precio mensual de su VPS/servidor. SBOS FinOps distribuye ese costo proporcional al uso de recursos por namespace:

```
costo_namespace_cpu = (cpu_usado_namespace / cpu_total_nodo) × precio_mensual_vps
costo_namespace_ram = (ram_usada_namespace / ram_total_nodo) × precio_mensual_vps
costo_namespace_total = costo_namespace_cpu + costo_namespace_ram
```

El parámetro `precio_mensual_vps` es **configurable por instalación** — lo define el administrador del cliente al momento de instalar SBOS.

### 1.3 Modos de instalación y su impacto en FinOps

| Modo | Descripción | Impacto en costos |
|------|-------------|------------------|
| **Nodo único** | Todos los 15 servidores lógicos en 1 VPS | El 100% del costo del VPS es atribuible al stack SBOS |
| **Horizontal (2-15 nodos)** | Cada servidor lógico en un VPS separado | Cada VPS tiene su propio `precio_mensual_vps` — sumar para el total |

---

## 2. Modelo de costos por namespace K8s

### 2.1 Namespaces K8s de los servidores lógicos

Cada servidor lógico de SBOS-016 tiene un namespace K8s correspondiente:

| Servidor lógico | Namespace K8s | Criticidad | Tipo de carga |
|----------------|--------------|-----------|---------------|
| S01 dataserver | `dataserver` | Máxima | CPU+RAM intensivo (PostgreSQL, Redis) |
| S02 gatewayserver | `gatewayserver` | Alta | Red intensivo (Kong, NGINX) |
| S03 identityserver | `identityserver` | Alta | CPU moderado (Keycloak, Wazuh) |
| S04 erpserver | `erpserver` | Alta | RAM intensivo (Tryton) |
| S05 devserver | `devserver` | Media | CPU variable (compilación) |
| S12 monitorserver | `monitoring` | Media | Disco intensivo (Prometheus, Loki) |
| S14 opsserver | `devops` | Media | Variable (GitLab CI) |
| S15 aiserver | `aiserver` | Baja/Opcional | GPU/CPU muy intensivo (Ollama) |

### 2.2 Métricas de Prometheus para el modelo de costos

El dashboard usa **métricas existentes** de Prometheus. No se requieren nuevas métricas:

```promql
# Uso de CPU por namespace (fracción del total del nodo)
sum by (namespace) (
  rate(container_cpu_usage_seconds_total{namespace!=""}[5m])
) / sum(machine_cpu_cores)

# Uso de RAM por namespace (fracción del total del nodo)
sum by (namespace) (
  container_memory_working_set_bytes{namespace!=""}
) / sum(machine_memory_bytes)

# Uso de disco (PVC por namespace)
sum by (namespace) (
  kubelet_volume_stats_used_bytes
) / sum by (namespace) (
  kubelet_volume_stats_capacity_bytes
)
```

### 2.3 Costo estimado por namespace (Grafana calculated field)

```promql
# Costo estimado mensual en USD para el namespace (usando precio del VPS como variable)
# $precio_vps es un parámetro configurable en el dashboard de Grafana

(
  sum by (namespace) (rate(container_cpu_usage_seconds_total[5m])) / sum(machine_cpu_cores)
  +
  sum by (namespace) (container_memory_working_set_bytes) / sum(machine_memory_bytes)
) / 2
* $precio_vps_mensual_usd
```

En Grafana, `$precio_vps_mensual_usd` es una variable de dashboard que el administrador configura al instalar el dashboard.

---

## 3. Dashboard Grafana "FinOps SBOS"

**Ubicación:** S12 monitorserver, Grafana
**Folder:** Infraestructura / FinOps
**Refresh:** Cada 5 minutos
**Variable de dashboard:** `precio_vps_mensual_usd` (configurable por el administrador)

### Panel 1 — CPU utilización % por namespace (Top 5 consumers)

```json
{
  "type": "timeseries",
  "title": "CPU por Namespace — Top 5",
  "targets": [{
    "expr": "topk(5, sum by (namespace) (rate(container_cpu_usage_seconds_total[5m])) / sum(machine_cpu_cores) * 100)",
    "legendFormat": "{{namespace}}"
  }],
  "thresholds": [
    { "value": 50, "color": "yellow", "op": "gt" },
    { "value": 75, "color": "red", "op": "gt" }
  ]
}
```

### Panel 2 — RAM utilización % por namespace (Top 5 consumers)

```json
{
  "type": "timeseries",
  "title": "RAM por Namespace — Top 5",
  "targets": [{
    "expr": "topk(5, sum by (namespace) (container_memory_working_set_bytes) / sum(machine_memory_bytes) * 100)",
    "legendFormat": "{{namespace}}"
  }]
}
```

### Panel 3 — Disco PVC utilizado vs disponible por namespace

```json
{
  "type": "bargauge",
  "title": "Disco PVC — Usado / Disponible por Namespace",
  "targets": [{
    "expr": "sum by (namespace) (kubelet_volume_stats_used_bytes) / sum by (namespace) (kubelet_volume_stats_capacity_bytes) * 100",
    "legendFormat": "{{namespace}}"
  }],
  "options": {
    "reduceOptions": { "calcs": ["lastNotNull"] },
    "orientation": "horizontal"
  }
}
```

### Panel 4 — Costo estimado mensual acumulado por namespace

```json
{
  "type": "table",
  "title": "Costo Estimado Mensual por Namespace (USD)",
  "targets": [{
    "expr": "((sum by (namespace) (rate(container_cpu_usage_seconds_total[5m])) / scalar(sum(machine_cpu_cores))) + (sum by (namespace) (container_memory_working_set_bytes) / scalar(sum(machine_memory_bytes)))) / 2 * $precio_vps_mensual_usd",
    "legendFormat": "{{namespace}}"
  }],
  "transformations": [
    { "id": "sortBy", "options": { "fields": [{ "displayName": "Value", "desc": true }] } }
  ]
}
```

### Panel 5 — Proyección de costo fin de mes

```json
{
  "type": "stat",
  "title": "Proyección Costo Total — Fin de Mes",
  "description": "Si el uso sigue igual hasta fin de mes",
  "targets": [{
    "expr": "sum(((sum by (namespace) (rate(container_cpu_usage_seconds_total[1h])) / scalar(sum(machine_cpu_cores))) + (sum by (namespace) (container_memory_working_set_bytes) / scalar(sum(machine_memory_bytes)))) / 2 * $precio_vps_mensual_usd)",
    "legendFormat": "USD proyectado"
  }]
}
```

---

## 4. Alertas FinOps en Alertmanager

Las siguientes reglas se agregan al `prometheus-rules.yml` de SBOS-024. No duplican ninguna de las alertas existentes (DiskUsageHigh, MemoryUsageHigh).

```yaml
# SBOS-028 — Alertas FinOps on-premise
# Archivo: prometheus-rules.yml — agregar al grupo "sbos.finops"

- name: sbos.finops
  rules:

    - alert: NamespaceCPUSpikeHigh
      expr: |
        sum by (namespace) (rate(container_cpu_usage_seconds_total[5m]))
        / scalar(sum(machine_cpu_cores))
        > 0.25
      for: 1h
      labels:
        severity: medium
        team: skull-ops
        channel: sbos-finops    # Canal separado — no mezclar con alertas críticas
      annotations:
        summary: "Namespace {{ $labels.namespace }} consume > 25% de CPU por > 1 hora"
        description: >
          El namespace {{ $labels.namespace }} está usando el {{ $value | humanizePercentage }}
          del CPU total del nodo durante más de 1 hora.
          Si este patrón se sostiene, puede presionar el hardware del cliente.
          Revisar si hay jobs o queries ineficientes en ese namespace.

    - alert: FinOpsCostProjectionHigh
      expr: |
        sum(
          (
            (sum by (namespace) (rate(container_cpu_usage_seconds_total[6h])) / scalar(sum(machine_cpu_cores)))
            +
            (sum by (namespace) (container_memory_working_set_bytes) / scalar(sum(machine_memory_bytes)))
          ) / 2
        ) * sbos_vps_monthly_cost_usd > sbos_finops_cost_threshold_usd
      for: 30m
      labels:
        severity: medium
        team: skull-ops
        channel: sbos-finops
      annotations:
        summary: "Proyección de costo mensual supera el umbral configurado"
        description: >
          La proyección de costo mensual basada en el uso actual de las últimas 6 horas
          supera el umbral configurado de {{ $labels.threshold }} USD/mes.
          Revisar el dashboard FinOps en Grafana para identificar namespaces de alto consumo.
          El umbral es configurable en sbos_finops_cost_threshold_usd.
```

Las métricas `sbos_vps_monthly_cost_usd` y `sbos_finops_cost_threshold_usd` son **métricas personalizadas** con valor constante, configuradas por el administrador al instalar SBOS:

```yaml
# En prometheus-custom-metrics.yml — configurar post-instalación
- name: sbos.config
  rules:
    - record: sbos_vps_monthly_cost_usd
      expr: "150"    # Reemplazar con el costo real mensual del VPS del cliente

    - record: sbos_finops_cost_threshold_usd
      expr: "180"    # Umbral de alerta: 120% del costo base esperado
```

---

## 5. Optimización activa con VPA

El Vertical Pod Autoscaler (VPA) en modo `Off` proporciona **recomendaciones** sin aplicarlas automáticamente. El administrador las revisa mensualmente.

### 5.1 Instalación de VPA

```bash
# VPA debe instalarse antes de configurar las fichas con VPA habilitado
kubectl apply -f https://github.com/kubernetes/autoscaler/releases/latest/download/vpa-v1.yaml
```

### 5.2 Configuración VPA para fichas del stack

```yaml
# Ejemplo: VPA para Tryton en erpserver
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: tryton-vpa
  namespace: erpserver
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: tryton
  updatePolicy:
    updateMode: "Off"     # Solo recomendaciones — no aplicar automáticamente
  resourcePolicy:
    containerPolicies:
      - containerName: tryton
        minAllowed:
          cpu: "100m"
          memory: "256Mi"
        maxAllowed:
          cpu: "4000m"
          memory: "8Gi"
```

### 5.3 Componentes EXCLUIDOS del VPA

Los siguientes StatefulSets tienen requerimientos de recursos fijos y bien conocidos. El VPA no debe sugerir cambios que puedan desestabilizarlos:

| Componente | Razón de exclusión |
|------------|-------------------|
| **PostgreSQL** | Los recursos de PostgreSQL deben estar sobredimensionados deliberadamente. Reducirlos causa degradación de performance inmediata. |
| **Keycloak** | Maneja picos de autenticación impredecibles. Necesita margen de seguridad constante. |
| **Redis** | Dataset en memoria — reducir RAM causa evictions que rompen la funcionalidad. |
| **Prometheus** | Requiere RAM proporcional al número de métricas. Cambiar en caliente puede causar pérdida de datos. |

### 5.4 Proceso de revisión mensual de recomendaciones VPA

```bash
# Ver todas las recomendaciones VPA activas
kubectl get vpa -A -o custom-columns=\
  'NAMESPACE:.metadata.namespace,NAME:.metadata.name,\
  CPU_REC:.status.recommendation.containerRecommendations[0].target.cpu,\
  MEM_REC:.status.recommendation.containerRecommendations[0].target.memory'

# Para cada recomendación: comparar con el resource request actual
# Si la diferencia es > 30%: evaluar ajustar la ficha correspondiente
# Si la diferencia es < 10%: ignorar (ruido)
```

---

## 6. Hardware mínimo recomendado

### 6.1 Configuraciones por modo de instalación

#### Modo nodo único (todos los servidores lógicos en 1 VPS)

| Componente | Mínimo | Recomendado | Notas |
|-----------|--------|-------------|-------|
| CPU | 16 vCPUs | 32 vCPUs | PostgreSQL + Keycloak + apps de negocio consumen mucho |
| RAM | 32 GB | 64 GB | Keycloak 4GB + PostgreSQL shared_buffers 8GB + Redis + apps |
| Disco OS | 50 GB SSD | 100 GB SSD | SO + logs del sistema |
| Disco datos | 500 GB SSD | 1 TB SSD | PostgreSQL data + MinIO backups + Prometheus metrics |
| Red | 100 Mbps | 1 Gbps | Kong + NGINX para tráfico de apps |
| S15 aiserver | + 8 vCPUs + 16 GB RAM | + GPU dedicada | Solo si se instala aiserver opcional |

#### Modo horizontal (servidores críticos separados)

| Servidor | CPU | RAM | Disco | Notas |
|---------|-----|-----|-------|-------|
| S01 dataserver | 8 vCPUs | 32 GB | 500 GB SSD | PostgreSQL necesita RAM generosa para shared_buffers |
| S03 identityserver | 4 vCPUs | 8 GB | 100 GB SSD | Keycloak |
| S12 monitorserver | 4 vCPUs | 8 GB | 200 GB SSD | Prometheus + Loki necesitan mucho disco |
| S14 opsserver | 4 vCPUs | 8 GB | 200 GB SSD | GitLab CI + pgBackRest |
| Resto (S02, S04-S11, S13) | 2-4 vCPUs | 4-8 GB | 50-100 GB SSD | Variable por workload |

### 6.2 Comparativa de costo: on-premise vs cloud equivalente

| Configuración | On-Premise (VPS) | Equivalente cloud (estimado) | Diferencia anual |
|--------------|-----------------|------------------------------|-----------------|
| Nodo único mínimo (16 vCPU, 32 GB) | ~$80-120 USD/mes | ~$280-400 USD/mes (c5.4xlarge equiv.) | -$2,400-3,360 USD/año |
| Nodo único recomendado (32 vCPU, 64 GB) | ~$150-200 USD/mes | ~$560-800 USD/mes | -$4,920-7,200 USD/año |
| Horizontal (5 nodos separados) | ~$250-350 USD/mes | ~$800-1,200 USD/mes | -$6,600-10,200 USD/año |

> **Nota:** Los precios son estimativos y varían por proveedor de VPS y región. Los precios cloud son precios bajo demanda sin descuentos. El ahorro real de SBOS on-premise incluye también la eliminación de costos de licencias de software (stack 100% libre).

---

## 7. Registro de cambios

| Versión | Fecha | Autor | Descripción |
|---------|-------|-------|-------------|
| 1.0 | Marzo 2026 | SKULL Team | Documento inicial — modelo de costos, dashboard Grafana, alertas FinOps, VPA, hardware |

---

*SKULL · SBOS · SBOS-028-FINOPS · v1.0 · Marzo 2026*
*Complementa: SBOS-016 (namespaces K8s por servidor lógico), SBOS-024 (alertas existentes DiskUsageHigh, MemoryUsageHigh)*
