# SBOS — Motores de Control por Dominio
## Investigación Profesional: Cada Dominio Tiene su Propio Motor, Políticas y Mecanismos
### SKULL · SBOS · Junio 2026 · v1.0

**Propósito:** Documentar que cada uno de los 12 dominios de soberanía (D1–D12) requiere su propio motor de control con políticas, estándares y mecanismos específicos. No es un evaluador genérico — cada dominio es un mundo distinto.

**Código:** SBOS-BAUTH-MOTORES-DOMINIO-v1.0
**Referencia:** `SBOS-BAUTH-DOMAIN-CONTROL-METHODOLOGY.md` v1.2

---

## D1 — Dominio Lógico (Apps, Roles, Verbos)

### Motor: `LogicalDomainEngine`

**Qué controla:** Qué aplicaciones puede usar un usuario y qué operaciones (verbos) puede ejecutar dentro de ellas.

### Políticas Específicas

| Política | Tipo | Descripción |
|----------|------|-------------|
| **POL-D1-APP-ACCESS** | Allowlist | Apps permitidas por rol: `{rol: "cajero", apps: ["tryton", "saleor"], verbs: ["nuevo", "editar", "ver"]}` |
| **POL-D1-MENU-VISIBILITY** | Ocultamiento | Menús y botones visibles según rol. Un Cajero no ve "Eliminar Comprobante" |
| **POL-D1-FIELD-LEVEL** | Granular | Campos editables por rol. Cajero edita `monto`, no `cuenta_contable` |
| **POL-D1-RATE-LIMIT** | Protección | 100 req/s para BIZ, 10 req/s para EXT, 1 req/s para Visitante |
| **POL-D1-CROSS-TENANT** | Aislamiento | Usuario del tenant A nunca ve datos del tenant B |

### Estándares

- **NIST SP 800-162 (ABAC Guide):** átomo como tupla `(sujeto, objeto, operación, entorno)`. El Dominio Contextual codifica objeto+entorno; el Dominio Lógico codifica operación.
- **OASIS XACML 3.0:** arquitectura PEP/PDP/PIP. El Rol BitMask actúa como pre-filtro del PEP.
- **NIST RBAC §4.2:** DAG de herencia de roles.
- **ISO/IEC 27001:2022 A.5.3 (SoD):** Conflict Matrix de pares de átomos incompatibles.

### Mecanismo de Control

```
Fast-Path (<0.5ns):  ¿bit en Rol BitMask para atom_position?
Policy-Path:         POL-D1-APP-ACCESS → ¿app en allowlist?
                     POL-D1-FIELD-LEVEL → ¿campo editable?
                     POL-D1-CROSS-TENANT → ¿tenant_id coincide?
```

### Átomos en REGISTRO-ESTADO: **B3 (7 átomos)**

---

## D2 — Dominio Físico (Puertas, Zonas, Hardware)

### Motor: `PhysicalDomainEngine`

**Qué controla:** Acceso a espacios físicos (zonas, puertas, cajones de punto de venta) y dispositivos de hardware (USB, impresoras, terminales).

### Políticas Específicas

| Política | Tipo | Descripción |
|----------|------|-------------|
| **POL-D2-ZONE-ACCESS** | Geozone | Zonas accesibles por rol: `{rol: "cajero", zonas: ["piso_ventas", "caja"], denegado: ["boveda", "servidor"]}` |
| **POL-D2-TIME-BINDING** | Temporal | Una zona solo es accesible en el turno del usuario. Fuera de turno → denegado aunque el bit esté activo |
| **POL-D2-ESCORT** | Acompañamiento | Zonas que requieren escolta: `{zona: "boveda", requiere_escolta: true, escolta_min_nivel: "N3"}` |
| **POL-D2-HARDWARE-CONTROL** | Dispositivos | USB bloqueado por defecto. Solo roles específicos pueden imprimir, usar Thunderbird, etc. |
| **POL-D2-ANTI-TAILGATING** | Anti-intrusión | Dos accesos con la misma credencial en <5s en la misma puerta → alerta |
| **POL-D2-ANTI-PASSBACK** | Anti-passback | No se puede salir por una puerta sin haber entrado por ella |

