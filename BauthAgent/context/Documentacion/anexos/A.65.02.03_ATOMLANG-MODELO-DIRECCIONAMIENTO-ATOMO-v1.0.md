# A.65.02.03 — AtomLang: Modelo de Direccionamiento de Átomos v1.0

**Versión:** 1.0 · **Fecha:** 2026-07-21 · **Estado:** ACTIVO  
**Dominio:** AtomLang · compilador `atomc` · árbol RolTemplate · T-162  
**Relación:** A.65.02.02 (extensión User Subject) · A.65.02.01 (decisiones DDL) · A.68 (catálogo propiedades)

---

## Propósito

Define el sistema canónico de **direccionamiento jerárquico de átomos** en el árbol
RolTemplate. Toda sección del árbol — dominio, bloque, setpolitica, politica, regla,
átomo — recibe un **nombre de una sola palabra** que la identifica. La concatenación de
esos nombres con `.` como separador produce una **dirección única y legible** para cada
átomo, incluyendo el verbo que controla.

Este modelo es la fuente de verdad para:
- La columna `clave` de T-162 (`idn_roles_template`) — el RuleId XACML de cada nodo
- El compilador AtomLang (`atomc`) — genera la dirección al serializar el árbol
- Los logs y la auditoría — toda decisión cita la dirección del átomo que la tomó
- La navegación del árbol — un desarrollador puede ubicar cualquier átomo por su dirección

---

## 1. Formato de dirección

```
{dominio}.{bloque}.{setpolitica?}.{politica?}.{regla?}.{atomo}.{verbo}
```

| Segmento | Obligatorio | Tipo XACML equivalente | Descripción |
|----------|:-----------:|----------------------|-------------|
| `dominio` | **sí** | PolicySet raíz | Plano de control D00–D13, D99 |
| `bloque` | **sí** | PolicySet hijo | Especialidad del dominio — agrupa políticas relacionadas |
| `setpolitica` | no | PolicySet nieto | Agrupa políticas dentro del bloque cuando hay muchas |
| `politica` | no | Policy | Una política específica |
| `regla` | no | Rule contenedor | Agrupa átomos relacionados dentro de la política |
| `atomo` | **sí** | Rule (hoja evaluable) | El nodo de evaluación — siempre el penúltimo segmento |
| `verbo` | **sí** | Target.Action | La acción que controla el átomo — siempre el último segmento |

**Longitud mínima:** 4 segmentos (`dominio.bloque.atomo.verbo`)  
**Longitud máxima:** 7 segmentos (todos los niveles presentes)

---

## 2. Reglas de nomenclatura

### 2.1 Separadores

| Carácter | Rol | Ejemplo |
|----------|-----|---------|
| `.` | Separa niveles de jerarquía | `d01.autenticacion.sesion` |
| `_` | Une palabras dentro de un mismo segmento (forma una palabra compuesta) | `sesion_activa`, `duracion_maxima_absoluta` |

La distinción es estricta: el `.` es siempre un salto de nivel. El `_` nunca salta
de nivel — solo compone el nombre de uno. La dirección se parsea splitting por `.`;
nunca hay ambigüedad entre separador y conector.

### 2.2 Charset de cada segmento

```
[a-z][a-z0-9_]*
```

- Todo en minúsculas
- Sin tildes (`autenticacion`, no `autenticación`)
- Sin guiones (`sesion_activa`, no `sesion-activa`)
- Sin espacios
- El `_` puede aparecer dentro pero nunca al inicio ni al final del segmento

### 2.3 El segmento `dominio`

Siempre usa el código del plano de control con cero delante para un dígito:

| Código | Nombre del plano |
|--------|-----------------|
| `d00` | Identidad Organizacional |
| `d01` | Acceso Lógico |
| `d02` | Acceso Físico |
| `d03` | Financiero |
| `d04` | Temporal |
| `d05` | Biométrico |
| `d06` | Geoespacial |
| `d07` | Red |
| `d08` | Contexto / Sesión |
| `d09` | Credenciales |
| `d10` | Delegación |
| `d11` | Auditoría |
| `d12` | Blockchain / Anclaje |
| `d13` | Firma Digital Externa |
| `d14` | Acceso Privilegiado (PAM) |
| `d15` | Identidad No-Humana (NHI) |
| `d99` | Baseline Administrativo Global |

### 2.4 El segmento `bloque` — bloques canónicos por dominio

Los nombres de bloque son **identificadores técnicos en inglés** — siguen el charset
`[a-z][a-z0-9_]*` del §2.2. Se derivan de la terminología canónica de los estándares
internacionales que rigen cada dominio.

**Leyenda de fuente:**
- **[N]** Norma verificada — ISO, NIST, RFC, OASIS u organismo equivalente con número de documento publicado.
- **[I]** Patrón de industria — ampliamente adoptado, sin número de estándar formal detrás.

> Los bloques [I] son tan utilizables en el árbol como los [N]. La distinción importa solo
> en reportes de conformidad normativa estricta (auditoría ISO 27001, XACML Conformance).

---

#### D00 — Identity (ISO 24760-2:2025 · NIST SP 800-63-4)

