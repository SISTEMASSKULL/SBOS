# SBOS — Administración de Llaves de Acceso
## Investigación Profesional: Rotación, Recuperación, Validación, Ciclo de Vida Completo
### SKULL · SBOS · Junio 2026 · v1.0

**Propósito:** Documentar estándares, arquitectura y mejores prácticas para la administración centralizada de llaves de acceso — criptográficas, API keys, JWT signing keys, contraseñas, certificados mTLS, y recovery codes.

**Código:** SBOS-BAUTH-ADMIN-LLAVES-v1.0
**Referencia normativa:** NIST SP 800-57 Part 1 Rev.6 (draft 2026), OWASP ASVS V6, PCI-DSS 4.0 Req.3

---

## 1. Catálogo de Llaves Administradas

| Tipo de Llave | Estándar | Uso en SBOS | Rotación | Almacenamiento |
|--------------|---------|------------|----------|---------------|
| **JWT Signing Key (EdDSA)** | Ed25519, RFC 8037 | Firmar tokens JWT emitidos por bAuth | Cada 24h (dual-signing) | Vault Transit |
| **TOTP Secret** | RFC 6238 | MFA para usuarios | Cada 90 días (o al cambiar dispositivo) | `bauth_mfa_enrollments` AES-256-GCM |
| **API Key (bauth-sync)** | Bearer token | Service account bAuth→KC | Cada 90 días (Vault automatic) | Vault KV v2 |
| **User Application Key (Tryton-PDP)** | Bearer token | Service account bAuth→Tryton-PDP | Cada 90 días | Vault KV v2 |
| **Certificado mTLS (banexus)** | X.509, Vault PKI | Autenticación dispositivo edge | Cada 24h (Vault PKI auto) | Vault PKI |
| **Clave de Firma Blockchain** | ECDSA secp256k1 | Firmar tx de anclaje en Arbitrum | Cada 180 días | SoftHSM2/HSM via PKCS#11 |
| **Clave de Validador Besu** | ECDSA secp256k1 | Firmar bloques QBFT | Cada 180 días | YubiHSM 2 FIPS via PKCS#11 |
| **Clave de Cifrado AES-256-GCM** | AES-256-GCM | Cifrar plantillas en reposo | Cada 90 días | Vault Transit |
| **Recovery Codes** | SHA-256 (hash) | Backup de acceso de emergencia | Solo al usar >50% de códigos | `bauth_recovery_codes` (hash) |
| **Contraseña de Usuario** | Argon2id (hash) | Autenticación primaria | Solo post-compromiso (NIST) | `bauth_user_credentials` (hash) |
| **Client Secret OAuth2** | Bearer token | Clientes OAuth2 (apps, external IdP) | Cada 90 días | Vault KV v2 |

---

## 2. Ciclo de Vida de Llaves (NIST SP 800-57 Part 1 Rev.6)

### 2.1 Las 8 Fases

