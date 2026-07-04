# BOS-REPAIR — Índice Maestro de Anexos
## Toda la documentación de investigación que respalda el Plan Maestro

**Proyecto:** BosAgent / SBOS · SKULL  
**Versión:** 2.0 — Inventario completo desde el inicio de la conversación  
**Fecha:** 07 de Junio, 2026  
**Política:** Todo material de investigación traído a la conversación se preserva aquí.
Nunca se descarta. Es la memoria permanente del proyecto.

---

## Política de Anexos

```
POLÍTICA-ANEXO-01 — Numeración secuencial permanente
  Cada anexo recibe un número ANX-XXX que nunca cambia.
  Si se agrega nuevo material: ANX-023, ANX-024, etc.
  Los números no se reutilizan aunque el material se supere.

POLÍTICA-ANEXO-02 — Archivos originales sin modificar
  El contenido del material original no se altera.
  Las observaciones y análisis van en el Informe de Cierre del átomo.

POLÍTICA-ANEXO-03 — Separación por origen
  TIPO A — Documentos del knowledge del proyecto (BOS-REPAIR-XX, código fuente)
  TIPO B — Archivos subidos directamente en la conversación (investigación externa)
  TIPO C — Documentos generados por Claude como parte del plan

POLÍTICA-ANEXO-04 — Todo anexo tiene su ANEXO-INDEX.md
  Cada directorio ANX-XXX tiene un ANEXO-INDEX.md con:
  origen, fecha, átomo relacionado, tipo, resumen de contenido.
```

---

## CATEGORÍA I — Auditoría y estado del código

### ANX-001 — Auditoría Técnica (16 problemas)
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivo original | `BOS-REPAIR-00-AUDITORIA-TECNICA.md` |
| Origen | Auditoría estática del código fuente BosAgent — Junio 2026 |
| Átomo relacionado | Base de F1.1..F1.7, F2.x, F3.x, F4.x |
| Resumen | 16 problemas con evidencia de código: P1 monolito 4834 líneas, P2 doble WS, P3 TEA violado, P4 infra en main, P5 kubeconfig ×6, P6/P14 race condition (crítico), P7..P16 |
| Por qué importa | **Base de todo el plan** — sin esta auditoría no hay contexto para ningún átomo |

### ANX-002 — Plan de Acción Original (v1 del plan maestro)
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivo original | `BOS-REPAIR-05-PLAN-ACCION-MAESTRO.md` |
| Origen | Equipo SKULL — Junio 2026 |
| Átomo relacionado | Base del Plan Maestro v3.0 |
| Resumen | Plan original de 9 fases. La v3.0 del plan maestro lo supera y amplía con 98 átomos, pero este documento es la referencia histórica del diseño original |

### ANX-015 — Código fuente `cmd/`
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivos | `cmd__bos__main.go.md` (1,417 líneas), `cmd__bosctl__main.go.md` (639 líneas), `cmd__bosctl__install_ui.go.md` (4,834 líneas), `cmd__bosctl__bootstrap.go.md` (648 líneas), más archivos cmd/ |
| Átomo relacionado | F1.x, F2.x, F3.x, F4.x |
| Resumen | Código fuente completo de la capa cmd/. Es el 40% del código con los 16 problemas. Referencia directa para cada átomo de extracción |

### ANX-016 — Código fuente `internal/`
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivos | `internal__state__manager.go.md`, `internal__server__jsonrpc.go.md`, `internal__repair__repair_manager.go.md`, `internal__installer__saga.go.md`, `internal__installer__compensator.go.md`, `internal__wslib__websocket.go.md`, `internal__reconcile__scheduler.go.md`, `internal__health__checker.go.md`, `internal__watchdog__unified_watchdog.go.md`, `internal__security__rbac_provider.go.md`, `internal__k8s__core.go.md`, `internal__plugin__loader.go.md`, `internal__ai__client.go.md`, `internal__ai__model_router.go.md`, `internal__config__config.go.md`, `internal__domain__types.go.md` |
| Átomo relacionado | Todos — es el código que no se toca (60% correcto) |
| Resumen | Código fuente completo de internal/. La máquina de 18 estados, el compensador de sagas, el reconciliador. La arquitectura correcta que sirve de modelo |

