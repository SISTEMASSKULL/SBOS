# BOS-REPAIR — Índice Maestro del Proyecto de Reparación
## SKULL · SBOS · BosAgent · Junio 2026 · v3.0

---

## Qué es este proyecto

**BOS-REPAIR** es el conjunto completo de documentos, decisiones arquitectónicas
y planes de trabajo para:

1. **Corregir el código** del BosAgent — modularización, bugs críticos, diseño ✅ (F0-F10)
2. **Robustecer el JSON-RPC** como interfaz universal de operación del bos ✅
3. **Implementar el Context Plane completo** (SBOS-049) con estados y privilegios ✅ (efectividad real: F5.B)
4. **Establecer el bos como Kubernetes Operator Soberano** con escalado y mantenimiento ✅
5. **Crear la capa de abstracción bosctl** que oculta Ubuntu y Kubernetes al operador ✅
6. **Definir cómo medir** que todo lo anterior funciona correctamente ✅
7. **Implementar biaos** — agente IA soberano OS + gateway IA centralizado ✅ (validación staging: F10.10)
8. **Formalizar el RBAC** delegando a Ubuntu (PAM/sudoers) y K8s (RBAC API) ✅
9. **Completar el PRODUCTO** — renders reales de las 15 pantallas, Ficha Engine completo, Context Plane contra PG+Redis reales 🔴 (F3.B, F11)
10. **Desplegar el stack por capas** con stubs de contrato de los daemons hermanos (ADR-007) 🔴 (F12-F15)
11. **Alcanzar la CÚSPIDE VDI** — fichas nextcloud/guacamole/fedora-logico, sbos-client, ISO con datos del tenant 🔴 (F16)
12. **Certificar con estándares internacionales** — CIS v1.12, NIST 800-190/SSDF, SLSA L2, ISO 27001/25010 🔴 (F17)

**Estado vivo de los 162 átomos:** `REGISTRO-ESTADO.md` (89 ✅ · 73 🔴) — leer SIEMPRE antes de ejecutar.

---

## Los 17 documentos del proyecto (+ índice + cuestionario)

### Leer primero — estado actual

| Archivo | Contenido | Por qué importa |
|---|---|---|
| `REGISTRO-ESTADO.md` | Estado de los 162 átomos en 18 fases (F0-F17) | La fuente de verdad del progreso |
| `BOS-REPAIR-00-AUDITORIA-TECNICA.md` | 16 problemas con evidencia de código real | Base de todo — sin esto no hay contexto |
| `BOS-REPAIR-CUESTIONARIO-01.md` | Aclaraciones del operador (stubs, VDI, fichas, pantallas) | Decisiones que sustentan F11-F17 |

### ADRs — decisiones arquitectónicas

| Archivo | Contenido | Por qué importa |
|---|---|---|
| `BOS-REPAIR-06-ADR002-ROLES-PRIVILEGIOS.md` | Roles bos: Instalador vs Daemon, 3 roles, 7 estados ctx_id | Límites de qué puede/no puede hacer el bos |
| `BOS-REPAIR-07-ADR003-ESTANDARES-DOCUMENTACION.md` | Estándar godoc: 6 niveles, plantillas, reglas | Todo código nuevo debe seguir este estándar |
| `BOS-REPAIR-02-ADR004-OPERATOR-SOBERANO.md` | bos como K8s Operator: escalado coordinado, mantenimiento | Justifica sagas de escalado, anti death-spiral HPA+VPA |
| `BOS-REPAIR-03-ADR005-ABSTRACCION-BOSCTL.md` | bosctl como capa soberana: vocabulario SBOS, CRDs | El operador nunca ve K8s, solo ve el bos |
| `BOS-REPAIR-11-ADR006-RBAC-HERENCIA-UBUNTU-K8S.md` | RBAC delegado a Ubuntu (PAM/sudoers) + K8s (impersonation) | Elimina rbac_provider.go — Teleport/BeyondCorp pattern |
| `BOS-REPAIR-16-ADR007-DAEMONS-STUB.md` | Daemons hermanos como stubs de contrato en sus repos definitivos | Contratos reales + datos ficticios — desbloquea F11.5, F14, F16 |

### Especificaciones de sistemas

| Archivo | Contenido | Por qué importa |
|---|---|---|
| `BOS-REPAIR-08-SBOS049-CONTEXT-PLANE.md` | Context Plane completo: dctx_id, ctx_id, DDL, API, estados | El bos es dueño del Context Plane |
| `BOS-REPAIR-09-SBOS052-VDI-SPEC.md` | VDI Layer: Fedora Físico/Lógico, Nextcloud, Guacamole, ISO | Cúspide del sistema — C-09..C-14 |
| `BOS-REPAIR-10-BIAOS-AGENTE-OS.md` | biaos: gateway IA + agente OS + ICAP Engine + sagas + entrenamiento | Agente soberano que usa todo lo demás |
| `BOS-REPAIR-14-SBOS-CLIENT-SPEC.md` | sbos-client: WS mTLS :9444, monorepo, 3 modos, push promoted/expired | Spec de desarrollo de F16.5-F16.9 |
| `BOS-REPAIR-15-ESTANDARES-INTERNACIONALES.md` | CIS v1.12 · NIST 800-190/SSDF · SLSA L2 · ISO 27001/25010 | Marco normativo de F17 — fuentes primarias |

