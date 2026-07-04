# BOS-ECO-008 — PLAN MAESTRO ATÓMICO DEL PROGRAMA
## G0–G5 descompuesto a nivel micro, medible y sincronizado entre bKernel y biedata

## 0. Metadatos del documento

| Campo | Valor |
|---|---|
| **Documento** | BOS-ECO-008-PLAN-MAESTRO-ATOMICO |
| **Versión** | 1.0 |
| **Estado** | VIGENTE — REDACTADO. Documento vivo: las tareas mueven estado en ECO-004 y los planes de serie |
| **Fase asociada** | Gobierna G0–G5 completo |
| **Serie** | BOS-ECO (nivel programa; el nivel micro POR MÓDULO vive en bK-190 y bd-160) |
| **Fuentes que absorbe** | `05-BKERNEL-PROPUESTA` §Plan (Fases 0–5, cronograma 14 semanas) · plan sincronizado G0–G5 de la estructura congelada · corpus biedata v3.0 (módulos a construir) |
| **Normas aplicables** | ISO/IEC/IEEE 15289:2019 cl. 10 (plan); ISO/IEC/IEEE 12207:2017 §6.3.1 (planificación) — toda tarea con criterio de verificación objetivo |
| **Audiencia** | Ambas |
| **Custodio** | Arquitecto (alcance) · sesiones (estado) |
| **Fecha** | 2026-06-10 |

---

## 1. Estructura del plan (jerarquía atómica)

```
PROGRAMA → FASE Gn → ETAPA Gn.En → TAREA ATÓMICA Gn.En.Tm
Tarea atómica = la unidad mínima ASIGNABLE A UNA SESIÓN, con:
  ID · entregable concreto · criterio MEDIBLE (comando/condición verificable) ·
  dependencias · documento(s) SSOT · dueño (bK | bd | ECO | bos)
Regla: si una tarea no cabe en una sesión o su criterio no es verificable
con un comando o una condición binaria, NO es atómica: se subdivide.
```

Convención de IDs: `bK-Gn.En.Tm` / `bd-Gn.En.Tm` / `ECO-Gn.En.Tm`.
El detalle micro de cada tarea (subpasos, firmas, archivos exactos) vive en el plan
atómico de su serie (→ bK-190, → bd-160); aquí viven las etapas, la sincronización y
los criterios de salida (gates) de cada fase.

## 2. Hitos verificables del programa

| Hito | Definición MEDIBLE |
|---|---|
| **H0** | Especificación congelada: ECO-000..010 + las 000–050 de ambas series + bK-140 en VALIDADO |
| **H1** | Intención→ejecución E2E en staging: un INSERT en una BD fuente de prueba produce, sin intervención, la escritura correspondiente en la BD destino con `origin='biedata'`, deduplicada en `_inbox`, con `event_id` trazable extremo a extremo; test automatizado en verde 10/10 ejecuciones |
| **H2** | Pipeline decisor: regla CESQL en `destination_registry` enruta a ≥2 destinos distintos según contenido; ficha de pipeline multi-paso de biedata ejecuta 5 pasos con merge de contexto |
| **H3** | Contexto: evento sin tenant_id resuelto por el enricher vía Entity Graph en < 2ms p99; `ctx_id` presente en logs de ambos daemons para el mismo flujo |
| **H4** | **Producción**: DDL BREAKING pausa fichas afectadas en < 100ms; RunEvents OpenLineage emitidos; resiliencia biedata (idempotencia/saga/breaker) demostrada con suite de caos básica |
| **H5** | Escala: con > 25 fuentes simuladas, failover de un Worker redistribuye en < 30s sin pérdida (checkpoints) |

## 3. Gates entre fases

Una fase NO arranca hasta que: (a) el hito anterior está VERIFICADO con evidencia en
ECO-004; (b) los documentos SSOT de sus tareas están al menos REDACTADOS; (c) el
arquitecto autoriza en sesión (queda en ECO-005).

## 4. Tablero de fases → etapas (estado vivo resumido; detalle en bK-190/bd-160)

### G0 — FUNDACIONES
| Etapa | Dueño | Contenido | Criterio de salida medible |
|---|---|---|---|
| G0.E1 Especificación | ECO | Lotes documentales 1–5 redactados/validados | H0 |
| G0.E2 Esqueleto bKernel | bK | workspace Cargo, binario mínimo, systemd, config TOML, CI | `cargo build --release` MUSL OK; binario < 15MB; CI verde; `systemctl status bkernel` activo en sandbox |
| G0.E3 Esqueleto biedata | bd | ídem + servidor HTTP mínimo `POST /rpc` con `common.server.version` | `curl POST /rpc common.server.version` → result; :9471/:9472 responden; CI verde |
| G0.E4 BD operacionales | bK+bd | DDL `sbos_kernel_db.bkernel` (núcleo) y `biedata_db` (operations, `_inbox`) con migraciones | migraciones aplican/revierten limpio en PG 17 de prueba |

