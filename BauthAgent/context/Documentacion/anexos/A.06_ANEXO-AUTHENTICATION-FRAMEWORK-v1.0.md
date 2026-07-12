# Anexo A.06 — El Authentication Framework (artefacto de diseño)
## Documento de respaldo: los 36+1 grupos del framework declarativo de autenticación

**Tipo:** ANEXO — documento de respaldo del corpus
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Estatus:** FUENTE AUTOSUFICIENTE — el artefacto ÍNTEGRO acompaña a este anexo como recurso: [`A.06_recurso_Authentication_Framework.json5`](A.06_recurso_Authentication_Framework.json5) (copia fiel; JSON comentado de diseño, 12.945 líneas)
**Respalda a:** MANUAL-AUTENTICACION (2.01) · MANUAL-METODOS (2.02) · MANUAL-NORMAS (7.03 §4 — marco `fw_01`) · MANUAL-POLITICAS (2.05)
**Fuentes de origen (cita histórica):** `Authentication_Framework.json` (metadata interna v2.0.0)
**Normas declaradas por grupo:** ISO 27001 · NIST PQC (FIPS 203/204/205) · ISO 30107 · NIST 800-207 · FIDO2/WebAuthn · OAuth/OIDC · RFC 6962 · RGPD — cada grupo declara la suya

---

## 1. Propósito y cómo citarlo

Respaldo del **artefacto de diseño** que define la arquitectura completa de autenticación por
grupos funcionales. **Cómo citarlo:** `A.06 G12` (el grupo 12) · el detalle vive en el recurso
adjunto (líneas referenciadas abajo). **Frontera:** la doctrina de autenticación vigente y su
materialización nativa viven en 2.01 (motor, 9 métodos, framework declarativo de 7 tablas) —
este anexo respalda con el artefacto de diseño de origen y su mapa.

**Autosuficiencia de bAuth:** el framework se materializa en el motor NATIVO y las 7 tablas
declarativas (2.01 §3-§7). Cualquier mención de época a motores externos dentro del recurso se
lee bajo ADR-010: **Keycloak y Tryton ya no forman parte de la solución**.

**Naturaleza del artefacto:** JSON **comentado** (comentarios `/* */` y `//` — formato de
diseño, no JSON estricto parseable); por eso el recurso conserva la extensión `.json5`
declarativa de esa naturaleza. Es la fuente sembrada como marco `fw_01` en la biblioteca de
políticas (7.03 §4).

## 2. El mapa de los 36+1 grupos (con su línea en el recurso)

| Grupo | Tema | Línea |
|---|---|---|
| G-meta | Metadatos y configuración base (versión, clasificación, changeHistory) | 4 |
| G1 | Autenticación fundamental | 31 |
| G2 | Seguridad post-cuántica y criptografía avanzada | 132 |
| G3 | Autenticación biométrica avanzada | 275 |
| G4 | Análisis comportamental y autenticación adaptativa | 447 |
| G5 | Autenticación contextual y evaluación de riesgo | 548 |
| G5.1 | Control de acceso orientado a WebSockets | 671 |
| G6 | IA y detección avanzada de amenazas | 814 |
| G7 | Autenticación cuántica y resistencia post-cuántica | 926 |
| G8 | Autenticación federada e identidad distribuida | 1072 |
| G9 | Biometría anti-suplantación | 1204 |
| G10 | Aprendizaje automático y detección de anomalías | 1327 |
| G11 | Gestión de sesiones y tokens avanzada | 1472 |
| G12 | Seguridad contextual y Zero Trust | 1620 |
| G13 | Seguridad de redes y comunicaciones | 1743 |
| G14 | Auditoría y registro avanzado | 1889 |
| G15 | Respuesta a incidentes | 2061 |
| G16 | Protección de datos y privacidad | 2210 |
| G17 | Control de acceso y políticas de autorización | 2379 |
| G18 | Monitoreo de seguridad y detección de amenazas | 2531 |
| G19 | Resiliencia y recuperación | 2676 |
| G20 | Seguridad de contenedores y orquestación | 2826 |
| G21 | Orquestación de identidad y acceso federado | 3000 |
| G22 | Seguridad de APIs y microservicios | 3158 |
| G23 | Criptografía y gestión de claves | 3294 |
| G24 | Gestión de secretos y credenciales | 3425 |
| G25 | Infraestructura Zero Trust | 3565 |
| G26 | Datos y privacidad avanzada | 3691 |
| G27 | Blockchain y contratos inteligentes | 3811 |
| G28 | Seguridad de IA | 3958 |
| G29 | Control de acceso adaptativo y contextual | 4098 |
| G30 | Microservicios y comunicaciones | 4238 |
| G31 | IoT y dispositivos edge | 4356 |
| G32 | Computación cuántica | 4465 |
| G33 | Datos en reposo y movimiento | 4594 |
| G34 | Endpoints y dispositivos | 7411 |
| G35 | Redes y comunicaciones (II) | 9071 |
| G36 | Aplicaciones y APIs | 12086 |