### ANX-017 — go.mod y dependencias
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivo original | `go_mod.md` |
| Átomo relacionado | F2.4 (eliminar gorilla/websocket) |
| Resumen | `module bos`, Go 1.25.0. Dependencias clave: bubbletea v1.3.10, lipgloss v1.1.0, gorilla/websocket v1.5.3 (a eliminar en F2.4), zerolog v1.33.0 |

### ANX-018 — Reportes de duplicaciones y propuesta internal/
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivos | `reporte__00_resumen.md`, `reporte__01_duplicaciones.md`, `reporte__02_plan_accion.md`, `reporte__03_propuesta_internal.md` |
| Átomo relacionado | F0.2, F1.x, F4.x |
| Resumen | Inventario completo de duplicaciones: `defaultSocket` duplicado, 24 funciones mal ubicadas en cmd/ que pertenecen a internal/, boilerplate inicial de los paquetes nuevos |

---

## CATEGORÍA II — ADRs (Decisiones Arquitectónicas)

### ANX-003 — ADR-002: Roles y Privilegios del daemon bos
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivo original | `BOS-REPAIR-06-ADR002-ROLES-PRIVILEGIOS.md` |
| Átomo relacionado | F1.5, F5.2, F6.1 |
| Resumen | 3 roles funcionales: Observador, Administrador Ubuntu+K8s, Gestor Context Plane. 2 modos: Instalador y Daemon Soberano. Límites exactos de qué puede y no puede hacer el bos |

### ANX-004 — ADR-003: Estándares de Documentación
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivo original | `BOS-REPAIR-07-ADR003-ESTANDARES-DOCUMENTACION.md` |
| Átomo relacionado | F7.x (toda la fase) |
| Resumen | 6 niveles de godoc obligatorios. 6 reglas R1..R6. Plantillas por módulo (observer, context, jsonrpc). Base normativa: Effective Go, Google Go Style Guide, ISO 27001:2022, NIST SP 800-207 |

### ANX-005 — ADR-004: bos como Kubernetes Operator Soberano
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivo original | `BOS-REPAIR-02-ADR004-OPERATOR-SOBERANO.md` |
| Átomo relacionado | F9.x (toda la fase) |
| Resumen | El bos implementa el patrón Operator de K8s. Escalado coordinado HPA+VPA anti-death-spiral. Saga de mantenimiento cordon→drain→op→uncordon con compensación. 9 nuevos métodos bos.k8s.* y 3 bos.maintenance.* |

### ANX-006 — ADR-005: Abstracción bosctl
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivo original | `BOS-REPAIR-03-ADR005-ABSTRACCION-BOSCTL.md` |
| Átomo relacionado | F4.5, F9.10 |
| Resumen | bosctl como capa soberana. Nivel 1: subcomandos con vocabulario SBOS (bosctl ficha, bosctl node, bosctl vdi). Nivel 2: CRD SBOSFicha en K8s. Nivel 3: bosctl rpc para JSON-RPC directo |

### ANX-007 — ADR-006: RBAC Delegado Ubuntu+K8s
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivo original | `BOS-REPAIR-11-ADR006-RBAC-HERENCIA-UBUNTU-K8S.md` |
| Átomo relacionado | F4.4 (eliminar rbac_provider.go) |
| Resumen | Eliminar rbac_provider.go. Delegar a Ubuntu PAM/sudoers (4 grupos: bos-readonly, bos-operators, bos-maintenance, denegaciones) y K8s RBAC API (impersonation). Plan de migración en 10 pasos |

---

## CATEGORÍA III — Especificaciones de Sistemas

### ANX-008 — Efectividad y Verificación (SLIs/SLOs)
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivo original | `BOS-REPAIR-01-EFECTIVIDAD-VERIFICACION.md` |
| Átomo relacionado | F5.x, F9.9, criterio 10/10 |
| Resumen | 5 capas de efectividad. 14 criterios C-01..C-14. SLOs: postgresql 99.95%, VDI 99%, Context Plane p99 < 2s. Métricas Prometheus por capa. El único criterio de completitud del plan |

### ANX-009 — Context Plane SBOS-049
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivo original | `BOS-REPAIR-08-SBOS049-CONTEXT-PLANE.md` |
| Átomo relacionado | F5.x (toda la fase) |
| Resumen | DeviceContext (dctx_id) pre-autenticación. SessionContext (ctx_id) post-autenticación. 7 estados: PENDIENTE→ACTIVO→SUSPENDIDO→BLOQUEADO→INVALIDADO→EXPIRADO→ARCHIVADO. BitMask uint64. TTLs ISO 27001 (8h dispositivos, 12h sesiones). DDL PostgreSQL + Redis DB1 |