### Estándares

- **OSDP v2.2.2 (IEC 60839-11-5):** Comunicación bidireccional cifrada AES-128 entre lector y controlador
- **SIA OSDP Verified:** Certificación de dispositivos
- **NIST SP 800-53 PE-3:** Physical Access Control — verificar autorización individual
- **NIST SP 800-53 PE-6:** Monitoring Physical Access — monitoreo en tiempo real
- **Aliro (2026):** Credenciales físicas basadas en certificados X.509

### Mecanismo de Control

```
Fast-Path (<0.5ns):  ¿bit en Rol BitMask para atom_position de puerta/lector?
Policy-Path:         POL-D2-ZONE-ACCESS → ¿zona en allowlist?
                     POL-D2-TIME-BINDING → ¿turno activo?
                     POL-D2-ESCORT → ¿escolta presente?
External-Path:       OSDP → lector físico → CredentialEvent normalizado → bAuth
```

### Átomos en REGISTRO-ESTADO: **B2 (8 átomos)**

---

## D3 — Dominio Financiero (Límites, SoD, Dual-Approval)

### Motor: `FinancialDomainEngine`

**Qué controla:** Quién puede mover dinero, cuánto, y bajo qué condiciones de aprobación.

### Políticas Específicas

| Política | Tipo | Descripción |
|----------|------|-------------|
| **POL-D3-LIMIT** | Cuantitativa | `max_transaction`, `max_daily`, `max_monthly`, `currency`. Por rol, por sucursal |
| **POL-D3-DUAL-APPROVAL** | Umbral | `requires_dual_approval_above: $1,000`. Dos firmas requeridas si monto > umbral |
| **POL-D3-SOD** | Conflictiva | Pares de átomos incompatibles: `FINANCIAL_CREATE ⟂ FINANCIAL_APPROVE` |
| **POL-D3-ESCALATION** | Temporal | Si el aprobador no responde en 30min → escala a su superior |
| **POL-D3-CURRENCY-CONTROL** | Moneda | Límites diferentes para BOB, USD, USDT |
| **POL-D3-VELOCITY** | Anti-fraude | Más de N transacciones en M minutos → bloquear + alerta |
| **POL-D3-AMOUNT-PATTERN** | Anti-fraude | Transacciones por debajo del umbral de aprobación repetidas (structuring) → alerta |

### Estándares

- **PCI-DSS 4.0.1:** Requisitos 7 (Access Control), 10 (Audit Trail), 11 (Monitoring)
- **SOX §404:** Conflict Matrix documentable y testeable para auditorías externas
- **FATF Recommendation 16 (Jun 2025):** Travel Rule — CoP obligatorio, ISO 20022
- **ISO 27001 A.5.3:** Segregation of Duties
- **NIST SP 800-53 AC-5:** Separation of Duties enforcement

### Mecanismo de Control

```
Fast-Path (<0.5ns):  ¿tiene FINANCIAL_CREATE?
Policy-Path (~5ms):  POL-D3-LIMIT → ¿monto ≤ max_transaction?
                     POL-D3-DUAL-APPROVAL → ¿monto > umbral?
                     POL-D3-SOD → ¿creador ≠ aprobador?
                     POL-D3-CURRENCY → ¿límite en esta moneda?
Resultado:           policy_state = 00 (no aplica) / 01 (pendiente) / 10 (aprobado) / 11 (rechazado)
```

### Átomos en REGISTRO-ESTADO: **B4 (7 átomos)**

---

## D4 — Dominio Temporal (Horarios, Turnos, Feriados)

### Motor: `TemporalDomainEngine`

