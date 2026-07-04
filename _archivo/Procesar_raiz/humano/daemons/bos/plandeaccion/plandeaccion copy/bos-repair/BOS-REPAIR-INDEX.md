# BOS-REPAIR — Índice Maestro del Proyecto de Reparación
## SKULL · SBOS · BosAgent · Junio 2026 · v2.0

---

## Qué es este proyecto

**BOS-REPAIR** es el conjunto completo de documentos, decisiones arquitectónicas
y planes de trabajo para:

1. **Corregir el código** del BosAgent — modularización, bugs críticos, diseño
2. **Robustecer el JSON-RPC** como interfaz universal de operación del bos
3. **Implementar el Context Plane completo** (SBOS-049) con estados y privilegios
4. **Establecer el bos como Kubernetes Operator Soberano** con escalado y mantenimiento
5. **Crear la capa de abstracción bosctl** que oculta Ubuntu y Kubernetes al operador
6. **Definir cómo medir** que todo lo anterior funciona correctamente
7. **Implementar biaos** — agente IA soberano OS + gateway IA centralizado
8. **Formalizar el RBAC** delegando a Ubuntu (PAM/sudoers) y K8s (RBAC API)

---

## Los 14 documentos del proyecto

### Leer primero — estado actual del código

| Archivo | Contenido | Por qué importa |
|---|---|---|
| `BOS-REPAIR-00-AUDITORIA-TECNICA.md` | 16 problemas con evidencia de código real | Base de todo — sin esto no hay contexto |

### ADRs — decisiones arquitectónicas

| Archivo | Contenido | Por qué importa |
|---|---|---|
| `BOS-REPAIR-06-ADR002-ROLES-PRIVILEGIOS.md` | Roles bos: Instalador vs Daemon, 3 roles, 7 estados ctx_id | Límites de qué puede/no puede hacer el bos |
| `BOS-REPAIR-07-ADR003-ESTANDARES-DOCUMENTACION.md` | Estándar godoc: 6 niveles, plantillas, reglas | Todo código nuevo debe seguir este estándar |
| `BOS-REPAIR-02-ADR004-OPERATOR-SOBERANO.md` | bos como K8s Operator: escalado coordinado, mantenimiento | Justifica sagas de escalado, anti death-spiral HPA+VPA |
| `BOS-REPAIR-03-ADR005-ABSTRACCION-BOSCTL.md` | bosctl como capa soberana: vocabulario SBOS, CRDs | El operador nunca ve K8s, solo ve el bos |
| `BOS-REPAIR-11-ADR006-RBAC-HERENCIA-UBUNTU-K8S.md` | RBAC delegado a Ubuntu (PAM/sudoers) + K8s (impersonation) | Elimina rbac_provider.go — Teleport/BeyondCorp pattern |

### Especificaciones de sistemas

| Archivo | Contenido | Por qué importa |
|---|---|---|
| `BOS-REPAIR-08-SBOS049-CONTEXT-PLANE.md` | Context Plane completo: dctx_id, ctx_id, DDL, API, estados | El bos es dueño del Context Plane |
| `BOS-REPAIR-09-SBOS052-VDI-SPEC.md` | VDI Layer: Fedora Físico/Lógico, Nextcloud, Guacamole, ISO | Cúspide del sistema — C-09..C-14 |
| `BOS-REPAIR-10-BIAOS-AGENTE-OS.md` | biaos: gateway IA + agente OS + ICAP Engine + sagas + entrenamiento | Agente soberano que usa todo lo demás |

### El trabajo real — plan y ejecución

| Archivo | Contenido | Por qué importa |
|---|---|---|
| `BOS-REPAIR-05-PLAN-ACCION-MAESTRO.md` | 10 fases, 57+ tareas atómicas, checkboxes, señales de retoma | El documento de trabajo — actualizar en cada commit |
| `BOS-REPAIR-04-SAGAS-CONSULTA-RPC.md` | 6 sagas consulta JSON-RPC: bos.query.system/repair/vdi/tenant/node/context | Agregación multi-fuente en paralelo |
| `BOS-REPAIR-12-SAGAS-CONSULTA-FUNDAMENTOS.md` | Marco normativo de las sagas: OTel CNCF, SRE InvD, ITIL 4, ISO 20000 | F6.6..F6.15 y F10.1..F10.24 son obligatorias por estándares |

