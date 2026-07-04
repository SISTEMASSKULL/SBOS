# SBOS — Motor de Firma Digital Interna
## Investigación Profesional: EdDSA, Vault PKI, PAdES/XAdES/CAdES, JWS
### SKULL · SBOS · Junio 2026 · v1.0

**Propósito:** Documentar estándares, arquitectura y mejores prácticas para el motor de firma digital interna de bAuth — el que firma documentos y datos dentro del ecosistema SBOS usando PKI propia vía Vault con EdDSA Ed25519.

**Código:** SBOS-BAUTH-FIRMA-DIGITAL-INTERNA-v1.0
**Referencia:** B25 (Motores de Firma Digital), SBOS-BAUTH-DIGITAL-SIGNATURE-ENGINES.md v1.0

---

## 1. Arquitectura del Motor Interno

```
┌─────────────────────────────────────────────────────────────────┐
│           MOTOR DE FIRMA DIGITAL INTERNA (PKI Propia)            │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    Root CA (Offline)                      │    │
│  │  Almacenada en HSM / Vault con auto-unseal               │    │
│  │  Solo firma CSRs del Intermediate CA                     │    │
│  │  TTL: 10 años. Rotación: cross-signing sin downtime      │    │
│  └────────────────────────┬─────────────────────────────────┘    │
│                           │                                       │
│  ┌────────────────────────▼─────────────────────────────────┐    │
│  │              Intermediate CA (Vault PKI)                  │    │
│  │  Firma certificados leaf (usuarios, dispositivos, M2M)   │    │
│  │  TTL: 5 años. Rotación: multi-issuer (Vault 1.11+)      │    │
│  │  Algoritmo: EdDSA Ed25519 (NIST SP 800-186)              │    │
│  └────────────────────────┬─────────────────────────────────┘    │
│                           │                                       │
│  ┌────────────────────────▼─────────────────────────────────┐    │
│  │                    Leaf Certificates                       │    │
│  │  ├── Usuarios: certificado personal (firma documentos)    │    │
│  │  ├── Dispositivos: mTLS banexus (TTL 24h)               │    │
│  │  ├── M2M: service accounts (bos, bkernel, biedata)       │    │
│  │  └── Servidores: TLS para comunicación interna            │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │              Vault Transit Engine (Firma)                 │    │
│  │  sign_data(payload) → firma Ed25519                      │    │
│  │  verify_data(payload, signature) → bool                  │    │
│  │  La clave privada NUNCA sale de Vault                     │    │
│  └──────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Estándares de Firma Digital

### 2.1 Perfiles de Firma por Formato

| Formato | Estándar | Uso en SBOS | Algoritmo |
|---------|---------|------------|-----------|
| **PAdES** (PDF) | ETSI EN 319 142-2 V1.2.1 (Jul 2025) | Firmar contratos, reportes, documentos PDF | EdDSA Ed25519 |
| **XAdES** (XML) | ETSI EN 319 132 | Firmar facturas electrónicas SIN, documentos XML | EdDSA Ed25519 (interno), RSA-SHA256 (externo ADSIB) |
| **CAdES** (CMS) | ETSI EN 319 122 | Firmar binarios, logs, backups | EdDSA Ed25519 |
| **JWS** (JSON) | RFC 7515 | Firmar tokens M2M, API requests entre daemons | EdDSA Ed25519 |
| **JAdES** (JSON Advanced) | ETSI TS 119 182 | Firmar documentos JSON con validez legal | EdDSA Ed25519 |

### 2.2 Niveles de Firma (Perfiles ETSI)

| Perfil | Descripción | Cuándo usarlo |
|--------|------------|--------------|
| **B-B (Basic)** | Firma básica sin timestamp | Documentos internos, logs |
| **B-T (Timestamp)** | Firma con sello de tiempo | Reportes, auditoría |
| **B-LT (Long-Term)** | Firma + timestamp + evidencia de validez (CRL/OCSP) | Contratos, facturas |
| **B-LTA (Long-Term Archive)** | B-LT + re-sellado periódico | Documentos fiscales (>10 años) |

### 2.3 Algoritmos (NIST SP 800-186)

| Algoritmo | Curva | Seguridad | Uso en SBOS |
|-----------|-------|----------|------------|
| **EdDSA Ed25519** | Curve25519 | 128 bits | **Recomendado** — firma interna, JWS M2M, certificados leaf |
| **EdDSA Ed448** | Curve448 | 224 bits | Alto valor, largo plazo |
| **ECDSA P-256** | NIST P-256 | 128 bits | Compatibilidad con sistemas externos |
| **RSA-3072** | — | 128 bits | Solo para ADSIB (firma externa Bolivia) |
| **ML-DSA-65** (FIPS 204) | Post-quantum | 192 bits | Futuro (planeado 2027-2028) |

---

## 3. Jerarquía de CA Interna (4 Niveles)

```
Nivel 0 — Root CA (Offline)
  │  Clave en HSM físico. Solo se enciende para firmar CSRs.
  │  TTL: 10 años. Rotación: cross-signing
  │
  ├── Nivel 1 — Sub-CA de Identidad
  │     Emite certificados de usuario (personas)
  │     TTL: 3 años. Role: clientAuth, emailProtection
  │
  ├── Nivel 1 — Sub-CA de Dispositivos
  │     Emite certificados mTLS para banexus, IoT
  │     TTL: 1 año. Role: clientAuth (mTLS)
  │
  ├── Nivel 1 — Sub-CA de Servicios (M2M)
  │     Emite certificados para daemons (bos, bkernel, biedata...)
  │     TTL: 6 meses. Role: clientAuth, serverAuth
  │
  └── Nivel 1 — Sub-CA de Firma
        Emite certificados de firma digital (non-repudiation)
        TTL: 1 año. Role: digitalSignature, contentCommitment
