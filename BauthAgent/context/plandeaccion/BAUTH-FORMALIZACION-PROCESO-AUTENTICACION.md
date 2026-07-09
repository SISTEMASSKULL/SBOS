# BAUTH — Formalización del Proceso de Autenticación y Contexto
**Versión 1.0 · 2026-06-26**

## 1. QUÉ ES bAuth

bAuth es el **orquestador central de autenticación y autorización** del ecosistema SBOS. No es un IdP — es la capa que administra y orquesta múltiples herramientas backend (Keycloak, Tryton, Vault, Besu, Redis, PostgreSQL) para entregar al usuario un **Plano de Contexto** unificado.

**El usuario NUNCA interactúa con Keycloak, Tryton, Vault, Besu, Redis ni PostgreSQL.** Solo interactúa con bAuth.

## 2. FLUJO DE AUTENTICACIÓN

```
USUARIO
  │
  │ 1. Presenta credenciales (password, TOTP, FIDO2, etc.)
  ▼
bAuth
  │
  │ 2. Selecciona método de autenticación según:
  │    - RolTemplate.credentials.requiredMethods (métodos obligatorios)
  │    - RolTemplate.credentials.availableMethods (métodos disponibles)
  │    - RolTemplate.credentials.alternativeMethods (sustitutos)
  │
  │ 3. Delega validación al backend adecuado:
  ├──► Keycloak: password, TOTP, WebAuthn, OIDC, SAML, CIBA
  ├──► Vault: mTLS certs, PKI validation, API keys
  ├──► FreeRADIUS: NFC, QR físico, tokens hardware
  ├──► Besu QBFT: liquidación on-chain (D12-B)
  │
  │ 4. Recibe token/confirmación del backend
  │
  │ 5. Evalúa políticas de acceso:
  ├──► D8 ContextEvaluator: ¿ctx_id válido?
  ├──► D9 CredentialEvaluator: ¿AAL suficiente?
  ├──► D1 LogicalEvaluator: ¿átomo en RolBitMask? (<0.5ns)
  ├──► D3 FinancialEvaluator: ¿límites, SoD, dual-approval?
  ├──► D2 PhysicalEvaluator: ¿zona, escolta, anti-passback?
  ├──► D10 DelegationEvaluator: ¿vigente, no revocada?
  ├──► D4 TemporalEvaluator: ¿en horario?
  ├──► D6 GeospatialEvaluator: ¿geo-fence, velocity?
  ├──► D7 NetworkEvaluator: ¿device trust, VPN, mTLS?
  ├──► D5 BiometricEvaluator: ¿liveness, FMR?
  ├──► D12 BlockchainEvaluator: ¿anclaje verificado?
  └──► D11 AuditDomainEvaluator: registro WORM (siempre)
  │
  │ 6. RuleEngine: 242 reglas validan cada valor configurado
  │
  │ 7. Promueve dctx_id → ctx_id
  │    dctx_id: contexto de dispositivo (pre-auth, mask=0x0)
  │    ctx_id:   contexto de sesión (post-auth, mask efectiva)
  │
  │ 8. Ensambla Context Plane y retorna al usuario:
  ▼
USUARIO recibe:
  {
    "ctx_id": "...",
    "token": "eyJ...",
    "identity": { "username": "...", "tenant": "..." },
    "permissions": ["tryton.sale_pos.read", ...],
    "trust_level": 0.95,
    "session_ttl": 28800
  }
```

## 3. EL USER TEMPLATE (Qué es y qué NO es)

### El UserTemplate define QUIÉN ES el usuario

**SECCIÓN 0 — identity**: Datos que bAuth usa para identificar al usuario ante cualquier backend:
- `username`, `email`, `display_name` → Keycloak User
- `tenant_id`, `empresa_id`, `sucursal_id`, `pos_logico` → Context Plane (ctx_id)
- `kc_user_id`, `tryton_user_id` → Referencias a los backends (bAuth los administra)
- `status`, `termination_date` → Ciclo de vida (JML: Joiner-Mover-Leaver)

**SECCIÓN 1 — personal_info**: PII. bAuth la usa para JWT claims y verificación IAL.

**SECCIÓN 2 — professional_info**: Datos laborales para Tryton res.user.