### Cómo medir que funciona

| Archivo | Contenido | Por qué importa |
|---|---|---|
| `BOS-REPAIR-01-EFECTIVIDAD-VERIFICACION.md` | 5 capas, C-01..C-14, SLIs/SLOs, sagas de reparación | Sin esto no se sabe si una reparación terminó bien |
| `BOS-REPAIR-13-FLUJO-END-TO-END.md` | Secuencia completa: NL → biaos → sagas → verificación → audit trail | Conecta todos los componentes en un flujo coherente |

---

## Mapa de dependencias

```
BOS-REPAIR-00 (Auditoría — 16 problemas)
      │
      ├──► BOS-REPAIR-06 (ADR-002 — roles y privilegios)
      │         └──► BOS-REPAIR-02 (ADR-004 — Operator Soberano)
      │                   └──► BOS-REPAIR-03 (ADR-005 — abstracción bosctl)
      │
      ├──► BOS-REPAIR-07 (ADR-003 — cómo documentar)
      │
      ├──► BOS-REPAIR-11 (ADR-006 — RBAC delegado Ubuntu+K8s)
      │
      ├──► BOS-REPAIR-08 (SBOS-049 — Context Plane)
      │         └──► BOS-REPAIR-09 (SBOS-052 — VDI Layer)
      │
      └──► BOS-REPAIR-05 (Plan de acción — 10 fases)
                │
                ├──► BOS-REPAIR-04 (Sagas consulta — F6.6..F6.15)
                │         └──► BOS-REPAIR-12 (Fundamentos normativos sagas)
                │
                ├──► BOS-REPAIR-10 (biaos — F10.1..F10.24)
                │
                └──► BOS-REPAIR-01 (Efectividad — cómo verificar)
                          └──► BOS-REPAIR-13 (Flujo end-to-end)
```

---

## Estado de las 10 fases

| Fase | Nombre | Estado | Duración est. |
|---|---|---|---|
| 0 | Estructura de paquetes | 🔴 NO INICIADA | 2h |
| 1 | Extraer infraestructura de cmd/bos/main.go | 🔴 NO INICIADA | 2-3d |
| 2 | Unificar WebSocket | 🔴 NO INICIADA | 1d |
| 3 | Partir install_ui.go | 🔴 NO INICIADA | 3-4d |
| 4 | Limpiar cmd/bosctl/ + eliminar rbac_provider.go | 🔴 NO INICIADA | 1-2d |
| 5 | Context Plane completo (SBOS-049) | 🔴 NO INICIADA | 3-4d |
| 6 | JSON-RPC robusto + sagas de consulta (F6.1..F6.15) | 🔴 NO INICIADA | 2-3d |
| 7 | Documentación continua (ADR-003) | 🔴 NO INICIADA | continuo |
| 8 | Tests | 🔴 NO INICIADA | 2-3d |
| 9 | Operator Soberano: escalado + VDI | 🔴 NO INICIADA | 4-5d |
| 10 | biaos: agente OS + gateway IA (F10.1..F10.24) | 🔴 NO INICIADA | 5-7d |

**Estados:** 🔴 NO INICIADA · 🟡 EN PROGRESO · 🟢 COMPLETA · ⚠️ BLOQUEADA

---

## ADRs vigentes en este proyecto

| ADR | Título | Estado | Fase que lo implementa |
|---|---|---|---|
| ADR-001 | BOS como capa OS — bosctl reemplaza sudo | Aceptado | Fase 1, 4 |
| ADR-002 | Roles, modos y privilegios del daemon bos | Aceptado → BOS-REPAIR-06 | Fase 1, 5, 6 |
| ADR-003 | Estándares de documentación godoc | Aceptado → BOS-REPAIR-07 | Fase 7 (continua) |
| ADR-004 | bos como Kubernetes Operator Soberano | Aceptado → BOS-REPAIR-02 | Fase 9 |
| ADR-005 | bosctl como capa de abstracción soberana | Aceptado → BOS-REPAIR-03 | Fase 4, 9 |
| ADR-006 | RBAC delegado a Ubuntu+K8s (elimina rbac_provider.go) | Aceptado → BOS-REPAIR-11 | Fase 4 |
| ADR-021 | Máquina de 18 estados de fichas | Existente | Fase 1 (mutex observer) |

