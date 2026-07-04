# INVESTIGACION-LOG — BOS-REPAIR
## Bitácora de Investigaciones Técnicas del Agente

**Proyecto:** BosAgent / SBOS · SKULL  
**Propósito:** Preservar hallazgos de investigaciones para no repetirlas entre sesiones.  
**Regla de oro:** Una entrada por investigación. Nunca eliminar. Solo agregar al final.  
**Cuándo usar:** Siempre que el agente lea documentos, analice código o evalúe arquitectura  
en profundidad. Los hallazgos van aquí — no en documentos separados.

---

## Cómo leer este log (para el agente)

Al iniciar trabajo sobre un tema, buscar primero si ya hay una entrada aquí.
Si existe → leer los hallazgos y usarlos directamente sin repetir la investigación.
Si no existe → investigar, luego agregar la entrada al final.

---

## Registro de investigaciones

---

## INV-001 — 2026-06-13 — Evaluación profesional M1: prerrequisitos del instalador y mock data

**Disparador:** El operador señaló que los datos del primer tenant en el instalador son
insuficientes para la magnitud del SBOS. Evaluación superficial previa detectada.

**Archivos leídos:**
- `servers/S-HOST/bos-preflight/manifest.yml`
- `servers/S-HOST/bos-preflight/task_catalog.sh`
- `cmd/bosctl/system_install.go` (funciones cmdSystemInstall, installServices, writeDefaultService)
- `internal/tui/ctrl/dash/model.go` (función loadMock completa — líneas 232-470)

---

### Hallazgo 1 — M1.1 lee pero no valida

`observer/reader.go` produce un `SystemSnap` con CPU, RAM, Disco, Red. Esa información
existe pero NINGÚN código la compara contra mínimos antes de arrancar la instalación.
Son tres piezas desconectadas: observer → (sin conexión) → preflight → (sin validación) → task_catalog.

---

### Hallazgo 2 — Mínimos reales del stack SBOS (cálculo desde primeros principios)

**RAM — componente a componente:**

| Componente | RAM mínima |
|-----------|-----------|
| k3s control plane (API server + etcd + scheduler + controller-manager) | 2 048 MB |
| PostgreSQL 18.4 (shared_buffers=25% de 16GB + work_mem 50 conx) | 4 096 MB |
| Redis 8.6.2 (Streams + DB0 pub/sub + DB1 ctx_id) | 1 024 MB |
| Keycloak 26.6.2 (JVM heap 2GB + Infinispan 512MB — doc oficial) | 2 560 MB |
| Vault 2.0.1 (Raft + leases) | 512 MB |
| Kong 3.9.x (plugins Lua + rate limiting + OIDC) | 1 024 MB |
| bKernel + biedata (Rust tokio, sin HTTP) | 512 MB |
| bAuth (Go + Java 5 SPIs — Java tiene GC overhead) | 1 024 MB |
| bSearch + bnotify (Go) | 768 MB |
| BOS daemon (Go) | 256 MB |
| Linkerd proxies (~10 pods × 26MB) | 512 MB |
| OS + systemd + kernel overhead | 2 048 MB |
| **TOTAL MÍNIMO** | **~16 GB** |
| **Recomendado** | **32 GB** |

**Disco — por capa:**

| Capa | Espacio |
|------|---------|
| Ubuntu 26.04 base + paquetes preflight | 15 GB |
| k3s + CRI-O + imágenes comprimidas | 20 GB |
| Container runtime overlay descomprimido | 25 GB |
| PostgreSQL data + WAL segments (64 segmentos × 16MB + datos) | 40 GB |
| Redis RDB | 5 GB |
| Vault data (Raft + audit) | 5 GB |
| /var/log (BOS + Loki + apps, 30 días retención) | 20 GB |
| BOS state + artifacts | 5 GB |
| Buffer crecimiento 3 meses | 30 GB |
| **TOTAL MÍNIMO** | **~165 GB** |
| **Recomendado** | **300 GB SSD NVMe** |