### El trabajo real — plan y ejecución

| Archivo | Contenido | Por qué importa |
|---|---|---|
| `BOS-REPAIR-PLAN-MAESTRO-v3.md` (v4.0) | PARTES I-IV (F0-F10) + PARTE V (complementos + F11-F17) | EL plan de trabajo vigente |
| `BOS-REPAIR-05-PLAN-ACCION-MAESTRO.md` | Diseño ORIGINAL v2.0 — histórico, con nota de estado | Referencia de diseño; no se ejecuta desde aquí |
| `BOS-REPAIR-04-SAGAS-CONSULTA-RPC.md` | 6 sagas consulta JSON-RPC: bos.query.* | Agregación multi-fuente en paralelo |
| `BOS-REPAIR-12-SAGAS-CONSULTA-FUNDAMENTOS.md` | Marco normativo de las sagas: OTel CNCF, SRE, ITIL 4, ISO 20000 | Las sagas son obligatorias por estándares |

### Cómo medir que funciona

| Archivo | Contenido | Por qué importa |
|---|---|---|
| `BOS-REPAIR-01-EFECTIVIDAD-VERIFICACION.md` | 5 capas, C-01..C-14, SLIs/SLOs, sagas de reparación | Sin esto no se sabe si una reparación terminó bien |
| `BOS-REPAIR-13-FLUJO-END-TO-END.md` | Secuencia completa: NL → biaos → sagas → verificación → audit trail | Conecta todos los componentes en un flujo coherente |

### Operación del agente (en plandeaccion/)

| Archivo | Contenido |
|---|---|
| `PROTOCOLO-SESION-AGENTE.md` | Apertura/ejecución/cierre + reglas F11-F17 + protocolo staging |
| `SESION-LOG.md` | Libro de novedades entre sesiones |
| `GESTION-RIESGOS-OPERATIVOS.md` (v2) | Gates ⛔/🔴 con planes de cambio — incluye F11.5, F12.3, F13.2, F14.2, F16.12, F17.1 |
| `MAPA-NAVEGACION.md` | Árbol de documentos + flujos de decisión |
| `BOS-REPAIR-EVALUACION-PLAN-MAESTRO.md` | Evaluación original + PARTE II re-evaluación (90→162 átomos) |
| `EVALUACION-AGENTE-IA-BOS-REPAIR.md` | Preparación del agente: 9.7/10 + addendum F11-F17 |

---

## Mapa de dependencias

```
BOS-REPAIR-00 (Auditoría — 16 problemas)
      │
      ├──► BOS-REPAIR-06 (ADR-002 — roles y privilegios)
      │         └──► BOS-REPAIR-02 (ADR-004 — Operator Soberano)
      │                   └──► BOS-REPAIR-03 (ADR-005 — abstracción bosctl)
      ├──► BOS-REPAIR-07 (ADR-003 — cómo documentar)
      ├──► BOS-REPAIR-11 (ADR-006 — RBAC delegado Ubuntu+K8s)
      │
      ├──► BOS-REPAIR-08 (SBOS-049 — Context Plane)
      │         └──► BOS-REPAIR-09 (SBOS-052 — VDI Layer)
      │                   └──► BOS-REPAIR-14 (sbos-client spec)  ← F16
      │
      ├──► BOS-REPAIR-16 (ADR-007 — daemons stub)               ← F11.5, F14, F16
      │         └──► contratos canónicos: SBOS-BAUTH-* · SBOS-NEXUS v3.0
      │
      └──► PLAN-MAESTRO v4.0 (PARTES I-V) + REGISTRO-ESTADO (162 átomos)
                ├──► BOS-REPAIR-04 + BOS-REPAIR-12 (sagas consulta)
                ├──► BOS-REPAIR-10 (biaos)
                ├──► BOS-REPAIR-15 (estándares)                  ← F17
                └──► BOS-REPAIR-01 (efectividad C-01..C-14)
                          └──► BOS-REPAIR-13 (flujo end-to-end)
```

---

## Estado de las 18 fases

