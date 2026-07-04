# CLAUDE.md — Proyecto SBOS
<!-- nivel: proyecto · root: true · hereda de: Fábrica ORQUESTA -->
<!-- Define el PROPÓSITO COMÚN del ecosistema SBOS y sus directrices transversales. -->
<!-- Cada daemon (microservicio) hereda esto y añade su propio CLAUDE + skills. -->
<!-- Regla: si es "cómo desarrollar UN daemon", NO va aquí — va en el CLAUDE del microservicio. -->

## Idioma — INMUTABLE
**Español obligatorio** en todo lo que un agente emita (mensajes, logs, docs, errores).
No se desactiva por ningún motivo.

## Propósito común del ecosistema
SBOS es un **sistema operativo empresarial soberano**: instala en el servidor del cliente toda la
infraestructura digital que una organización necesita para operar — ERP, RRHH, CRM, correo,
identidad, escritorio corporativo e IA — **sin que ningún dato salga del servidor y sin licencias
externas**. *Soberano* = los datos nunca abandonan la infraestructura del cliente · código
auditable en su totalidad · el sistema opera sin depender de SKULL.

Fuente de verdad conceptual: `context/BOS_V8/` — `SBOS-001-VISION`, `-002-ARCH`, `-003-DOMAIN`,
`-004-RULES`. **No es un microservicio ni un producto suelto: es un ECOSISTEMA de daemons soberanos
con un fin compartido.** Skill: `sbos-arquitectura`.

## Los daemons del ecosistema (cada uno es un microservicio)
| Daemon | Directorio | Plano | Producto que desarrolla |
|--------|-----------|-------|-------------------------|
| **bos** | `BosAgent/` | Control | IAM Installer — despliega y gobierna el plano de control |
| **bauth** | `BauthAgent/` | Identidad | Orquestador central de identidad (BitMask 64-bit, token unificado) |
| **bkernel** | `BkernelAgent/` | Datos | Listener CDC + Fanout (WAL → Redis Streams) |
| **biedata** | `BiedataAgent/` | Integración | Orquestador JSON-RPC 2.0 — aduana de datos |
| **bsearch** | `BintelligenceAgent/` | Búsqueda | Motor de búsqueda soberano (PostgreSQL 18+) |
| **bnexus** | `BnexusAgent/` | Conectividad/Edge | Proxy de hardware universal (bhnexus + banexus) |
| **bnotify** | `BnotifyAgent/` | Notificación | Push MFA y notificaciones del sistema |

Catálogo con rutas: `paths.yml → microservicios`. **El propósito propio y el producto de cada daemon
viven en su propio CLAUDE + skills** — este CLAUDE los precede, no los sustituye.

## Reglas comunes irrenunciables (todo daemon las cumple)
- **Interface Dual (ADR-020):** WebSocket RPC + JSON-RPC 2.0 sobre el MISMO Unix socket `/run/bos/<daemon>.sock`. **NUNCA HTTP/TCP entre daemons** (SBOS-050 P9).
- **Context Plane (SBOS-049):** `ctx_id` obligatorio en toda operación (logs, auditoría, requests).
- **Puertos (SBOS-050):** rango daemons 9400–9499; BD solo ClusterIP; deny-all salvo 22/80/443.
- **systemd en el host** (no pods K8s). K8s solo aloja infraestructura (PostgreSQL, Redis, Keycloak, Vault, Kong).
- **Normas irrenunciables:** SBOS-047 (ISO 27001), 049 (Context Plane), 050 (Port Catalog).

## Recursos compartidos del proyecto — uso general (shared kernel · fábrica ORQUESTA-051 §7)

Tres carpetas son **espacio público de todo el proyecto**: todo agente las consulta para referirse
a SBOS. **Ninguna es privada de un daemon** — son el *shared kernel* del proyecto (co-propiedad).
Sus rutas se resuelven por `paths.yml → recursos_proyecto` (sin hardcode).

| Carpeta | Qué es (significado para el proyecto) | Índice = QUÉ contiene y DÓNDE |
|---|---|---|
| **`servers/`** | Catálogo de **fichas** de despliegue por servidor lógico (S00–S15). Cada servidor es la **unidad de migración** a hardware físico. | `servers/servers.yml` · skill `sbos-fichas` |
| **`DDLs/`** | Esquema de la **base de datos única `SBOS_db`** (un schema por servicio) + seeds. Fuente única del modelo de datos. | `DDLs/ddls.yml` · skill `sbos-ddl` |
| **`context/`** | **Documentación conceptual** — BOS_V8 (51 docs), IAM_Enterprise_Stack, normas. Fuente de verdad; en conflicto, prevalece sobre derivados. | `context/BOS_V8/…-000-INDEX` |

**Cómo se usan — lectura libre, cambio consultado (HITL):**
- **Leer:** siempre libre; es la referencia común de SBOS que todo agente usa.
- **Cambiar:** **todo cambio en `servers/`, `DDLs/` o `context/` se CONSULTA con el humano ANTES de aplicarlo o commitearlo.** El agente **propone**, el humano **aprueba**, el Bibliotecario **custodia** la norma. Principio: *quien escribe el cambio no es quien lo aprueba*.
- **Antes de crear o mover algo**, consulta el **YML índice** de esa carpeta (define nombres, ubicación y propósito). Reglas duras vigentes: nombre de ficha **canónico**, nunca arbitrario · un `SBOS_db`, un schema por servicio, convención `<servicio>_NN__objeto` · **ubicación por función, no por consumidor** (una BD vive en dataserver aunque la use otra app — `servers.yml` REGLA #3) · solo versiones **estables** del stack (ADR-017).

## Herencia — modelo de 3 niveles (ORQUESTA-051)
Fábrica (cómo trabaja *cualquier* agente) → **este CLAUDE (propósito común SBOS)** → CLAUDE de cada
daemon (su propósito propio + su producto). Un agente que se levanta en `SBOS/<Daemon>` recibe los
tres en cascada, resueltos por su ruta de ancestros (sin hardcode).
**`root: true`** — SBOS no ve otros proyectos ni comparte conocimiento con ellos.
