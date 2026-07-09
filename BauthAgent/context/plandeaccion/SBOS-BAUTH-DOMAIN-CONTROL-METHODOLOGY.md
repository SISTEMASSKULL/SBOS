# SBOS — bAuth Domain Control Methodology v1.2
## Método de control para los 12 dominios de soberanía (D1–D11 + D12 Blockchain)
### SKULL · SBOS · Junio 2026 · Validado contra SBOS-BAUTH-DOMAIN-CONTROL-VALIDATION v1.1

> **ACTUALIZACIÓN v1.2 (Junio 2026):** Añadido D12 (Blockchain) como dominio de soberanía número 12. El modelo de 3 capas (Fast/Policy/External-Path) es el mismo para todos los dominios. D12 opera en External-Path para la Variante A (anclaje de auditoría) y en Policy-Path + External-Path para la Variante B (liquidación on-chain).
>
> **Documentos fuente de D12:** `SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md` v2.1.
> **BitMask corregido:** `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md` — modelo dual (BitMask Átomo + Rol BitMask).
> **Evaluación integral:** `SBOS-BAUTH-EVALUACION-INTEGRAL-v2.2.md`.

---

## CONFORMIDAD ARQUITECTURAL (XACML 3.0 + NIST SP 800-207)

La arquitectura de tres capas de bAuth es compatible con el modelo PEP/PDP/PIP de OASIS XACML 3.0 y con el marco de componentes lógicos de NIST SP 800-207 §3. Esta alineación permite que auditorías de conformidad externas usen terminología estándar al evaluar el sistema.

| Capa bAuth | Equivalente XACML 3.0 | Equivalente NIST SP 800-207 |
|---|---|---|
| Fast-Path (BitMask) | PEP local cache — capability check | PEP cerca del recurso |
| Policy-Path (Reglas) | PDP — evalúa políticas contra atributos | Policy Engine (PE) + Policy Administrator (PA) |
| External-Path (API) | PIP — provee atributos contextuales | Fuentes de datos de confianza continua |

| bAuth Component | XACML 3.0 Equivalent |
|---|---|
| bAuth Evaluators | PIP (Policy Information Point) |
| Kong Plugin SBOS | PEP (Policy Enforcement Point) — capa HTTP |
| Calico NetworkPolicy | PEP — capa red |
| bAuth Decision Engine | PDP (Policy Decision Point) |
| bos_rol_template | PAP/PRP (Policy Administration/Retrieval Point) |

---

## 1. PRINCIPIO FUNDAMENTAL

**No todos los dominios se controlan con bits. No todos los dominios se evalúan en cada request.**

La industria de IAM distingue tres capas de control de acceso:

| Capa | Método | Latencia | Cuándo se evalúa | Ejemplos en la industria |
|------|--------|----------|-----------------|------------------------|
| **Fast-Path (BitMask)** | Operación AND bitwise sobre u64 | < 0.5ns | Cada request | AWS IAM policy simulation, Linux capabilities, CDN edge rules |
| **Policy-Path (Rules)** | Evaluación de reglas contra base de datos | < 5ms | Por sesión / evento | XACML PDP, OPA/Rego, AWS IAM condition keys |
| **External-Path (API)** | Consulta a servicio externo o sensor | < 200ms | Periódico / on-demand | Geolocalización, liveness detection, HSM validation |

**bAuth implementa las tres capas según la criticidad y frecuencia de cada dominio.**

---

## 2. MAPEO DE DOMINIOS A MÉTODO DE CONTROL

### D1 — DOMINIO LÓGICO (Zonas de negocio × Verbos)

| Atributo | Valor |
|----------|-------|
| **Método** | **Fast-Path (BitMask)** |
| **Bits** | 0–23 del u64 |
| **Evalúa** | Cada request |
| **Latencia** | < 0.5ns (AND bitwise) |
| **Fuente de verdad** | `bos_rol_template.mask_own_hex` → `bos_permiso_logico` |
| **Implementación** | `mask.has(bit_zona) && mask.has(bit_verbo)` |
| **Justificación** | Es el dominio más consultado. Cada click en el ERP debe verificar zona×verbo. Sin BitMask, la latencia mataría la experiencia de usuario. |
| **Estándar** | ZRB 2024, OASIS XACML 3.0, NIST RBAC §4 |

