# SBOS-0XX — Bloques Canónicos de AtomLang: Ampliación con Ejemplos y Verificación Normativa

**Estado:** Propuesto — ampliación de la taxonomía de dominios/bloques ya definida
**Dominio:** bAuth · AtomLang (`.atm.yaml`) · Direcciones de átomo `dNN.bloque.verbo`
**Objetivo:** ampliar cada bloque canónico con ejemplos concretos de átomo, y verificar/reforzar el respaldo normativo con hallazgos de investigación adicional.

---

## 0. Nota metodológica

Este documento no reemplaza la taxonomía original (§2.3–2.5) — la extiende. Cada bloque conserva su norma de origen ya asignada y agrega:

1. **2–4 ejemplos concretos** de átomo en formato `dNN.bloque.verbo`, con una breve nota de qué controla.
2. **Verificación o refuerzo normativo**, cuando la investigación encontró una actualización relevante del estándar de origen (ej. NIST SP 800-63-4 ya está en versión final, no en draft) o un estándar complementario de industria que conviene citar.
3. **Bloques adicionales sugeridos**, donde la práctica de industria (no solo la norma) sugiere que falta un bloque canónico en ese dominio.

Se marca explícitamente cuándo una recomendación es de **norma verificada** vs. **patrón de industria** (buena práctica ampliamente adoptada, pero sin número de estándar formal detrás) — la distinción importa para tu objetivo de conformidad estricta.

Este documento incorpora además (§3) una revisión estructural posterior: no solo ejemplos y verificación de los 15 dominios ya definidos, sino una comparación completa contra las categorías de mercado que definen "IAM enterprise" (Gartner, PAM, NHI), que identificó dos dominios faltantes (D14, D15) y dos capacidades transversales sin bloque propio (IGA, ITDR).

---

## 1. Hallazgo importante que afecta a varios dominios: NIST SP 800-63-4 ya es definitivo

La investigación confirma que **NIST SP 800-63 Revisión 4 fue publicada en versión final en julio de 2025** (no sigue siendo un borrador). Esto es relevante para D00, D05 y D09, que citan SP 800-63B/800-63-4. Cambios sustantivos de la Rev. 4 que conviene reflejar en el diseño de átomos:

- El modelo de tres niveles (IAL, AAL, FAL) se mantiene, pero se vuelve más **modular y basado en riesgo** — la organización debe seleccionar el nivel de assurance por función (identidad, autenticación, federación) de forma independiente, no como un combo fijo.
- Se agrega explícitamente la **Federation Assurance Level (FAL)** como tercera dimensión, separada de IAL y AAL — gobierna la integridad de las aserciones federadas (SAML/OIDC) cuando bAuth actúa como IdP hacia terceros.
- Los **autenticadores resistentes a phishing (FIDO Passkeys, tanto device-bound como sincronizadas) pasan a ser la base recomendada** para AAL2 y AAL3 — ya no son solo el techo (AAL3), sino la recomendación general.
- Se introduce el concepto de **wallets controladas por el sujeto** (credenciales verificables, mDL) integradas al modelo de federación — relevante para tu roadmap de SSI/W3C DIDs ya mencionado en tu contexto.

**Implicancia para AtomLang:** si D00/D09 van a tener átomos de nivel de assurance, conviene modelar **tres familias de nivel**, no solo AAL:

```
d00.proofing.validate       — verificación de IAL (identidad real de la persona)
d09.mfa.validate            — verificación de AAL (fuerza del autenticador)
d13.certification.validate  — verificación de FAL (integridad de la federación, cuando bAuth es IdP hacia terceros)
```

---

## 2. Hallazgo importante: CAEP tiene tipos de evento formales que debes reusar, no inventar

La especificación **OpenID CAEP 1.0** (parte del Shared Signals Framework, publicada en versión final en 2025) ya define tipos de evento estandarizados que corresponden exactamente a conceptos que tu taxonomía necesita en D08 y D11. Verificados en la especificación:

| Evento CAEP oficial | Uso en tu arquitectura |
|---|---|
| **Assurance Level Change** | Exactamente el evento que se propuso en SBOS-0XX-G04 para step-up de LoA/AAL — no hace falta inventar un tipo de evento propio, `assurance-level-change` **es** el nombre normativo. |
| **Risk Level Change** | Corresponde directamente a tu bloque `d08.risk` — el Transmitter comunica cambios en el score de riesgo continuo del sujeto. |
| **Token Claims Change** | El que ya usás en el gap original (revocación de permisos → invalidar JWT). |
| **Device Compliance Change** | Corresponde a `d08.device` — cambios en postura de dispositivo (MDM, parches, cifrado) comunicados en tiempo real por el EDR/MDM como Transmitter. |
| **Session Revoked** | Corresponde a `d08.session` — terminación forzada de sesión. |

**Recomendación:** en la definición del bloque `d08.risk` y `d08.session`, referenciar explícitamente estos nombres de evento CAEP como el vocabulario canónico a emitir — así Kong/bAuth quedan interoperables con cualquier Receiver externo que hable CAEP estándar (EDR, CASB, otros IdPs), en vez de un vocabulario propietario de SBOS.

---

## 3. Gaps estructurales de dominio: PAM, NHI/Machine Identity, IGA e ITDR

Una revisión posterior, dirigida específicamente contra las categorías de mercado que definen "IAM enterprise" (Gartner Market Guide for IGA 2025-2026, reportes de consolidación de vendors PAM/NHI 2026), encontró que la taxonomía D00-D13/D98/D99 cubre bien **Access Management** (autenticación, autorización runtime, contexto) pero le faltan **tres categorías de mercado completas**. Dos ameritan dominio nuevo; dos son capacidades transversales que encajan en dominios ya existentes.

### 3.1 Nuevo dominio D14 — Privileged Access (PAM)

D01 (`authorization`) resuelve autorización runtime ordinaria; D10 (`delegation`) resuelve transferencia de permisos entre sujetos. Ninguno cubre el ciclo de vida específico de una cuenta o sesión privilegiada, que el mercado trata como disciplina separada con cuatro pilares consistentes en todos los vendors relevantes (CyberArk, BeyondTrust, Delinea, HashiCorp Vault, Saviynt): descubrimiento de cuentas privilegiadas, vaulting/rotación de credenciales, Just-in-Time + Zero Standing Privilege, y brokering/grabación de sesión.

Relevante para vos: el mercado 2026 migra activamente de "vault de contraseñas" a **Zero Standing Privilege** — ningún admin con privilegio permanente, todo otorgado bajo demanda y auto-expirable. Es coherente con tu propio hardening ya en marcha (usuario `agente-bos` restringido con sudoers acotado, tras el incidente de abuso de Contabo con acceso root permanente) — ya estás caminando hacia ZSP de forma orgánica, sin tenerlo modelado como dominio formal.

| Código | Nombre |
|---|---|
| `d14` | Privileged Access |

| Bloque | Descripción | Ejemplos de átomo | Norma de origen |
|---|---|---|---|
| `discovery` | Inventario de cuentas/credenciales privilegiadas | `d14.discovery.read`, `d14.discovery.audit` | NIST AC-2(6) |
| `vaulting` | Almacenamiento y rotación de credenciales privilegiadas | `d14.vaulting.read` (checkout de credencial), `d14.vaulting.configure` (política de rotación) | NIST AC-6 |
| `jit` | Acceso privilegiado efímero, Zero Standing Privilege | `d14.jit.approve`, `d14.jit.execute`, `d14.jit.validate` (¿sigue vigente la ventana?) | NIST AC-6, AC-2(6) |
| `brokering` | Mediación y grabación de sesión privilegiada | `d14.brokering.execute` (iniciar sesión mediada), `d14.brokering.audit` (revisar grabación) | Patrón de industria — sin estándar ISO/NIST dedicado; se recomienda citar NIST SP 800-53 AC-6/AC-2(6) como base normativa, dado que no existe un estándar único equivalente a los que ya usás en otros dominios. |

### 3.2 Nuevo dominio D15 — Non-Human Identity (NHI)

