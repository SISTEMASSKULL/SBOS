# A.09 — Seguridad: mTLS, AES-256-GCM y Canal Privilegiado
## Especificación técnica de seguridad de bNexus: mTLS + SPIFFE + AES + threat model

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Respalda:** `7.02_MANUAL-SEGURIDAD-NEXUS.md`  
**Carta rectora:** `0.00_MANUAL-DIRECTRICES-NEXUS.md`

---

## 1. Especificación mTLS — Puerta 1 (banexus ↔ bhnexus)

### 1.1 Parámetros TLS

| Parámetro | Valor | Justificación |
|-----------|-------|---------------|
| Versión mínima | TLS 1.3 | RFC 8446 — elimina cipher suites inseguros de TLS 1.2 |
| Cipher suites | `TLS_AES_256_GCM_SHA384`, `TLS_CHACHA20_POLY1305_SHA256` | AEAD con autenticación integrada |
| Grupos DH | X25519 (preferido), P-256 | Resistentes a ECDLP + eficientes en ARM |
| Verificación | Obligatoria en ambos extremos (mTLS) | Sin autenticación mutua → cualquier proceso podría conectar |
| SNI | `bhnexus.sbos.skull` | Permite multiple virtual hosting si necesario |

### 1.2 Perfil de certificado para bhnexus

```
Subject: CN=bhnexus.sbos.skull, O=SKULL, C=BO
Subject Alternative Names:
  DNS: bhnexus.sbos.skull
  URI: spiffe://sbos.skull/daemon/bhnexus
Key: Ed25519 (Vault PKI)
Validity: 365 días (rotado por bOS)
Usage: TLS Web Server Authentication, TLS Web Client Authentication
CA: CN=SBOS Root CA, O=SKULL
```

### 1.3 Perfil de certificado para cada nodo banexus

```
Subject: CN=banexus-<node_id>.sbos.skull, O=SKULL, C=BO
Subject Alternative Names:
  DNS: banexus-<node_id>.sbos.skull
  URI: spiffe://sbos.skull/agent/banexus/<node_id>
Key: Ed25519 (Vault PKI, clave por nodo)
Validity: 90 días (rotado automáticamente por bOS)
Usage: TLS Web Client Authentication
CA: CN=SBOS Root CA, O=SKULL
```

**Nota**: la clave privada del certificado del nodo sirve como material de entrada para derivar la clave del policy cache (HKDF-SHA256). La rotación del certificado implica que el cache anterior es ilegible.

### 1.4 Proceso de verificación en la conexión

```
banexus → SYN → bhnexus (TCP 9444)

bhnexus TLS Server Hello:
  1. Envía ServerCertificate (bhnexus.crt)
  2. Solicita ClientCertificate

banexus verifica:
  a. bhnexus.crt firmado por CA SBOS ✅
  b. bhnexus.crt no expirado ✅
  c. bhnexus.crt SAN contiene "spiffe://sbos.skull/daemon/bhnexus" ✅

banexus TLS Client Hello:
  1. Envía ClientCertificate (banexus-<node_id>.crt)

bhnexus verifica:
  a. banexus.crt firmado por CA SBOS ✅
  b. banexus.crt no expirado ✅
  c. banexus.crt SAN contiene "spiffe://sbos.skull/agent/banexus/*" ✅
  d. node_id extraído del SPIFFE URI ✅
  e. node_id existe en idn_identity_entity con status=ACTIVE ✅

Si cualquier verificación falla:
  → TLS Alert + cierre + log WARNING + Wazuh NEXUS-003
```

---

## 2. Especificación AES-256-GCM — Policy Cache de banexus

### 2.1 Derivación de clave completa (HKDF-SHA256)

```
Input Key Material (IKM):
  private_key_bytes = DER encoding de la clave privada Ed25519 del certificado mTLS

Salt:
  salt = UTF-8 bytes de node_id (e.g. "Ventas-01")
  Longitud: variable (según longitud del node_id)

Info:
  info = b"banexus-policy-cache-v1"  (23 bytes fijos)

Output Length:
  L = 32 bytes (256 bits — clave AES-256)

Algoritmo:
  key = HKDF-Extract(salt, IKM) → PRK (32 bytes)
  key = HKDF-Expand(PRK, info, L) → OKM (32 bytes)
```

En Rust usando el crate `hkdf`:

```rust
use hkdf::Hkdf;
use sha2::Sha256;

fn derive_cache_key(private_key: &[u8], node_id: &str) -> [u8; 32] {
    let hk = Hkdf::<Sha256>::new(Some(node_id.as_bytes()), private_key);
    let mut okm = [0u8; 32];
    hk.expand(b"banexus-policy-cache-v1", &mut okm)
        .expect("longitud válida para HKDF-SHA256");
    okm
}
```

### 2.2 Cifrado de un bloque de cache

```rust
use aes_gcm::{Aes256Gcm, Key, Nonce};
use aes_gcm::aead::{Aead, NewAead};
use rand::Rng;

fn encrypt_cache(plaintext: &[u8], key: &[u8; 32]) -> Vec<u8> {
    let cipher = Aes256Gcm::new(Key::from_slice(key));

    // Nonce aleatorio de 12 bytes (96 bits) — nunca reutilizar
    let nonce_bytes: [u8; 12] = rand::thread_rng().gen();
    let nonce = Nonce::from_slice(&nonce_bytes);

    let ciphertext = cipher.encrypt(nonce, plaintext)
        .expect("cifrado AES-256-GCM");

    // Formato: [12 nonce] + [ciphertext + 16 GCM tag]
    let mut result = Vec::with_capacity(12 + ciphertext.len());
    result.extend_from_slice(&nonce_bytes);
    result.extend_from_slice(&ciphertext);
    result
}
```