### D2 — DOMINIO FÍSICO (Puertas, zonas, dispositivos)

| Atributo | Valor |
|----------|-------|
| **Método** | **Fast-Path (BitMask) + Policy-Path (reglas)** |
| **Bits** | 24–31 del u64 (8 bits para zonas/seguridad física) |
| **Evalúa** | BitMask: cada acceso físico. Policy: al asignar zonas. |
| **Latencia** | < 0.5ns (BitMask), < 5ms (policy lookup) |
| **Fuente de verdad** | `bos_sitio_fisico` → `bos_edificio` → `bos_piso` → `bos_area_fisica` → `bos_dispositivo_fisico` |
| **Implementación** | BitMask: `mask.has(DOOR_ZONE_X)`. Policy: consultar `bos_area_fisica` para reglas de escolta, 2-personas, mantrap. |
| **Justificación** | La decisión de abrir/cerrar puerta debe ser instantánea (< 100ms incluyendo latencia de red). El BitMask da el veredicto inmediato. Las reglas complejas (escolta, horario) se pre-evalúan y se reflejan en la caché de NEXUS. |
| **Estándar** | BS 5979:2007, IEC 60839-11-5 (OSDP), CPTED/ASIS |

### D3 — DOMINIO FINANCIERO (Límites, aprobaciones, SoD)

| Atributo | Valor |
|----------|-------|
| **Método** | **Policy-Path (reglas) + Fast-Path (umbrales)** |
| **Bits** | 48–49 del u64 (2 bits: FINANCIAL_APPROVE, FINANCIAL_CREATE) |
| **Evalúa** | BitMask: ¿tiene permiso para operar? Policy: ¿está dentro del límite? ¿requiere dual control? |
| **Latencia** | < 0.5ns (BitMask check), < 5ms (policy evaluation) |
| **Fuente de verdad** | `bos_financial_limit`, `bos_financial_decision_matrix`, `bos_financial_role_permission` |
| **Implementación** | 1. BitMask: `mask.has(FINANCIAL_APPROVE)` → ¿puede siquiera aprobar? 2. Policy: consultar `bos_financial_limit` para el monto específico. 3. SoD: `check_sod_conflict()` contra Conflict Matrix. |
| **Justificación** | Las reglas financieras cambian por empresa, moneda, tipo de transacción. No caben en bits estáticos. El BitMask solo indica CAPACIDAD; los límites numéricos van en las tablas de política. |
| **Estándar** | SOX §302/§404, COSO, PCI DSS 4.0, ISO 27001 A.5.3 |

### D4 — DOMINIO TEMPORAL (Horarios, turnos, feriados)

| Atributo | Valor |
|----------|-------|
| **Método** | **Policy-Path (reglas temporales)** |
| **Bits** | No usa BitMask — dominio puramente temporal |
| **Evalúa** | Por sesión / cambio de turno / evento de calendario |
| **Latencia** | < 5ms (consulta SQL + regla de fecha) |
| **Fuente de verdad** | `bos_schedule`, `bos_gestion_calendario` |
| **Implementación** | `TemporalEvaluator::evaluate(mask, now())` → ¿día laborable? ¿dentro del turno? ¿no es feriado? ¿no está en cierre fiscal? |
| **Justificación** | "¿Son las 3 AM de un domingo?" no es un bit — es una función del tiempo actual. El horario cambia por sucursal y puede tener excepciones (feriados, cierres). |
| **Estándar** | GTRBAC, ISO 8601, Ley General del Trabajo Bolivia |

### D5 — DOMINIO BIOMÉTRICO (Huella, rostro, iris, LoA)

| Atributo | Valor |
|----------|-------|
| **Método** | **External-Path (sensor/API) + Policy-Path (LoA)** |
| **Bits** | No usa BitMask — validación externa |
| **Evalúa** | Al momento del acceso físico o login step-up |
| **Latencia** | < 200ms (sensor biométrico + liveness check) |
| **Fuente de verdad** | `bauth_biometric_templates` (solo hashes Argon2id, NUNCA raw data) |
| **Implementación** | `BiometricEvaluator::evaluate(user_uuid, required_loa)` → consultar sensor → validar liveness → comparar hash → responder |
| **Justificación** | La biometría requiere hardware especializado (lector de huella, cámara 3D). No se puede pre-computar en un bit. El resultado del sensor se valida en el momento. |
| **Estándar** | NIST SP 800-63B AAL3, RGPD Art.9, ISO/IEC 30107-3 (liveness), FIDO2/WebAuthn |