La proporción de identidades máquina vs. humanas en el mercado ya ronda 45:1, e IGA 2025 redefine explícitamente su alcance para incluir "personas, cuentas de servicio, y cada vez más rutas de acceso mediadas por IA". Esto es directamente relevante a tu propia arquitectura: **12 agentes Claude Code corriendo en paralelo** (Fábrica SBOS), acceso SSH vía usuario restringido, y daemons del sistema (`bkernel`, `biedata`, `bcompass`, etc.) que actúan como sujetos autónomos frente a bAuth. Ningún dominio actual distingue explícitamente a un agente de IA o un daemon como categoría de sujeto con ciclo de vida propio — hoy probablemente se modela como un `user_id` más en `privilege_atom_grant`, lo cual funciona a nivel de mecánica de grant pero pierde la semántica de gobernanza que un auditor va a exigir sobre "cómo controlás el acceso de tus agentes de IA" — señalada explícitamente como preocupación de la agenda Gartner 2026.

| Código | Nombre |
|---|---|
| `d15` | Non-Human Identity |

| Bloque | Descripción | Ejemplos de átomo | Norma de origen |
|---|---|---|---|
| `service_account` | Ciclo de vida de cuentas de servicio/daemon | `d15.service_account.create`, `d15.service_account.delete` | Patrón de industria |
| `workload` | Identidad de carga de trabajo (contenedor, pod, proceso) | `d15.workload.validate` (¿la identidad del workload es la esperada antes de conceder acceso?) | Patrón de industria (Zero Trust, NIST SP 800-207 §3 aplicado a workloads) |
| `agent` | Identidad y alcance de agentes de IA — tus 12 agentes Claude Code | `d15.agent.create`, `d15.agent.configure` (scope de permisos del agente), `d15.agent.audit` | Categoría emergente, sin estándar formal aún |
| `secrets` | Credenciales/API keys de máquina — distinto de D14, que es privilegio humano elevado | `d15.secrets.validate`, `d15.secrets.delete` (rotación forzada) | Patrón de industria |

**Nota de diseño:** conviene distinguir D14 (`vaulting`/`jit` para privilegio humano elevado) de D15 (`secrets` para credenciales de máquina) aunque ambos "vaulteen" credenciales — el modelo de riesgo es distinto: un humano puede reportar un compromiso; un agente automatizado no necesariamente detecta que fue comprometido, por lo que D15 exige controles más agresivos de rotación y detección de anomalías.

**Sin estándar ISO/NIST formal dedicado a NHI todavía** — es categoría de mercado emergente. Se recomienda documentarlo explícitamente como "patrón de industria, sin estándar formal aún" en vez de forzar una cita normativa que no corresponde.

### 3.3 Capacidad transversal — IGA como gobernanza (bloque nuevo en D01, no dominio nuevo)

D01 (`authorization`) responde *"¿puede hacer esto ahora?"* (runtime). IGA responde *"¿debería seguir teniendo este acceso?"* (revisión periódica). Gartner 2025 enfatiza que los programas de IGA fallan cuando el ciclo de certificación no captura el crecimiento real de "entitlement sprawl". Esto no amerita dominio propio — pertenece naturalmente a D01, junto a `authorization`, `roles`, `zones`, `fields`, `contracts`:

| Bloque nuevo en D01 | Descripción | Ejemplos de átomo |
|---|---|---|
| `certification` | Campañas de recertificación periódica de accesos otorgados | `d01.certification.approve` (recertificar un grant existente), `d01.certification.audit` (reporte de entitlement sprawl) |

Conecta directamente con tu modelo ya definido: cada fila de `privilege_atom_grant` con `status = 'ACTIVE'` es candidata a campaña de recertificación periódica — el bit no debería quedar ACTIVE indefinidamente sin revisión, si el objetivo es estatus IAM enterprise real.

### 3.4 Capacidad transversal — ITDR (ampliación de `d08.risk`, no dominio nuevo)

D11 (`monitoring`) ya cubre monitoreo en tiempo real genérico. ITDR es más específico: detección de amenazas basadas en señales de identidad (uso anómalo de credenciales, movimiento lateral vía identidad, señales de compromiso de cuenta) — no logging genérico, sino un modelo de detección con foco exclusivo en identidad. El mercado 2026 lo trata como categoría independiente. Dado que ya existe `d08.risk` (score de riesgo continuo, mapeado al evento CAEP `Risk Level Change`), ITDR encaja como extensión natural de ese bloque:

| Bloque existente ampliado | Descripción adicional | Ejemplos de átomo |
|---|---|---|
| `risk` (D08, ya existía) | Agregar detección activa de patrones de amenaza de identidad, no solo score pasivo | `d08.risk.audit` (investigación de incidente de identidad), `d08.risk.execute` (respuesta automatizada — forzar step-up o revocar sesión ante señal de compromiso) |

### 3.5 Taxonomía de dominios actualizada

| Código | Nombre | Estado |
|---|---|---|
| d00–d13 | (ya definidos) | Sin cambios |
| **d14** | **Privileged Access** | Nuevo |
| **d15** | **Non-Human Identity** | Nuevo |
| d98 | Registro Estructural | Sin cambios |
| d99 | Baseline Administrativo Global | Sin cambios |

### 3.6 Honestidad sobre el alcance de esta revisión

Esta investigación cubrió las categorías de mercado más visibles (Gartner, principales reportes de PAM/NHI 2025-2026). No es exhaustiva — el espacio de IAM enterprise sigue moviéndose rápido, y la gobernanza de agentes de IA es un área activa de cambio, citada explícitamente como prioridad de la agenda Gartner 2026. Se recomienda repetir este tipo de revisión de mercado periódicamente, dado que tu propio roadmap (Context Plane, agentes de IA como sujetos) está exactamente en la intersección de lo que más está evolucionando ahora mismo.

---

## 4. Ampliación por dominio

### D00 — Identity

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `identity` | `d00.identity.read`, `d00.identity.write`, `d00.identity.validate` | Lectura/edición de atributos del sujeto; `validate` para verificación de unicidad/formato. |
| `proofing` | `d00.proofing.validate` (IAL2/IAL3), `d00.proofing.approve` (aprobación manual de evidencia dudosa) | Alineado a SP 800-63A. Con Rev. 4, considerar `d00.proofing.configure` para seleccionar el IAL requerido por servicio (modelo modular). |
| `organization` | `d00.organization.create` (alta de tenant), `d00.organization.configure` (jerarquía), `d00.organization.delegate` (delegación de admin de tenant) | — |

**Bloque adicional sugerido (patrón de industria, no norma formal):** `consent` — gestión de consentimiento del sujeto sobre uso de sus atributos, cada vez más exigido por marcos de privacidad (GDPR, y el borrador AGETIC de Bolivia que ya identificaste como no promulgado). Ejemplo: `d00.consent.write`, `d00.consent.read`, `d00.consent.delete` (derecho al olvido).

### D01 — Logical Access

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `authorization` | `d01.authorization.approve`, `d01.authorization.execute` | El átomo raíz de PDP; casi todo grant termina resolviéndose acá. |
| `roles` | `d01.roles.create`, `d01.roles.delegate` (asignar rol a otro admin) | ANSI INCITS 359 ya cubre esto (RBAC estándar). |
| `zones` | `d01.zones.access`, `d01.zones.configure` | — |
| `fields` | `d01.fields.read` (con obligación de masking), `d01.fields.export` | Relevante para PII — combina con obligation de LoA. |
| `contracts` | `d01.contracts.configure` (definir modo READ_ONLY/APPEND_ONLY) | — |
| `certification` | `d01.certification.approve`, `d01.certification.audit` | Añadido en §3.3 — capacidad IGA (recertificación periódica), distinta de `authorization` (runtime). |

### D02 — Physical Access

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `facilities` | `d02.facilities.access`, `d02.facilities.configure` | — |
| `readers` | `d02.readers.configure`, `d02.readers.audit` | OSDP v2.2.2 confirmado como estándar activo de industria para lectores IP. |
| `presence` | `d02.presence.validate` (verificación dual/mantrap) | NIST SP 800-116 sigue siendo la referencia para control de acceso físico basado en PIV. |

**Bloque adicional sugerido:** `visitors` — gestión de acceso temporal a terceros no empleados, un caso de uso recurrente en control de acceso físico que suele requerir su propio ciclo de vida (`d02.visitors.create`, `d02.visitors.delete` con expiración automática).

### D03 — Financial

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `limits` | `d03.limits.configure`, `d03.limits.approve` (excepción de límite) | — |
| `approvals` | `d03.approvals.approve` (con obligation de quórum k-de-N), `d03.approvals.delegate` | Este es tu caso de estudio de G-04 (aprobar venta con LoA). |
| `segregation` | `d03.segregation.validate` (chequeo de conflicto SoD antes de asignar rol) | COSO Control Activities + NIST AC-5. |
| `billing` | `d03.billing.emit` (emisión de factura electrónica), `d03.billing.validate` | Específico Bolivia SIN — ya identificado en tu contexto de depo.bo. |