### ANX-010 — VDI Layer SBOS-052
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivos | `BOS-REPAIR-09-SBOS052-VDI-SPEC.md`, `SBOS-052-VDI-SPEC.md` |
| Átomo relacionado | F9.9 |
| Resumen | Fedora Lógico como pod K8s. Nextcloud para home. Guacamole para acceso web. sbos-fedora.iso booteable. 6 pasos de verificación. SLO: tiempo de login Fedora p95 < 10s |

### ANX-011 — biaos: Agente OS + Gateway IA
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivos | `BOS-REPAIR-10-BIAOS-AGENTE-OS.md`, `biaos-proyecto-ia-robusta.md` |
| Átomo relacionado | F10.x (toda la fase) |
| Resumen | Gateway LLM singleton (DeepSeek→Claude→Ollama). ICAP Engine con action_catalog.yml. SagaEngine Go con DAG topológico y compensaciones. Loop ReAct Thought→Action→Observation. HITL para acciones destructivas. Exportar trayectorias como JSONL para fine-tuning |

### ANX-012 — Sagas de Consulta RPC (especificación técnica)
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivo original | `BOS-REPAIR-04-SAGAS-CONSULTA-RPC.md` |
| Átomo relacionado | F6.6..F6.11 |
| Resumen | 6 sagas: bos.query.system, bos.query.repair, bos.query.vdi, bos.query.tenant, bos.query.node, bos.query.context. Cada una agrega múltiples fuentes en paralelo. Objetivo: < 4s por saga |

### ANX-013 — Sagas de Consulta: Fundamentos Normativos
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivo original | `BOS-REPAIR-12-SAGAS-CONSULTA-FUNDAMENTOS.md` |
| Átomo relacionado | F6.6..F6.11 (marco normativo) |
| Resumen | Por qué las 6 sagas son obligatorias: OpenTelemetry CNCF (graduado Mayo 2026), Google SRE InvD (44% reducción MTTM), ITIL 4 + ISO 20000. Prerequisito directo de F10.1..F10.9 (biaos no puede operar sin ellas) |

### ANX-014 — Flujo End-to-End de Reparación
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivo original | `BOS-REPAIR-13-FLUJO-END-TO-END.md` |
| Átomo relacionado | Criterio definitivo 10/10 |
| Resumen | Flujo completo: lenguaje natural → biaos ReAct → sagas JSON-RPC → verificación → usuario. Caso canónico: "nextcloud no abre". Mapeo ITIL 4 (identificación→diagnóstico→resolución→revisión) a componentes SBOS. El test `bosctl vdi test-repair` es el criterio de completitud del plan |

---

## CATEGORÍA IV — Arquitectura y Configuración

### ANX-019 — biaos Arquitectura
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivo original | `biaos-arquitectura.md` |
| Átomo relacionado | F10.x |
| Resumen | Diagrama de arquitectura de biaos. Principios de diseño: diagnostica primero, nunca propone repair sin evidencia, HITL obligatorio. Restricciones: Go 1.25 stdlib, Ollama offline |

### ANX-020 — Arquitectura SBOS (YAML + scripts)
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivos | `00_ARCHITECTURE_SBOS.yml`, `00_MASTER_INSTALL_SBOS.sh`, `00_YAML_ENGINE_SBOS.sh`, `00_TASK_CATALOG_SBOS.sh`, `00_CLEANUP_SBOS.sh`, `SBOS-049-CONTEXT-PLANE.md`, `SBOS-MANUAL-ACOPLAMIENTO.md` |
| Átomo relacionado | F1.2 (bootstrap), F9.x (K8s), F10.x (biaos) |
| Resumen | El DAG completo de 22 fichas. Script master de instalación. Motor YAML. Catálogo de tareas. Manual de acoplamiento entre daemons. La arquitectura real del sistema que el bos administra |