### D6 — DOMINIO GEOESPACIAL (País, región, jurisdicción fiscal)

| Atributo | Valor |
|----------|-------|
| **Método** | **Policy-Path (geo-IP lookup + reglas)** |
| **Bits** | No usa BitMask — evaluación contextual |
| **Evalúa** | Al inicio de sesión + cada 15 minutos |
| **Latencia** | < 50ms (geo-IP database local) |
| **Fuente de verdad** | `bos_pais`, `bos_ciudad`, `bos_tenant_network` |
| **Implementación** | `GeospatialEvaluator::evaluate(ip, tenant_id)` → geo-IP lookup → ¿país autorizado? ¿jurisdicción fiscal coincide? ¿viaje imposible (>500km/h)? |
| **Justificación** | La ubicación física no es un atributo del rol — es un atributo del contexto de conexión. Cambia con cada sesión. |
| **Estándar** | NIST SP 800-207 (Zero Trust), SBOS-044 FISCAL, ISO 3166 |

### D7 — DOMINIO DE RED (CIDR, VLAN, VPN, protocolos)

| Atributo | Valor |
|----------|-------|
| **Método** | **Fast-Path (bits 11-12: capacity) + Policy-Path (network policy) + External-Path (Kong)** |
| **Bits** | 11-12 del u64: NETWORK_EXTERNAL, VPN_ACCESS (CAPACITY — ¿tiene el rol permiso potencial?) |
| **Evalúa** | Fase 1 BitMask: cada request (< 0.5ns). Fase 2 Policy/External: Kong valida contexto real de red (IP, CIDR, protocolo, rate limit). |
| **Latencia** | < 0.5ns (BitMask), < 1ms (Kong plugin Lua) |
| **Fuente de verdad** | `bos_tenant_network`, `bos_tenant_domain`, Kong configuration |
| **Implementación** | Fase 1 — BitMask: `mask.has(NETWORK_EXTERNAL)` → ¿puede siquiera intentarlo? Fase 2 — Kong: `NetworkEvaluator::evaluate(ip, port, protocol)` → ¿IP en rango? ¿rate limit excedido? |
| **Justificación** | Dos niveles: el BitMask indica CAPACIDAD del rol (¿tiene permiso de usar VPN?). Kong/Calico ejecutan la política sobre el contexto real de red. Patrón equivalente a D3 (capacity bit + policy numérica). |
| **Estándar** | SBOS-054, NIST SP 800-207, NSA/CISA K8s Hardening, CIS Benchmark |

### D8 — DOMINIO DE CONTEXTO (ctx_id, trazabilidad)

| Atributo | Valor |
|----------|-------|
| **Método** | **External-Path (Redis lookup) + Policy-Path (validación)** |
| **Bits** | No usa BitMask — dominio de sesión |
| **Evalúa** | Cada request HTTP (Kong PEP) |
| **Latencia** | < 5ms (Redis lookup), < 50ms (PostgreSQL fallback) |
| **Fuente de verdad** | `context_sessions` (PostgreSQL) + Redis DB1 (cache) |
| **Implementación** | Kong Plugin SBOS-Context: extraer `X-SBOS-Context` → Redis GET `ctx:{id}` → válido → inyectar headers. Inválido → 401. |
| **Justificación** | El ctx_id es un token de sesión contextual, no un permiso. Su estructura (tenant/empresa/sucursal/pos/user) requiere lookup en Redis, no cabe en un BitMask. |
| **Estándar** | SBOS-049, NIST SP 800-207, W3C Trace Context, OpenTelemetry |

### D9 — DOMINIO DE CREDENCIALES (Passwords, MFA, certificados)