### D04 — Temporal

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `windows` | `d04.windows.configure`, `d04.windows.validate` (¿el request cae dentro de la ventana?) | GTRBAC es el marco académico de referencia (Generalized Temporal RBAC, Bertino et al.) — sigue siendo la cita correcta, no hay reemplazo formal más reciente. |
| `periods` | `d04.periods.configure` (duración de asignación), `d04.periods.validate` (¿expiró?) | — |
| `calendar` | `d04.calendar.configure` (días festivos por país/tenant) | RFC 5545 (iCalendar) confirmado vigente. |

### D05 — Biometric

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `enrollment` | `d05.enrollment.create`, `d05.enrollment.delete` | — |
| `verification` | `d05.verification.validate` (match contra template) | — |
| `liveness` | `d05.liveness.validate` (PAD — Presentation Attack Detection) | ISO/IEC 30107 sigue siendo la familia normativa correcta (30107-1 marco, 30107-3 métricas de testing PAD). |

### D06 — Geospatial

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `geofencing` | `d06.geofencing.configure`, `d06.geofencing.validate` | — |
| `location` | `d06.location.validate` | — |
| `velocity` | `d06.velocity.validate` ("viaje imposible") | Patrón UEBA de industria — no tiene número de norma formal, es correcto documentarlo como "patrón de industria" y no atribuirle una norma que no existe. |

**Bloque adicional sugerido (patrón de industria):** `residency` — soberanía de datos por jurisdicción (dónde puede procesarse/almacenarse un dato según su origen geográfico), directamente relevante para tu filosofía sovereignty-first de SBOS. Ejemplo: `d06.residency.validate` (¿el procesamiento respeta la jurisdicción de origen del dato?).

### D07 — Network

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `connection` | `d07.connection.validate` (mTLS presente), `d07.connection.configure` | NIST SP 800-207 (Zero Trust Architecture) confirmado como marco vigente de referencia. |
| `tokens` | `d07.tokens.validate` (DPoP/PKCE proof-of-possession) | RFC 9449 (DPoP) es relativamente reciente (2023) — confirmado como RFC activo, buena elección. |
| `rate` | `d07.rate.configure`, `d07.rate.validate` | — |

**Bloque adicional sugerido (patrón de industria, alineado a Zero Trust NIST 800-207):** `posture` — postura de red del dispositivo/servicio en el momento de la conexión (segmento de red, VPN vs. directo, reputación de IP). Distinto de `d08.device` (que es postura del dispositivo en sí, no de la conexión de red). Ejemplo: `d07.posture.validate`.

### D08 — Context / Session

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `session` | `d08.session.validate`, `d08.session.delete` (revocación forzada) | Mapea al evento CAEP `Session Revoked`. |
| `risk` | `d08.risk.validate`, `d08.risk.audit`, `d08.risk.execute` | Mapea al evento CAEP `Risk Level Change` (verificado en §2). Ampliado en §3.4 con capacidad ITDR — `audit` para investigación de incidente, `execute` para respuesta automatizada (forzar step-up/revocar sesión). |
| `device` | `d08.device.validate` | Mapea al evento CAEP `Device Compliance Change`. |
| `emergency` | `d08.emergency.approve` (break-glass con aprobación dual) | NIST AC-17(3) confirmado vigente para acceso de emergencia. |

**Bloque adicional sugerido (norma verificada — falta explícitamente):** `assurance` — nivel de garantía de la sesión activa (`current_loa`), como bloque propio separado de `session`, dado que ya se estableció en G-04 que el LoA vive en el Context Plane, no en el JWT. Ejemplo: `d08.assurance.validate` (¿la sesión cumple el LoA requerido?), mapeado al evento CAEP `Assurance Level Change` verificado en §2.