```

### 3.1 Configuración en Vault

```bash
# 1. Root CA (offline — solo en inicialización)
vault secrets enable -path=pki-root pki
vault write pki-root/root/generate/internal \
    common_name="SBOS Root CA" \
    key_type=ed25519 \
    ttl=87600h  # 10 años

# 2. Intermediate CA — Firma (dentro de Vault)
vault secrets enable -path=pki-signing pki
vault write pki-signing/intermediate/generate/internal \
    common_name="SBOS Signing CA" \
    key_type=ed25519 \
    ttl=43800h  # 5 años
vault write pki-root/root/sign-intermediate \
    csr=@pki-signing.csr \
    format=pem_bundle \
    ttl=43800h

# 3. Role para certificados de firma de usuario
vault write pki-signing/roles/user-signing \
    key_type=ed25519 \
    key_usage="DigitalSignature,ContentCommitment" \
    ext_key_usage="emailProtection" \
    ttl=8760h  # 1 año

# 4. Emitir certificado para usuario
vault write pki-signing/issue/user-signing \
    common_name="juan.perez@sbos.skull.bo" \
    ttl=8760h
```

---

## 4. Flujos de Firma

### 4.1 Firma de Documento PDF (PAdES B-T)

```
1. Usuario sube documento PDF al Core UI
2. bAuth calcula hash SHA-256 del documento
3. bAuth solicita firma a Vault Transit:
   vault write transit/sign/signing-key input=$(base64 <<< $hash)
4. Vault firma dentro de su espacio (clave nunca sale)
5. bAuth recibe la firma Ed25519
6. bAuth solicita timestamp a Vault PKI (o RFC 3161 TSA):
   vault write pki-signing/issue/timestamp
7. bAuth incrusta firma + timestamp en el PDF
8. Documento sellado con PAdES B-T
9. Auditoría: signature_event (user_id, doc_hash, timestamp)
```

### 4.2 Firma M2M (JWS RFC 7515)

```
1. bKernel necesita firmar un evento antes de publicarlo
2. bKernel → bAuth JSON-RPC: bauth.sign.internal.jws(payload)
3. bAuth construye JWS:
   {
     "protected": base64({"alg":"EdDSA","kid":"sbos-signing-2026"}),
     "payload": base64(event_json),
     "signature": base64(Ed25519_sign(protected + "." + payload))
   }
4. bAuth firma via Vault Transit (clave nunca sale)
5. Retorna JWS compacto a bKernel
6. bKernel publica evento firmado en Redis Stream
7. Consumidor verifica firma contra JWKS público
```

### 4.3 Firma de Lote (Batch Signing)

```
1. Admin necesita firmar 1000 documentos (ej: facturas del día)
2. bauthctl sign batch --input=facturas/ --profile=PAdES-B-T
3. bAuth procesa en paralelo (hasta 50 concurrentes)
4. Cada documento: hash → sign via Vault Transit → timestamp → embed
5. Reporte final: 1000 firmados, 0 errores, 2min 30s
```

---

## 5. Verificación de Firmas

### 5.1 Verificación Local

```
1. Receptor recibe documento firmado
2. Extrae firma + certificado del documento
3. Verifica cadena de confianza:
   Leaf Cert → Intermediate CA → Root CA (offline, pre-distribuida)