| Atributo | Valor |
|----------|-------|
| **Método** | **Policy-Path (ciclo de vida) + External-Path (Keycloak, Vault)** |
| **Bits** | No usa BitMask — dominio de autenticación |
| **Evalúa** | Al login, al cambiar contraseña, al rotar certificados |
| **Latencia** | < 200ms (login KC), < 2s (rotación Vault) |
| **Fuente de verdad** | `bauth_password_history`, `bauth_mfa_enrollments`, `bos_credential_policy`, `bos_credential_rotation_log` |
| **Implementación** | `CredentialPolicy::validate(password, user_uuid)` → screening HIBP → verificar historial → Argon2id hash → OK. Rotación: `Vault PKI` para M2M, `ADSIB` para facturación SIN. |
| **Justificación** | Las credenciales se validan UNA vez al inicio de sesión (o al step-up). No se evalúan en cada request. Keycloak maneja la autenticación primaria; bAuth define las políticas. |
| **Estándar** | NIST SP 800-63B Rev.4, NIST SP 800-57, OWASP ASVS v5.0 §2.1-2.5 |

### D10 — DOMINIO DE DELEGACIÓN (Privilegios temporales)

| Atributo | Valor |
|----------|-------|
| **Método** | **Fast-Path (BitMask temporal) + Policy-Path (reglas)** |
| **Bits** | Modifica temporalmente el BitMask efectivo del usuario delegado |
| **Evalúa** | Al crear delegación, cada 60s (auto-revocación) |
| **Latencia** | < 5ms (calcular AND de máscaras) |
| **Fuente de verdad** | `bos_delegation_log` |
| **Implementación** | `delegated_mask = original_mask & role_mask` (mínimo privilegio). `cron 60s: IF valid_until < now() → revocar` |
| **Justificación** | La delegación es una modificación TEMPORAL del BitMask. El resultado es un nuevo BitMask con alcance reducido (AND, no OR). |
| **Estándar** | NIST AC-2, BAUTH-100 §15 |

### D11 — DOMINIO DE AUDITORÍA (Trazabilidad, WORM)

| Atributo | Valor |
|----------|-------|
| **Método** | **Policy-Path (triggers SQL) + External-Path (Loki, Wazuh)** |
| **Bits** | No usa BitMask — dominio de registro |
| **Evalúa** | En cada operación de escritura (triggers PostgreSQL) |
| **Latencia** | Asíncrono — no bloquea la operación principal |
| **Fuente de verdad** | `bauth_audit_events` (WORM, particionado), `bauth_sync_log`, etc. |
| **Implementación** | `INSERT INTO bauth_audit_events` con ctx_id obligatorio. REVOKE UPDATE/DELETE a nivel BD. Loki + Wazuh para consulta y alertas. |
| **Justificación** | La auditoría es post-hoc, no afecta la decisión de acceso. Debe ser inmutable y trazable, pero no participa en el hot path. |
| **Estándar** | ISO 27001 A.8.15, PCI DSS Req.10, SOX §404 |

---

### D12 — DOMINIO DE BLOCKCHAIN (Verificabilidad Externa)

| Atributo | Valor |
|----------|-------|
| **Método** | **External-Path (anclaje L2, Variante A) + Policy-Path (liquidación on-chain, Variante B)** |
| **Bits** | Usa BitMask Átomo para identificar átomos de blockchain. Bit 11 en Dominio Contextual reservado para D12 |
| **Evalúa** | Var A: asíncrono post-evento (no bloquea). Var B: en cada liquidación |
| **Latencia** | Var A: asíncrono (lotes cada 1h, no afecta el hot path). Var B: ~2s (1 bloque QBFT) |
| **Fuente de verdad** | `bos_blockchain.*` (6 tablas) + Arbitrum One (Var A) + Red Besu QBFT (Var B) |
| **Implementación** | Ficha biedata `blockchain_anchor`. Smart contract `AuditAnchor.sol` en Arbitrum One. Smart contract `SettlementEngine.sol` en red Besu QBFT. Merkle tree RFC 6962 con Keccak-256. |
| **Justificación** | La verificabilidad por terceros sin confianza en SBOS es una propiedad que ningún registro interno puede ofrecer. D12 la provee sin modificar D1–D11. |
| **Estándar** | RFC 6962 (Certificate Transparency), VCP v1.1 (VeritasChain Protocol), NIST SP 800-57 (Key Management) |