**CPU:** mínimo 8 cores físicos (k3s 2, PostgreSQL 2, Keycloak 2, Kong 2, resto 2).
Recomendado 16 cores para absorber picos sin degradar ctx_id P99 < 5ms.

---

### Hallazgo 3 — bos-preflight/manifest.yml tiene valores de placeholder, no reales

```yaml
# Valores actuales (INCORRECTOS para el stack completo):
ram_min_mb: 512        # suficiente solo para el preflight en sí
disk_min_gb: 5         # insuficiente — solo k3s images son 20GB comprimidas
cpu_min: 1             # insuficiente — k3s control plane solo necesita 2
```

Y `task_catalog.sh` ficha_pre_install() solo hace `verificar_root` y `verificar_os`
(acepta 22.04 y 24.04 con un warning — debería ser estricto: solo 26.04 LTS).
**No hay ningún check de RAM, disco, CPU ni puertos.**

---

### Hallazgo 4 — 18 violaciones en el mock data de DashModel loadMock()

**CRÍTICAS (afectan comprensión del stack real):**

- V-01: RAM mock = 8.0 GB (model.go:243) — con 8GB el stack falla en Keycloak (2.5GB) + PG (4GB)
- V-02..V-09: **Ausentes del pods list**: Keycloak, Vault, Kong, bKernel, biedata, bAuth, bSearch, bnotify
  → El mock muestra solo nginx, postgres, redis, coredns, calico, bos-agent — no el stack SBOS
- V-10: LimitRange Container max 512Mi (model.go:319) — bloquearía Keycloak que necesita 2GB JVM

**GRAVES (violan normas SBOS):**

- V-11/12: postgres-svc y redis-svc en namespace "default" (model.go:329-330) — deben ir en `infra`
- V-13: PV postgres solo 20Gi (model.go:346) — necesita ≥40GB para WAL + data real
- V-14: StorageClass con política **Delete** (model.go:357) — SBOS-018 exige **Retain**
- V-15/16: nginx-svc como LoadBalancer + nginx-ingress (model.go:328, 334) — Kong es el único gateway
- V-17: Proceso nginx corriendo (model.go:370) — no pertenece al stack SBOS
- V-18: PAM user `svc-bos` (model.go:398) — debe ser `bosagent` (ADR-001)

**MODERADAS:**

- V-19: Puertos ClusterIP fuera de rango SBOS-050 (postgres debe ser 8100, redis 8120)
- V-20: bos-agent con ClusterRole `view` en `*` — BOS necesita permisos específicos para gestionar fichas
- V-21: grupo `docker` en PAM user skull — SBOS usa containerd/CRI-O
- V-22: Cert etcd RSA-2048 — SBOS-031 pide Ed25519 o RSA-4096 para certs internos
- V-23: `vm.overcommit_memory` ausente — Redis requiere valor 1 o 2
- V-24: postgres RSS mock 512MB — con shared_buffers=4GB el RSS real sería ≥4GB

---

### Hallazgo 5 — El wizard no captura datos del primer tenant

El instalador va directo ScreenBoot → ScreenDashboard. No hay pantallas de configuración
del tenant antes de instalar las fichas. Lo que falta recoger:

| Dato | Para qué se usa |
|------|----------------|
| Perfil S/M/L | Sizing de PostgreSQL, Redis maxmemory, Keycloak réplicas |
| País/Región | SBOS-044-FISCAL: schema fiscal diferente por país (Bolivia ≠ Colombia ≠ México) |
| Empresas máximo | max_replication_slots PG, particionamiento |
| Sucursales máximo | Redis hash slots, Kong upstream pools |
| Usuarios concurrentes estimados | Redis DB1 maxmemory (700 bytes × N ctx_id) |
| Modo online/offline | Si offline: bundle de imágenes. Si online: verificar conectividad |

Un tenant SBOS no es "insertar una fila" — son 7 pasos (KC realm + K8s namespace +
PG schemas × daemon + Redis keyspace + Vault policies + biedata registro + BOS ctx_id seed).

---

### Hallazgo 6 — M1.2 ya está corregido en el código

