# Anexo A.12 — Port Manager: Motor de Asignación de Puertos
## Basado en RFC 6335 (BCP 165) — IANA Port Registry Procedures

**Versión:** 4.0.0 · **Fecha:** 2026-07-18 · **Autor:** bos-developer — SBOS
**Fortalece al motor:** ③ Server FICHAS
**Referencia:** [3.08 — Port Manager](../3.08_MANUAL-PORT-MANAGER.md) · [RFC 6335](https://datatracker.ietf.org/doc/rfc6335/) (BCP 165) · [SBOS-050-PORT-CATALOG](../../../context/BOS_V8/BOS_V8_SBOS-050-PORT-CATALOG.md)
**Código futuro:** `internal/portman/` — subsistema del daemon BOS

**Cambio en v4.0.0:** Kardex ampliado a inventario de activos de red ISO 27001 A.8.20.
Modelo de dos capas (IP estable vs IP efímera). Nuevos campos: `asset_type`, `asset_id`,
`asset_owner`, `labels`, `external_ip`, `dns_name`, `subdominio`, `ruta_kong`.
División proveedores (Kardex) vs consumidores (Context Plane).

---

## 1. Fundamento normativo — RFC 6335 (BCP 165)

El **RFC 6335** es el estándar de la IETF que define cómo se administran los puertos TCP/UDP
en internet. Es un **BCP 165** (Best Current Practice): todo el mundo — IANA, fabricantes de SO,
proveedores cloud, operadores de red — sigue este proceso.

El Port Manager de SBOS implementa el RFC 6335 **dentro del sistema operativo empresarial**.
Lo que IANA hace para internet, el Port Manager lo hace para el SBOS.

### 1.1 Los tres rangos IANA que el RFC define

| Rango | Nombre | Política de asignación | SBOS |
|-------|--------|----------------------|------|
| 0–1023 | **System Ports** | IETF Review / IESG Approval | 🔒 SBOS no asigna — son del SO y protocolos estándar |
| 1024–49151 | **User Ports** | Expert Review | ✅ **SBOS opera aquí** — toda asignación sigue el proceso RFC 6335 |
| 49152–65535 | **Dynamic Ports** | Nunca se asignan — efímeros del OS | 🚫 SBOS nunca asigna servicios en este rango |

### 1.2 Los 8 campos obligatorios del RFC 6335

Cada asignación de puerto requiere estos campos. El Port Manager los completa automáticamente:

| # | Campo RFC 6335 | Obligatorio | Implementación SBOS |
|:--|---------------|:-----------:|---------------------|
| 1 | **Service Name** | ✅ | `sbos-<ficha>-<tipo>` — 1-15 chars, letras/dígitos/guiones, sin guiones adyacentes |
| 2 | **Transport Protocol** | ✅ | TCP, UDP, SCTP o DCCP. TCP en 90% de casos |
| 3 | **Assignee** | ✅ | `bos.ficha.install` — el agente o proceso que asignó |
| 4 | **Contact** | ✅ | `ficha_id: keycloak` — la ficha responsable del puerto |
| 5 | **Description** | ✅ | `ClusterIP HTTP — Keycloak SSO (S03 identityserver, T=0)` |
| 6 | **Reference** | ✅ | `SBOS-050 §12.3, S03 F0` — ubicación en el documento canónico |
| 7 | **Port Number** | Opcional | Derivado por el Rule Engine: `8200` |
| 8 | **Assignment Notes** | Opcional | `containerPort=8080, namespace=sbos-identity` |

### 1.3 Ciclo de vida de un puerto según RFC 6335 §8

El RFC establece que los puertos **nunca se borran** del registro. Solo cambian de estado:

```
RFC 6335                          SBOS Kardex
─────────                         ────────────
Assigned      → puerto en uso     → estado: asignado
De-Assignment → devuelto por el   → estado: liberado  (liberado_en = now())
                Assignee
Revocation    → IANA lo revoca    → estado: revocado   (requiere HITL)
Reuse         → mismo Assignee,   → nuevo registro con mismo puerto + nuevo propósito
                nuevo propósito
Transfer      → PROHIBIDO por     → no implementado en Kardex
                RFC 6335 §8.4
```

### 1.4 Principios de conservación del RFC 6335

| Principio | Implementación SBOS |
|-----------|-------------------|
| **Un puerto por servicio** — no asignar múltiples puertos al mismo servicio | El Port Manager asigna un ClusterIP por cada `containerPort + tipo_t`. Si una ficha tiene 3 containerPorts, recibe 3 ClusterIPs |
| **Version sharing** — múltiples versiones del servicio comparten el mismo puerto | Si keycloak se actualiza de v26 a v27, el ClusterIP 8200 no cambia |
| **Transport-specific** — asignar solo para los protocolos solicitados | Si la ficha solo declara TCP, no se asigna UDP |
| **Preferir nombres sobre números** — usar DNS SRV records en lugar de hardcodear puertos | El Service Name `sbos-keycloak-http` es el identificador canónico; el puerto 8200 es derivado |
| **Desasignación cuando ya no se usa** — devolver el puerto al pool | `bos.ficha.remove` ejecuta `bos.portman.release` → estado `liberado` |

---

## 2. El problema y la solución

### 2.1 Escala

SBOS gestiona 112+ fichas en 16 servidores lógicos. Cada ficha consume entre 2 y 10 puertos.
En un sistema completo hay **400+ puertos asignados** simultáneamente.

Sin automatización, cada asignación es una decisión humana. Con 112 fichas, son 112
oportunidades de error: colisión, omisión de registro, Service YAML mal configurado.

### 2.2 La solución

El **Port Manager** es un subsistema del daemon BOS que implementa el RFC 6335 de forma
automática. No es una herramienta externa ni un script manual — es un engranaje del ciclo
de vida de la ficha que el BOS invoca sin intervención humana.

```
bosctl ficha install keycloak
  │
  └─► bos.ficha.install (daemon)
        │
        ├─► DEPENDENCY_RESOLVER: ¿dependencias satisfechas?
        │
        ├─► PORT MANAGER: bos.portman.assign  ← AUTOMÁTICO
        │     • PASO 1: Registrar Service Name "sbos-keycloak-http"
        │     • PASO 2: Derivar puerto (fórmula determinística)
        │     • PASO 3: Verificar 3 capas (lista negra → IANA → Kardex)
        │     • PASO 4: Registrar en Kardex (inmutable, UUIDv7)
        │     • PASO 5: Generar Service YAML
        │
        ├─► K8S CORE: kubectl apply -f service.yaml
        │
        └─► HEALTH CHECK: keycloak responde en 8200 ✅
```

El operador ejecutó `bosctl ficha install keycloak`. En ningún momento eligió un número de
puerto. El BOS derivó, verificó, registró y aplicó. **Cero decisiones humanas.**

---

## 3. El algoritmo de asignación

El Port Manager usa dos algoritmos complementarios. El 99.9% de las asignaciones se
resuelven con el Algoritmo A. El Algoritmo B es el fallback de último recurso.

### 3.1 Algoritmo A — Derivación determinística (SBOS-050 §12.1)

**Fórmula:** `ClusterIP = BASE_SERVIDOR + (ÍNDICE_FICHA × 10) + TIPO_T`

```
Ejemplo: Keycloak en S03 identityserver
  BASE_S03    = 8200
  ficha_index = 0      (primera ficha del servidor)
  tipo_t      = 0      (HTTP principal)

  ClusterIP   = 8200 + (0 × 10) + 0 = 8200 ✅

Puertos derivados para la misma ficha:
  T=0 (HTTP)        → 8200
  T=1 (HTTPS)       → 8201
  T=2 (métricas)    → 8202
  T=3 (healthcheck) → 8203
  T=4 (admin)       → 8204
  T=6 (WebSocket)   → 8206
```

**Origen del algoritmo:** patrón de asignación secuencial determinística usado por:
- **RFC 7422 §5.1** (Deterministic CGN Port Allocation — Algorithm 0: Sequential)
- **Infrahub Resource Manager** — asignación idempotente desde pools de prefijos
- **KubeBlocks PortManager** — ConfigMap como registro global con asignación por índice

**Ventajas:**
- Predecible: un humano puede calcular el puerto mentalmente
- Trazable: el número revela servidor lógico, ficha y tipo
- Idempotente: misma ficha, mismo índice → mismo puerto siempre
- Legible en logs: `8200` = S03, ficha 0, HTTP

### 3.2 Algoritmo B — Hash determinístico (fallback)

Cuando el bloque de un servidor está agotado (más fichas que índices disponibles), el
Port Manager cambia automáticamente al algoritmo de hash.

**Fórmula:**
```
hash_input  = ficha_id + ":" + tipo_desc + ":" + clash_counter
hash_bytes  = SHA256(hash_input)[0:4]
hash_int    = big_endian_u32(hash_bytes)
puerto      = RANGO_MIN + (hash_int % RANGO_SIZE)
```

**Origen del algoritmo:** usado en producción por:
- **ISO Code** (Rust crate) — SHA256 de `repo_id:branch` para asignar puertos de CI/CD
- **Marathon-LB** (Mesosphere/DCOS) — SHA1 de `app_id:task_port:clash` para service ports
- **Neurogrim-core** — `TcpListener::bind` + persistencia atómica en `ports.json`

**Ejemplo en SBOS:**
```
ficha_id    = "smartorc"
tipo_desc   = "http"
RANGO_MIN   = 32000
RANGO_SIZE  = 17151  (49151 - 32000)

hash_input  = "smartorc:http:0"
SHA256      = a3f7b2c9... (primeros 4 bytes → 0xa3f7b2c9)
hash_int    = 2749362889
puerto      = 32000 + (2749362889 % 17151)
            = 32000 + 8233
            = 40233
```

**Ventajas:**
- Sin límite de fichas por servidor
- Probabilísticamente imposible de colisionar
- clash_counter resuelve colisiones (máx 50 reintentos)

**Desventaja:** no es legible por humanos — `40233` no revela qué ficha lo usa. Requiere
consulta al Kardex: `bosctl port lookup 40233`.

### 3.3 Selección automática de algoritmo

```
ENTRADA: servidor_logico, ficha_index, tipo_t

SI ficha_index < (TAMAÑO_BLOQUE / 10):
  → Algoritmo A (fórmula)
SINO:
  → Algoritmo B (hash)
  → Registrar en Kardex con referencia "HASH-{sha256_truncado}"
  → Log: "bloque S03 agotado — usando hash para keycloak-http → 40233"
```

---

## 4. Resolución de conflictos — 3 niveles automáticos, 0 bloqueo

El Port Manager **nunca debe bloquear la saga de instalación** esperando input humano.
Para garantizarlo, implementa 3 niveles de resolución automática:

| Nivel | Gatillo | Acción automática | Latencia |
|:-----:|---------|-------------------|:--------:|
| **N1 — Fórmula** | Ficha nueva, índice libre | Derivar y asignar | < 1ms |
| **N2 — Auto-incremento** | Conflicto en el índice del servidor | `ficha_index += 1`, reintentar (máx 5 saltos) | < 5ms |
| **N3 — Hash fallback** | Bloque del servidor agotado (5 saltos N2 fallidos) | SHA256(ficha_id) → puerto en rango libre 32000-49151 | < 10ms |
| **HITL** | Los 3 niveles fallaron (solo por bug o error de configuración) | `log.Error()` → el orquestador falla la ficha con mensaje descriptivo. El operador corrige el manifest y reintenta. | Manual |

**En operación normal, el Port Manager resuelve en < 10ms sin intervención humana.**

### 4.1 Ejemplo: conflicto N2

```
bosctl ficha install wazuh  (S03 identityserver)

PASO 2: DeriveClusterIP(BASE=8200, ficha=1, tipo=0) → 8210
PASO 3: ConflictCheck(8210):
  Capa 3 → SELECT * FROM bos.port_assignment WHERE puerto=8210
         → OCUPADO por "wazuh-manager" (asignado previamente con índice 1)

N2 — Auto-incremento: ficha_index = 1 + 1 = 2
PASO 2: DeriveClusterIP(BASE=8200, ficha=2, tipo=0) → 8220
PASO 3: ConflictCheck(8220):
  Capa 3 → 0 filas → LIBRE ✅

PASO 4: INSERT 8220 → Kardex
PASO 5: Service YAML generado con ClusterIP 8220

Log: "índice 1 ocupado por wazuh-manager → auto-incrementado a 2 → 8220"
```

### 4.2 Ejemplo: conflicto N3 (hash fallback)

```
bosctl ficha install nueva-app-99  (S03, ficha_index=99)

N1: DeriveClusterIP(8200, 99, 0) → 9190
N2: ConflictCheck → OCUPADO (el bloque S03 solo llega a 8249)
    Auto-incremento 5 veces → todo ocupado

N3 — Hash fallback:
  SHA256("nueva-app-99:http:0")[0:4] → 0xc4e8a17f
  32000 + (0xc4e8a17f % 17151) → 32000 + 14015 → 46015

PASO 4: INSERT 46015 → Kardex (referencia: HASH-c4e8a17f)
PASO 5: Service YAML con ClusterIP 46015

Log: "bloque S03 agotado (5 intentos) → hash fallback: 46015"
```

---

## 5. Verificación de 3 capas (RFC 6335 Expert Review adaptado)

El RFC 6335 exige "Expert Review" para asignaciones en el rango User Ports. El Port Manager
automatiza esta revisión en 3 capas secuenciales:

```
CAPA 1 — LISTA NEGRA LOCAL (§5 SBOS-050)
  ┌─────────────────────────────────────────────────────────────┐
  │ ¿El puerto está en la tabla de NO DISPONIBLES?              │
  │ • Well-Known IANA (0-1023)                                  │
  │ • Kubernetes core (6443, 2379-2380, 10248-10259)            │
  │ • Linkerd sidecar (4140, 4143, 4191, 8086)                  │
  │ • Alta conflictividad (3000, 5000, 8000, 8080, 9000...)     │
  │                                                              │
  │ SI aparece → RECHAZADO. No continuar.                       │
  └─────────────────────────────────────────────────────────────┘
                              │ PASA
                              ▼
CAPA 2 — IANA REGISTRY
  ┌─────────────────────────────────────────────────────────────┐
  │ ¿El puerto está asignado por IANA a otro servicio?          │
  │ Fuente: https://www.iana.org/assignments/                   │
  │         service-names-port-numbers                          │
  │                                                              │
  │ • Unassigned → OK, continuar                                │
  │ • Asignado a otro servicio → WARN                           │
  │   - Si es containerPort canónico del fabricante → OK        │
  │     (ej: PostgreSQL containerPort 5432 es IANA assigned)    │
  │   - Si es ClusterIP SBOS → RECHAZADO                        │
  │     (no podemos usar un puerto IANA para ClusterIP propio)  │
  └─────────────────────────────────────────────────────────────┘
                              │ PASA
                              ▼
CAPA 3 — KARDEX LOCAL (bos.port_assignment)
  ┌─────────────────────────────────────────────────────────────┐
  │ ¿El puerto ya está en el Kardex para este namespace?        │
  │                                                              │
  │ SELECT COUNT(*) FROM bos.port_assignment                    │
  │ WHERE puerto = ? AND tipo_puerto = ? AND namespace = ?     │
  │   AND estado = 'asignado'                                   │
  │                                                              │
  │ • 0 filas → LIBRE. Asignar.                                 │
  │ • 1 fila, mismo ficha_id → REUTILIZAR (reinstall)          │
  │ • 1 fila, diferente ficha_id → CONFLICTO → N2 o N3          │
  └─────────────────────────────────────────────────────────────┘
```

---

## 6. El Kardex — inventario de activos de red (ISO 27001 A.8.20)

El Kardex no es solo un registro de puertos. Es el **inventario de activos de red**
que exige ISO 27001:2022 A.8.20, implementado como tabla SQL inmutable dentro de `SBOS_db`.

### 6.1 El modelo de dos capas: identidad estable vs IPs efímeras

Kubernetes distingue dos niveles de identidad de red. Confundirlos es la causa más común
de inventarios incorrectos:

| Capa | Identidad | Ciclo de vida | Ejemplo | ¿Se guarda en Kardex? |
|------|-----------|:------------:|---------|:---------------------:|
| **Service** (estable) | ClusterIP + puerto | Años — sobrevive a reinicios, scaling, reschedules | `10.100.74.8:8200` → keycloak | ✅ **SÍ** — es el activo permanente |
| **Pod** (efímero) | Pod IP + containerPort | Minutos/Horas — cambia en cada restart, scale, reschedule | `192.168.24.212:8080` → keycloak-pod-3 | ❌ **NO** — se consulta en tiempo real |

**Por qué esto importa:** cuando el Horizontal Pod Autoscaler (HPA) escala keycloak de
2 a 5 réplicas, el ClusterIP `10.100.74.8:8200` no cambia. Pero las Pod IPs cambian:
3 nuevas aparecen, y cuando la carga baja, 3 desaparecen. Si el inventario registrara
las Pod IPs, estaría obsoleto en minutos.

**Lo que el Kardex almacena es la capa estable.** La capa efímera se consulta vía
K8s API en el momento de la auditoría, no se persiste.

### 6.2 Qué activos van en el Kardex y cuáles no

La división es por **rol de red**: proveedor vs consumidor.

| Activo | Rol | ¿Va en Kardex? | Si no, ¿dónde? |
|--------|:---:|:-------------:|---------------|
| **Servidores lógicos** (S00-S16) | Proveedor — cada uno tiene rango ClusterIP | ✅ `asset_type: server_logico` | — |
| **Servidores físicos / nodos K8s** | Proveedor — kubelet :10250, Calico :179, MetalLB :7946 | ✅ `asset_type: nodo_k8s` | — |
| **Daemons** (bos, bauth, bkernel...) | Proveedor — 24 puertos fijos en 9400-9499 | ✅ `asset_type: daemon` | — |
| **Fichas / aplicaciones** | Proveedor — cada ficha = N puertos ClusterIP | ✅ `asset_type: ficha` | — |
| **Services K8s** (ClusterIP, NodePort, LoadBalancer) | Proveedor — identidad estable | ✅ `asset_type: service_k8s` | — |
| **Ingress / rutas Kong** | Proveedor — exponen servicios al exterior | ✅ `asset_type: ruta_kong` | — |
| **Dispositivos hardware** (USB, RFID, relés) | **Consumidor** — se conectan vía bhnexus :9444 | ❌ | `bos.registered_devices` (Context Plane) |
| **VDI / escritorios** (fedora-logico) | **Consumidor** — se conectan vía Guacamole | ❌ | `bos.registered_devices` |
| **Conexiones externas** (biedata → SIAT) | **Consumidor** — iniciadas por biedata, puerto 443 saliente | ❌ | `biedata_db.box_executions` |
| **Dispositivos móviles / BYOD** | **Consumidor** — autenticados por bauth | ❌ | `bauth_db.device_sessions` |

**Regla:** si el activo **abre** un puerto y **responde** en él → Kardex. Si el activo
**consume** un puerto pero no escucha → Context Plane o auditoría del daemon correspondiente.

### 6.3 Crecimiento horizontal: el ClusterIP es la constante

Cuando una ficha escala horizontalmente, el Kardex no necesita registrar nada nuevo.
El puerto y la IP del Service son los mismos. Lo que cambia son los **endpoints**
(los pods que responden detrás del Service). Esos se consultan de K8s en tiempo real.

```
ANTES DE ESCALAR (2 réplicas):
  Kardex: 10.100.74.8:8200 → keycloak (estable, no cambia)
  K8s API (tiempo real):
    endpoints: [192.168.24.212:8080, 192.168.50.185:8080]

DESPUÉS DE ESCALAR (5 réplicas, HPA):
  Kardex: 10.100.74.8:8200 → keycloak (MISMO registro, sin cambios)
  K8s API (tiempo real):
    endpoints: [192.168.24.212:8080, 192.168.50.185:8080,
                192.168.63.93:8080,  192.168.12.44:8080,
                192.168.77.21:8080]
```

**Para una auditoría en el momento T:** el Kardex responde "puerto 8200 = keycloak".
K8s API responde "en el momento T, keycloak se servía desde estas 5 IPs de pod".
El auditor tiene trazabilidad completa sin que el Kardex almacene datos efímeros.

**Excepción — StatefulSets:** cuando un pod necesita identidad estable (bases de datos,
Kafka, etc.), se usa Headless Service + StatefulSet. En ese caso cada pod recibe un
DNS estable (`postgres-0.sbos-data.svc.cluster.local`). El Kardex registra el
Headless Service, y los pods individuales se descubren por DNS.

### 6.4 Linkerd y los puertos del sidecar

Linkerd inyecta un proxy sidecar en cada pod que intercepta todo el tráfico en los
puertos 4140 (outbound) y 4143 (inbound). Estos puertos:

- Están en **cada pod** del cluster (no solo en servicios SBOS)
- Están registrados en SBOS-050 §5.3 como "Nunca bloquear"
- **No se registran en el Kardex** — son infraestructura de malla, no servicios de negocio
- Si se necesitan para auditoría, se consultan vía `kubectl describe pod`

### 6.5 Schema ampliado — `bos.port_assignment` v2

```sql
CREATE TABLE bos.port_assignment (
    -- Identidad del registro (inmutable)
    id              UUID PRIMARY KEY DEFAULT gen_uuid_v7(),
    
    -- Campos RFC 6335 obligatorios
    service_name    TEXT NOT NULL,          -- "sbos-keycloak-http" (1-15 chars)
    puerto          INTEGER NOT NULL,       -- 8200
    transport       TEXT NOT NULL,          -- TCP | UDP | SCTP | DCCP
    asignado_por    TEXT NOT NULL,          -- "bos.ficha.install"
    ficha_id        TEXT NOT NULL,          -- Contact: ficha responsable
    descripcion     TEXT NOT NULL,          -- Description: qué hace este puerto
    referencia_doc  TEXT NOT NULL,          -- Reference: SBOS-050 §12.3
    
    -- Tipo de puerto
    tipo_puerto     TEXT NOT NULL,          -- containerPort | ClusterIP | NodePort | hostPort | daemonPort
    servidor_logico TEXT NOT NULL,          -- S00..S16, S-HOST
    namespace       TEXT,                   -- namespace K8s (NULL para host/daemon)
    container_port  INTEGER,                -- puerto canónico del contenedor
    tipo_t          SMALLINT DEFAULT 0,     -- 0=HTTP, 1=HTTPS, 2=métricas, 3=health, 4=admin...
    
    -- IPs estables (NUEVO en v2)
    cluster_ip      TEXT,                   -- IP del Service K8s (ClusterIP, LoadBalancer IP)
    external_ip     TEXT,                   -- IP externa si aplica (MetalLB VIP, WireGuard IP)
    dns_name        TEXT,                   -- FQDN si tiene (keycloak.sbos-identity.svc.cluster.local)
    
    -- Activo asociado (NUEVO en v2 — ISO 27001 A.8.20)
    asset_type      TEXT NOT NULL DEFAULT 'ficha',  -- ficha | daemon | server_logico | nodo_k8s | service_k8s | ruta_kong
    asset_id        TEXT,                   -- ID del activo (ficha_id, nodo nombre, daemon nombre)
    asset_owner     TEXT,                   -- Responsable del activo (tenant, sistema)
    labels          JSONB,                  -- Etiquetas flexibles: {"hpa": "enabled", "replicas": "2-20", "critico": true}
    
    -- Subdominio y ruta (NUEVO en v2)
    subdominio      TEXT,                   -- auth.sksistemas.com (si está expuesto vía Kong)
    ruta_kong       TEXT,                   -- /auth → 8200 (ruta interna de Kong)
    
    -- Estado
    estado          TEXT DEFAULT 'asignado',-- asignado | liberado | revocado | en_conflicto
    asignado_en     TIMESTAMPTZ DEFAULT now(),
    liberado_en     TIMESTAMPTZ,            -- NULL si activo
    ultima_validacion TIMESTAMPTZ,          -- Última vez que validate confirmó este registro
    notas           TEXT,
    
    -- Unicidad: mismo puerto + tipo + namespace no puede asignarse dos veces
    CONSTRAINT uq_port_type_ns UNIQUE (puerto, tipo_puerto, namespace)
);

-- Índices para auditoría
CREATE INDEX idx_port_ficha    ON bos.port_assignment(ficha_id);
CREATE INDEX idx_port_server   ON bos.port_assignment(servidor_logico);
CREATE INDEX idx_port_state    ON bos.port_assignment(estado);
CREATE INDEX idx_port_service  ON bos.port_assignment(service_name);
CREATE INDEX idx_port_asset    ON bos.port_assignment(asset_type, asset_id);
CREATE INDEX idx_port_subdominio ON bos.port_assignment(subdominio);
CREATE INDEX idx_port_labels   ON bos.port_assignment USING GIN(labels);
```

### 6.6 Lo que el Kardex almacena vs lo que consulta en tiempo real

```
┌──────────────────────────────────────────────────────────────────┐
│  PREGUNTA DE AUDITORÍA                                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  "¿Qué puertos tiene abiertos el servidor S03?"                   │
│  → Kardex: SELECT * WHERE servidor_logico='S03'                  │
│                                                                   │
│  "¿Qué ficha usa el puerto 8200?"                                  │
│  → Kardex: SELECT * WHERE puerto=8200                            │
│                                                                   │
│  "¿Qué IPs estaban sirviendo keycloak ayer a las 14:00?"         │
│  → Kardex: 10.100.74.8:8200 (ClusterIP, no cambia)              │
│  → K8s API histórico o snapshot: pods [192.168.24.212, ...]     │
│                                                                   │
│  "¿Cuántas réplicas tenía keycloak cuando ocurrió el incidente?" │
│  → Kardex: labels → {"hpa": "enabled", "replicas": "2-20"}      │
│  → Prometheus/Métricas: serie temporal de replicas               │
│                                                                   │
│  "¿Qué dispositivos USB se conectaron ayer?"                      │
│  → NO está en Kardex → bos.registered_devices (Context Plane)    │
│                                                                   │
│  "¿Hay algún puerto abierto en K8s sin registro?"                │
│  → bosctl port validate → compara Kardex vs kubectl get svc     │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### 6.7 Propiedades

| Propiedad | Garantía | Fundamento |
|-----------|----------|-----------|
| **Inmutabilidad lógica** | Filas nunca se borran — transicionan `asignado → liberado` | RFC 6335 §8 |
| **Unicidad forzada** | CONSTRAINT `uq_port_type_ns` | RFC 6335 §7 |
| **UUIDv7** | PKs time-ordered (RFC 9562) | Ordenables por fecha sin índice adicional |
| **Service Name único** | `service_name` no se repite | RFC 6335 §5.1 |
| **Doble capa de identidad** | IP estable (ClusterIP) en Kardex · IP efímera (Pod IP) en K8s API | Kubernetes Service abstraction |
| **Trazabilidad de activo** | `asset_type` + `asset_id` + `asset_owner` vinculan puerto→activo→responsable | ISO 27001:2022 A.8.20 |
| **Auditable en tiempo real** | `bos.portman.validate` compara Kardex vs K8s real | NIST SP 800-53 CM-8(3) |
| **Consultable** | `bos.portman.lookup(puerto)` → dueño, activo, historia, IP | RFC 6335 §6 |

---

## 7. API JSON-RPC — `bos.portman.*`

Siete métodos expuestos vía el socket `/opt/skull/SBOS/runtime/bos.sock`:

| Método | Invocado por | Qué hace |
|--------|-------------|----------|
| `bos.portman.assign` | `bos.ficha.install` (automático) | Ejecuta el algoritmo de asignación, verifica 3 capas, registra en Kardex, retorna Service YAML |
| `bos.portman.lookup` | `bosctl port lookup`, biaos | Consulta el Kardex: ¿qué ficha usa este puerto? ¿qué puertos usa esta ficha? |
| `bos.portman.release` | `bos.ficha.remove` (automático) | Transiciona todos los puertos de una ficha a `liberado` (RFC 6335 De-Assignment) |
| `bos.portman.check` | `bosctl port check`, biaos | Dry-run: verifica conflictos SIN asignar. Retorna sugerencias |
| `bos.portman.list` | `bosctl port list` | Lista el Kardex con filtros (servidor, estado, tipo) |
| `bos.portman.validate` | `reconcile/scheduler.go` (cada 300s) | Compara Kardex vs K8s real. Detecta drift: puertos sin registro, registros sin Service |
| `bos.portman.export` | `bosctl port export` | Exporta el Kardex completo en formato SBOS-050 Markdown |

---

## 8. Integración con el ciclo de vida de la ficha

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                       │
│  FICHA INSTALL                                                        │
│  ─────────────                                                        │
│  orchestrator.Install(ficha)                                          │
│    │                                                                  │
│    ├─► DEPENDENCY_RESOLVER: orden DAG verificado                     │
│    │                                                                  │
│    ├─► PORT MANAGER: bos.portman.assign                              │
│    │     • PASO 1: Service Name → "sbos-keycloak-http"               │
│    │     • PASO 2: Derivar puerto → 8200                             │
│    │     • PASO 3: Verificar 3 capas → LIBRE                         │
│    │     • PASO 4: Registrar Kardex → INSERT                         │
│    │     • PASO 5: Service YAML → retornar                           │
│    │                                                                  │
│    ├─► K8S CORE: kubectl apply -f service.yaml                       │
│    │                                                                  │
│    └─► HEALTH CHECK: TCP probe 8200 → OK                             │
│                                                                       │
│  FICHA REMOVE                                                         │
│  ────────────                                                         │
│  orchestrator.Remove(ficha)                                           │
│    │                                                                  │
│    ├─► K8S CORE: kubectl delete service, kubectl delete deployment   │
│    │                                                                  │
│    └─► PORT MANAGER: bos.portman.release                             │
│          • UPDATE estado='liberado', liberado_en=now()                │
│          • Puerto queda en Kardex como histórico (RFC 6335 §8)        │
│                                                                       │
│  CICLO DE RECONCILIACIÓN (cada 300s)                                  │
│  ──────────────────────────────────                                   │
│  reconcile.Scheduler.Run()                                            │
│    │                                                                  │
│    └─► PORT MANAGER: bos.portman.validate                            │
│          • Compara Kardex vs kubectl get svc --all-namespaces        │
│          • Si drift → alerta al watchdog unificado                    │
│          • Auto-repair opcional: recrear Service desde Kardex         │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 9. Validación con normas internacionales

| Norma | Requerimiento | Cómo lo cumple |
|-------|-------------|----------------|
| **RFC 6335 (BCP 165)** | Procedimientos IANA para registro de puertos | El Port Manager ES la implementación del RFC 6335 dentro del SBOS |
| **RFC 7422** | Port Allocation Algorithms for CGN | Algoritmo A = Sequential (algo=0). Algoritmo B = Cryptographic (algo=4) |
| **ISO 27001:2022 A.8.20** | Inventario de activos de red actualizado, registro de cambios, automatización | Kardex actualizado en tiempo real. Cada cambio registrado con timestamp + autor |
| **NIST SP 800-53 CM-8** | Inventario de componentes automatizado, detección de no autorizados | `assign` automático. `validate` detecta puertos sin registro |
| **NIST SP 800-53 CM-8(3)** | Detección automatizada de componentes no autorizados | `validate` detecta Services K8s sin entrada en Kardex → alerta |
| **NIST SP 800-207 ZTA** | Verificación continua, microsegmentación | Kong consulta el Context Plane validando que el puerto esté en el Kardex |
| **CIS K8s Benchmark v1.8 §5.3** | NetworkPolicy default-deny | NetworkPolicy generadas desde puertos exactos del Kardex |

---

## 10. Validación con experiencias de la industria

| Sistema | Quién lo usa | Patrón que valida |
|---------|-------------|-------------------|
| **NetBox** | Cisco, INFN, Fortune 500 | Fuente de verdad central con REST API — mismo concepto que el Kardex |
| **KubeBlocks PortManager** | Clústeres K8s de bases de datos | ConfigMap como registro global de puertos — mismo concepto que `bos.port_assignment` |
| **Marathon-LB** | Mesosphere/DCOS | SHA1 determinístico para service ports — mismo algoritmo B de fallback |
| **ISO Code** (Rust) | CI/CD port leasing | SHA256 de `repo:branch` → puerto determinístico — validación del algoritmo B |
| **Infrahub Resource Manager** | Automatización de redes | Asignación idempotente desde pools — mismo concepto de derivación por fórmula |
| **port-daddy** | Entornos de desarrollo multi-agente | Asignación atómica con `TcpListener::bind` — validación de verificación real de disponibilidad |

---

## 11. Estructura de código

```
BosAgent/src/internal/portman/
├── engine.go           ← Algoritmo A (fórmula) + Algoritmo B (hash SHA256)
├── rfc6335.go          ← Implementación del proceso RFC 6335 (8 campos, ciclo de vida)
├── conflict.go         ← Verificación 3 capas (lista negra, IANA, Kardex)
├── kardex.go           ← CRUD sobre bos.port_assignment
├── validate.go         ← Drift detection: Kardex vs kubectl get svc
├── export.go           ← Exportador Markdown (SBOS-050)
├── server/
│   └── jsonrpc.go      ← 7 handlers JSON-RPC 2.0
└── portman_test.go     ← Tests con race detector
```

---

## 12. CLI — `bosctl port`

```bash
bosctl port lookup 8200                   # ¿Quién usa este puerto?
bosctl port lookup --ficha keycloak       # ¿Qué puertos usa esta ficha?
bosctl port list --server S03             # Todos los puertos de identityserver
bosctl port check --server S03 --port 8240  # ¿Está libre? (dry-run)
bosctl port validate                      # Auditar: Kardex vs K8s real
bosctl port export --format markdown      # Generar SBOS-050.md desde Kardex
```

---

## 13. Estado y hoja de ruta

| Componente | Estado | Próximo paso |
|-----------|:------:|-------------|
| RFC 6335 — proceso documentado | ✅ v3.0.0 (este anexo) | — |
| SBOS-050 — reglas y rangos | ✅ v3.1 | — |
| Schema `bos.port_assignment` | 📐 Diseñado | `DDLs/migrations/bos_02__port_assignment.sql` |
| Algoritmo A (fórmula) | 📐 Diseñado | `internal/portman/engine.go` |
| Algoritmo B (hash SHA256) | 📐 Diseñado | `internal/portman/engine.go` |
| Verificación 3 capas | 📐 Diseñado | `internal/portman/conflict.go` |
| Kardex CRUD | 📐 Diseñado | `internal/portman/kardex.go` |
| JSON-RPC handlers | 📐 Diseñado | `internal/portman/server/jsonrpc.go` |
| CLI `bosctl port` | 📐 Diseñado | `cmd/bosctl/port.go` |
| Wire en `bos.ficha.install` | 📐 Diseñado | `installer/orchestrator.go` |
| Wire en reconciliación | 📐 Diseñado | `reconcile/scheduler.go` |

---

*SKULL · SBOS · BosAgent · Julio 2026*