> ⚠️ **NIST SP 800-63-4 es versión final desde julio 2025** — ya no es borrador. Cambios clave:
> el modelo IAL/AAL/FAL pasa a ser modular por función (no combo fijo); se agrega FAL (Federation
> Assurance Level) como tercera dimensión; Passkeys FIDO pasan a ser la base recomendada para
> AAL2/AAL3, no solo el techo de AAL3.

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `identity` | `d00.identity.read`, `d00.identity.write`, `d00.identity.validate` | Atributos del sujeto — quién es la entidad | [N] ISO 24760-2:2025 §5 |
| `proofing` | `d00.proofing.validate`, `d00.proofing.approve` | Verificación de identidad IAL1–IAL3; `approve` para evidencia ambigua que requiere revisión manual | [N] NIST SP 800-63-4 §4 |
| `organization` | `d00.organization.create`, `d00.organization.configure`, `d00.organization.delegate` | Estructura organizacional — tenant, actor, jerarquía; `delegate` = delegación de admin de tenant | [N] ISO 24760-2:2025 §6 |
| `consent` | `d00.consent.write`, `d00.consent.read`, `d00.consent.delete` | Consentimiento del sujeto sobre uso de sus atributos; `delete` = derecho al olvido | [I] GDPR Art. 7/17 · marcos de privacidad |

---

#### D01 — Logical Access (ISO 27001:2022 A.5.15–18 · NIST SP 800-53 AC · ANSI INCITS 359)

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `authorization` | `d01.authorization.approve`, `d01.authorization.execute` | Enforcement de acceso runtime — qué puede hacer el sujeto ahora | [N] NIST AC-3 · ISO A.5.15 |
| `roles` | `d01.roles.create`, `d01.roles.delegate` | Agrupaciones RBAC — jerarquía y herencia de roles | [N] ANSI INCITS 359 · NIST AC-6 |
| `zones` | `d01.zones.access`, `d01.zones.configure` | Segmentación de zonas — lógica, financiera, sensible | [N] ISO A.5.15 · NIST AC-4 |
| `fields` | `d01.fields.read`, `d01.fields.export` | Acceso a nivel campo — enmascaramiento y visibilidad; `export` con obligation de PII | [N] ISO A.8.11 · NIST AC-3(7) |
| `contracts` | `d01.contracts.configure` | Contratos de acceso — modos (READ_ONLY, APPEND_ONLY) | [N] ISO A.5.18 |
| `certification` | `d01.certification.approve`, `d01.certification.audit` | Recertificación periódica IGA — ¿debería seguir teniendo este acceso? Distinto de `authorization` (runtime) | [N] NIST AC-2(2) · Gartner IGA 2025 |

---

#### D02 — Physical Access (IEC 60839-11-5 · ISO 27001:2022 A.7 · OSDP v2.2.2)

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `facilities` | `d02.facilities.access`, `d02.facilities.configure` | Perímetros físicos — salas, almacenes, zonas | [N] ISO A.7.1 · IEC 60839-11-5 |
| `readers` | `d02.readers.configure`, `d02.readers.audit` | Control de lectores OSDP — torniquetes, puertas | [N] OSDP v2.2.2 |
| `presence` | `d02.presence.validate` | Control de presencia física — dual, mantrap | [N] NIST SP 800-116 §4 |
| `visitors` | `d02.visitors.create`, `d02.visitors.delete` | Acceso temporal de terceros no empleados — ciclo de vida con expiración automática | [I] Patrón de industria PAC |

---

#### D03 — Financial (PCI DSS 4.0 · SOX §404 · COSO · RND 102100000011 SIN Bolivia)

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `limits` | `d03.limits.configure`, `d03.limits.approve` | Límites y umbrales financieros — monto, frecuencia; `approve` para excepción de límite | [N] PCI DSS Req 7 · COSO §3 |
| `approvals` | `d03.approvals.approve`, `d03.approvals.delegate` | Flujos de aprobación — quórum k-de-N, SLA (caso de estudio G-04: venta + LoA) | [N] SOX §404 · COSO Control Activities |
| `segregation` | `d03.segregation.validate` | Separación de funciones (SoD) — chequeo de conflicto antes de asignar rol | [N] COSO §3 · NIST AC-5 |
| `billing` | `d03.billing.emit`, `d03.billing.validate` | Facturación electrónica Bolivia SIN/NIT | [N] RND 102100000011 SIN Bolivia |

---

#### D04 — Temporal (GTRBAC · RFC 5545 · ISO 8601)

> `GTRBAC` = Generalized Temporal RBAC (Bertino et al.) — marco académico de referencia
> vigente para restricciones temporales en RBAC; sin reemplazo formal ISO/NIST más reciente.

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `windows` | `d04.windows.configure`, `d04.windows.validate` | Ventanas horarias — rangos de acceso autorizado; `validate` = ¿el request cae dentro? | [N] GTRBAC §4 · RFC 5545 DTSTART/DTEND |
| `periods` | `d04.periods.configure`, `d04.periods.validate` | Períodos de validez de asignaciones; `validate` = ¿expiró? | [N] GTRBAC §5 · ISO 8601 duration |
| `calendar` | `d04.calendar.configure` | Restricciones por calendario — días festivos por país/tenant | [N] RFC 5545 VEVENT |

---

#### D05 — Biometric (ISO/IEC 30107 · NIST SP 800-63-4 §5.2.3)

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `enrollment` | `d05.enrollment.create`, `d05.enrollment.delete` | Registro biométrico — captura, calidad, almacenamiento | [N] ISO/IEC 19794 · NIST SP 800-63-4 §5.2.3 |
| `verification` | `d05.verification.validate` | Verificación — FMR, umbral de confianza, match contra template | [N] ISO/IEC 30107-1 §6 |
| `liveness` | `d05.liveness.validate` | Detección de ataques de presentación (PAD) | [N] ISO/IEC 30107-3 §7 |