REGISTRO-ESTADO dice M1.2 = "Fix User=root → bosagent". Verificación directa:
- `system_install.go:231` → `User=bosagent` ✅
- `system_install.go:247` → `User=bosagent` ✅

El bug no existe en el código. M1.2 debe marcarse ✅ en REGISTRO-ESTADO.

---

### Átomos derivados de esta investigación

| Átomo propuesto | Acción | Urgencia |
|----------------|--------|---------|
| M1.P1 | Corregir manifest.yml: ram=16384, disk=170, cpu=8, os_strict=true | CRÍTICA |
| M1.P2 | Agregar _check_resources(), _check_ports(), _check_os_strict() en task_catalog.sh | CRÍTICA |
| M1.P3 | Reemplazar loadMock() con datos SBOS-correctos (stack completo, namespaces correctos) | ALTA |
| M1.P4 | Diseñar pantallas wizard para captura del primer tenant antes de instalar fichas | ALTA |

---

---

## INV-002 — Modelo de Capacidad Dinámico: Implementación y Patrones

**Fecha:** 2026-06-13  
**Contexto:** Derivado de INV-001. Implementación del autómata de capacidad (SBOS-BOS-CAP-001) nivel base.

### Decisión: Estimate × Calculate → Requirements (no umbrales estáticos)

Los umbrales del preflight y del observer NO son valores fijos. Se calculan dinámicamente a partir de los estimados del operador:

```
T (tenants) × E (empresas/tenant) × S (sucursales/empresa) × U (usuarios/sucursal) = Total Users
Concurrentes = Total / 10 (estimación conservadora pico)

Redis DB1  = concurrentes × 700 bytes × 1.5 + overhead (min 256 MB)
PG data    = T×500 + T×E×50 + T×E×S×20 + Total×5 MB
Keycloak   = 2048 + (Total/10000)×512 MB
Kong       = 1024 + T×256 MB
CPU        = max(8, 8 + concurrentes/100000 × 2)
RAM mín    = suma de todos los componentes
```

Esto significa que un servidor con 1 tenant/1 empresa/1 sucursal/5 usuarios puede arrancar con menos de 16GB, mientras que uno con 50 tenants/20 empresas/50 sucursales/100 usuarios necesita 64GB+.

### Patrón ReloadCapacity en observer

El observer usa `sync.Once` para cargar capacity.yaml una sola vez al arrancar. Pero el wizard guarda capacity.yaml DESPUÉS de que el observer arranca (durante la instalación). Para este caso:

```go
capOnce = sync.Once{}  // reset del Once
capReqs = nil          // próxima llamada a Read() intentará cargar
```

Limitación: en producción el daemon arranca después de la instalación, por lo que el Once se dispara con el archivo ya disponible. El ReloadCapacity() es solo para el TUI (donde observer y wizard corren simultáneamente).

### Admisión en tiempo de ejecución (bos.capacity.check)

Antes de crear un tenant, empresa, sucursal o usuario, el llamador debe invocar:

```json
{"method": "bos.capacity.check", "params": {"op_type": "tenant", "current": 3, "used_mb": 0, "req_mb": 0}}
```

Si `allowed=false`, la operación se deniega con `reason` legible para el operador. Esto implementa el motor de Políticas (SBOS-BOS-CAP-001 §5) en su forma más simple.

### Átomos ejecutados de INV-001

| Átomo | Estado |
|-------|--------|
| M1.P1 (manifest.yml real) | ✅ 2dca9e6 |
| M1.P2 (checks task_catalog.sh) | ✅ 2dca9e6 |
| M1.P4 (pantalla wizard capacidad P3B) | ✅ 2dca9e6 |

### Pendiente de INV-001

| Átomo | Estado |
|-------|--------|
| M1.P3 (corregir loadMock() DashModel) | 🔴 pendiente |

### Próximos pasos para M5 (Autómata completo)

- `internal/capacity/collector.go`: recolección 60s de métricas reales (Redis info, PG stats, K8s metrics)
- `internal/capacity/forecaster.go`: regresión lineal + horizonte 7/30/90 días
- `internal/capacity/policy_engine.go`: evaluación declarativa YAML cada 60s