| Fase | Nombre | Estado |
|---|---|---|
| F0 | Fundación e infraestructura | 🟢 8/9 — F0.6.S 🔴 (prioritario con SSH) |
| F1 | Extraer cmd/bos/main.go | 🟢 9/9 |
| F2 | Unificar WebSocket | 🟢 4/4 |
| F3 | TUI: monolito partido + pantallas reales | 🟡 10/17 — renders 3.B 🔴 (F3.11-F3.17) |
| F4 | Limpiar bosctl + eliminar RBAC propio | 🟢 5/5 |
| F5 | Context Plane | 🟡 6/8 — efectividad real 5.B 🔴 (F5.7-F5.8) |
| F6 | JSON-RPC robusto + sagas | 🟡 11/12 — catálogo F6.12 🔴 |
| F7 | Documentación | 🟢 8/8 |
| F8 | Tests y cobertura | 🟢 7/7 |
| F9 | Operator Soberano (validado en vivo) | 🟢 11/11 |
| F10 | biaos | 🟡 10/11 — validación staging F10.10 🔴 (prioritario) |
| F11 | Ficha Engine completo (SBOS-019 + ADR-021) | 🔴 0/11 |
| F12 | Capa 3: PostgreSQL HA + Redis + Vault | 🔴 0/8 |
| F13 | Capa 4: Keycloak + Kong + Linkerd | 🔴 0/7 |
| F14 | Capa 5: daemons soberanos como stubs (ADR-007) | 🔴 0/6 |
| F15 | Capa 6: fichas de aplicación | 🔴 0/5 |
| F16 | Capa 7: VDI — LA CÚSPIDE ✦ | 🔴 0/14 |
| F17 | Estándares internacionales + certificación | 🔴 0/10 |

**Total: 89 ✅ / 73 🔴 = 162 átomos (55%)**
**Estados:** 🔴 NO INICIADA · 🟡 EN PROGRESO/PARCIAL · 🟢 COMPLETA · ⚠️ BLOQUEADA

---

## ADRs vigentes en este proyecto

| ADR | Título | Estado | Fase que lo implementa |
|---|---|---|---|
| ADR-001 | BOS como capa OS — bosctl reemplaza sudo | Aceptado | F1, F4 ✅ |
| ADR-002 | Roles, modos y privilegios del daemon bos | Aceptado → BOS-REPAIR-06 | F1, F5, F6 ✅ |
| ADR-003 | Estándares de documentación godoc | Aceptado → BOS-REPAIR-07 | F7 ✅ (continua) |
| ADR-004 | bos como Kubernetes Operator Soberano | Aceptado → BOS-REPAIR-02 | F9 ✅ |
| ADR-005 | bosctl como capa de abstracción soberana | Aceptado → BOS-REPAIR-03 | F4, F9 ✅ |
| ADR-006 | RBAC delegado a Ubuntu+K8s (elimina rbac_provider.go) | Aceptado → BOS-REPAIR-11 | F4 ✅ |
| ADR-007 | Daemons hermanos como stubs de contrato | Aceptado → BOS-REPAIR-16 | F14 🔴 (habilita F11.5, F16) |
| ADR-021 | Máquina de 18 estados de fichas | Existente — REEMPLAZA al modelo de 5 estados de SBOS-019 | F1 ✅ · consistencia total: F11.4 |

---

## Señal de retoma rápida

```bash
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src

echo "=== F0-F10 (reparación — debe estar todo ✅) ==="
echo -n "F1 main.go ≤350L: "; [ $(wc -l < cmd/bos/main.go) -le 350 ] && echo "✅" || echo "❌"
echo -n "F3 install_ui ≤80L:"; [ $(wc -l < cmd/bosctl/install_ui.go 2>/dev/null || echo 9999) -le 80 ] && echo "✅" || echo "❌"
echo -n "F4 rbac_provider:  "; [ ! -f internal/security/rbac_provider.go ] && echo "✅" || echo "❌"
echo -n "F5 context plane:  "; [ -f internal/context/service.go ] && echo "✅" || echo "❌"
echo -n "F9 operator:       "; [ -d internal/scaler ] && echo "✅" || echo "❌"
echo -n "F10 biaos:         "; [ -f internal/biaos/gateway.go ] && echo "✅" || echo "❌"

echo "=== Pendientes (F3.B → F17) ==="
echo -n "F3.B renders:   "; grep -q "stub" internal/tui/screens/screen_dashboard.go 2>/dev/null && echo "❌ stubs" || echo "✅"
echo -n "F11 resolver:   "; [ -f internal/fichaengine/resolver.go ] && echo "✅" || echo "❌"
echo -n "F14 bauth-stub: "; [ -d ../../BauthAgent/src ] && echo "✅" || echo "❌"
echo -n "F16 sbos-client:"; [ -d cmd/sbos-client ] && echo "✅" || echo "❌"
go build ./... && echo "✅ BUILD" || echo "🔴 BUILD ROTO"

# Próximo átomo y novedades:
grep "🟡" ../../context/.../plandeaccion/REGISTRO-ESTADO.md | head -3
tail -40 ../../context/.../plandeaccion/SESION-LOG.md
```