---

#### D06 — Geospatial (OGC GeoFence · NIST SP 800-207 · UEBA)

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `geofencing` | `d06.geofencing.configure`, `d06.geofencing.validate` | Reglas de geovalla — zonas permitidas/prohibidas | [N] OGC GeoFence Standard |
| `location` | `d06.location.validate` | Verificación de ubicación — país, ciudad, coordenada | [I] BeyondCorp §3 |
| `velocity` | `d06.velocity.validate` | Viaje imposible — velocidad máxima entre ubicaciones consecutivas | [I] Patrón industria bancaria (UEBA) |
| `residency` | `d06.residency.validate` | Soberanía de datos por jurisdicción — ¿el procesamiento respeta la jurisdicción de origen del dato? | [I] Filosofía sovereignty-first SBOS · GDPR Art. 44 |

---

#### D07 — Network (NIST SP 800-207 · IEEE 802.1X · RFC 9449)

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `connection` | `d07.connection.validate`, `d07.connection.configure` | Requisitos de conexión — mTLS, VPN, token binding | [N] NIST SP 800-207 §4 · IEEE 802.1X |
| `tokens` | `d07.tokens.validate` | Vinculación de tokens — DPoP/PKCE proof-of-possession | [N] RFC 9449 DPoP (2023) · RFC 7636 PKCE |
| `rate` | `d07.rate.configure`, `d07.rate.validate` | Limitación de tasa — API throttling, lockout | [N] OWASP ASVS §4.2 |
| `posture` | `d07.posture.validate` | Postura de red en el momento de la conexión — segmento, VPN vs. directo, reputación de IP. Distinto de `d08.device` (postura del dispositivo en sí) | [I] NIST SP 800-207 §3 aplicado a red |

---

#### D08 — Context / Session (SBOS-049 · W3C Trace Context · CAEP 1.0)

> **Vocabulario normativo CAEP 1.0 (especificación final 2025) — reusar estos nombres de evento,
> no inventar vocabulario propietario SBOS, para interoperabilidad con EDR/CASB/IdPs externos:**
>
> | Bloque | Evento CAEP canónico |
> |--------|---------------------|
> | `session` | `Session Revoked` |
> | `risk` | `Risk Level Change` |
> | `device` | `Device Compliance Change` |
> | `assurance` | `Assurance Level Change` |
> | `tokens` (D09) | `Token Claims Change` |

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `session` | `d08.session.validate`, `d08.session.delete` | Gestión de sesión — idle, duración, concurrencia; `delete` = revocación forzada → CAEP `Session Revoked` | [N] CAEP 1.0 · SBOS-049 |
| `risk` | `d08.risk.validate`, `d08.risk.audit`, `d08.risk.execute` | Score de riesgo continuo; `audit` = investigación de incidente ITDR; `execute` = respuesta automática (step-up/revocar sesión) → CAEP `Risk Level Change` | [N] NIST SP 800-207 §3.4 · CAEP 1.0 |
| `device` | `d08.device.validate` | Postura de dispositivo — MDM, parches, cifrado → CAEP `Device Compliance Change` | [N] NIST SP 800-124 · CAEP 1.0 |
| `emergency` | `d08.emergency.approve` | Sesiones break-glass — aprobación dual, tiempo acotado | [N] NIST AC-17(3) · ISO A.5.17 |
| `assurance` | `d08.assurance.validate` | Nivel de garantía de la sesión activa (current_loa); distinto de `session` — governa el LoA del Context Plane → CAEP `Assurance Level Change` | [N] CAEP 1.0 · NIST SP 800-63-4 §6 (FAL) |

---

#### D09 — Credentials (NIST SP 800-63-4 · FIDO2 · WebAuthn W3C · RFC 5280)

> ⚠️ **ADSIB fue disuelta por DS 5519 (14-ene-2026).** Competencias transferidas a AGETIC.
> La norma `ADSIB-FD-POLT-015 v2.3` debe reverificarse — confirmar si AGETIC la republicó
> bajo nueva numeración. Mientras no se confirme, citar como
> **"ADSIB-FD-POLT-015 / AGETIC (pendiente verificación)"**.

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `password` | `d09.password.configure`, `d09.password.validate` | Política de contraseñas — longitud, historial, screening | [N] NIST SP 800-63-4 §5.1.1 |
| `mfa` | `d09.mfa.validate`, `d09.mfa.configure` | Autenticación multifactor — TOTP, WebAuthn, hardware; con SP 800-63-4 final, Passkeys FIDO son la base recomendada para AAL2/AAL3 | [N] NIST SP 800-63-4 §5.1 · FIDO2 |
| `certificates` | `d09.certificates.validate`, `d09.certificates.delete` | Certificados x.509/mTLS — emisor, expiración, revocación | [N] RFC 5280 · AGETIC ex-ADSIB (⚠️ ver arriba) |
| `tokens` | `d09.tokens.emit`, `d09.tokens.delete` | Ciclo de vida de tokens — JWT, OAuth, refresh → CAEP `Token Claims Change` | [N] RFC 6749 · RFC 9068 JWT Access Token |
| `revocation` | `d09.revocation.execute` | Revocación de credenciales — propagación < 30s, grace period | [N] NIST SP 800-63-4 §8 · RFC 5280 CRL |

---