4. Verifica firma criptográfica:
   Ed25519_verify(public_key, hash, signature)
5. Verifica timestamp (si aplica)
6. Verifica CRL/OCSP (si perfil B-LT o superior)
7. Resultado: VÁLIDO / INVÁLIDO / CADUCADO / REVOCADO
```

### 5.2 JWKS Endpoint Público

```
GET /.well-known/jwks.json
{
  "keys": [{
    "kid": "sbos-signing-2026",
    "kty": "OKP",
    "crv": "Ed25519",
    "x": "base64url_encoded_public_key",
    "use": "sig",
    "alg": "EdDSA"
  }]
}
```

---

## 6. Rotación de Claves de Firma

### 6.1 Dual-Signing (Zero-Downtime)

```
Fase 1 — Nueva clave
  vault write pki-signing/roles/user-signing key_type=ed25519
  Genera K2. Agrega K2_pub a JWKS.

Fase 2 — Overlap (24h)
  Ambas claves K1 y K2 válidas.
  Firmar con K2. Verificar con K1 y K2.

Fase 3 — Cleanup
  Remover K1_pub de JWKS.
  K1 solo para verificación de firmas antiguas.
```

---

## 7. Integración con B25

| Átomo B25 | Descripción | Estándar |
|-----------|------------|---------|
| **B25.T01** | Vault PKI Engine — 4 niveles (Root + 3 Sub-CAs) | NIST SP 800-186, Vault PKI |
| **B25.T02** | Motor Interno — Firmar documentos (PAdES/XAdES/CAdES) | ETSI EN 319 102/132/142 |
| **B25.T03** | Motor Interno — JWS (JSON Web Signature) para M2M | RFC 7515 |
| **B25.T06** | Gestión de Certificados ADSIB en Vault (externo) | ADSIB-FD-POLT-015 |
| **B25.T07** | API JSON-RPC dual — 9 métodos de firma | ADR-020 |
| **B25.T08** | Tests integrales — firma interna + externa end-to-end | BAUTH-050 |

---

## 8. Referencias

- [NIST SP 800-186 — Recommendations for Discrete Logarithm-Based Cryptography: Elliptic Curves](https://csrc.nist.gov/publications/detail/sp/800-186/final)
- [ETSI EN 319 142-2 V1.2.1 (Jul 2025) — PAdES digital signatures Part 2](https://standards.iteh.ai/catalog/standards/etsi/69c69b76-f8c6-49ef-a5e5-f1ee75d94cd4/etsi-en-319-142-2-v1-2-1-2025-07)
- [ETSI EN 319 132 — XAdES digital signatures](https://www.etsi.org/standards-search)
- [ETSI EN 319 122 — CAdES digital signatures](https://www.etsi.org/standards-search)
- [ETSI TS 119 182 — JAdES digital signatures](https://www.etsi.org/standards-search)
- [RFC 7515 — JSON Web Signature (JWS)](https://datatracker.ietf.org/doc/html/rfc7515)
- [RFC 8037 — CFRG ECDH and Signatures in JOSE (Ed25519)](https://datatracker.ietf.org/doc/html/rfc8037)
- [HashiCorp Vault PKI — Build Your Own CA](https://developer.hashicorp.com/vault/tutorials/pki/pki-engine)
- [HashiCorp Vault PKI — Rotation Primitives (v1.21.x)](https://docs.hashicorp.com/vault/docs/v1.21.x/secrets/pki/rotation-primitives)
- [HashiCorp Vault Transit — Sign/Verify API](https://developer.hashicorp.com/vault/api-docs/secret/transit#sign-data)
- [NIST SP 800-57 Part 1 Rev.6 (draft 2026) — Key Management](https://csrc.nist.gov/pubs/sp/800/57/pt1/r6/ipd)
- [FIPS 204 — Module-Lattice-Based Digital Signature Standard (ML-DSA)](https://csrc.nist.gov/pubs/fips/204/final)

---

*SKULL · SBOS · SBOS-BAUTH-FIRMA-DIGITAL-INTERNA-v1.0 · Junio 2026*