```
┌─────────────────────────────────────────────────────────────────┐
│           CICLO DE VIDA DE LLAVE (NIST SP 800-57)                │
│                                                                   │
│  1. GENERACIÓN                                                    │
│     ├── FIPS 140-2/3 approved RBG (Random Bit Generator)        │
│     ├── Generar en HSM cuando sea posible                       │
│     └── Registrar: key_id, type, algorithm, created_at, owner   │
│                                                                   │
│  2. DISTRIBUCIÓN                                                  │
│     ├── Nunca en texto plano                                    │
│     ├── TLS 1.3 para distribución en red                        │
│     ├── PKCS#11 para distribución a HSM                         │
│     └── Registrar: distributed_to, distributed_at               │
│                                                                   │
│  3. ALMACENAMIENTO                                                │
│     ├── Vault (KV v2, Transit, PKI)                             │
│     ├── HSM para llaves críticas (validador, firma blockchain)  │
│     ├── Nunca en código fuente, Git, config files               │
│     └── Cifradas en reposo (AES-256-GCM)                        │
│                                                                   │
│  4. BACKUP Y ARCHIVO                                              │
│     ├── Backup cifrado a MinIO S01                               │
│     ├── Múltiples copias en ubicaciones físicas separadas       │
│     ├── Archive-encryption key dedicada (solo para backups)      │
│     └── Probar restauración trimestral                           │
│                                                                   │
│  5. ROTACIÓN                                                      │
│     ├── Dual-credential: ambas llaves válidas durante transición │
│     ├── Período de overlap: 24h (mínimo max_token_ttl)          │
│     ├── Automática: Vault auto-rotate                            │
│     └── Manual: emergencia o compromiso                          │
│                                                                   │
│  6. REVOCACIÓN                                                    │
│     ├── Inmediata ante compromiso                                │
│     ├── CRL (Certificate Revocation List) para X.509             │
│     ├── OCSP (Online Certificate Status Protocol)                │
│     └── Auditoría obligatoria de cada revocación                 │
│                                                                   │
│  7. RECUPERACIÓN                                                  │
│     ├── Break-glass: Vault 2-of-3 unseal para llaves críticas   │
│     ├── Recovery codes para usuario final                        │
│     ├── Procedimiento documentado + aprobación requerida         │
│     └── Post-evento: auditoría completa en ≤24h                  │
│                                                                   │
│  8. DESTRUCCIÓN                                                   │
│     ├── Zeroización criptográfica (PKCS#11 C_DestroyObject)      │
│     ├── HSM: comando zeroize                                     │
│     ├── Software: sobrescribir memoria (zeroize crate en Rust)   │
│     └── Registrar: key_id, destroyed_at, method, witness         │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Períodos Criptográficos Recomendados (SP 800-57)

| Tipo de Llave SBOS | Uso | Período |
|-------------------|-----|---------|
| JWT Signing (Ed25519) | Firmar tokens | 24h rotación, 48h overlap |
| API Key (bauth-sync) | Service account | 90 días |
| TOTP Secret | MFA usuario | 90 días o evento (nuevo dispositivo) |
| Certificado mTLS banexus | Auth dispositivo | 24h (Vault PKI auto) |
| Clave Firma Blockchain | Anclaje Arbitrum | 180 días |
| Clave Validador Besu QBFT | Firma bloques | 180 días |
| Clave Cifrado (AES-256-GCM) | Plantillas en reposo | 90 días |
| Recovery Codes | Backup acceso | Solo al usar >50% |
| Contraseña usuario | Auth primaria | Solo post-compromiso (NIST SP 800-63B) |

---

## 3. Patrón Dual-Credential (Zero-Downtime Rotation)

### 3.1 El Estándar de la Industria

```
FASE 1 — PRE-ROTACIÓN
  Llave activa: K1 (firmando, validando)
  JWKS: { "keys": [K1_pub] }

FASE 2 — TRANSICIÓN (T0 → T0+24h)
  Generar K2
  Agregar K2_pub a JWKS: { "keys": [K1_pub, K2_pub] }
  K1 sigue firmando, K2_pub ya es conocida por clientes
  Ambos certificados/keys válidos simultáneamente

FASE 3 — CUTOVER (T0+24h → T0+48h)
  Cambiar firma a K2
  K1_pub sigue en JWKS para validar tokens existentes
  Período mínimo = max_token_ttl + cache_ttl + buffer

FASE 4 — LIMPIEZA (T0+48h+)
  Verificar que no hay tokens válidos firmados con K1
  Remover K1_pub de JWKS
  Destruir K1 (zeroize)
  Auditoría: rotation_completed