#### D10 — Delegation (ANSI INCITS 359 DSD · NIST AC-5/6)

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `delegation` | `d10.delegation.create`, `d10.delegation.delete` | Delegación de permisos — scope, período, reducción AND | [N] ANSI INCITS 359 §3.4 DSD |
| `renewal` | `d10.renewal.approve`, `d10.renewal.validate` | Renovación de asignaciones — contador, re-aprobación; `validate` = ¿expiró? | [N] NIST AC-2(2) |
| `restrictions` | `d10.restrictions.validate` | Restricciones SoD sobre delegaciones — chequeo de conflicto antes de aprobar | [N] NIST AC-5 · ANSI INCITS 359 SSD |

---

#### D11 — Audit (ISO 27001:2022 A.8.15 · PCI DSS 4.0 Req 10 · SOX §802 · NIST AU)

> **Dos relojes de retención distintos — no mezclar bajo un valor único:**
> - **PCI DSS Req 10.5.1**: mínimo 12 meses accesibles en línea para logs de transacciones con tarjeta.
> - **SOX §802**: 7 años para papeles de trabajo de auditoría financiera.
>
> El átomo `d11.retention.configure` necesita modular el período según el tipo de evento;
> un valor único "7 años" sería incorrecto para eventos PCI que solo exigen 12 meses.

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `events` | `d11.events.create`, `d11.events.read` | Eventos auditables — qué registrar, con qué dimensiones, categoría ABAC | [N] NIST AU-2 · ISO A.8.15 |
| `retention` | `d11.retention.configure`, `d11.retention.delete` | Períodos de retención WORM por tipo de evento (PCI DSS: 12m; SOX: 7a); `delete` = purga controlada tras vencimiento | [N] PCI DSS Req 10.5.1 · SOX §802 |
| `integrity` | `d11.integrity.validate` | Integridad del log — verificación de hash-chain, anti-tampering | [N] NIST AU-9 · PCI DSS 10.3.2 |
| `monitoring` | `d11.monitoring.configure`, `d11.monitoring.audit` | Monitoreo en tiempo real — SIEM, alertas, Wazuh | [N] ISO A.8.16 · NIST AU-6 |

---

#### D12 — Blockchain (NIST IR 8202 · EIP-712 · W3C DID)

> **Nota de peso normativo:**
> - NIST IR 8202 es un **informe técnico** (Informational Report), no un estándar normativo
>   obligatorio como SP o FIPS — peso informativo en auditoría, no prescriptivo.
> - W3C DID Core es una **recomendación W3C**, no un estándar ISO/NIST — mismo criterio.
> Por eso estos bloques se marcan [I], aunque tengan documentos de referencia formales.

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `anchoring` | `d12.anchoring.emit`, `d12.anchoring.validate` | Anclaje Merkle de auditoría — Keccak-256, RFC 6962 | [I] NIST IR 8202 §4 (informe, no norma) |
| `transactions` | `d12.transactions.execute`, `d12.transactions.validate` | Límites y validación de transacciones on-chain | [I] EIP-712 · Besu QBFT |
| `wallet` | `d12.wallet.configure`, `d12.wallet.delete` | Gestión de wallet — compromiso, claves, acceso | [I] W3C DID Core (recomendación W3C) · EIP-725 |

---

#### D13 — Digital Signature (Ley 164 Bolivia · AGETIC ex-ADSIB · RFC 3161)

> ⚠️ **ADSIB fue disuelta por DS 5519 (14-ene-2026).** La norma `ADSIB-FD-POLT-015 v2.3`
> debe reverificarse con AGETIC antes de citarla en documentos de conformidad.
> **Citar provisionalmente como: "ADSIB-FD-POLT-015 / AGETIC (pendiente verificación)".**

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `signing` | `d13.signing.emit`, `d13.signing.execute` | Firma digital — motor interno Ed25519 (Vault) y externo RSA-SHA256 (AGETIC ex-ADSIB) | [N] Ley 164 Art. 8 · ADSIB-FD-POLT-015 / AGETIC (⚠️) |
| `certification` | `d13.certification.validate`, `d13.certification.create` | Gestión de certificados — emisión, renovación, cadena de confianza | [N] ADSIB-FD-POLT-015 / AGETIC (⚠️) · RFC 5280 |
| `timestamping` | `d13.timestamping.emit`, `d13.timestamping.validate` | Sellado de tiempo TSA — RFC 3161, validez jurídica | [N] RFC 3161 · Ley 164 Art. 10 |

---

#### D14 — Privileged Access / PAM (NIST AC-6 · AC-2(6))

> **Dominio nuevo.** Cubre el ciclo de vida de acceso privilegiado (PAM): distinto de D01
> (autorización runtime ordinaria) y D10 (delegación entre sujetos). El mercado 2026 consolida
> hacia **Zero Standing Privilege** — ningún admin con privilegio permanente, todo bajo demanda
> y auto-expirable. Coherente con el hardening ya aplicado a `agente-bos` en SBOS.
> Cuatro pilares consistentes en los vendors PAM relevantes: discovery, vaulting, JIT/ZSP, brokering.

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `discovery` | `d14.discovery.read`, `d14.discovery.audit` | Inventario de cuentas y credenciales privilegiadas existentes | [N] NIST AC-2(6) |
| `vaulting` | `d14.vaulting.read`, `d14.vaulting.configure` | Almacenamiento y rotación de credenciales privilegiadas; `read` = checkout de credencial | [N] NIST AC-6 |
| `jit` | `d14.jit.approve`, `d14.jit.execute`, `d14.jit.validate` | Acceso privilegiado efímero (JIT/ZSP) — ventana temporal; `validate` = ¿sigue vigente la ventana? | [N] NIST AC-6 · AC-2(6) |
| `brokering` | `d14.brokering.execute`, `d14.brokering.audit` | Mediación y grabación de sesión privilegiada | [I] Patrón PAM (CyberArk, BeyondTrust, Delinea) — base normativa NIST AC-6 |