---

## Señal de retoma rápida

```bash
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src

echo "=== Estado de fases ==="
echo -n "F0 (paquetes):      "; [ -f internal/audit/doc.go ] && echo "✅" || echo "❌"
echo -n "F1 (infra extraída):"; grep -q "func auditLog" cmd/bos/main.go 2>/dev/null && echo "❌ auditLog en main" || echo "✅"
echo -n "F2 (WS unificado):  "; grep -rq "gorilla/websocket" cmd/ 2>/dev/null && echo "❌ gorilla en cmd/" || echo "✅"
echo -n "F3 (install_ui):    "; lines=$(wc -l < cmd/bosctl/install_ui.go 2>/dev/null || echo 9999); [ $lines -gt 500 ] && echo "❌ ($lines líneas)" || echo "✅"
echo -n "F4 (bosctl limpio): "; grep -rq "rbac_provider" internal/security/rbac_provider.go 2>/dev/null && echo "❌ rbac_provider existe" || echo "✅"
echo -n "F5 (context plane): "; [ -f internal/context/service.go ] && echo "✅" || echo "❌"
echo -n "F6 (sagas consulta):"; grep -q "bos.query.system" internal/server/jsonrpc.go 2>/dev/null && echo "✅" || echo "❌"
echo -n "F9 (operator):      "; [ -d internal/scaler ] && echo "✅" || echo "❌"
echo -n "F10 (biaos):        "; [ -f internal/biaos/gateway.go ] && echo "✅" || echo "❌"
```

---

## Archivos que deben estar en el Knowledge de Claude

```
Todos estos archivos BOS-REPAIR (14 + este índice = 15 total):

  BOS-REPAIR-INDEX.md                         ← leer primero siempre
  BOS-REPAIR-00-AUDITORIA-TECNICA.md
  BOS-REPAIR-01-EFECTIVIDAD-VERIFICACION.md
  BOS-REPAIR-02-ADR004-OPERATOR-SOBERANO.md
  BOS-REPAIR-03-ADR005-ABSTRACCION-BOSCTL.md
  BOS-REPAIR-04-SAGAS-CONSULTA-RPC.md
  BOS-REPAIR-05-PLAN-ACCION-MAESTRO.md
  BOS-REPAIR-06-ADR002-ROLES-PRIVILEGIOS.md
  BOS-REPAIR-07-ADR003-ESTANDARES-DOCUMENTACION.md
  BOS-REPAIR-08-SBOS049-CONTEXT-PLANE.md
  BOS-REPAIR-09-SBOS052-VDI-SPEC.md
  BOS-REPAIR-10-BIAOS-AGENTE-OS.md
  BOS-REPAIR-11-ADR006-RBAC-HERENCIA-UBUNTU-K8S.md  ← nuevo
  BOS-REPAIR-12-SAGAS-CONSULTA-FUNDAMENTOS.md        ← nuevo
  BOS-REPAIR-13-FLUJO-END-TO-END.md                  ← nuevo

Del código fuente (para referencia al trabajar):
  cmd__bos__main.go.md, cmd__bosctl__main.go.md
  cmd__bosctl__install_ui.go.md, cmd__bosctl__bootstrap.go.md
  internal__server__jsonrpc.go.md, internal__wslib__websocket.go.md
  internal__reconcile__scheduler.go.md, internal__repair__repair_manager.go.md
  internal__ai__model_router.go.md, internal__ai__client.go.md
  internal__security__rbac_provider.go.md
  go_mod.md

Del manual JSON-RPC (para referencia de sagas):
  JSON-RPC-01-fundamentos.md  .. JSON-RPC-09-orquestacion-multi-motor.md

De la especificación SBOS:
  SBOS-049-CONTEXT-PLANE.md, SBOS-052-VDI-SPEC.md
  SBOS-MANUAL-ACOPLAMIENTO.md, 00_ARCHITECTURE_SBOS.yml
  00_MASTER_INSTALL_SBOS.sh, 00_YAML_ENGINE_SBOS.sh
```

---

_BOS-REPAIR-INDEX v2.0 · SKULL · SBOS · Junio 2026_
_Actualizar este índice cada vez que se agregue un documento BOS-REPAIR_
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