### ANX-021 — Manual JSON-RPC (9 partes)
| Campo | Valor |
|---|---|
| Tipo | A — Knowledge del proyecto |
| Archivos | `JSON-RPC-01-fundamentos.md` .. `JSON-RPC-09-orquestacion-multi-motor.md` |
| Átomo relacionado | F6.x (toda la fase) |
| Resumen | Manual completo del protocolo JSON-RPC del bos. Fundamentos, autenticación, CRUD de contexto, cadena de eventos, arquitectura servidor, errores en producción, arquitectura híbrida, ecosistema, orquestación multi-motor |

---

## CATEGORÍA V — Investigación Externa (archivos subidos)

### ANX-022 — GAP 1: Pipeline CI/CD ✅
| Campo | Valor |
|---|---|
| Tipo | B — Archivo subido en la conversación |
| Archivos | `ci.yml`, `validate.sh`, `F0.5-activacion-branch-protection.md` |
| Origen | Investigación externa — respuesta al prompt del GAP 1 |
| Átomo relacionado | **F0.5** |
| Fecha | 07 de Junio, 2026 |
| Estado | ✅ Incorporado — Informe de Cierre: `INFORME-CIERRE-F0.5-CI-CD.md` |
| Resumen | Pipeline GitHub Actions con 4 jobs. Race detection HARD GATE con `GORACE=halt_on_error=1` y `-count=10`. Coverage como WARNING. validate.sh como espejo local |

---

### ANX-023 — GAP 2: Entornos DEV/STAGING/PROD ✅
| Campo | Valor |
|---|---|
| Tipo | B — Archivo subido en la conversación |
| Archivos | `ENVIRONMENTS.md`, `staging-runner-setup.sh` |
| Origen | Investigación externa — respuesta al prompt del GAP 2 |
| Átomo relacionado | **F0.6** + **F0.6.S** (derivado — deuda seguridad staging) |
| Fecha | 07 de Junio, 2026 |
| Estado | ✅ Incorporado — Informe de Cierre: `INFORME-CIERRE-F0.6-ENTORNOS.md` |
| Resumen | VPS DEV (144.91.76.130/skull) + VPS STAGING (13.140.128.230/root). Self-hosted runner con usuario bos-runner y least privilege. Feature flags por entorno. Flujo Windows+WSL→SSH→VPS→GitHub Actions→Staging. Deuda: staging corre como root → átomo F0.6.S |

### ANX-024 — GAP 3: Runbooks Operacionales ✅
| Campo | Valor |
|---|---|
| Tipo | C — Generado desde knowledge del proyecto (sin investigación externa) |
| Archivos | `RB-01-FICHA-DEGRADADA.md`, `RB-02-DATA-RACE-DETECTADA.md`, `RB-03-CONTEXT-PLANE-DOWN.md`, `INDEX.md`, `INCIDENTES-LOG.md` |
| Origen | Generado desde BOS-REPAIR-00..13 + código fuente. Sin archivo externo necesario |
| Átomo relacionado | **F7.8** |
| Fecha | 07 de Junio, 2026 |
| Estado | ✅ Incorporado — Informe de Cierre: `INFORME-CIERRE-F7.8-RUNBOOKS.md` |
| Resumen | 3 runbooks operacionales: RB-01 Ficha DEGRADADA (5 casos), RB-02 DATA RACE (P6/P14 + solución temporal y permanente), RB-03 Context Plane Down (4 casos incluyendo F5.x pendiente). + INDEX.md + INCIDENTES-LOG.md |

### ANX-025 — GAP 4: `action_catalog.yml` biaos ✅
| Campo | Valor |
|---|---|
| Tipo | C — Generado desde knowledge del proyecto (sin investigación externa) |
| Archivos | `action_catalog.yml` (26 acciones en 3 categorías) |
| Origen | Construido desde biaos-proyecto-ia-robusta.md + BOS-REPAIR-10 + 00_ARCHITECTURE_SBOS.yml |
| Átomo relacionado | **F10.0** |
| Fecha | 07 de Junio, 2026 |
| Estado | ✅ Incorporado — Informe de Cierre: `INFORME-CIERRE-F10.0-ACTION-CATALOG.md` |
| Resumen | 13 acciones cat-1 (lectura sin HITL), 8 acciones cat-2 (escritura HITL simple), 5 acciones cat-3 (destructivas HITL doble). Cubre todos los módulos bos.query/ficha/k8s/ctx/maintenance. Schema compatible con CatalogEntry de catalog.go. Aliases en español coloquial latinoamericano. Guardia de dominio que bloquea bCompass/Tryton/Saleor. |

