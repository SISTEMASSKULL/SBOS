# SKILL AGENTE PROGRAMADOR — bKernel
## Definición de la skill para Claude Code

**Skill name:** `bkernel-dev`
**Versión:** 1.0 · **Fecha:** 2026-06-19
**Directorio de trabajo:** `/opt/skull/orquestador/proyectos/desarrollo/sbos/BkernelAgent/src/`

---

## Descripción

Agente especializado en el desarrollo del daemon bkernel (Data Kernel) del proyecto
SBOS/SKULL. Conoce el plan maestro atómico, los 43 átomos organizados en 7 gates
(G0–G5 + FICHA), y el protocolo completo de sesión.

---

## Activación

Usar esta skill SIEMPRE que el usuario mencione:
- "bkernel", "data kernel", "motor de datos"
- Ejecutar un átomo bkernel
- Continuar el desarrollo de bkernel
- Verificar el estado del plan bkernel
- "qué sigue en bkernel" o "estado de bkernel"
- Consultar REGISTRO-ESTADO.md de bkernel

---

## Al iniciar

1. Leer `MAPA-NAVEGACION.md` completo
2. Verificar `REGISTRO-ESTADO.md` — primer 🔴 del gate activo
3. Leer `LOG-DE-SESIONES.md` — últimas 2 sesiones
4. Ejecutar señal de retoma (§1.3 del PROTOCOLO-SESION-AGENTE.md)
5. Determinar siguiente átomo y ejecutar

---

## Documentos que DEBE conocer

| Documento | Propósito |
|-----------|-----------|
| `BKERNEL-PLAN-MAESTRO-v1.md` | Definición de cada átomo y criterio de aceptación |
| `REGISTRO-ESTADO.md` | Estado actual de cada átomo |
| `MAPA-NAVEGACION.md` | Estructura, reglas, jerarquía documental |
| `PROTOCOLO-SESION-AGENTE.md` | Apertura/ejecución/cierre de sesiones |
| `INSTRUCCIONES-DE-USO.md` | Comandos prácticos por gate |
| `SBOS_bkernel_ARQUITECTURA.md` | Stack Rust, módulos, loop principal |
| `SBOS_bkernel_DOMINIO.md` | BkernelEvent, fichas, entity_crossref |
| `SBOS_bkernel_FUNCIONALIDADES.md` | CDC, fanout, anti-loop, DLQ |
| `SBOS_bkernel_DATOS.md` | Esquema bkernel_db |
| `BOS_V8_SBOS-023-DAEMON-BKERNEL.md` | Documento canónico V8 |
| `BOS_V8_SBOS-049-CONTEXT-PLANE.md` | Context Plane spec |
| `BOS_V8_SBOS-050-PORT-CATALOG.md` | Política de puertos |

---

## Stack tecnológico

| Componente | Versión | Uso |
|-----------|---------|-----|
| Rust | 1.85+ (Edition 2024) | Lenguaje principal |
| tokio | 1.x (rt-multi-thread) | Async runtime |
| tokio-postgres | 0.7 | Cliente PostgreSQL |
| deadpool-postgres | 0.13 | Pool de conexiones |
| redis-rs | 0.25 (tokio-comp) | Cliente Redis |
| serde | 1.x | Serialización |
| serde_yaml | 0.9 | Parsing de fichas YAML |
| prometheus | 0.13 | Métricas :9460 |
| tracing | 0.1 | Logging estructurado |

---

## Reglas de implementación

1. **Código en Rust 1.85+ Edition 2024** — sin excepciones
2. **MUSL estático** — target x86_64-unknown-linux-musl
3. **Traits para todo punto de integración** — SQLExecutor, RedisClient, Store (dependency inversion)
4. **Cero hardcoding de aplicaciones** — todo en fichas YAML
5. **Nunca exponer HTTP** — solo :9460 (métricas) + :9461 (health) GET only
6. **ctx_id en todo audit_event** — ISO 27001 A.8.15
7. **Interface Dual (ADR-020)** — WebSocket + JSON-RPC 2.0 sobre `/run/bos/bkernel.sock` para comandos de gestión
8. **Testing obligatorio** — unit tests + integration tests (PG fixture) + bench tests (criterios de latencia)

---
*SKILL-AGENTE-PROGRAMADOR v1.0 · 2026-06-19*
