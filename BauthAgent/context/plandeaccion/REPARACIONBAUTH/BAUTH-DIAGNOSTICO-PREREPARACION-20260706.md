# BAUTH — Diagnóstico Pre-Reparación
**Versión:** 1.0 · **Fecha:** 2026-07-06 · **Autor:** bauth-developer
**Propósito:** Identificar qué falta y qué bloquea antes de iniciar la reparación bAuth v3.0.
Verificado contra disco y VPS 13.140.128.230.

---

## Resumen

| Categoría | Cantidad |
|-----------|:--------:|
| Decisiones HITL bloqueantes (DDL) | 2 |
| Inconsistencias entre documentos | 6 |
| Errores en la retoma del Bibliotecario | 3 |
| Tareas ejecutables YA (FASE 0.S) | 4 |
| Archivos .rs existentes en BauthAgent/src | 165 |
| Líneas DDL D00 ya escritas sin aplicar | 856 |

---

## 1. Decisiones HITL — Bloquean todo el DDL

### HITL #1 — Conflicto arquitectónico en D00 (elegir diseño)

Coexisten dos DDL incompatibles para el Dominio D00. `INFORME-DELTA-DDL-D00.md` (v2.0, 2026-07-06) documenta el conflicto: **Iván debe decidir cuál aplicar.**

| | Diseño A — Semántico | Diseño B — D.A.M.V. |
|---|---|---|
| **Átomos** | 20 (verbos-campo 51-63) | 120 (CRUD por campo) |
| **DDL** | `003_d00_identidad_organizacional.sql` (282 líneas) | `003_d00_identidad_organizacional_CRUD.sql` (574 líneas) |
| **Estado en MASTER §6.3** | Aprobación DDL pendiente | Aprobación de concepto primero |

**Impacto:** El diseño elegido determina qué seeds son correctos para el Grupo B de FASE 0.S.

### HITL #2 — Aprobación formal del DDL para aplicar en VPS

Una vez resuelto el conflicto A/B, se requiere aprobación explícita de Iván antes de aplicar cualquier migración. El DDL ya está escrito.

> **Estado real en VPS:** `privilege_domain` tiene CHECK constraint `domain_code BETWEEN 1 AND 15` — D0 bloqueado a nivel de BD. La migración debe modificar el constraint antes de insertar D00.

---

## 2. Inconsistencias entre documentos

### 2.1 BAUTH-COBERTURA-100PCT vs BAUTH-GAP-ANALISIS — planos distintos
La COBERTURA-100PCT (diseño atómico completo) y el GAP-ANALISIS (47 tablas nuevas en BD) no se contradicen: el **diseño** está completo, la **implementación en PostgreSQL** no. El PLAN-ACCION solo cubre 364 átomos, **no las 47 tablas**. Las 12 tablas de prioridad ALTA bloquean AAL2/AAL3.

### 2.2 SSOT del BitMask — referencia al doc histórico superado
El INDICE-NAVEGACION referencia `SBOS-BITMASK-ANALISIS-SAM128` marcado explícitamente como `⚠️ HISTÓRICO — SUPERADO` (usa Go). El SSOT correcto es `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md` (Rust, 1358 líneas) en `context/plandeaccion/` — **no referenciado en el INDICE**.

### 2.3 BOS-BAUTH-CONTRATOS.md — ruta incorrecta en CLAUDE.md
CLAUDE.md apunta a `/opt/skull/orquestador/proyectos/desarrollo/sbos/` (no existe).
Ruta real: `/opt/skull/orquestador/proyectos/SBOS/context/contracts/BOS-BAUTH-CONTRATOS.md`.

### 2.4 agente_enviar.sh — reportado como inexistente, sí existe
`BauthAgent/scripts/agente_enviar.sh` existe en disco. El error de inicialización era incorrecto.

### 2.5 REGISTRO-ESTADO-REDISEÑO — no refleja que el DDL D00 ya fue escrito
El REGISTRO muestra FASE 1 como "🔒 BLOQUEADA" con todas las tareas sin estado. Los dos DDL D00 ya existen en `db/migrations/` — el trabajo de escritura ya ocurrió.