### D09 — Credentials

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `password` | `d09.password.configure`, `d09.password.validate` | — |
| `mfa` | `d09.mfa.validate`, `d09.mfa.configure` | Con SP 800-63-4 confirmado: dar prioridad a FIDO Passkeys como base, no solo como techo AAL3. |
| `certificates` | `d09.certificates.validate`, `d09.certificates.delete` (revocación) | RFC 5280 confirmado vigente. |
| `tokens` | `d09.tokens.emit`, `d09.tokens.delete` | RFC 9068 (JWT Access Token profile) es relativamente reciente — confirmado como estándar correcto para tokens de acceso OAuth 2.0. |
| `revocation` | `d09.revocation.execute` | — |

### D10 — Delegation

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `delegation` | `d10.delegation.create`, `d10.delegation.delete` | INCITS 359 (RBAC ANSI) confirmado como la norma correcta para DSD (Dynamic Separation of Duty). |
| `renewal` | `d10.renewal.approve`, `d10.renewal.validate` | — |
| `restrictions` | `d10.restrictions.validate` (chequeo SoD antes de aprobar delegación) | — |

### D11 — Audit

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `events` | `d11.events.create`, `d11.events.read` | — |
| `retention` | `d11.retention.configure`, `d11.retention.delete` (purga controlada tras vencimiento) | PCI DSS 4.0 Req 10.5.1 mantiene el mínimo de 12 meses en línea + retención extendida — verificar la cifra exacta de "7 años" citada contra la versión 4.0 vigente antes de fijarla como norma dura, porque PCI DSS especifica un mínimo distinto (12 meses accesible + hasta 3 años según el caso); el "7 años" suele venir de requisitos fiscales/SOX, no de PCI DSS en sí. |
| `integrity` | `d11.integrity.validate` (verificación de hash-chain) | — |
| `monitoring` | `d11.monitoring.configure`, `d11.monitoring.audit` | — |

**Nota de corrección:** conviene separar en la documentación de origen qué exige PCI DSS Req 10 (retención de logs de transacciones con tarjeta) de qué exige SOX §802 (retención de papeles de trabajo de auditoría financiera, 7 años) — son dos relojes de retención distintos con propósitos distintos, y mezclarlos bajo un solo bloque `retention` puede requerir que el átomo module el período según el tipo de evento auditado, no un valor fijo único.

### D12 — Blockchain

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `anchoring` | `d12.anchoring.emit`, `d12.anchoring.validate` | NIST IR 8202 sigue siendo la referencia de blockchain técnico de NIST, aunque es un informe (IR), no un estándar normativo obligatorio — vale aclarar esa distinción de peso normativo en el documento fuente. |
| `transactions` | `d12.transactions.execute`, `d12.transactions.validate` | — |
| `wallet` | `d12.wallet.configure`, `d12.wallet.delete` | W3C DID Core es un estándar de recomendación W3C (no ISO/NIST) — vale la misma aclaración de nivel normativo. |

### D13 — Digital Signature

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `signing` | `d13.signing.emit`, `d13.signing.execute` | — |
| `certification` | `d13.certification.validate`, `d13.certification.create` | Recordar el cambio ya documentado en tu contexto: ADSIB fue disuelta el 14 de enero de 2026 (DS 5519), competencias transferidas a AGETIC — la norma de origen citada como `ADSIB-FD-POLT-015` debería revisarse para confirmar si AGETIC republicó la política bajo nueva numeración. |
| `timestamping` | `d13.timestamping.emit`, `d13.timestamping.validate` | RFC 3161 confirmado vigente y ampliamente usado (TSA — Time Stamp Authority). |

### D14 — Privileged Access

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `discovery` | `d14.discovery.read`, `d14.discovery.audit` | Ver detalle completo en §3.1. |
| `vaulting` | `d14.vaulting.read`, `d14.vaulting.configure` | — |
| `jit` | `d14.jit.approve`, `d14.jit.execute`, `d14.jit.validate` | Zero Standing Privilege — coherente con el hardening ya aplicado a `agente-bos`. |
| `brokering` | `d14.brokering.execute`, `d14.brokering.audit` | — |

### D15 — Non-Human Identity

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `service_account` | `d15.service_account.create`, `d15.service_account.delete` | Ver detalle completo en §3.2. |
| `workload` | `d15.workload.validate` | — |
| `agent` | `d15.agent.create`, `d15.agent.configure`, `d15.agent.audit` | Directamente aplicable a los 12 agentes de la Fábrica SBOS. |
| `secrets` | `d15.secrets.validate`, `d15.secrets.delete` | Distinto de `d14.vaulting` — ver nota de diseño en §3.2. |