### G1 — CONTRATO BILATERAL (el corazón; requiere ECO-020 VALIDADO)
| Etapa | Dueño | Contenido | Criterio de salida medible |
|---|---|---|---|
| G1.E1 mod cdc base | bK | listener PostgreSQL pgoutput, canal por fuente, checkpoints | INSERT/UPDATE/DELETE capturados; checkpoint persiste y reanuda tras kill -9 sin pérdida ni duplicado |
| G1.E2 Outbox→streams | bK | construcción de intención (sobre ECO-020) + publicación `bkernel:stream:biedata.*` | intención conforme al esquema del contrato (validador en verde); reintento ante Redis caído |
| G1.E3 Inbox+consumer | bd | consumer group, `_inbox UNIQUE(event_id)`, ACK | evento duplicado consumido 2 veces ejecuta 1 vez (test); XACK correcto |
| G1.E4 Ejecutor mínimo | bd | ficha inbound mínima que escribe `origin='biedata'` | escritura visible en BD destino de prueba con origin correcto |
| G1.E5 Anti-loop | bK | skipback (origin + inbox doble capa, F-06) | el eco de la escritura de biedata NO genera nueva intención hacia biedata (test de eco en verde) |
| G1.E6 Integración E2E | ECO | suite staging | **H1** |

### G2 — PIPELINE DECISOR
| Etapa | Dueño | Contenido | Criterio |
|---|---|---|---|
| G2.E1 Destination Registry | bK | DDL + CRUD bosctl + carga | reglas listadas/pausadas/reanudadas por CLI |
| G2.E2 CESQL Engine | bK | parser subset (comparaciones, AND/OR/NOT, field access) + integración pre-ejecución | suite de gramática 100%; routing dinámico demostrado |
| G2.E3 Router de métodos + validation engine | bd | resolución `method_rpc`→ficha; validation.yml → -32602 con detalle | request inválido rechazado con campo/regla/mensaje exactos; BD intacta |
| G2.E4 Pipeline multi-paso | bd | manifest.pipeline, merge_into context/result, on_error | ficha de 5 pasos del corpus reproducida (test) |
| G2.E5 Fichas de referencia | bK+bd | 2 fichas bK (4 archivos) + 2 fichas bd (3 archivos), de ejemplo (apps variables) | fichas cargan en caliente (SIGHUP/SIGUSR1) sin reinicio |
| — gate | ECO | | **H2** |

### G3 — CONTEXTO Y GRAFO
| Etapa | Dueño | Contenido | Criterio |
|---|---|---|---|
| G3.E1 Apache AGE + grafo | bK | extensión, DDL `sbos_entities`, migración crossref | consultas de jerarquía con tenant aislado |
| G3.E2 mod enricher | bK | resolución tenant/empresa/sucursal | < 2ms p99 (bench) |
| G3.E3 ctx_id en biedata | bd | `params._ctx_id` obligatorio, verificación Registry, logs/spans | operación sin ctx_id → -32602; con ctx_id → presente en log JSON y span |
| — gate | ECO | + ECO-030 parcial | **H3** |

### G4 — PROTECCIÓN, LINAJE Y RESILIENCIA → PRODUCCIÓN
| Etapa | Dueño | Contenido | Criterio |
|---|---|---|---|
| G4.E1 DDL Guardian v2 | bK | event triggers, clasificador 5 severidades, response engine, maintenance windows | BREAKING pausa fichas < 100ms; SAFE no interrumpe |
| G4.E2 mod lineage | bK | RunEvents OpenLineage fire-and-forget | RunEvent válido contra spec por cada escritura ejecutada |
| G4.E3 Idempotencia+Saga | bd | `_idempotency_key` (TTL, conflicto), compensaciones declarativas | replay no re-ejecuta; fallo en paso 4/5 compensa 3 anteriores (test) |
| G4.E4 Circuit breaker + observabilidad | bd | breaker por BD destino; catálogo métricas :9471; alertas | breaker abre al umbral y half-open recupera; dashboard carga |
| — gate | ECO | suite de caos básica | **H4 (PRODUCCIÓN)** |

### G5 — ESCALA
| Etapa | Dueño | Contenido | Criterio |
|---|---|---|---|
| G5.E1 Coordinator/Worker | bK | distribución, heartbeat, failover (solo si > 25 fuentes) | **H5** |
| G5.E2 Hardening biedata | bd | límites, rate, fuzzing del endpoint | suite seguridad en verde |
| G5.E3 Cierre documental | ECO | lotes 8–9 + actualización SBOS-050 (C-15) | catálogo de puertos actualizado y validado |

## 5. Reglas de gestión del plan

1. Estado de tareas SOLO en los registros (ECO-004/bK-004/bd-004) con evidencia.
2. Toda enmienda de alcance la valida el arquitecto (queda en ECO-005 y aquí como changelog).
3. Estimaciones de la fuente A5 (semanas) se conservan en bK-190 como referencia; el
   avance se mide por criterios cumplidos, no por tiempo.
4. Ninguna tarea referencia una aplicación concreta como requisito (D10): los destinos
   y fuentes de prueba son fixtures declarados en fichas de ejemplo.

## 6. Criterios de completitud de este documento

- [x] Jerarquía atómica definida con regla de atomicidad verificable.
- [x] 6 fases → 21 etapas con dueño y criterio de salida medible cada una.
- [x] Hitos H0–H5 con definición medible y gates entre fases.
- [x] Sincronización bK↔bd explícita en G1 (el corazón) y gates ECO.
- [x] Anclado en fuentes (A5 fases/cronograma; corpus biedata v3.0) sin inventar alcance.
- [ ] Detalle micro por tarea en bK-190/bd-160 mantenido en paridad con este tablero.
- [ ] Validación del arquitecto.

---
*BOS-ECO-008 v1.0 · 2026-06-10 · Nivel micro: → BOS-bKernel-190 · → BOS-biedata-160.*