## 3. Verificación de completitud

| Verificación | Resultado |
|---|---|
| Cobertura | 36+1 grupos — coherente con la cita del corpus "27+1 grupos" ampliada (el artefacto real contiene 36; la cifra 27+1 era de época) |
| **Divergencia de versión** | La metadata interna dice `2.0.0`; el corpus lo cita "v3.0.0" (7.03 §4 fw_01, CLAUDE) — **resolución: la versión operativa es la del marco sembrado `fw_01` en la biblioteca**; la metadata del artefacto quedó sin actualizar (hallazgo documentado) |
| Nomenclatura PQC | El artefacto usa nombres de época en algunos grupos ("quantum-resistant") — la nomenclatura vigente es FIPS 203/204/205 (ML-KEM/ML-DSA/SLH-DSA — 7.03 §5.3, misma resolución que A.02 U2) |
| Materialización | Los grupos se materializan en las 7 tablas declarativas + el pipeline nativo (2.01) — no en motores externos (ADR-010) |

## 3.bis Estado de materialización en código (verificado 2026-07-11)

| Verificación | Evidencia | Estado |
|---|---|---|
| **¿El framework se siembra?** | `DDLs/seeds/bauth_fw_01__authentication_framework.sql` **existe** | ✅ **SÍ sembrado** (marco `fw_01` de la biblioteca — 7.03 §4) |
| Materialización del comportamiento | Las 7 tablas declarativas (`auth_method`, `auth_policy`, `auth_config`… — 2.01 §7) gobiernan el runtime | ✅ el framework NO se ejecuta como JSON: se materializa en tablas |

**Corrección a mi verificación previa:** en la primera versión sugerí que el sembrado estaba por
confirmar; **verificado: `bauth_fw_01` existe** — el framework está sembrado como marco de la
biblioteca de políticas. La divergencia de versión (metadata 2.0.0 vs corpus 3.0.0) sigue siendo
el único hallazgo abierto (§3).

## 4. Referencias e historial

**Del proyecto:** el recurso adjunto (íntegro) · 2.01 · 2.02 · 7.03 §4 (`bauth_fw_01`) · 2.05.

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.1.0 | 2026-07-11 | **Añadida verificación de código real** (§3.bis: CORRECCIÓN — bauth_fw_01 SÍ existe (framework sembrado)). |
| 1.0.0 | 2026-07-11 | Anexo inicial: naturaleza del artefacto (JSON comentado de diseño), mapa completo de los 36+1 grupos con línea de acceso al recurso fiel adjunto, verificación de completitud (divergencia de versión resuelta a favor del marco sembrado fw_01; cifra 27+1 de época; nomenclatura PQC alineada a FIPS) y aclaración de autosuficiencia bAuth. |