### 2.6 INDICE-NAVEGACION — rutas de src/ incorrectas
Sección 7.1 del INDICE usa la ruta `desarrollo/sbos/BauthAgent/src/`. La ruta real es `SBOS/BauthAgent/src/`.

---

## 3. Errores en la retoma canónica del Bibliotecario

La `RETOMA-BAUTH-VERIFICADA-2026-07-06.md` contiene afirmaciones incorrectas:

| # | Afirmación en retoma | Realidad verificada en disco |
|---|---|---|
| 1 | "No hay código" | `BauthAgent/src/` tiene 165 archivos .rs |
| 2 | "agente_enviar.sh no existe" | Existe en `BauthAgent/scripts/` |
| 3 | "No hay migraciones SQL" | `db/migrations/` tiene 003_d00 (2 archivos, 856 líneas) + INFORME-DELTA |

---

## 4. Estado real del sistema

### Base de datos (VPS 13.140.128.230)

| Objeto | Estado | Detalle |
|--------|--------|---------|
| `privilege_domain` | ⚠ PARCIAL | D1-D12 ok. CHECK bloquea D0 |
| `privilege_atom` | ⚠ PARCIAL | 5808 átomos. 0 en D0 |
| `privilege_verb` | ✅ OK | 50 verbos (1-50) |
| `idn_tenant` | ⚠ PARCIAL | 1 registro, sin columna `is_internal` |
| `idn_user_template` | ✅ OK | 9 registros |

### Seeds

| Archivo | Estado | Problema |
|---------|--------|---------|
| `run_all_seeds.sql` | ⚠ BUG | Dice "49 seeds", hay 81 `\ir`. Falta `seed_compliance_results.sql` |
| `064_idn_user_template_data.sql` | ❌ ROTO | 14 claves camelCase, versión '3.0', columna inexistente `mask_eff_hex` |
| `seed_idn_role_template_data.sql` | ⚠ PARCIAL | 7 nombres de bloque JSONB incorrectos vs RolTemplate v6.0 |

---

## 5. Tareas ejecutables YA — FASE 0.S

> **Nota:** El Grupo B tiene partes que dependen de HITL #1. Ejecutar A, C, D primero.

| Grupo | Descripción | Dependencia |
|-------|-------------|-------------|
| **A** | Corregir `run_all_seeds.sql`: contadores (49→82) + agregar `seed_compliance_results.sql` | Ninguna |
| **C** | 7 renombres de bloques JSONB en `seed_idn_role_template_data.sql` | Ninguna |
| **D** | Verificar frameworks referenciados en seeds | Ninguna |
| **B*** | `064_idn_user_template_data.sql`: camelCase→snake_case, versión 3.0→6.0.0, `mask_eff_hex→rol_bitmask_base64` (partes independientes de D00) | Parcial: requiere HITL #1 para subconsultas de átomos |

---

## 6. Orden de ejecución recomendado

1. Ejecutar FASE 0.S Grupos A, C, D — **ahora, sin bloqueos**
2. Iván decide: ¿Diseño A o Diseño B para D00? **(HITL #1)**
3. Completar Grupo B con subconsultas de átomos
4. Iván aprueba el DDL elegido **(HITL #2)**
5. Aplicar migración DDL en VPS + verificar constraint D0
6. FASES 2-3: DDL D4-D12, D13
7. FASES 4-6: Seeds nuevos, Rust, verificación VPS

---

## 7. Gaps sin plan de acción

- **47 tablas nuevas** (GAP-ANALISIS) no tienen fase asignada. 12 son prioridad ALTA y bloquean AAL2/AAL3.
- **8 tablas** con columnas faltantes identificadas en GAP-ANALISIS sin tarea en REGISTRO-ESTADO.
- **~43 archivos** con referencias a Mattermost en BauthAgent (E0.11 pendiente).
- **INDICE-NAVEGACION** no referencia los 3 SSOTs vigentes fuera de REPARACIONBAUTH.

---

*Documento generado por bauth-developer · 2026-07-06*
*Todas las afirmaciones verificadas contra disco y VPS — C12 cumplido*
