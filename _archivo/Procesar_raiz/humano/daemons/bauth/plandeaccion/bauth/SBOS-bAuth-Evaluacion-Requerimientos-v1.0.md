# SBOS bAuth — Evaluación Técnica y Requerimientos Pendientes
**Versión:** 1.0 · BitMask Dual Jun 2026  
**Fecha:** Abril 2025  
**Estado:** En definición — prerrequisitos para desarrollo

---

> ⚠️ **CORRECCIÓN BITMASK — JUNIO 2026:** Las referencias a SAM-128 o al modelo "2 capas" en este documento corresponden al diseño anterior. El modelo actual es el **BitMask Dual** definido en `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`. Ver también `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7.

## Tabla de Contenidos

1. [Veredicto General](#1-veredicto-general)
2. [Fortalezas: Lo que está bien definido](#2-fortalezas-lo-que-está-bien-definido)
3. [Requerimientos Pendientes](#3-requerimientos-pendientes)
4. [Orden de Trabajo por Dependencias](#4-orden-de-trabajo-por-dependencias)
5. [Tabla Resumen de Estado](#5-tabla-resumen-de-estado)
6. [Estimación de Ejecución](#6-estimación-de-ejecución)

---

## 1. Veredicto General

La arquitectura conceptual de bAuth está **completa y es sólida**. El sistema está **listo para programarse**. Sin embargo, existen **6 artefactos técnicos concretos** que deben producirse antes de que un desarrollador pueda iniciar la implementación sin ambigüedades.

> **Nota:** El Faltante 1 (schema SQL completo de `bauth_db`) no puede definirse en detalle hasta que los demás contratos estén cerrados. El orden correcto de ejecución es por dependencias reales, no por número de faltante.

---

## 2. Fortalezas: Lo que está bien definido

Los siguientes componentes están suficientemente especificados para codificarse directamente:

### Arquitectura general
El triángulo **KC–bAuth–Tryton** está correctamente conceptualizado. La separación entre sincronización y *login time* es precisa, y el patrón PAP/PIP/PDP/PEP es estándar de la industria. Sin ambigüedades.

### SAM-128
Completamente especificado. La implementación en Go es directamente compilable — `struct{ lo, hi uint64 }` con 7 operaciones algebraicas y la anatomía completa de los 128 bits. Un desarrollador puede escribir `sam128.go` desde el documento v4.0 sin preguntas adicionales.

### Modelos de datos
El `RolTemplate` y `UserTemplate` con esquema JSONB en PostgreSQL están suficientemente detallados para escribir las migraciones y los `structs` de Go.

### Flujo de sincronización
Los 11 pasos del flujo maestro son suficientemente precisos para implementar el loop principal del daemon.

### Stack tecnológico
Definido sin ambigüedades:

| Componente | Tecnología |
|---|---|
| Lenguaje principal | Go 1.22+ |
| Cliente KC Admin API | `go.companyinfo.dev/keycloak` (retry, token refresh, type safety) |
| Cliente Tryton | `github.com/kolo/xmlrpc` |
| Cliente PostgreSQL | `github.com/jackc/pgx/v5` |

---

## 3. Requerimientos Pendientes

Los siguientes 6 artefactos están **faltantes y bloquean el desarrollo**. Se presentan ordenados por dependencia real (ver sección 4).

---

### REQ-1 — `bauth.toml` completo
**Bloqueo:** Sin este archivo, el daemon no arranca.

Se necesita el archivo de configuración de referencia completo, con todas las secciones, valores por defecto, rangos válidos, y la forma en que cada secreto (KC, Tryton, PostgreSQL, Redis) se obtiene de Vault.

**Estructura mínima esperada:**

```toml
[keycloak]
url                    = "https://keycloak.sbos.internal"
realm                  = "master"
client_id              = "bauth-admin"
# client_secret desde Vault — ¿cómo?
token_refresh_interval = ?

[tryton]
url       = "http://tryton.sbos.internal:8000"
db        = "tryton_db"
user      = "admin"
pool_size = ?

[postgres]
dsn = "postgres://..."   # ¿También desde Vault?

[redis]
addr             = "localhost:6379"
cache_ttl_seconds = 300

[socket]
path = "/run/bos/bauth.sock"