**SECCIÓN 3 — roles_assignments**: Roles asignados. bAuth calcula RolBitMask efectivo a partir de esto.

**SECCIÓN 4 — credentials**: **SOLO LECTURA**. bAuth refleja el estado real de métodos del usuario en KC. NUNCA configura KC desde aquí.

**SECCIÓN 5-10**: physical, device, session, location, temporal, network. Contexto que bAuth evalúa.

**SECCIÓN 11-14**: audit, external, compliance, lifecycle. Trazabilidad y gobierno.

### Lo que NO es el UserTemplate

- ❌ NO es configuración de Keycloak
- ❌ NO es configuración de Tryton
- ❌ NO contiene políticas (eso es el RolTemplate)
- ❌ NO contiene permisos (eso es el RolTemplate)
- ❌ NO contiene el BitMask (eso lo calcula bAuth)

## 4. EL ROL TEMPLATE (Qué es)

El RolTemplate define **QUÉ PUEDE HACER** un rol. Es la fuente de autoridad:

```
RolTemplate (16 secciones v6.0)
  │
  ├──► D1 logical_access:   zonas, apps, verbos, scope
  ├──► D2 physical_access:  zonas, métodos, escolta
  ├──► D3 financial:        límites, aprobaciones, SoD
  ├──► D4 temporal:         horarios, turnos, feriados
  ├──► D5 biometric:        FMR, liveness, enrollment
  ├──► D6 geospatial:       geo-fence, velocity, trust
  ├──► D7 network:          CIDR, VPN, mTLS, ZTNA
  ├──► D8 context:          sesión, inactividad, CAEP
  ├──► D9 credentials:      métodos requeridos, alternativos, AAL
  ├──► D10 delegation:      duración, cadena, auto-revoke
  ├──► D11 audit:           retención, hash-chain, revisión
  ├──► D12 blockchain:      anclaje, Merkle, proof
  ├──► SEC security:        llaves, algoritmos, certificados
  ├──► COMP compliance:     GDPR, SOX, PCI, ISO
  └──► sync:                mapeo KC + Tryton
```

## 5. EVALUACIÓN DE MÉTODOS DE AUTENTICACIÓN

El RolTemplate sección D9 define tres categorías de métodos:

```
credentials:
  ├── requiredMethods[]:    MÉTODOS OBLIGATORIOS
  │   El usuario DEBE tener al menos estos métodos enrolados.
  │   Si no los tiene → STEP_UP o DENY.
  │   Ej: SU requiere FIDO2 HW (AAL3)
  │
  ├── availableMethods[]:   MÉTODOS DISPONIBLES
  │   El usuario PUEDE usar cualquiera de estos.
  │   bAuth selecciona el más seguro disponible.
  │   Ej: BIZ puede usar TOTP, FIDO2 o Passkey
  │
  └── alternativeMethods[]: MÉTODOS ALTERNATIVOS
      Si un requiredMethod falla, bAuth ofrece estas alternativas.
      Pueden requerir aprobación adicional.
      Ej: TOTP falla → BACKUP_CODES (requiere aprobación)
```

## 6. dctx_id → ctx_id: EL CONTEXT PLANE

```
1. Dispositivo arranca
   → bos crea dctx_id (pre-auth, mask=0x0, state=PENDING)

2. Usuario se autentica
   → bAuth valida con backend (KC/Tryton/Vault)
   → bAuth evalúa 12 dominios
   → bAuth calcula RolBitMask efectivo
   → bAuth aplica 242 reglas de validación

3. bAuth promueve dctx_id → ctx_id
   → ctx_id = {tenant, empresa, sucursal, pos, user, traceparent, bitmask, loa, trust}
   → dctx_id marcado como StateInvalidado

4. ctx_id propagado vía W3C traceparent
   → Kong PEP valida ctx_id en cada request
   → Redis DB0 cachea ctx_id (TTL ≤ sesión KC)

5. Logout / timeout
   → bAuth invalida ctx_id (Redis DELETE + BD StateInvalidado)
   → Kong rechaza requests con ctx_id inválido (401)
```

---
*BAUTH-FORMALIZACION-PROCESO-AUTENTICACION v1.0 · 2026-06-26*