```

### 3.2 Aplicación en SBOS

| Componente | Implementación Dual-Credential |
|-----------|-------------------------------|
| **JWT Signing** | B14.T16 — `jwt_signing_key_rotation()`: generar K2 → agregar a JWKS → esperar 2× TTL → cambiar firma a K2 → eliminar K1 |
| **API Keys** | B12.T17 — `kc_client_secret_rotation()`: generar nuevo secret en KC → almacenar en Vault (nueva versión) → esperar 2× token TTL → revocar anterior |
| **Tryton-PDP Key** | B13.T16 — User Application Key: crear nueva key → ambas válidas 24h → revocar anterior |
| **mTLS Certs** | B15.T18 — `DeviceCertificateLifecycle`: Vault PKI emite nuevo cert 24h antes de expiración → banexus descarga → activa → revoca anterior |
| **Blockchain Key** | B29.T16 — Validator Key Management: generar en HSM → ambos keys válidos 7 días → revocar anterior |

---

## 4. Recuperación de Llaves (Break-Glass)

### 4.1 Niveles de Recuperación

| Nivel | Quién | Procedimiento | Tiempo Máximo |
|-------|-------|--------------|---------------|
| **Usuario final** | El propio usuario | Recovery codes (B22.T05) o MFA recovery flow (B27.T12) | Inmediato (self-service) |
| **Admin de Tenant** | Admin Seguridad (S003) | Reset MFA con aprobación del manager del usuario | 1 hora |
| **SU Break-Glass** | Superusuario (S001) | Vault 2-of-3 unseal. Máx 4h session. Post-evento audit ≤24h | 15 minutos |
| **Llave comprometida** | Admin Seguridad (S003) | Revocación inmediata + rotación de emergencia + notificación | Inmediato |
| **Desastre total** | Admin Infra (S004) | Restaurar desde backup en MinIO S01 (B19.T25-T26) | RTO ≤ 4h |

### 4.2 Procedimiento Break-Glass (SU)

```
1. SU solicita activación break-glass
2. Vault 2-of-3 unseal: 3 admins (S002, S003, S004) proveen sus shards
3. Vault desbloquea — SU obtiene acceso temporal
4. Session recording obligatorio (todo se graba)
5. Máximo 4 horas de sesión
6. Post-evento (≤24h): reporte completo a S002, S003, CISO
7. Rotación de todas las llaves accedidas durante break-glass
```

---

## 5. Validación de Llaves

### 5.1 Checks de Integridad

| Check | Frecuencia | Qué verifica |
|-------|-----------|-------------|
| **JWKS consistency** | Cada 1h | `/.well-known/jwks.json` contiene las llaves esperadas, sin llaves extra |
| **Certificate expiry** | Cada 6h | Certificados mTLS próximos a expirar (<24h) → alerta + renovar |
| **Key usage audit** | Continuo | Cada uso de llave privada → audit_event con ctx_id |
| **HSM health** | Cada 5min | SoftHSM2/HSM responde PKCS#11, tokens accesibles |
| **Vault seal status** | Cada 1min | Vault no está sellado. Si sellado → alerta P1 |
| **Recovery codes integrity** | Cada 24h | Verificar SHA-256 de códigos no usados coincide con BD |
| **API key last used** | Cada 24h | Keys sin uso >90 días → alerta + proponer revocación |

### 5.2 Anti-Replay para Llaves

```
Cada uso de llave incluye:
  - Nonce único (UUID v4)
  - Timestamp (UNIX ms)
  - Firma del request (HMAC-SHA256 con la llave)

Validación:
  1. ¿Nonce ya fue usado? → REPLAY → rechazar + alerta P1
  2. ¿Timestamp > 5min de drift? → EXPIRADO → rechazar
  3. ¿Firma coincide? → VÁLIDO → procesar