**Prioridad al recuperar SSH del staging:** F10.10 + F0.6.S en una sola
ventana multiplexada, bajo el protocolo sbos-staging-security-monitor
(incidente Contabo — ver GESTION-RIESGOS v2 §staging).

---

## Archivos que deben estar en el Knowledge de Claude

```
Documentos BOS-REPAIR (17 + este índice + cuestionario = 19):

  BOS-REPAIR-INDEX.md                         ← leer primero siempre
  BOS-REPAIR-00-AUDITORIA-TECNICA.md
  BOS-REPAIR-01-EFECTIVIDAD-VERIFICACION.md
  BOS-REPAIR-02-ADR004-OPERATOR-SOBERANO.md
  BOS-REPAIR-03-ADR005-ABSTRACCION-BOSCTL.md
  BOS-REPAIR-04-SAGAS-CONSULTA-RPC.md
  BOS-REPAIR-05-PLAN-ACCION-MAESTRO.md         (histórico v2.0 + nota)
  BOS-REPAIR-06-ADR002-ROLES-PRIVILEGIOS.md
  BOS-REPAIR-07-ADR003-ESTANDARES-DOCUMENTACION.md
  BOS-REPAIR-08-SBOS049-CONTEXT-PLANE.md
  BOS-REPAIR-09-SBOS052-VDI-SPEC.md
  BOS-REPAIR-10-BIAOS-AGENTE-OS.md
  BOS-REPAIR-11-ADR006-RBAC-HERENCIA-UBUNTU-K8S.md
  BOS-REPAIR-12-SAGAS-CONSULTA-FUNDAMENTOS.md
  BOS-REPAIR-13-FLUJO-END-TO-END.md
  BOS-REPAIR-14-SBOS-CLIENT-SPEC.md                  ← nuevo
  BOS-REPAIR-15-ESTANDARES-INTERNACIONALES.md        ← nuevo
  BOS-REPAIR-16-ADR007-DAEMONS-STUB.md               ← nuevo
  BOS-REPAIR-CUESTIONARIO-01.md                      ← nuevo (respondido)

Plan y operación:
  BOS-REPAIR-PLAN-MAESTRO-v3.md (v4.0 con PARTE V)
  REGISTRO-ESTADO.md · SESION-LOG.md
  PROTOCOLO-SESION-AGENTE.md · GESTION-RIESGOS-OPERATIVOS.md
  MAPA-NAVEGACION.md · BOS-REPAIR-EVALUACION-PLAN-MAESTRO.md
  EVALUACION-AGENTE-IA-BOS-REPAIR.md
  instrucciones-agente/EJECUCION-*.md · informes-cierre/*.md
  docs/runbooks/RB-01..03 + INDEX + INCIDENTES-LOG

Contratos canónicos para F11-F17 (daemons, permisos, VDI):
  SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md
  SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1_0.md     ← contrato socket bauth
  SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md           ← protocolo WS :9444
  SBOS-ROLTEMPLATE-v5_0.md · SBOS-USERTEMPLATE-v5_0.md
  SBOS-008-ROLFRAMEWORK-v1_0.md
  SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md  ← BitmaskBundle v3
  SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md
  SBOS-TEMPLATES-DECISIONES-v1_0.md
  MANUAL_DE_SISTEMA_DE_PRIVILEGIOS.txt
  SBOS-008-001-DOMAINS-BITMASK-REALM-v1_0.md

Del código fuente (para referencia al trabajar):
  cmd__*.md · internal__*.md · go_mod.md
  (+ el agente lee el código REAL y _snapshots/ en BosAgent/src/)

Del manual JSON-RPC:
  JSON-RPC-01-fundamentos.md .. JSON-RPC-09-orquestacion-multi-motor.md
  + JSON-RPC-RESUMEN-EJECUTIVO.md

De la especificación SBOS:
  SBOS-049-CONTEXT-PLANE.md · SBOS-052-VDI-SPEC.md
  SBOS-018-DAEMON-BOS.md · SBOS-019-FICHAS.md (estados → ADR-021)
  SBOS-MANUAL-ACOPLAMIENTO.md · 00_ARCHITECTURE_SBOS.yml
  biaos-arquitectura.md · action_catalog.yml · ENVIRONMENTS.md
```

---

_BOS-REPAIR-INDEX v3.0 · SKULL · SBOS · Junio 2026_
_Actualizar este índice cada vez que se agregue un documento BOS-REPAIR_
_Cambios v3.0: +BOS-REPAIR-14/15/16 +CUESTIONARIO-01 · estado real 89/162 ·_
_18 fases F0-F17 · ADR-007 · contratos canónicos F11-F17 · prioridad SSH_
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*