---

#### D15 — Non-Human Identity / NHI (NIST SP 800-207 §3 · Zero Trust)

> **Dominio nuevo.** Cubre identidades máquina: daemons SBOS (`bkernel`, `biedata`, etc.),
> los 12 agentes Claude Code de la Fábrica, contenedores y API keys. La proporción
> NHI:humano en el mercado 2026 ronda 45:1. IGA 2025 redefine su alcance para incluir
> agentes de IA como sujetos con ciclo de vida propio.
> **Sin estándar ISO/NIST formal dedicado aún** — categoría emergente, todos los bloques [I].
>
> Distinguir D14 (`vaulting`/`jit` para privilegio humano elevado) de D15 (`secrets` para
> credenciales de máquina): un humano puede reportar un compromiso; un agente automatizado
> no necesariamente lo detecta — D15 exige controles más agresivos de rotación y detección.

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `service_account` | `d15.service_account.create`, `d15.service_account.delete` | Ciclo de vida de cuentas de servicio/daemon | [I] Patrón de industria |
| `workload` | `d15.workload.validate` | Identidad de carga de trabajo — ¿la identidad del workload es la esperada antes de conceder acceso? | [I] NIST SP 800-207 §3 aplicado a workloads |
| `agent` | `d15.agent.create`, `d15.agent.configure`, `d15.agent.audit` | Identidad y scope de agentes de IA — directamente aplicable a los 12 agentes Claude Code de la Fábrica SBOS | [I] Categoría emergente — sin estándar formal aún |
| `secrets` | `d15.secrets.validate`, `d15.secrets.delete` | API keys y credenciales de máquina; `delete` = rotación forzada ante anomalía. Distinto de `d14.vaulting` (privilegio humano elevado) | [I] Patrón de industria |

---

#### D99 — Global Baseline (NIST SP 800-53 PS · ISO 27001:2022 A.6)

| Bloque | Ejemplos de átomo | Descripción | Fuente |
|--------|------------------|-------------|--------|
| `users` | `d99.users.create`, `d99.users.delete` | Ciclo de vida de usuarios — alta, modificación, baja | [N] NIST PS-4/5 · ISO A.6.5 |
| `notifications` | `d99.notifications.configure`, `d99.notifications.emit` | Notificaciones del sistema — alertas, canales, bNotify | [N] ISO A.6.8 · NIST IR-6 |
| `exceptions` | `d99.exceptions.approve` | Excepciones administrativas — overrides aprobados por HITL | [N] NIST CA-6 · ISO A.5.20 |

---

### 2.5 El segmento `verbo`

Siempre el **último segmento** de la dirección. Usa el vocabulario canónico de 16 verbos:

| # | Verbo | Acción que controla |
|---|-------|-------------------|
| 1 | `access` | Acceso a recurso o zona |
| 2 | `read` | Lectura / consulta |
| 3 | `write` | Escritura / modificación |
| 4 | `create` | Creación de registros |
| 5 | `delete` | Eliminación |
| 6 | `approve` | Aprobación de operaciones |
| 7 | `configure` | Configuración del sistema |
| 8 | `execute` | Ejecución de operaciones |
| 9 | `audit` | Auditoría / revisión |
| 10 | `delegate` | Delegación de permisos |
| 11 | `export` | Exportación de datos |
| 12 | `emit` | Emisión (firma, documento, token) |
| 13 | `login` | Inicio de sesión |
| 14 | `validate` | Validación inicial — disparada por una acción del usuario |
| 15 | `reassess` | Reevaluación reactiva — disparada por señal externa (CAEP, risk engine, scheduler) |
| 16 | `ANY` | Wildcard — aplica a cualquier verbo |

El verbo nunca lleva `_` — todos son palabras simples.

---

#### 2.5.1 `validate` vs. `reassess` — similitudes, diferencias y operaciones concretas

##### Lo que tienen en común

Ambos verbos activan el **mismo motor PDP** de bAuth. Internamente, la evaluación sigue
los mismos pasos en ambos casos:

1. Resolver la identidad del sujeto (desde JWT / ctx_id)
2. Localizar los átomos cuya `clave` corresponde a la operación
3. Verificar el bitmask — ¿el sujeto tiene ese átomo en sus grants?
4. Evaluar condiciones ABAC (Subject · Object · Action · Environment)
5. Aplicar PolicyChain y chequeo SoD
6. Retornar Effect: `Permit` | `Deny` | `StepUp (challenge)`
7. Adjuntar ObligationExpressions si las hay
8. Registrar el evento en el log de auditoría ISO 27001

| Característica compartida | `validate` | `reassess` |
|--------------------------|-----------|-----------|
| Motor de evaluación | PDP bAuth | PDP bAuth (el mismo) |
| Resultados posibles | Permit / Deny / StepUp | Permit / Deny / StepUp |
| Condiciones ABAC evaluadas | Subject, Object, Action, Env | Subject, Object, Action, Env |
| ObligationExpressions | Sí | Sí |
| Registro de auditoría | Sí | Sí |
| Reglas PolicyChain + SoD | Aplican | Aplican |
| Átomos en `idn_roles_template` | Nodos `tipo = 'evaluacion'` | Nodos `tipo = 'evaluacion'` |