**Qué controla:** Cuándo puede un usuario ejercer sus privilegios. No tiene átomos propios — se activa como política encadenada a átomos de D1.

### Políticas Específicas

| Política | Tipo | Descripción |
|----------|------|-------------|
| **POL-D4-SHIFT** | Periódica | `{rol: "cajero", allowed_days: [L,M,X,J,V,S], shift_start: "08:00", shift_end: "17:00"}` |
| **POL-D4-HOLIDAY** | Calendario | Feriados nacionales y locales. En feriado → denegar acceso (excepto roles de emergencia) |
| **POL-D4-MAX-SESSION** | Duración | Máximo 8h continuas. Después → forzar reautenticación |
| **POL-D4-INACTIVITY** | Timeout | 15min sin actividad → bloquear pantalla. 60min → cerrar sesión |
| **POL-D4-GRACE-PERIOD** | Transición | 5min antes del fin del turno → warning. Al terminar → guardar trabajo + logout |
| **POL-D4-OVERTIME** | Excepción | Extensión de turno requiere aprobación del supervisor. Máx 2h extra |

### Estándares

- **GTRBAC (Generalized Temporal RBAC):** Periodicity constraints, duration constraints, triggers
- **NIST SP 800-63B §7:** Session Management — max 8h, inactivity 15min, reauth 4h
- **ISO 27001 A.9.2.5:** Review of access rights (temporal: ¿sigue necesitando este acceso?)

### Mecanismo de Control

```
Policy-Path (encadenado):  POL-D4-SHIFT → ¿hora actual en [shift_start, shift_end]?
                           POL-D4-HOLIDAY → ¿hoy es feriado?
                           POL-D4-MAX-SESSION → ¿sesión > 8h?
                           POL-D4-INACTIVITY → ¿última actividad > 15min?
```

### Átomos en REGISTRO-ESTADO: **B6 (6 átomos)** — Sin átomos propios, se encadenan a D1

---

## D5 — Dominio Biométrico (Huella, Rostro, LoA)

### Motor: `BiometricDomainEngine`

**Qué controla:** Verificación de identidad mediante factores biométricos. Se resuelve en el login (Keycloak), no en cada request.

### Políticas Específicas

| Política | Tipo | Descripción |
|----------|------|-------------|
| **POL-D5-LOA-REQUIRED** | Nivel | `{rol: "SU", loa_required: 3, methods: [FIDO2_HW, FACE]}` |
| **POL-D5-STEP-UP** | Elevación | Si LoA_token < LoA_required → challenge biométrico adicional |
| **POL-D5-LIVENESS** | Anti-spoofing | Requerir prueba de vida (parpadeo, movimiento) para operaciones críticas |
| **POL-D5-METHOD-PREFERENCE** | Jerarquía | Huella > Rostro > Iris > Voz. Según dispositivo disponible |
| **POL-D5-FALLBACK** | Degradación | Si sensor biométrico no disponible → degradar a TOTP + contraseña |
| **POL-D5-MAX-ATTEMPTS** | Anti-fuerza bruta | 3 intentos biométricos fallidos → bloquear + requerir recovery code |

### Estándares

- **NIST SP 800-63B Rev.4:** AAL2 (TOTP/Passkey), AAL3 (FIDO2 HW + biométrico)
- **FIDO2/WebAuthn L3:** User Verification con biometric
- **RGPD Art.9:** Datos biométricos = categoría especial. Nunca raw data
- **ISO/IEC 19794:** Biometric data interchange formats
- **ISO/IEC 30107:** Presentation attack detection (liveness)

### Mecanismo de Control

```
External-Path (login):  Keycloak → sensor biométrico → verificar
                        POL-D5-LOA-REQUIRED → ¿LoA suficiente?
                        POL-D5-STEP-UP → ¿requiere elevación?
                        POL-D5-LIVENESS → ¿prueba de vida superada?
```