### D99 — Global Baseline

| Bloque | Ejemplos de átomo | Nota |
|---|---|---|
| `users` | `d99.users.create`, `d99.users.delete` | — |
| `notifications` | `d99.notifications.configure`, `d99.notifications.emit` | Mapea directo a tu bNotify. |
| `exceptions` | `d99.exceptions.approve` (override HITL) | NIST CA-6 (Authorization) es la cita correcta para autorización de excepciones. |

---

## 5. Verbo adicional a evaluar

Los 15 verbos canónicos cubren bien CRUD + control, pero hay un caso de uso recurrente en Zero Trust / CAEP que no calza limpio en ninguno de los 15: **la re-evaluación forzada de una decisión ya tomada** (ej. Kong necesita re-verificar una sesión activa cuando llega un evento CAEP `Risk Level Change`, sin que el usuario haya iniciado una acción nueva).

`validate` cubre parcialmente esto, pero semánticamente `validate` sugiere "verificar antes de conceder", mientras que este caso es "re-verificar algo ya concedido, en reacción a una señal externa". Si tu PDP necesita distinguir estos dos casos en auditoría (verificación inicial vs. reevaluación reactiva), vale la pena considerar si conviene un decimosexto verbo, por ejemplo `reassess`, o si `validate` se usa para ambos casos y la diferencia se captura en otro campo (ej. `trigger_source: initial | caep_event`).

---

## 6. Fuentes consultadas (adicionales a las ya citadas en documentos previos)

- NIST SP 800-63-4, *Digital Identity Guidelines* — versión final, publicada julio 2025 (pages.nist.gov/800-63-4)
- OpenID Foundation, *Continuous Access Evaluation Profile (CAEP) 1.0* — especificación final (openid.net/specs/openid-caep-1_0-final.html)
- OpenID Foundation, *Shared Signals Framework (SSF) 1.0* — especificación final
- Resúmenes de industria sobre SP 800-63-4 (ID Dataweb, HYPR, Ping Identity) — usados solo para contexto de adopción, no como fuente normativa primaria
- Gartner, *Market Guide for Identity Governance and Administration* 2025-2026 (resúmenes de terceros: Omada, Pathlock, NHIMG) — contexto de categorización de mercado IGA
- Gartner, *2026 Predicts: Identity and Access Management* — tendencias ITDR, machine identity
- *IAM Vendor Consolidation Trends in 2026* (Start with Identity) — consolidación PAM/IGA/CIAM, proporción NHI:humano
- Reportes de industria sobre PAM 2026 (IDSA, Saviynt, Palo Alto Networks, Avatier, Waldo Security) — los cuatro pilares de PAM (discovery, vaulting, JIT/ZSP, brokering)

## 7. Pendiente

- Confirmar el estado real de `ADSIB-FD-POLT-015` tras la disolución de ADSIB (DS 5519) — verificar si AGETIC la republicó con nueva numeración antes de seguir citándola sin verificar en documentos de conformidad.
- Verificar la cifra exacta de retención de PCI DSS 4.0 Req 10.5.1 en el texto oficial (no en resúmenes de terceros) antes de fijarla como constraint dura en `d11.retention`.
- Decidir si se agrega el verbo `reassess` (§5) o si la reevaluación reactiva se modela con `validate` + metadato de origen del trigger.
- Evaluar la incorporación de los bloques adicionales sugeridos (`consent` en D00, `visitors` en D02, `residency` en D06, `posture` en D07, `assurance` en D08) al documento canónico original.
- Definir si D14 y D15 requieren tabla de grant separada de `privilege_atom_grant`, o si conviven en la misma tabla con `user_id` extendido — requiere decisión sobre si hace falta una columna `subject_type` (humano / máquina / servicio / agente).
- Diseñar el mecanismo de campaña de `d01.certification` (quién dispara la recertificación, cadencia, qué pasa si nadie certifica a tiempo — ¿expira el grant automáticamente?).
- Evaluar si ITDR (`d08.risk.audit`/`execute`) amerita un daemon dedicado, similar al `bauth-reactor` ya pendiente en el documento de consistencia de grants.
