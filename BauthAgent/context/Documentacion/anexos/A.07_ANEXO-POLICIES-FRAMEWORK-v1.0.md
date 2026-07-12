# Anexo A.07 — El Policies Authentication Framework (artefacto de diseño)
## Documento de respaldo: los 14 grupos del framework de políticas de autenticación

**Tipo:** ANEXO — documento de respaldo del corpus
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Estatus:** FUENTE AUTOSUFICIENTE — el artefacto ÍNTEGRO acompaña como recurso: [`A.07_recurso_Policies_Authentication_Framework.json5`](A.07_recurso_Policies_Authentication_Framework.json5) (copia fiel; JSON comentado, 2.545 líneas)
**Respalda a:** MANUAL-POLITICAS (2.05) · MANUAL-AUTENTICACION (2.01 §8 — políticas por tier) · MANUAL-NORMAS (7.03 §4 — marco `fw_02`) · MANUAL-RIESGO (3.01)
**Fuentes de origen (cita histórica):** `Policies_Authentication_Framework.json` (metadata interna v3.0.0)

---

## 1. Propósito y cómo citarlo

Respaldo del artefacto que define las **políticas** de autenticación por grupos (el QUÉ se
exige por contexto — complementa al A.06, que define la arquitectura). **Cómo citarlo:**
`A.07 G6` · detalle en el recurso adjunto. **Frontera:** la doctrina de políticas vigente
(biblioteca `cfg_policy_library`, 9.874 nodos con `standard_ref`, PDP XACML) vive en 2.05.

**Autosuficiencia de bAuth:** las políticas se evalúan en el PolicyEngine NATIVO; menciones de
época en el recurso se leen bajo ADR-010 (**Keycloak y Tryton eliminados de la solución**).

## 2. El mapa de los 14 grupos (línea en el recurso)

| Grupo | Tema | Línea |
|---|---|---|
| G1 | Autenticación moderna (WebAuthn/FIDO2, passwordless) | 12 |
| G2 | Seguridad y privacidad | 85 |
| G3 | Identidad y acceso | 177 |
| G4 | Autenticación física-lógica integrada | 230 |
| G5 | Políticas de edge computing | 512 |
| G6 | Autenticación quantum-resistant | 552 |
| G7 | Gestión de identidad avanzada | 682 |
| G8 | Monitoreo avanzado con ML | 964 |
| G9 | Auditoría blockchain y trazabilidad | 1045 |
| G10 | Autoajuste y aprendizaje adaptativo | 1212 |
| G11 | Protecciones de próxima generación | 1359 |
| G12 | Integraciones y APIs | 1591 |
| G13 | Gestión de emergencias | 1811 |
| G14 | Cumplimiento y regulación | 2145 |

## 3. Verificación de completitud

| Verificación | Resultado |
|---|---|
| Cobertura de los 14 grupos | ✅ — mapa completo con acceso por línea |
| **Divergencia de versión** | Metadata interna `3.0.0`; el corpus lo cita "v4.0.0" (fw_02) — **resolución: rige el marco sembrado `fw_02`**; hallazgo documentado (mismo patrón que A.06) |
| Física-lógica integrada (G4) | Coherente con D1+D2 del modelo de dominios (1.01) |
| Emergencias (G13) | Coherente con break-glass/EMERGENCY del catálogo (A.03 §3) y `validity EMERGENCY` 72h (A.01 §B2) |
| Cumplimiento (G14) | Se materializa como dato en `compliance_map`/`standard_ref` (7.03 §2) |

## 3.bis Estado de materialización en código (verificado 2026-07-11)

| Verificación | Evidencia | Estado |
|---|---|---|
| **¿El framework se siembra?** | `DDLs/seeds/bauth_fw_02__policies_framework.sql` **existe** | ✅ **SÍ sembrado** (marco `fw_02`) |
| Biblioteca de políticas | `cfg_policy_library` (9.874 nodos con `standard_ref` — 2.05) alimentada desde los 16 marcos | ✅ el motor PolicyEngine evalúa desde tablas, no desde el JSON |

**Verificado: `bauth_fw_02` existe** — el framework de políticas está sembrado. La divergencia de
versión (metadata 3.0.0 vs corpus 4.0.0) es el hallazgo abierto (§3).

## 4. Referencias e historial

**Del proyecto:** el recurso adjunto · 2.05 · 2.01 §8 · 7.03 §4 (`bauth_fw_02`) · 3.01.

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.1.0 | 2026-07-11 | **Añadida verificación de código real** (§3.bis: bauth_fw_02 SÍ existe (framework sembrado)). |
| 1.0.0 | 2026-07-11 | Anexo inicial: mapa completo de los 14 grupos con acceso por línea al recurso fiel, verificación de completitud (divergencia de versión resuelta a favor del marco sembrado fw_02) y aclaración de autosuficiencia. |