### Átomos en REGISTRO-ESTADO: **B5 (6 átomos)**

---

## D6 — Dominio Geoespacial (País, Viaje Imposible, Jurisdicción)

### Motor: `GeospatialDomainEngine`

**Qué controla:** Desde dónde se origina una operación y si esa ubicación es coherente.

### Políticas Específicas

| Política | Tipo | Descripción |
|----------|------|-------------|
| **POL-D6-COUNTRY** | Geográfica | Países permitidos: `["BO", "AR", "MX", "CO", "PE", "CL"]`. Fuera → denegar |
| **POL-D6-IMPOSSIBLE-TRAVEL** | Velocidad | Si distancia entre último acceso y actual > 900km en < 1h → bloqueo + alerta |
| **POL-D6-FISCAL-JURISDICTION** | Fiscal | Datos fiscales de Bolivia solo accesibles desde IP Bolivia |
| **POL-D6-GEOFENCE** | Perimetral | `{sucursal: "central", fence_radius_m: 500}`. Fuera del perímetro → denegar |
| **POL-D6-VPN-DETECTION** | Anti-evasíon** | Detectar VPN/proxy comercial. Si detectado → requerir verificación adicional |
| **POL-D6-LOCATION-ACCURACY** | Precisión | GPS > Wi-Fi > IP. Si solo IP disponible → degradar confianza |

### Estándares

- **IETF draft-lkspa-wimse-verifiable-geo-fence-02 (Oct 2025):** Verifiable geofencing con TPM attestation
- **NIST SP 800-207:** Zero Trust — sin confianza por ubicación
- **Microsoft Entra ID Conditional Access:** Impossible travel detection
- **GDPR Art.44-49:** Transferencia internacional de datos

### Mecanismo de Control

```
External-Path (al login):  GPS + Wi-Fi + IP → ubicación compuesta
Policy-Path (encadenado):  POL-D6-COUNTRY → ¿país en allowlist?
                           POL-D6-IMPOSSIBLE-TRAVEL → ¿viaje > 900km/h?
                           POL-D6-FISCAL-JURISDICTION → ¿IP Bolivia para datos fiscales?
```

### Átomos en REGISTRO-ESTADO: **B7 (5 átomos)**

---

## D7 — Dominio de Red (CIDR, VPN, Protocolo, Device Posture)

### Motor: `NetworkDomainEngine`

**Qué controla:** Desde qué dirección de red, con qué protocolo, y bajo qué condiciones de conexión.

### Políticas Específicas

| Política | Tipo | Descripción |
|----------|------|-------------|
| **POL-D7-CIDR** | IP Range | `{rol: "admin", allowed_cidr: ["10.0.0.0/8", "172.16.0.0/12"]}` |
| **POL-D7-VPN-REQUIRED** | Conectividad | `{acceso: "externo", vpn_required: true, vpn_provider: "WireGuard"}` |
| **POL-D7-PROTOCOL** | Protocolo | Solo HTTPS/WebSocket. HTTP vetado (SBOS-050 P9). SSH solo desde management |
| **POL-D7-MTLS-REQUIRED** | Autenticación | M2M → mTLS obligatorio. Sin certificado → denegar |
| **POL-D7-DEVICE-POSTURE** | Estado | OS patch level, EDR signals, encryption status, jailbreak detection |
| **POL-D7-MICROSEGMENTATION** | /32 CIDR | Un dispositivo = una /32. Sin tráfico east-west entre dispositivos |
| **POL-D7-RATE-LIMIT** | Anti-DoS | 100 req/s por IP. 1000 req/s para daemons internos |

### Estándares

- **NIST SP 800-207:** Zero Trust Architecture — continuous verification, microsegmentation
- **SBOS-050 P9:** HTTP vetado entre daemons. Solo WebSocket o Unix socket
- **SBOS-054 §6:** Network Security Requirements (NRS-01 a NRS-12)
- **ZTNA (Zero Trust Network Access):** Reemplaza VPN tradicional. Acceso por aplicación, no por red
- **eBPF/WFP:** Kernel-level microsegmentation (Alibaba Cloud 2026)