[reconcile]
interval_seconds = 60
```

**Entregable:** `bauth.toml` de referencia con todos los campos documentados y la integración con Vault especificada.

---

### REQ-2 — JSON Schema de validación del `RolTemplate`
**Bloqueo:** Sin esto, el paso 2 del flujo de sincronización no puede rechazar templates malformados.

Se necesita:

- Qué campos son **obligatorios** vs. opcionales.
- Valores válidos de cada campo de tipo enum.
- Rangos numéricos válidos (ej. `max_session_duration`).
- Reglas semánticas: herencia sin ciclos (DAG), Conflict Matrix, Separación de Deberes (SoD).
- Mensajes de error para cada tipo de violación.

**Entregable:** JSON Schema (draft-07 o superior) + reglas de validación semántica documentadas.

---

### REQ-3 — Protocolo del Unix socket `/run/bos/bauth.sock`
**Bloqueo:** Sin esta especificación, `bhnexus` no puede implementar su cliente del socket.

Se necesita definir:

- **Framing:** ¿JSON con length prefix? ¿Newline delimited?
- **Timeouts:** Tiempo máximo de espuesta por request.
- **Conexiones:** ¿Pool de conexiones o una por request?
- **Manejo de errores:** Códigos de error del protocolo interno, comportamiento si bAuth está sobrecargado o no disponible.
- **Reconexión:** Estrategia de reconexión de `bhnexus` si el socket no está disponible.

**Entregable:** Especificación del protocolo de transporte del socket (framing, encoding, timeouts, error codes).

---

### REQ-4 — Contrato KC Admin API: `sync_role()`
**Dependencia:** REQ-1, REQ-2, REQ-3 deben estar cerrados primero.

Se necesita especificar:

- El **orden exacto de llamadas** a la KC Admin API para crear o actualizar un rol.
- Estrategia de **idempotencia**: GET antes de POST para verificar si el grupo ya existe.
- **Manejo de fallo parcial**: qué ocurre si la sincronización de KC falla a mitad del proceso.
- **Rollback**: estrategia de reversión ante error.
- **Rate limits** de la KC Admin API en producción.
- **Provisión automática del Authentication Flow** en un realm nuevo vía API (sin intervención manual en la consola).

Adicionalmente, el **proyecto Maven de los 5 SPIs** se define en este contexto, ya que depende de REQ-2 para saber qué validar. Se necesita:

- Versión exacta de Keycloak contra la que compilan los SPIs.
- `pom.xml` base con dependencias `keycloak-core` y `keycloak-server-spi`.
- Nombre del archivo de servicio `META-INF/services/` para cada SPI.
- Script de deployment automático vía KC Admin API.

**Entregable:** Pseudocódigo o especificación de `KeycloakSynchronizer.sync_role()` con orden de llamadas, manejo de errores, estrategia de rollback + estructura del proyecto Maven `bauth-spi/`.

---

### REQ-5 — Schema SQL completo de `bauth_db`
**Dependencia:** Todos los requerimientos anteriores (REQ-1 a REQ-4) deben estar cerrados.

Este es el **último artefacto** porque depende de todos los demás:

- REQ-4 determina qué campos necesita `bauth_sync_log`.
- REQ-1 y REQ-3 determinan qué cachea en base de datos vs. Redis.
- REQ-2 determina qué tablas requieren triggers de auditoría.

**Entregable:** Archivo `migrations/001_bauth_init.sql` ejecutable, con schema completo, índices y constraints.

---

## 4. Orden de Trabajo por Dependencias

```
┌─────────────────────────────────────────────────────────┐
│  FASE 1 — Paralelos (sin dependencia entre sí)          │
│                                                         │
│  REQ-1: bauth.toml ──────┐                              │
│  REQ-2: JSON Schema ─────┼──► REQ-4: KC sync_role()    │
│  REQ-3: Unix socket ─────┘         + Maven SPIs         │
└─────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                         REQ-5: Schema SQL bauth_db
                         (cierra el ciclo completo)
```

**REQ-1, REQ-2 y REQ-3** no tienen dependencia entre sí — pueden trabajarse en paralelo o en cualquier secuencia dentro de la misma sesión de trabajo.

**REQ-4** requiere que REQ-1, REQ-2 y REQ-3 estén completamente cerrados.

**REQ-5** requiere que todos los anteriores estén completamente cerrados.

---

## 5. Tabla Resumen de Estado

| Componente | Estado | ¿Puede codificarse ahora? |
|---|---|---|
| SAM-128 (`sam128.go`) | ✅ Completo | **SÍ** — directamente |
| `RolTemplate` struct Go | ✅ Completo | **SÍ** — desde el JSON |
| `PrivilegeEngine` lógica | ✅ Completo | **SÍ** — 7 operaciones definidas |
| Flujo de sincronización | ✅ Completo | **SÍ** — 11 pasos claros |
| Conflict Matrix | ✅ Completo | **SÍ** — reglas definidas |
| REST API endpoints | ✅ Completo | **SÍ** — rutas y contratos claros |
| `bauth_db` schema SQL | ❌ Falta (REQ-5) | **NO** — bloqueante |
| JSON Schema validación `RolTemplate` | ❌ Falta (REQ-2) | **NO** — bloqueante |
| Proyecto Maven SPIs | ❌ Falta (REQ-4) | **NO** — bloqueante |
| Protocolo Unix socket framing | ❌ Falta (REQ-3) | **PARCIAL** |
| `bauth.toml` completo | ❌ Falta (REQ-1) | **PARCIAL** |
| KC Admin API sync contract | ❌ Falta (REQ-4) | **PARCIAL** |

---

## 6. Estimación de Ejecución

### Producción de artefactos faltantes

| Sesión | Contenido | REQs cubiertos |
|---|---|---|
| **Sesión A** | `bauth.toml` + JSON Schema `RolTemplate` + protocolo Unix socket | REQ-1, REQ-2, REQ-3 |
| **Sesión B** | Estructura Maven SPIs + contrato KC Admin API `sync_role()` | REQ-4 |
| **Sesión C** | Schema SQL `migrations/001_bauth_init.sql` | REQ-5 |

### Implementación de bAuth v0.9

Una vez completadas las 3 sesiones de definición, dos desarrolladores senior pueden trabajar en paralelo:

- **Desarrollador Go** — daemon principal, SAM-128, flujo de sincronización, Unix socket, REST API.
- **Desarrollador Java** — 5 SPIs de Keycloak, proyecto Maven, deployment automático.

**Tiempo estimado para bAuth v0.9 funcional (sin UI):** 6–8 semanas.

---

*Documento generado a partir de la evaluación técnica de bAuth — SBOS Security Layer*