### 2.3 Propiedades de seguridad de AES-256-GCM

| Propiedad | Valor |
|-----------|-------|
| Confidencialidad | AES-256 en modo CTR — indistinguible de ruido aleatorio |
| Autenticidad | GHASH MAC — detecta cualquier modificación del ciphertext |
| Nonce único | 12 bytes aleatorios por cifrado — probabilidad de colisión negligible |
| Tag size | 128 bits — falsificación requiere 2^128 intentos |
| AEAD | Autenticación del header (magic+version+timestamp+TTL) sin cifrar |

---

## 3. Threat Model del canal privilegiado (Sub-canal B)

### 3.1 Descripción del canal

| Propiedad | Valor |
|-----------|-------|
| Socket | `/run/bos/bauth-nexus.sock` |
| Propietario | `bhnexus:bos-group` (bhnexus crea el socket) |
| Permisos | `0660` (solo grupo bos-group) |
| Dirección | bhnexus crea y escucha; bAuth conecta como cliente |
| Protocolo | Frame TLV + HMAC-SHA256 por sesión |

### 3.2 Árbol de amenazas (STRIDE)

**S — Spoofing (suplantación)**

| Amenaza | Probabilidad | Impacto | Control |
|---------|:-----------:|:-------:|---------|
| Proceso suplanta a bAuth en el sub-canal B | Baja | Crítico | Permisos Unix `0660 bhnexus:bos-group`; solo bAuth corre como `bos-group` |
| Proceso suplanta a bhnexus para recibir mensajes de bAuth | Baja | Alto | Socket creado por bhnexus; bAuth conecta como cliente |

**T — Tampering (manipulación)**

| Amenaza | Probabilidad | Impacto | Control |
|---------|:-----------:|:-------:|---------|
| Modificar frame `emergency_revoke` en tránsito | Muy baja | Crítico | HMAC-SHA256 por frame con clave de sesión |
| Replay de `blacklist_node` antiguo | Baja | Alto | Sequence counter monotónico por sesión |

**R — Repudiation (repudio)**

| Amenaza | Probabilidad | Impacto | Control |
|---------|:-----------:|:-------:|---------|
| bAuth niega haber emitido `emergency_revoke` | Muy baja | Medio | Audit trail en SBOSDB con ctx_id + timestamp |

**I — Information Disclosure (divulgación)**

| Amenaza | Probabilidad | Impacto | Control |
|---------|:-----------:|:-------:|---------|
| Sniffing del socket Unix | Muy baja | Bajo | Unix sockets no tienen red — no son sniffeables remotamente |
| Exfiltración de la lista de nodos blacklisted | Baja | Medio | Solo procesos bos-group pueden leer el socket |

**D — Denial of Service (denegación de servicio)**

| Amenaza | Probabilidad | Impacto | Control |
|---------|:-----------:|:-------:|---------|
| Inundación del sub-canal B con mensajes | Media | Alto | Rate limiting: 100 msg/s; excedente descartado con WARNING |
| Proceso bos-group cierra el socket continuamente | Baja | Alto | bhnexus recrea el socket automáticamente al detectar cierre |

**E — Elevation of Privilege (elevación de privilegios)**

| Amenaza | Probabilidad | Impacto | Control |
|---------|:-----------:|:-------:|---------|
| Atacante usa sub-canal B para otorgar acceso (GRANT) | Muy baja | Crítico | El sub-canal B **no tiene mensajes de tipo GRANT** — solo revocación/restricción |

### 3.3 Conclusión del threat model

Un atacante que compromete el sub-canal B puede hacer el sistema **más restrictivo** (revocar accesos, blacklistear nodos), pero **nunca puede otorgar accesos**. La asimetría es intencional y es la propiedad de seguridad más importante del canal.

---

## 4. Resumen de reglas Wazuh (referencia rápida)

| ID | Regla | Severidad | ISO 27001 |
|----|-------|:---------:|-----------|
| 100100 | NEXUS-001: >10 auth denied/min mismo nodo | 10 | A.8.15 |
| 100101 | NEXUS-002: nodo sin heartbeat >30min | 8 | A.7.4 |
| 100102 | NEXUS-003: cert mTLS inválido | 12 | A.5.15 |
| 100103 | NEXUS-004: error hardware persistente OSDP | 12 | A.7.9 |
| 100104 | NEXUS-005: offline fail-secure zona crítica | 15 | A.7.5 |
| 100105 | NEXUS-006: versión banexus desactualizada | 5 | A.8.8 |
| 100106 | NEXUS-007: uptime sospechoso en heartbeat | 8 | A.8.15 |
| 100107 | NEXUS-008: actuador sin auth_request previo | 15 | A.5.18 |
| 100200 | banexus: integrity_breach (hash mismatch) | 15 | A.12.2.1 |
| 100201 | banexus: tamper_alert (hardware tamper) | 12 | A.7.2 |
| 100202 | banexus: offline_mode (cache activo) | 10 | — |
| 100203 | banexus: replay_detected (credencial duplicada) | 8 | A.5.15 |

---

*SKULL · SBOS · bNexus · A.09_SEGURIDAD-MTLS-AES · v1.0.0 · Agosto 2026*