### Mecanismo de Control

```
External-Path (Kong):   POL-D7-CIDR → ¿IP en rango?
                         POL-D7-VPN-REQUIRED → ¿conexión VPN?
                         POL-D7-PROTOCOL → ¿protocolo permitido?
                         POL-D7-MTLS-REQUIRED → ¿certificado válido?
Policy-Path:            POL-D7-DEVICE-POSTURE → ¿parches al día?
```

### Átomos en REGISTRO-ESTADO: **B8 (5 átomos)**

---

## D8 — Dominio de Contexto (ctx_id, Sesión, Trazabilidad)

### Motor: `ContextPlaneEngine`

**Qué controla:** La existencia, validez y propagación del contexto de sesión (ctx_id). Es la PRECONDICIÓN de toda evaluación de acceso.

### Políticas Específicas

| Política | Tipo | Descripción |
|----------|------|-------------|
| **POL-D8-CTX-REQUIRED** | Precondición | Sin ctx_id válido → denegar TODO. Es el paso 0 del motor de resolución |
| **POL-D8-CTX-STRUCTURE** | Validación | 6 campos obligatorios: tenant, empresa, sucursal, pos_logico, user_id, traceparent |
| **POL-D8-CTX-TTL** | Expiración | TTL sincronizado con KC session. Default 8h |
| **POL-D8-CTX-ANTI-REPLAY** | Seguridad | Nonce único + secuencia incremental por operación |
| **POL-D8-CTX-PROPAGATION** | Trazabilidad | W3C Trace Context (traceparent) + OpenTelemetry Baggage en cada request |
| **POL-D8-DCTX-PRE-AUTH** | Pre-autenticación | dctx_id debe existir en Redis antes de permitir login. Sin dispositivo → sin auth |

### Estándares

- **W3C Trace Context:** `traceparent: 00-{trace_id}-{span_id}-01`
- **OpenTelemetry Baggage:** `sbos={tenant_id}`
- **NIST SP 800-207:** Policy Engine (PE) — bAuth evalúa el contexto
- **SBOS-049:** Context Plane — ctx_id obligatorio en cada operación

### Mecanismo de Control

```
Pre-BitMask (<5ms):  POL-D8-CTX-REQUIRED → ¿ctx_id existe en Redis?
                     POL-D8-CTX-STRUCTURE → ¿6 campos válidos?
                     POL-D8-CTX-TTL → ¿no expiró?
                     POL-D8-CTX-ANTI-REPLAY → ¿nonce único?
                     POL-D8-DCTX-PRE-AUTH → ¿dctx_id válido? (solo en login)
```

### Átomos en REGISTRO-ESTADO: **B16 (19 átomos)**

---

## D9 — Dominio de Credenciales (Passwords, MFA, Certificados)

### Motor: `CredentialDomainEngine`

**Qué controla:** El ciclo de vida de contraseñas, factores MFA, certificados de identidad.

### Políticas Específicas

| Política | Tipo | Descripción |
|----------|------|-------------|
| **POL-D9-PASSWORD** | Complejidad | Longitud mínima por tier (NIST 800-63B Rev.4). Sin reglas de composición. Cribado HIBP |
| **POL-D9-MFA-ENROLLMENT** | Registro | Grace period 7d para enrolar MFA. Sin MFA → sin acceso post-grace |
| **POL-D9-TOKEN-BINDING** | Vinculación | mTLS (SU/M2M) + DPoP (SYS) + PKCE (BIZ/EXT). Sin token binding → denegar |
| **POL-D9-CERT-LIFECYCLE** | Ciclo de vida | Emitir (Vault PKI) → Rotar (24h) → Revocar (CRL + OCSP) |
| **POL-D9-RECOVERY** | Recuperación | Recovery codes SHA-256. Admin reset con aprobación. Sin bypass MFA |
| **POL-D9-ROTATION** | Rotación | Solo post-compromiso para passwords. 90 días para API keys. 24h para certificados |