---

### ANX-026 — Motor biaos: scripts análogos a 00_* de fichas ⚠️
| Campo | Valor |
|---|---|
| Tipo | C — Generado desde knowledge del proyecto |
| Archivos | `00_ARCHITECTURE_BIAOS.yml`, `00_INTENT_ENGINE_BIAOS.sh`, `00_INTENT_CATALOG_BIAOS.sh`, `00_MASTER_BIAOS.sh` |
| Origen | Generado en sesión interrumpida — pendiente revisión de estructura |
| Átomo relacionado | **F10.0, F10.3, F10.4** |
| Fecha | 07 de Junio, 2026 |
| Estado | ⚠️ Generado — requiere revisión: una "ficha biaos" debe resolver peticiones NL, no instalar servicios K8s |
| Resumen | Juego propio de scripts para el motor de intenciones biaos. Análogos a 00_ARCHITECTURE/YAML_ENGINE/TASK_CATALOG/MASTER_INSTALL del bos pero para dominio IA. Una intención biaos = conjunto de comandos que resuelve una petición en lenguaje natural. |

---

## Resumen de estado

| Categoría | Total | ✅ Con contenido | ⚠️ Requiere revisión | 🔴 Pendiente |
|---|---|---|---|---|
| I — Auditoría y código | ANX-001, 002, 015, 016, 017, 018 | 6 | 0 | 0 |
| II — ADRs | ANX-003 a 007 | 5 | 0 | 0 |
| III — Especificaciones | ANX-008 a 014 | 7 | 0 | 0 |
| IV — Arquitectura | ANX-019 a 021 | 3 | 0 | 0 |
| V — Investigación externa / generada | ANX-022 a 026 | 5 | 1 | 0 |
| **Total** | **27 anexos** | **26** | **1** | **0** |

**Los 4 gaps documentales están cerrados.**
**ANX-026 requiere revisión de estructura antes de incorporar al proyecto.**

---

## Cómo agregar un nuevo anexo

Cuando llegue nueva investigación externa:

```
1. Crear directorio: anexos/ANX-0NN-descripcion-breve/
2. Copiar archivos originales sin modificar
3. Crear ANEXO-INDEX.md con la tabla estándar
4. Agregar entrada en este índice (CATEGORÍA V)
5. Actualizar la tabla de resumen
6. Referenciar en el átomo correspondiente del plan maestro
```

---

*Índice de Anexos v2.0 · BOS-REPAIR · SKULL · SBOS · 07 de Junio 2026*  
*25 anexos catalogados · 22 con contenido · 3 pendientes de investigación*

### ANX-026 — Motor de Intenciones biaos (scripts propios) ⚠️
| Campo | Valor |
|---|---|
| Tipo | C — Generado desde knowledge del proyecto |
| Archivos | `00_ARCHITECTURE_BIAOS.yml`, `00_INTENT_ENGINE_BIAOS.sh`, `00_INTENT_CATALOG_BIAOS.sh`, `00_MASTER_BIAOS.sh` |
| Átomo relacionado | **F10.0** (complemento del action_catalog.yml) |
| Fecha | 07 de Junio, 2026 |
| Estado | ⚠️ Generado — Pendiente rediseño del patrón propio |
| Resumen | 4 scripts análogos a los 00_ del bos pero para intenciones IA. Pendiente rediseño: los scripts biaos deben tener su PROPIO patrón. Una "acción biaos" = conjunto de comandos que resuelve una petición en lenguaje natural, no gestión de ciclo de vida K8s. |

---

## Resumen de estado actualizado

| Categoría | Total | ✅ OK | ⚠️ Revisión | 🔴 Pendiente |
|---|---|---|---|---|
| I — Auditoría y código | ANX-001, 002, 015, 016, 017, 018 | 6 | 0 | 0 |
| II — ADRs | ANX-003 a 007 | 5 | 0 | 0 |
| III — Especificaciones | ANX-008 a 014 | 7 | 0 | 0 |
| IV — Arquitectura | ANX-019 a 021 | 3 | 0 | 0 |
| V — Investigación / generada | ANX-022 a 026 | 4 | 1 | 0 |
| **Total** | **27 anexos** | **25** | **1** | **0** |
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