```

---

## 6. Integración con Vault + HSM

### 6.1 Arquitectura de Custodia

```
┌─────────────────────────────────────────────────────────────────┐
│           JERARQUÍA DE CUSTODIA DE LLAVES                         │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    HSM Físico (Prod)                      │    │
│  │  YubiHSM 2 FIPS / nCipher / Thales Luna                  │    │
│  │  └── Llaves de validador Besu QBFT                       │    │
│  │  └── Llave de firma blockchain (Arbitrum)                │    │
│  │  └── Root CA interna (Vault PKI)                         │    │
│  └──────────────────────────────────────────────────────────┘    │
│                              │                                    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    SoftHSM2 (Dev/Staging)                 │    │
│  │  └── Misma interfaz PKCS#11 que HSM físico               │    │
│  │  └── Desarrollo y pruebas sin hardware dedicado           │    │
│  │  └── Migración a HSM físico sin cambios de código         │    │
│  └──────────────────────────────────────────────────────────┘    │
│                              │                                    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    Vault (HashiCorp)                      │    │
│  │  ├── PKI Secrets Engine: certificados mTLS               │    │
│  │  ├── Transit Secrets Engine: cifrado/descifrado          │    │
│  │  ├── KV v2: API keys, client secrets, recovery shards    │    │
│  │  └── Auto-unseal: via cloud KMS o HSM                    │    │
│  └──────────────────────────────────────────────────────────┘    │
│                              │                                    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │              PostgreSQL (encriptado en reposo)            │    │
│  │  ├── TOTP secrets (AES-256-GCM, clave en Vault)          │    │
│  │  ├── Recovery codes (SHA-256 hash, nunca texto plano)    │    │
│  │  ├── Contraseñas (Argon2id hash)                         │    │
│  │  └── User Application Keys (Vault reference, no valor)   │    │
│  └──────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Principios No Negociables

| # | Principio | Fundamento |
|---|----------|-----------|
| **P1** | Llave privada NUNCA sale del HSM en texto plano | PKCS#11: operaciones criptográficas dentro del HSM |
| **P2** | Toda operación criptográfica es auditable | `bauth_audit_events` con ctx_id + key_id + operation |
| **P3** | Rotación con dual-credential, nunca con downtime | Overlap mínimo = max_token_ttl + cache_ttl + buffer |
| **P4** | Backup de llaves cifrado y en ubicación separada | MinIO S01, cifrado con archive-key dedicada |
| **P5** | Recuperación requiere aprobación múltiple (M-of-N) | SU: 2-of-3 Vault unseal. Admin reset: aprobación manager |
| **P6** | Secretos NUNCA en logs, responses, errores | B20.T12 (SecretDetectionEngine) |
| **P7** | Sin rotación forzada de contraseñas sin evidencia de compromiso | NIST SP 800-63B Rev.4 §5.1.1.2 |

---

## 7. Dashboard de Administración de Llaves (Core UI)

1. **Inventario de Llaves:** todas las llaves activas por tipo, edad, próxima rotación
2. **Próximas a Expirar:** llaves con <7 días para expiración → alerta
3. **Historial de Rotación:** últimas 100 rotaciones con resultado
4. **Break-Glass Log:** activaciones SU con timestamp, duración, motivo
5. **Llaves sin Uso:** API keys >90 días sin uso → candidatas a revocación

---

## 8. Referencias

- [NIST SP 800-57 Part 1 Rev.6 (draft 2026)](https://csrc.nist.gov/pubs/sp/800/57/pt1/r6/ipd) — Key Management Guidelines
- [NIST SP 800-57 Part 2 Rev.1](https://csrc.nist.gov/publications/detail/sp/800-57-part-2/rev/1/final) — Best Practices for Key Management Organizations
- [NIST SP 800-63B Rev.4](https://pages.nist.gov/800-63-3/sp800-63b.html) — Digital Identity (password rotation deprecation)
- [OWASP ASVS V6 — Stored Cryptography](https://github.com/OWASP/ASVS/blob/master/5.0/en/0x14-V6-Cryptography.md)
- [PCI-DSS 4.0 Req.3 — Cryptographic Key Management](https://www.pcisecuritystandards.org/)
- [Zalando — Automated JWK Rotation (2025)](https://engineering.zalando.com/posts/2025/01/automated-json-web-key-rotation.html)
- [OneUptime — Secret Rotation Strategies (2026)](https://oneuptime.com/blog/post/2026-01-30-security-secret-rotation-strategies/view)
- [Hideez — Credential Rotation Guide (2025)](https://hideez.com/blogs/news/credential-rotation-guide)
- [NHIMG — Non-Human Identity Key Management (2026)](https://nhimg.org/)

---

*SKULL · SBOS · SBOS-BAUTH-ADMIN-LLAVES-v1.0 · Junio 2026*
*Confidencial — Propiedad de SKULL Desarrollo de Software*