### Estándares

- **NIST SP 800-63B Rev.4:** Password length > complexity. No forced rotation. HIBP screening
- **NIST SP 800-57:** Key Management — 8 fases del ciclo de vida
- **OWASP ASVS V2:** Authentication verification requirements
- **RFC 9470:** Step-Up Authentication
- **FIDO2/WebAuthn L3:** Phishing-resistant authentication

### Mecanismo de Control

```
Pre-BitMask (login):  POL-D9-PASSWORD → ¿longitud mínima? ¿cribado HIBP?
                      POL-D9-MFA-ENROLLMENT → ¿MFA enrolado?
External-Path:        Vault PKI → emitir/rotar/revocar certificados
Policy-Path:          POL-D9-TOKEN-BINDING → ¿mTLS/DPoP/PKCE según tier?
```

### Átomos en REGISTRO-ESTADO: **B12 (20 átomos) + B9 (30 átomos) + B37 (8 átomos)**

---

## D10 — Dominio de Delegación (Privilegios Temporales, Vigencia)

### Motor: `DelegationDomainEngine`

**Qué controla:** Permisos temporales que un usuario presta a otro, con revocación automática.

### Políticas Específicas

| Política | Tipo | Descripción |
|----------|------|-------------|
| **POL-D10-MAX-DURATION** | Temporal | Máximo 21 días. Delegaciones más largas requieren cambio de RolTemplate |
| **POL-D10-AND-REDUCTION** | Matemática | `delegado = original_mask AND target_role_mask`. Garantiza mínimo privilegio |
| **POL-D10-AUTO-REVOKE** | Automática | Cron 60s: `valid_until < now()` → revocar delegación |
| **POL-D10-SOD-PRECHECK** | Conflictiva | Verificar que la delegación no crea conflicto SoD |
| **POL-D10-NOTIFICATION** | Notificación | Notificar al delegado: "Tienes acceso temporal al rol X hasta el Y" |
| **POL-D10-AUDIT** | Auditoría | Cada delegación (creación, uso, revocación) → audit_event |

### Estándares

- **NIST AC-5:** Separation of Duties — static + dynamic
- **NIST SP 800-162 (ABAC):** Delegation as attribute-based constraint
- **ISO 27001 A.9.2.5:** Review of delegated access rights

### Mecanismo de Control

```
Policy-Path:  POL-D10-MAX-DURATION → ¿duración ≤ 21 días?
              POL-D10-AND-REDUCTION → `delegado = senior & junior`
              POL-D10-SOD-PRECHECK → ¿conflicto SoD?
              POL-D10-AUTO-REVOKE → Cron 60s
```

### Átomos en REGISTRO-ESTADO: **B17 (33 átomos incluye delegación + operaciones)**

---

## D11 — Dominio de Auditoría (WORM, Trazabilidad, Compliance)

### Motor: `AuditDomainEngine`

**Qué controla:** El registro inalterable de todo lo que ocurrió en el sistema. No evalúa — solo registra.

### Políticas Específicas

| Política | Tipo | Descripción |
|----------|------|-------------|
| **POL-D11-WORM** | Inmutabilidad | REVOKE UPDATE/DELETE a nivel BD. Hash chain SHA-256 entre eventos |
| **POL-D11-CTX-REQUIRED** | Trazabilidad | Todo audit_event DEBE tener ctx_id. Sin ctx_id → rechazar INSERT |
| **POL-D11-RETENTION** | Retención | Auth events: 12 meses. Audit events: 10 años (fiscal Bolivia). GDPR: anonimizar PII |
| **POL-D11-STREAMING** | Tiempo real | Publicar en Redis Stream `bkernel:audit:events` para SIEM (Wazuh, Splunk, ELK) |
| **POL-D11-INTEGRITY-CHECK** | Verificación | Hash chain verification cada 1h. Alertar si cadena rota |
| **POL-D11-COMPLIANCE-REPORT** | Reportes | ISO 27001, PCI-DSS, SOX, ETF Bolivia — generación automatizada |