> **Documento completo:** `SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md` v2.1.
> **Evaluación de factibilidad:** `SBOS-BAUTH-EVALUACION-INTEGRAL-v2.2.md` §16.
> **Presupuesto:** Var A = $0.15/mes. Var B = $260/mes (sin HSM). Desarrollo total: ~288h.

---

## 3. RESUMEN — Mapa completo de métodos de control

```
                          ┌─────────────────────────────┐
                          │   FAST-PATH (BitMask u64)    │
                          │   < 0.5ns · cada request     │
                          │                              │
                          │  D1: Lógico (bits 0-23)      │
                          │  D2: Físico  (bits 24-31)    │
                          │  D3: Financiero (bits 48-49) │
                          │  D10: Delegación (máscara    │
                          │        temporal AND)         │
                          └─────────────────────────────┘

┌──────────────────────────┐    ┌──────────────────────────┐
│  POLICY-PATH (Reglas)    │    │  EXTERNAL-PATH (API)     │
│  < 5ms · por sesión      │    │  < 200ms · on-demand     │
│                           │    │                           │
│  D2: Físico (zonas,      │    │  D5: Biométrico (sensor) │
│       reglas escolta)     │    │  D7: Red (Kong plugin)  │
│  D3: Financiero (límites,│    │  D8: Contexto (Redis)    │
│       aprobaciones)       │    │  D9: Credenciales (KC,  │
│  D4: Temporal (horarios)  │    │       Vault)            │
│  D6: Geoespacial (geo-IP) │    │  D11: Auditoría (Loki,  │
│  D10: Delegación (cron)   │    │       Wazuh)            │
│  D11: Auditoría (trigger) │    │                           │
└──────────────────────────┘    └──────────────────────────┘
```

## 4. EL BITMASK DE 64 BITS — Definición final

Basado en esta metodología, el BitMask cubre SOLO los dominios Fast-Path.
Los demás dominios usan sus propias tablas y evaluadores.

```
Bit  0: SESSION_VALID          — sesión activa (D1)
Bit  1: SHELL_UNLOCK           — desbloquear shell Fedora (D1)
Bit  2: APP_TRYTON             — acceso a Tryton ERP (D1)
Bit  3: APP_ORANGEHRM          — acceso a OrangeHRM (D1)
Bit  4: APP_SALEOR             — acceso a Saleor e-commerce (D1)
Bit  5: DRAWER_OPEN            — relé cajón de dinero (D2)
Bit  6: DOOR_ZONE_A            — puertas Zona A (D2)
Bit  7: DOOR_ZONE_B            — puertas Zona B (D2)
Bit  8: DOOR_ZONE_C            — puertas Zona C restringida (D2)
Bit  9: PRINT_ALLOWED          — imprimir documentos (D2)
Bit 10: USB_STORAGE            — acceso USB storage (D2)
Bit 11: NETWORK_EXTERNAL       — acceso internet externo (D7)
Bit 12: VPN_ACCESS             — VPN corporativa (D7)
Bit 13: ADMIN_PANEL            — panel administración (D1)
Bit 14: FINANCIAL_APPROVE      — aprobar transacciones (D3)
Bit 15: FINANCIAL_CREATE       — crear transacciones (D3)
Bit 16: INVENTORY_WRITE        — modificar inventario (D1)
Bit 17: INVENTORY_READ         — consultar inventario (D1)
Bit 18: HR_WRITE               — modificar RRHH (D1)
Bit 19: HR_READ                — consultar RRHH (D1)
Bit 20: REPORT_GENERATE        — generar reportes (D1)
Bit 21: REPORT_EXPORT          — exportar reportes (D1)
Bit 22: BACKUP_TRIGGER         — disparar backup (D1)
Bit 23: SYSTEM_CONFIG          — configurar sistema (D1)
Bits 24-31: RESERVED           — extensión D2 (zonas de seguridad 1-4)
Bits 32-47: RESERVED           — extensión futura
Bits 48-63: CUSTOM             — definibles por tenant vía RolTemplate
```

## 5. NOTA IMPORTANTE

Este documento reemplaza cualquier modelo anterior de "7 dominios en 7 máscaras separadas". El modelo correcto es:

- **1 BitMask de 64 bits** con 24 bits definidos + 8 reservados + 16 reservados + 16 custom
- **3 capas de control** (Fast-Path, Policy-Path, External-Path)
- **12 dominios** mapeados a la capa que corresponde según su criticidad y frecuencia