> **Conclusión de similitud:** si solo miras el interior del PDP, los dos verbos son
> indistinguibles — el motor no sabe si llegó por un request del usuario o por un evento CAEP.
> La diferencia está completamente afuera del PDP: en quién lo llama, cuándo, y qué
> hace con el resultado.

---

##### Lo que los diferencia

| Dimensión | `validate` | `reassess` |
|-----------|-----------|-----------|
| **Disparador** | Acción nueva del usuario | Señal externa (CAEP, risk engine, scheduler, admin) |
| **Quién llama al PDP** | Kong PEP (intercepta el request HTTP) | bAuth mismo (CAEP receiver / reactor interno) |
| **Estado de la sesión antes** | Puede o no existir sesión previa | Siempre hay una sesión activa ya concedida |
| **Qué se evalúa** | ¿Puede el sujeto hacer esta operación nueva? | ¿Sigue siendo válida la operación ya concedida? |
| **Latencia esperada** | Síncrona, < 5ms (Kong espera la respuesta) | Puede ser asíncrona, en cola, en lote |
| **Consecuencia de Deny** | Kong rechaza el request (HTTP 403) | bAuth modifica / revoca / eleva la sesión activa |
| **Input de contexto** | Resource + Action del request HTTP | Evento de cambio (delta de postura, nuevo score) |
| **Átomo seleccionado** | `…verbo = validate` → bit N del bitmask | `…verbo = reassess` → bit M del bitmask (distinto) |
| **Grants independientes** | Un rol puede tener validate sin reassess | Un rol puede tener reassess sin validate |

---

##### Flujo concreto — `validate`

```
[Operación: contador aprueba una venta de alto valor]

1. Contador → POST /api/ventas/V-2024-891/aprobar
              (JWT en header, ctx_id en X-Context-ID)

2. Kong PEP → intercepta
              extrae subject_id del JWT
              extrae resource = "ventas.V-2024-891", action = "aprobar"

3. Kong PEP → bAuth JSON-RPC:
              bauth.authorize({
                subject_id: "usr_contador_42",
                atom:       "d03.approvals.approve",   ← verbo = approve (no validate)
                ctx_id:     "ctx_8fa3...",
                context: {
                  resource_id: "ventas.V-2024-891",
                  amount:      95000,
                  currency:    "BOB"
                }
              })

4. bAuth PDP evalúa d03.approvals.approve:
   - bitmask: ¿bit de d03.approvals.approve está activo para usr_contador_42? → SÍ
   - ABAC conditions:
       current_loa >= AAL2         → OK (sesión AAL2)
       amount <= limite_aprobacion → FALLA (límite del cargo: 50.000 BOB)
   - Resultado: Deny
   - Obligation: { notify: "supervisor_43", reason: "monto_excede_limite" }

5. Kong PEP → HTTP 403
              { error: "insufficient_limit", obligation_executed: "notify_supervisor" }
```

---

##### Flujo concreto — `reassess`

```
[Evento: laptop del contador pierde compliance a las 10:23]

1. MDM corporativo → CAEP Transmitter → bAuth CAEP Receiver:
   {
     event_type: "DeviceComplianceChange",
     subject:    { user: "usr_contador_42", device: "laptop_7" },
     delta: {
       patch_status:  "NONCOMPLIANT",    ← antes era COMPLIANT
       last_patch:    "2026-01-15",
       policy_violated: "WIN-SEC-004"
     },
     timestamp: "2026-07-21T10:23:41Z"
   }

2. bAuth CAEP Receiver → busca sesiones activas de usr_contador_42
   → encuentra ctx_id "ctx_8fa3..." (sesión AAL2 desde las 09:00)

3. bAuth Reactor → llama al PDP internamente:
   bauth.reassess({
     subject_id: "usr_contador_42",
     atom:       "d08.device.reassess",   ← verbo = reassess
     ctx_id:     "ctx_8fa3...",
     trigger: {
       source:     "caep_event",
       event_type: "DeviceComplianceChange",
       delta:      { patch_status: "NONCOMPLIANT" }
     }
   })

4. bAuth PDP evalúa d08.device.reassess:
   - bitmask: ¿bit de d08.device.reassess está activo para el reactor? → SÍ
   - ABAC conditions:
       device.patch_status == "COMPLIANT" → FALLA (nuevo estado: NONCOMPLIANT)
       session.loa >= AAL2               → OK
   - Resultado: StepUp
   - Obligation: { required_loa: "AAL3", grace_period: "300s" }

5. bAuth → push al cliente activo (WebSocket / CAEP outbound):
   {
     event_type: "AssuranceLevelChange",
     required_action: "step_up_to_aal3",
     grace_period:    300,
     reason:          "device_compliance_lost"
   }

   Si el usuario no eleva a AAL3 en 300s:
   bAuth → Session Revoked → ctx_id "ctx_8fa3..." invalidado
           → bAuth emite CAEP "Session Revoked" hacia todos los Receivers
```

---

##### El punto clave de los grants independientes

El verbo forma parte de la `clave` del átomo → selecciona un **bit diferente en el bitmask**.
`d08.device.validate` y `d08.device.reassess` son dos átomos distintos, con dos bits distintos,
con dos filas distintas en `privilege_atom_grant`. Se pueden asignar de forma completamente
independiente:

```
Rol: SECURITY_ANALYST
  ✅ d08.device.validate    → puede verificar compliance al acceder a recursos protegidos
  ✅ d08.device.reassess    → puede además interrumpir sesiones activas para re-verificarlas
  ✅ d08.risk.reassess      → puede disparar re-evaluación por cambio de score

Rol: CONTADOR
  ✅ d08.device.validate    → sus propios accesos verifican compliance del dispositivo
  ❌ d08.device.reassess    → NO puede interrumpir sesiones de otros usuarios
  ❌ d08.risk.reassess      → NO puede disparar re-evaluaciones del risk engine
```

Un CONTADOR puede validar sus propios accesos pero no interrumpir sesiones ajenas.
Un SECURITY_ANALYST tiene ambos permisos — puede operar el plano de control de identidad
en tiempo real. Son responsabilidades distintas modeladas como átomos distintos.

---

##### Tabla resumen de operaciones por verbo

| Operación real | Verbo | Átomo | Quién llama |
|----------------|-------|-------|------------|
| Usuario intenta acceder a zona financiera | `validate` | `d01.zones.validate` | Kong PEP |
| Usuario intenta aprobar venta > límite | `approve` | `d03.approvals.approve` | Kong PEP |
| Usuario intenta iniciar sesión con TOTP | `validate` | `d09.mfa.validate` | bAuth login flow |
| MDM reporta dispositivo no conforme | `reassess` | `d08.device.reassess` | bAuth CAEP Receiver |
| Risk engine detecta anomalía (score 0.3→0.85) | `reassess` | `d08.risk.reassess` | bAuth Risk Engine |
| Scheduler re-verifica sesiones AAL3 (cada 30 min) | `reassess` | `d08.session.reassess` | bAuth Scheduler |
| Admin fuerza re-evaluación de sesión sospechosa | `reassess` | `d08.session.reassess` | Admin via JSON-RPC |
| Certificado x.509 revocado → tokens afectados | `reassess` | `d09.revocation.reassess` | bAuth PKI Monitor |
| Ventana JIT de admin expiró a mitad de tarea | `reassess` | `d14.jit.reassess` | bAuth JIT Watcher |

---

##### Dominios donde `reassess` es más crítico para la reparación del árbol

| Átomo | Qué controla | Impacto en árbol actual |
|-------|-------------|------------------------|
| `d08.session.reassess` | Quién puede forzar re-evaluación de sesión activa | Ausente — sin él, el árbol no puede modelar control de sesión en tiempo real |
| `d08.risk.reassess` | Quién puede disparar re-evaluación por cambio de score | Ausente — CAEP Risk Level Change no tiene átomo receptor |
| `d08.device.reassess` | Quién puede disparar re-evaluación por postura de dispositivo | Ausente — CAEP Device Compliance Change sin cobertura |
| `d08.assurance.reassess` | Quién puede modificar el LoA de una sesión en curso | Ausente — step-up reactivo no modelado |
| `d09.revocation.reassess` | Quién puede disparar re-evaluación de tokens ante revocación | Ausente — revocación de credencial no propaga a sesiones activas |
| `d14.jit.reassess` | Quién puede re-verificar si una ventana JIT/ZSP sigue vigente | Ausente — ventanas JIT no se verifican en curso |

---

## 3. Niveles opcionales — cuándo existen

### 3.1 `setpolitica` — opcional

Existe cuando un bloque contiene suficientes políticas como para necesitar una
agrupación intermedia. Si el bloque tiene pocas políticas que son directamente
legibles, se omite.

```
// Sin setpolitica — bloque tiene pocas politicas:
d09.password.longitud_minima.configure

// Con setpolitica — bloque tiene muchas politicas agrupadas:
d09.credenciales.password.longitud_minima.configure
     ^bloque     ^setpol  ^atomo
```

### 3.2 `politica` — opcional

Existe cuando hay una agrupación semántica de reglas/átomos bajo un nombre común.
Si el átomo es suficientemente específico por sí solo dentro del bloque (o setpolitica),
la politica se omite.

### 3.3 `regla` — opcional

Existe cuando dentro de una política hay sub-agrupaciones de átomos relacionados.
Es el nivel más fino antes del átomo. Se omite cuando la política contiene átomos
directamente sin sub-agrupación.

### 3.4 Regla de profundidad mínima

Antes de agregar un nivel intermedio, verificar que aporta claridad:
- ¿Hay al menos 3 elementos a ese nivel que justifiquen la agrupación? → agregar
- ¿Solo hay 1 o 2? → omitir el nivel, subir los elementos al nivel padre

---

## 4. Ejemplos por profundidad

```
// 4 segmentos — mínimo (bloque + átomo + verbo directos):
d09.password.longitud_minima.configure

// 5 segmentos — con setpolitica:
d01.autorizacion.zonas.sensibilidad_critica.access

// 5 segmentos — con politica (sin setpolitica):
d08.sesion.activa.duracion_maxima_absoluta.access

// 6 segmentos — con setpolitica + politica:
d01.autenticacion.sesiones.activa.duracion_maxima_absoluta.access

// 7 segmentos — completo:
d01.autenticacion.sesiones.activa.tiempo.duracion_maxima_absoluta.access
```

Todos los ejemplos anteriores son direcciones válidas para distintos átomos.
La profundidad depende del árbol, no de una regla fija.

---

## 5. Relación con T-162 y el compilador `atomc`

### 5.1 Columna `clave` en T-162

La dirección completa del átomo **es** el valor de la columna `clave` en T-162
para los nodos `tipo = 'evaluacion'`:

```sql
-- Ejemplo de fila en T-162 para un átomo:
INSERT INTO bauth.idn_roles_template (clave, tipo, help, verb_id, ...)
VALUES (
    'd01.autenticacion.sesiones.activa.duracion_maxima_absoluta',  -- RuleId XACML
    'evaluacion',
    'Duración máxima absoluta de sesión activa — sin importar actividad',  -- Description XACML
    (SELECT id FROM bauth.idn_verb WHERE nombre = 'access'),
    ...
);
```

El verbo va en la columna `verb_id` (FK), no en la cadena `clave` del nodo evaluacion.
La dirección con verbo (`...absoluta.access`) se forma dinámicamente al construir
el path completo para logs y auditoría.

### 5.2 Columna `clave` para niveles intermedios

Los nodos que no son `evaluacion` (dominio, bloque, setpolitica, politica, regla)
también usan la dirección parcial acumulada hasta su nivel:

| Nodo | `tipo` | `clave` en T-162 |
|------|--------|-----------------|
| Dominio | `dominio` | `d01` |
| Bloque | `bloque` | `d01.autenticacion` |
| SetPolitica | `setpolitica` | `d01.autenticacion.sesiones` |
| Politica | `politica` | `d01.autenticacion.sesiones.activa` |
| Regla | `regla` | `d01.autenticacion.sesiones.activa.tiempo` |
| Átomo | `evaluacion` | `d01.autenticacion.sesiones.activa.tiempo.duracion_maxima_absoluta` |

Esto garantiza que cualquier nodo del árbol es localizable por su `clave` sin ambigüedad,
y que la jerarquía padre-hijo es reconstruible por simple análisis del prefijo.

### 5.3 Responsabilidad del compilador `atomc`

El compilador Rust `atomc` es quien genera las `clave` al serializar el árbol Dart fuente:

1. Recorre el árbol en profundidad acumulando el path
2. Al llegar a un nodo, escribe en `clave` el path acumulado hasta ese nivel
3. Para nodos `evaluacion`: extrae el `verbo` del hijo correspondiente y lo asigna
   a `verb_id` (no lo incluye en `clave`)
4. El texto del primer argumento de `_ev()` pasa a la columna `help` (Description XACML)

El árbol Dart fuente **no necesita cambios** para adoptar este modelo — la transformación
ocurre enteramente en `atomc`.

---

## 6. Bloques canónicos por dominio

Los bloques canónicos están formalizados en **§2.4** de este documento. Cada dominio
(D00–D13, D99) tiene entre 3 y 5 bloques en inglés derivados de los estándares
internacionales que rigen ese dominio.

El compilador `atomc` valida que todo nodo `bloque` del árbol Dart fuente use uno de
los nombres registrados en §2.4. Un bloque fuera de catálogo genera error de compilación
`E_BLOCK_UNKNOWN` con sugerencia del bloque canónico más cercano (distancia Levenshtein).

---

## 7. Relación con A.68 (catálogo de correcciones del árbol)

A.68 documenta los errores del árbol Dart actual y las correcciones propuestas.
Este documento (A.65.02.03) define el modelo de destino al que el árbol debe converger
tras aplicar esas correcciones.

| Corrección en A.68 | Relación con este modelo |
|--------------------|------------------------|
| F.6 — `clave` debe ser slug, no descripción | La `clave` debe seguir el formato de dirección de §5.2 |
| A.1.1 — separador `.` en slugs | Codificado en §2.1 de este documento |
| F.1 — claves con `·`, `*`, `/`, espacios | Violaciones del charset de §2.2 |
| F.4 — 291 átomos sin `verbo:` explícito | El verbo es obligatorio en §1 — debe asignarse |

---

## 8. Historial

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 2.2 | 2026-07-21 | §2.5.1 reescrito en profundidad: tabla de similitudes (mismo PDP, mismos resultados, mismas reglas), tabla de diferencias (8 dimensiones), dos flujos concretos paso a paso (validate: contador + límite de aprobación; reassess: MDM → CAEP → step-up/revocación), modelo de grants independientes por verbo (SECURITY_ANALYST vs CONTADOR), tabla de 9 operaciones reales con átomo y quién llama, tabla de 6 átomos reassess ausentes en el árbol actual con su impacto. |
| 2.1 | 2026-07-21 | `reassess` promovido a verbo 16 oficial. §2.5.1: distinción `validate` vs. `reassess`, ejemplos, tabla de 6 átomos tipo por dominio. Base: NIST SP 800-207 §3.3.1 + CAEP 1.0. |
| 2.0 | 2026-07-21 | §2.3 ampliado: D14 (PAM) y D15 (NHI). §2.4 reescrito con investigación profunda: leyenda [N]/[I], ejemplos de átomo por bloque, bloques nuevos (D00 `consent`, D01 `certification`, D02 `visitors`, D06 `residency`, D07 `posture`, D08 `assurance`), vocabulario CAEP 1.0, correcciones normativas (SP 800-63-4 final, ADSIB/AGETIC, PCI DSS 12m vs SOX 7a, NIST IR 8202 informe). Fuente: SBOS-0XX-ATOMLANG-BLOQUES-AMPLIADOS.md. |
| 1.1 | 2026-07-21 | §2.4 añadido: 15 dominios × 3-5 bloques canónicos en inglés. §2.5 renumerado. §6 actualizado. Validación `atomc` con `E_BLOCK_UNKNOWN`. |
| 1.0 | 2026-07-21 | Versión inicial. Modelo completo: formato, reglas de nomenclatura, niveles opcionales, ejemplos, relación con T-162 y `atomc`. |