### Estándares

- **ISO 27001 A.8.15:** Logging and monitoring
- **PCI-DSS 4.0.1 Req.10:** Audit trail security
- **SOX §404:** Conflict Matrix documentable
- **NIST SP 800-92:** Log Management
- **RFC 9943 (SCITT):** Verifiable data structures

### Mecanismo de Control

```
Post-hoc (siempre):  POL-D11-WORM → INSERT con REVOKE UPDATE/DELETE
                     POL-D11-CTX-REQUIRED → ctx_id NOT NULL
                     POL-D11-RETENTION → particionado por mes, purgado por política
                     POL-D11-INTEGRITY-CHECK → hash chain verification cada 1h
```

### Átomos en REGISTRO-ESTADO: **B17 (33 átomos incluye auditoría + trazabilidad)**

---

## D12 — Dominio de Blockchain (Verificabilidad Externa)

### Motor: `BlockchainDomainEngine`

**Qué controla:** La verificabilidad externa de los registros de auditoría mediante anclaje criptográfico en blockchain pública y liquidación on-chain entre entidades.

### Políticas Específicas

| Política | Tipo | Descripción |
|----------|------|-------------|
| **POL-D12-ANCHOR-FREQUENCY** | Temporal | Gold tier: cada 1 hora. Platinum: cada 10min (>$10K). Silver: 24h (eventos no críticos) |
| **POL-D12-MERKLE-ALGORITHM** | Criptográfica | RFC 6962 binary Merkle tree. Keccak-256. Domain separation 0x00/0x01 |
| **POL-D12-GAS-MANAGEMENT** | Económica | Min balance 0.005 ETH. Alerta si <0.001 ETH. Recarga manual |
| **POL-D12-SETTLEMENT-CONFIRMATIONS** | Finalidad | 1 confirmación (2s) para <$100K. 3 confirmaciones (6s) para >$100K |
| **POL-D12-VERIFICATION-PUBLIC** | Transparencia | Panel público de verificación. Sin login. `bos-verify` CLI |
| **POL-D12-VALIDATOR-GOVERNANCE** | Consorcio | QBFT voting: ≥⅔ para añadir/quitar validador. Emergency transitions en genesis |
| **POL-D12-CUSTODY** | Custodia | Custodia gestionada (nunca auto-custodia). Claves en HSM vía PKCS#11 |

### Estándares

- **RFC 6962:** Certificate Transparency — Merkle tree construction
- **RFC 9943 (SCITT):** Supply Chain Integrity, Transparency, and Trust Architecture
- **draft-fassbender-scitt-time-anchor:** External temporal anchoring via OpenTimestamps/Bitcoin
- **VCP v1.1 (VeritasChain Protocol):** 3-layer integrity + tier system
- **eIDAS 2.0 (ETSI TS 119 535):** Qualified Electronic Registers
- **FATF Recommendation 16 (Jun 2025):** Travel Rule — CoP obligatorio

### Mecanismo de Control

```
External-Path (Var A):  POL-D12-ANCHOR-FREQUENCY → sellar lote + anclar
                        POL-D12-MERKLE-ALGORITHM → RFC 6962 + Keccak-256
                        POL-D12-GAS-MANAGEMENT → verificar balance > min

External-Path (Var B):  POL-D12-SETTLEMENT-CONFIRMATIONS → esperar N bloques
                        POL-D12-VALIDATOR-GOVERNANCE → votación QBFT
                        POL-D12-CUSTODY → firma dentro de HSM (PKCS#11)
```