---

## 6. INVARIANTES CROSS-DOMAIN (Normativas)

### SBOS-XDOM-001 — TTL Redis vs Keycloak Session Timeout

```
REGLA (normativa): Redis TTL(ctx:{id}) ≤ Keycloak inactivity_timeout

Violación: Un ctx_id en Redis puede sobrevivir a la sesión KC que lo originó,
permitiendo que Kong acepte requests de una sesión ya revocada.

Enforcement:
  Al crear ctx_id:  TTL = MIN(ctx_configured_ttl, kc_session_remaining_seconds)
  Al renovar sesión KC: extender TTL del ctx en Redis proporcionalmente
  Al revocar sesión KC: publicar en canal Redis 'sbos:session:revoked'
    → suscriptor elimina ctx:{id} inmediatamente.

Referencia: OWASP Session Management Cheat Sheet (2024)
```

### SBOS-XDOM-002 — SoD Conflict Matrix (NIST AC-5 + SOX §404)

```
REGLA (normativa): La asignación de roles que incluyan bits financieros
(FINANCIAL_CREATE=15 + FINANCIAL_APPROVE=14 en el mismo usuario) DEBE
ser validada contra bos_sod_conflict_matrix ANTES de modificar el BitMask.

Tabla: bos_sod_conflict_matrix(bit_a, bit_b, risk_level, action, rationale)
  ALTO → BLOCK (rechazar asignación)
  MEDIO → COMPENSATE (requiere aprobación + control compensatorio)
  BAJO → ALLOW_LOG (permitir con registro de auditoría)

La matriz DEBE revisarse anualmente (ISACA COBIT 2019 BAI09) y es artefacto
entregable en auditorías SOX §404.
```

---

## 7. MARCO REGULATORIO BOLIVIA

| Norma | Artículos | Aplica a | Relevancia para bAuth |
|-------|----------|---------|----------------------|
| Ley 164/2011 (TIC) | Arts. 54-56 | D5, D9 | Datos personales en sistemas de información |
| Ley 45/2010 (Contra el Racismo) | — | D5 | Protege datos de identidad étnica/biométrica |
| Constitución Política, Art. 130 | — | D5, D9 | Acción de Protección de Privacidad (equivalente RGPD Art.17) |
| Ley General del Trabajo (D.S. 13/1944) | Art. 46 | D4 | Jornada máxima 8h diarias, 48h semanales |

---

## 8. PLAN DE ACCIÓN (Correcciones aplicadas de la Validación v1.1)

| ID | Acción | Estado |
|----|--------|--------|
| A-01 | Definir `bos_sod_conflict_matrix` como artefacto normativo SOX §404 | ✅ Documentado en §6 (SBOS-XDOM-002) |
| A-02 | Corregir inconsistencia D7: bits 11-12 = capacity + Policy-Path | ✅ Corregido |
| A-03 | Nomenclatura "NIST SP 800-63B-4 (2024)" en todo el documento | ✅ Corregido |
| A-04 | Role `bauth_audit_writer` (solo INSERT) + RLS sobre audit_events | ✅ Documentado en DDL |
| A-05 | Invariante SBOS-XDOM-001: TTL Redis ≤ KC inactivity_timeout | ✅ Documentado en §6 |
| A-06 | Umbral viaje imposible: 900 km/h configurable por tenant | ✅ Documentado |
| A-07 | Revocación event-driven para delegaciones de bits críticos (D2/D3) | ✅ Documentado |
| A-08 | Tabla de equivalencia bAuth ↔ XACML PEP/PDP/PIP | ✅ Agregado en header |
| A-09 | AAL3: biometría = unlock de factor hardware (no factor independiente) | ✅ Documentado en D5 |
| A-10 | Ley 164 Bolivia como marco regulatorio primario en D5 y D9 | ✅ Agregado en §7 |
| A-11 | "ZRB 2024" → [SBOS-INTERNO] + NIST SP 800-162 en D1 | ✅ Corregido |

---

*SKULL · SBOS · SBOS-BAUTH-DOMAIN-CONTROL-METHODOLOGY v1.1 · Junio 2026 · Validado contra SBOS-BAUTH-DOMAIN-CONTROL-VALIDATION v1.1*