### Átomos en REGISTRO-ESTADO: **B29 (22 átomos)**

---

## Resumen: Un Motor por Dominio

| Dominio | Motor | Mecanismo Principal | Capa | Átomos |
|---------|-------|-------------------|------|--------|
| **D1** | LogicalDomainEngine | Fast-Path: Rol BitMask bit check | Fast-Path | B3: 7 |
| **D2** | PhysicalDomainEngine | OSDP Secure Channel + zone policies | Fast-Path + External | B2: 8 |
| **D3** | FinancialDomainEngine | Límites + SoD + Dual-Approval | Fast-Path + Policy | B4: 7 |
| **D4** | TemporalDomainEngine | Shift/Holiday/Inactivity policies | Policy (encadenado) | B6: 6 |
| **D5** | BiometricDomainEngine | LoA verification via Keycloak | External (login) | B5: 6 |
| **D6** | GeospatialDomainEngine | Impossible travel + geofencing | External (login) | B7: 5 |
| **D7** | NetworkDomainEngine | CIDR + VPN + mTLS + Device Posture | External (Kong) | B8: 5 |
| **D8** | ContextPlaneEngine | ctx_id validation (precondición) | Pre-BitMask | B16: 19 |
| **D9** | CredentialDomainEngine | Password + MFA + Token Binding | Pre-BitMask (login) | B12: 20 + B9: 30 + B37: 8 |
| **D10** | DelegationDomainEngine | AND reduction + auto-revoke | Policy-Path | B17: 33 |
| **D11** | AuditDomainEngine | WORM + hash chain + streaming | Post-hoc (siempre) | B17: 33 |
| **D12** | BlockchainDomainEngine | Merkle anchoring + settlement | External-Path | B29: 22 |

---

## Referencias

- [ABAC — NIST SP 800-162](https://csrc.nist.gov/publications/detail/sp/800-162/final)
- [OASIS XACML 3.0](https://docs.oasis-open.org/xacml/3.0/xacml-3.0-core-spec-os-en.html)
- [GTRBAC — Generalized Temporal RBAC](https://ieeexplore.ieee.org/document/1368675)
- [OSDP v2.2.2 — SIA Standard](https://www.securityindustry.org/industry-standards/open-supervised-device-protocol/)
- [Aliro — Certificate-Based Physical Identity (2026)](https://www.globenewswire.com/fr/news-release/2026/06/03/3306343/0/en/safetrust-hosts-expert-briefing-on-aliro-the-enterprise-standard-for-certificate-based-physical-identity.html)
- [IETF Verifiable Geofencing (Oct 2025)](https://datatracker.ietf.org/doc/html/draft-lkspa-wimse-verifiable-geo-fence-02)
- [ZTNA — Zero Trust Network Access](https://www.opensecurityarchitecture.org/patterns/sp-029/)
- [NIST SP 800-63B Rev.4 — Digital Identity](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [NIST SP 800-207 — Zero Trust](https://csrc.nist.gov/publications/detail/sp/800-207/final)
- [NIST SP 800-57 Part 1 Rev.6 — Key Management (draft 2026)](https://csrc.nist.gov/pubs/sp/800/57/pt1/r6/ipd)
- [RFC 6962 — Certificate Transparency](https://www.rfc-editor.org/info/rfc6962)
- [RFC 9943 — SCITT Architecture](https://www.rfc-editor.org/authors/rfc9943.html)
- [VCP v1.1 — VeritasChain Protocol](https://dev.to/veritaschain/building-tamper-evident-audit-trails-for-trading-systems-a-vcp-v11-implementation-guide-3b2d)

---

*SKULL · SBOS · SBOS-BAUTH-MOTORES-DOMINIO-v1.0 · Junio 2026*
*Confidencial — Propiedad de SKULL Desarrollo de Software*
