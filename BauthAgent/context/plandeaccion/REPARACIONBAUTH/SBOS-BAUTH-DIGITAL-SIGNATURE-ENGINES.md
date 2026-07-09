# SBOS — Motores de Firma Digital bAuth v1.0
## Doble Motor: Interno (PKI Propia) + Externo (ADSIB/SIN Bolivia)
### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Junio 2026 · Alineado con bAuth v2.0

---

| Campo | Valor |
|---|---|
| **Código** | SBOS-BAUTH-DIGITAL-SIGNATURE-ENGINES-v1_0 |
| **Versión** | 1.0 — especificación inicial de los motores de firma digital |
| **Estado** | ACTIVO |
| **Propósito** | Definir la arquitectura y operación de los dos motores de firma digital de bAuth: Interno (PKI propia vía Vault) y Externo (ADSIB para facturación SIN y entidades externas) |
| **Estándares** | ETSI EN 319 102/122/132/142 (CAdES/XAdES/PAdES) · X.509 PKI (RFC 5280) · Ley 164 Bolivia · DS 1793/3527 · NIST SP 800-186 (EdDSA) · eIDAS (EU) N° 910/2014 · SIN RND 102100000011 |
| **Integra** | Authentication_Framework.json v3.0.0 · SBOS-ROLTEMPLATE-v6_0 · SBOS-USERTEMPLATE-v6_0 · Vault 2.0.1 PKI Engine · Kong 3.9.x |
| **Dependencia** | ADSIB — Agencia para el Desarrollo de la Sociedad de la Información en Bolivia (firmadigital.bo) · ATT — Autoridad de Regulación y Fiscalización de Telecomunicaciones |

---

## PRINCIPIO ABSOLUTO

> **bAuth opera DOS motores de firma digital independientes con propósitos distintos.**
> El Motor Interno firma documentos y datos dentro del ecosistema SBOS.
> El Motor Externo firma documentos destinados a entidades fuera del SBOS,
> especialmente facturas electrónicas para el SIN de Bolivia.
> **Nunca se debe usar el motor equivocado para el contexto equivocado.**

---

## 1. ARQUITECTURA GENERAL

```
┌──────────────────────────────────────────────────────────────────┐
│                      bAuth Signature Service                      │
│                                                                   │
│  ┌─────────────────────────┐    ┌─────────────────────────────┐  │
│  │   MOTOR INTERNO          │    │   MOTOR EXTERNO (SIN/ADSIB) │  │
│  │   (Internal PKI)         │    │   (Bolivia Official PKI)     │  │
│  │                          │    │                              │  │
│  │  • Vault PKI Engine      │    │  • ADSIB Certificates        │  │
│  │  • EdDSA Ed25519         │    │  • RSA 2048/4096 + SHA-256   │  │
│  │  • Certs TTL 24h (M2M)   │    │  • Certs TTL 365 días        │  │
│  │  • Internal CA chain     │    │  • ATT → ADSIB → Signatario  │  │
│  │  • Self-managed CRL/OCSP │    │  • ADSIB CRL/OCSP externos   │  │
│  │                          │    │                              │  │
│  │  Formatos:                │    │  Formatos:                   │  │
│  │  • PAdES (PDF internos)  │    │  • XAdES (XML SIN factura)   │  │
│  │  • XAdES (XML datos)     │    │  • PAdES (PDF factura)       │  │
│  │  • CAdES (binarios)      │    │  • CAdES (archivos fiscales) │  │
│  │  • JWS (JWT firmados)    │    │                              │  │
│  └─────────────────────────┘    └─────────────────────────────┘  │
│                                                                   │
│  Consumidores:                     Consumidores:                   │
│  • bos-agent (sagas, fichas)      • bosctl factura-emitir          │
│  • biedata (orquestación)         • biedata (fiscal.factura.emitir)│
│  • bkernel (eventos CDC)          • SmartTax (facturación)         │
│  • bauth (sincronización KC)      • Portal cliente (descarga PDF)  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 2. MOTOR INTERNO — PKI Propia vía Vault

### 2.1 Propósito y Alcance

El Motor Interno firma digitalmente documentos, eventos y datos que circulan
**exclusivamente dentro del ecosistema SBOS**. Sus certificados son emitidos por
la CA interna alojada en Vault PKI Engine.

**Usos autorizados:**
- Firmar sagas de instalación de fichas (bos-agent → .sbos_state.json)
- Firmar eventos CDC antes de publicar en Redis Streams (bkernel)
- Firmar respuestas JSON-RPC entre daemons (biedata, bos, bauth)
- Firmar logs de auditoría inmutables (ctx-orchestrator)
- Firmar documentos internos: reportes, contratos entre tenants, políticas
- Firmar JWT internos para service-to-service (M2M)

### 2.2 Jerarquía de Certificación Interna

```
SBOS Root CA (Vault PKI — offline, 10 años)
  │
  ├── SBOS Internal Sub-CA (Vault PKI — online, 5 años)
  │     │
  │     ├── Daemon Certificates (TTL 24h, ECDSA P-384)
  │     │   • bos-agent, bauth-daemon, bkernel-daemon, biedata-daemon,
  │     │     bsearch-daemon, bhnexus-daemon, banexus-daemon
  │     │
  │     ├── Service Account Certificates (TTL 90 días, ECDSA P-256)
  │     │   • ctx-orchestrator, ctx-validator, prometheus-collector
  │     │
  │     ├── Admin User Certificates (TTL 180 días, EdDSA Ed25519)
  │     │   • SU, SYS N1-N2
  │     │
  │     └── Application Certificates (TTL 365 días, EdDSA Ed25519)
  │         • biedata-saga, bos-state-manager, kong-admin
  │
  └── SBOS Code Signing CA (offline, 5 años)
        └── bosctl binary signing, daemon binary signing
```

### 2.3 Algoritmos y Parámetros

| Elemento | Algoritmo | Parámetros | Estándar |
|----------|----------|-----------|---------|
| **Firma** | EdDSA Ed25519 | Curve25519, 128-bit security | NIST SP 800-186 §3.2.1, RFC 8032 |
| **Firma (legacy)** | ECDSA P-256 | NIST P-256 curve | NIST SP 800-186 §3.1 |
| **Hash** | SHA-256 / SHA-384 | 256/384 bits | FIPS 180-4 |
| **Certificado** | X.509 v3 | Extensions: Key Usage, EKU, SAN, CRL DP, OCSP | RFC 5280 |
| **CRL** | X.509 CRL v2 | TTL 24h, actualización automática | RFC 5280 §5 |
| **OCSP** | OCSP Responder | Vault PKI built-in | RFC 6960 |

### 2.4 Perfiles de Firma

| Perfil | Formato | Nivel | Uso principal |
|--------|---------|-------|--------------|
| **INT-B** | PAdES-B / XAdES-B / CAdES-B | Basic | Firma simple de documentos internos. Sin timestamp. |
| **INT-T** | PAdES-T / XAdES-T / CAdES-T | Timestamp | Añade sello de tiempo confiable (Vault TimeStamp). Recomendado para logs y sagas. |
| **INT-LT** | PAdES-LT / XAdES-LT / CAdES-LT | Long-Term | Incluye certificados + CRL/OCSP. Verificable tras expiración del certificado. Para auditoría. |
| **INT-JWS** | JWS (JSON Web Signature) | Compact | Firma de payloads JSON. Usado para M2M y API responses. RFC 7515. |

### 2.5 Flujo de Firma Interna

```
1. Solicitud de firma → bAuth Signature Service
   { "document_hash": "sha256:abc...",
     "profile": "INT-T",
     "format": "XAdES",
     "requester_role": "ROL-SYS-BOS-AGENT",
     "purpose": "saga_install_ficha_postgresql" }

2. bAuth Signature Service:
   a. Verifica que requester_role tiene permiso para firmar con este perfil
   b. Recupera certificado vigente del Vault PKI para el rol
   c. Genera firma: sign(hash, private_key) → signature_value
   d. Si perfil ≥ INT-T: añade timestamp vía Vault TimeStamp
   e. Si perfil ≥ INT-LT: embeBE certificados + CRL/OCSP
   f. Construye contenedor de firma (PAdES/XAdES/CAdES/JWS)
   g. Registra operación en audit log (ctx_id, role, document_hash, signature_id)
   h. Retorna documento firmado

3. Verificación (cualquier daemon):
   a. Extrae firma del contenedor
   b. Valida certificado contra CRL/OCSP interno
   c. Verifica firma criptográfica: verify(document_hash, signature, public_key)
   d. Si timestamp: verifica que el sello de tiempo es válido
   e. Retorna: { valid: true/false, signer_role, sign_date, cert_expiry }
```

### 2.6 Políticas de Acceso al Motor Interno

| Tier | Perfiles permitidos | Límite diario | Requiere aprobación |
|------|-------------------|---------------|---------------------|
| SU | INT-B, INT-T, INT-LT, INT-JWS | Ilimitado | No |
| SYS N1-N2 | INT-B, INT-T, INT-LT, INT-JWS | 10,000 | No |
| SYS N3 | INT-B, INT-T, INT-JWS | 1,000 | > 100/día |
| SYS N4 (M2M) | INT-T, INT-JWS | Ilimitado (automático) | No |
| BIZ N3-N5 | INT-B (solo docs internos) | 100 | Sí (admin tenant) |
| BIZ N1-N2 | No autorizado | 0 | N/A |
| EXT N0 | No autorizado | 0 | N/A |

---

## 3. MOTOR EXTERNO — ADSIB / SIN Bolivia

### 3.1 Propósito y Alcance

El Motor Externo firma digitalmente documentos destinados a entidades **fuera del
ecosistema SBOS**, con validez legal plena según la **Ley N° 164 de Bolivia**.
Utiliza certificados emitidos por **ADSIB** (Entidad Certificadora Pública) bajo
la jerarquía de la **ATT** (Entidad Certificadora Raíz).

**Usos autorizados:**
- Emitir facturas electrónicas para el SIN (Sistema de Facturación Virtual)
- Firmar notas de crédito/débito fiscales
- Firmar documentos de exportación (NITEX, SENAVEX)
- Firmar contratos con entidades externas (proveedores, clientes, gobierno)
- Firmar declaraciones juradas y comunicaciones oficiales
- Firmar documentos para licitaciones públicas (SICOES)

### 3.2 Jerarquía de Certificación — Infraestructura Nacional PKI Bolivia

```
ATT — Entidad Certificadora Raíz (ECR)
│   Certificado raíz auto-firmado. Vigencia: 20 años.
│   Regulada por: ATT-DJ-CON SCD 1/21
│
└── ADSIB — Entidad Certificadora Pública
    │   Certificado emitido por ATT. Vigencia: 10 años.
    │   Opera: firmadigital.bo
    │   Política: ADSIB-FD-POLT-015 v2.3 (Sept 2024)
    │
    ├── Certificado Persona Natural (vigencia: 1 año)
    │   • Titular: ciudadano boliviano mayor de edad
    │   • Clave: RSA 2048-bit mínimo
    │   • Hash: SHA-256
    │   • Nivel Normal: software
    │   • Nivel Alto: hardware token/HSM (FIPS 140-2)
    │
    ├── Certificado Persona Jurídica (vigencia: 1 año)
    │   • Titular: representante legal de empresa
    │   • Clave: RSA 2048-bit mínimo (4096 recomendado)
    │   • Hash: SHA-256
    │   • Nivel Alto: HSM homologado ATT obligatorio
    │   • Usado para facturación electrónica SIN
    │
    └── Certificado Firma Digital Automática (vigencia: 1 año)
        • Titular: persona jurídica (delegado a sistema)
        • Clave: RSA 2048-bit
        • Modo: desatendido (firma por lote)
        • Usado para emisión masiva de facturas
```

### 3.3 Requisitos Legales y Técnicos para Facturación Electrónica SIN

| Requisito | Detalle | Base Legal |
|-----------|---------|-----------|
| **Certificado digital** | Emitido por ADSIB (u otra EC autorizada por ATT). Vigencia 1 año. | Ley 164 Art.83, DS 1793 |
| **Modalidad SIN** | Facturación Electrónica en Línea (SFV) | RND 102100000011 |
| **Formato documento** | XML 1.0 UTF-8, validado contra esquema XSD del SIN | SIN SFV Specification |
| **Firma XML** | XAdES-BES (Basic Electronic Signature) enveloped dentro del XML de factura | ETSI EN 319 132, SIN Anexo Técnico |
| **Hash** | SHA-256 | FIPS 180-4 |
| **Algoritmo de firma** | RSA-SHA256 (PKCS#1 v1.5) | RFC 3447, requerido por ADSIB |
| **CUFD** | Código Único de Facturación Diaria — emitido por SIN cada 24h | SIN SFV API |
| **Código QR** | QR en formato impreso con URL de verificación SIN | SIN Especificación QR |
| **Dosificación** | Solicitud previa al SIN. Rango de números autorizados. | RND 102100000020 |
| **Archivo** | Conservar facturas firmadas por 8 años mínimo (Código de Comercio) | Ley 164, Código de Comercio Art.44 |

### 3.4 Formato de Firma XAdES para Factura SIN

**Estructura del XML firmado (conceptual):**

```xml
<facturaElectronica xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <!-- Datos de la factura -->
  <cabecera>
    <nitEmisor>1234567890</nitEmisor>
    <razonSocialEmisor>EMPRESA ACME S.A.</razonSocialEmisor>
    <numeroFactura>12345</numeroFactura>
    <cufd>ABCD1234EFGH5678</cufd>
    <fechaEmision>2026-06-20T10:30:00</fechaEmision>
    <!-- ... resto de campos SIN ... -->
  </cabecera>
  <detalle>...</detalle>

  <!-- Firma XAdES enveloped: el Signature envuelve la factura -->
  <Signature xmlns="http://www.w3.org/2000/09/xmldsig#">
    <SignedInfo>
      <CanonicalizationMethod Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/>
      <SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
      <Reference URI="">
        <Transforms>
          <Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>
        </Transforms>
        <DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
        <DigestValue>base64_encoded_hash</DigestValue>
      </Reference>
    </SignedInfo>
    <SignatureValue>base64_encoded_signature</SignatureValue>
    <KeyInfo>
      <X509Data>
        <X509Certificate>base64_encoded_certificate</X509Certificate>
        <X509SubjectName>CN=EMPRESA ACME S.A., O=ACME, C=BO</X509SubjectName>
        <X509IssuerSerial>...</X509IssuerSerial>
      </X509Data>
    </KeyInfo>
  </Signature>
</facturaElectronica>
```

### 3.5 Flujo de Firma para Facturación Electrónica SIN

```
1. Sistema de facturación (SmartTax / Tryton / biedata) genera XML de factura
   según esquema XSD del SIN con todos los datos fiscales.

2. Solicitud de firma externa → bAuth Signature Service
   { "document_xml": "<facturaElectronica>...</facturaElectronica>",
     "engine": "EXTERNAL",
     "profile": "SIN-XAdES-BES",
     "tenant_id": "empresa-acme",
     "certificate_type": "PERSONA_JURIDICA",
     "cufd": "ABCD1234EFGH5678",
     "purpose": "factura_electronica_sin" }

3. bAuth Signature Service:
   a. Verifica que el tenant tiene certificado ADSIB vigente registrado
   b. Verifica que el CUFD es válido y no ha expirado
   c. Verifica que el número de factura está dentro del rango dosificado
   d. Recupera el certificado ADSIB + clave privada del tenant (Vault KV)
   e. Calcula hash SHA-256 del XML canónico
   f. Genera firma RSA-SHA256 con la clave privada
   g. Construye contenedor XAdES enveloped dentro del XML
   h. Genera código QR con URL de verificación del SIN
   i. Registra operación en audit log fiscal (ctx_id, tenant, nro_factura, cufd)
   j. Retorna XML firmado + QR code

4. Transmisión al SIN:
   a. biedata o SmartTax envía el XML firmado al endpoint del SIN
   b. SIN valida: esquema XSD, firma digital, CUFD, dosificación
   c. SIN retorna: aceptación o rechazo con código de error
   d. bAuth registra el resultado en audit log fiscal

5. Entrega al cliente:
   a. PDF con representación impresa (PAdES firmado)
   b. Incluye código QR para verificación en portal SIN
   c. XML firmado disponible para descarga
```

### 3.6 Gestión de Certificados ADSIB en Vault

```
Vault KV v2 Engine — Path: secret/adsib/{tenant_id}/

{
  "certificate_pem": "-----BEGIN CERTIFICATE-----\nMIID...\n-----END CERTIFICATE-----",
  "private_key_pkcs8": "-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----",
  "certificate_type": "PERSONA_JURIDICA",
  "security_level": "ALTO",
  "hsm_serial": "HSM-SBOS-001",
  "issued_by": "ADSIB",
  "issued_to": "EMPRESA ACME S.A.",
  "nit": "1234567890",
  "serial_number": "0x4A3B2C1D",
  "valid_from": "2026-01-15T00:00:00Z",
  "valid_until": "2027-01-15T00:00:00Z",
  "status": "ACTIVE",
  "renewal_due_date": "2026-12-15T00:00:00Z",
  "auto_renewal_enabled": true,
  "adsib_account": "acme@firmadigital.bo",
  "last_crl_check": "2026-06-20T00:00:00Z",
  "last_ocsp_check": "2026-06-20T08:00:00Z"
}
```

**Políticas de gestión:**
- Rotación: reemisión cada 365 días. Máximo 4 reemisiones por certificado.
- Alerta: 30 días antes de la expiración, notificar al Admin Tenant.
- Auto-renovación: si está habilitada, bAuth solicita reemisión a ADSIB.
- CRL check: diario contra ADSIB CRL.
- OCSP check: cada hora para operaciones de firma.
- Si el certificado es revocado por ADSIB → bloquear firma inmediatamente.

### 3.7 Cumplimiento con Ley 164 y Normativa ADSIB

| Requisito Legal | Implementación en bAuth |
|----------------|------------------------|
| **Validez jurídica** (Art. 78-80) | Toda firma con certificado ADSIB vigente tiene plena validez legal |
| **Control exclusivo del signatario** (Art. 78.II) | Clave privada almacenada en Vault con políticas de acceso estrictas |
| **Integridad detectable** (Art. 78.III) | SHA-256 hash + firma RSA. Cualquier modificación invalida la firma |
| **Verificabilidad** (Art. 78.IV) | Clave pública en certificado X.509. Verificación vía ADSIB CRL/OCSP |
| **Certificado vigente** (Art. 82) | Validación automática de vigencia antes de cada firma |
| **Protección de datos personales** | Claves privadas nunca salen de Vault. Acceso auditado. |
| **Conservación 8 años** | Facturas firmadas almacenadas en WORM storage vía Loki + backup S3/MinIO |
| **Firma Automática** (DS 3527) | Soportada para emisión masiva. El tenant delega en bAuth. |

### 3.8 Renovación y Reemisión de Certificados ADSIB

```
bAuth Certificate Lifecycle Manager (cron: semanal)

1. 30 días antes de expiración → Alerta al Admin Tenant (S016)
2. 15 días antes → Segunda alerta + notificación al Admin bAuth (S006)
3. 7 días antes → Si auto-renovación habilitada:
   a. Genera nuevo par de claves RSA-4096 en Vault
   b. Genera CSR (Certificate Signing Request)
   c. Envía CSR a ADSIB vía API o portal firmadigital.bo
   d. Recibe nuevo certificado (vigencia: 365 días)
   e. Almacena en Vault: secret/adsib/{tenant_id}/
   f. Registra en audit log: certificado renovado
   g. El certificado anterior permanece válido hasta su expiración
      (período de solapamiento para validar facturas emitidas)
4. Si no se renueva antes de expiración → bloqueo de firma externa
5. Máximo 4 reemisiones por certificado (política ADSIB)
```

---

## 4. COMPARATIVA DE MOTORES

| Característica | Motor Interno | Motor Externo (ADSIB/SIN) |
|---------------|--------------|--------------------------|
| **Propósito** | Documentos y datos internos SBOS | Documentos para entidades externas (SIN, gobierno, clientes) |
| **Autoridad Certificadora** | Vault PKI (SBOS Root CA) | ATT → ADSIB (PKI Nacional Bolivia) |
| **Algoritmo de firma primario** | EdDSA Ed25519 | RSA-SHA256 (PKCS#1 v1.5) |
| **Hash** | SHA-256 / SHA-384 | SHA-256 |
| **Vigencia del certificado** | 24h (M2M) a 365 días (Apps) | 365 días (1 año) |
| **Validez legal externa** | No (solo dentro del SBOS) | Sí (Ley 164 Bolivia, plena validez jurídica) |
| **Formatos** | PAdES, XAdES, CAdES, JWS | XAdES (SIN), PAdES (PDF cliente) |
| **Timestamp** | Vault TimeStamp (interno) | ADSIB/ATT TimeStamp Authority |
| **CRL/OCSP** | Autogestionado vía Vault | ADSIB externo (diario + cada hora) |
| **Renovación** | Automática vía Vault | Manual o auto-renovación vía ADSIB |
| **Perfiles de firma** | B, T, LT, JWS | BES (SIN), T (contratos), LT (archivo fiscal) |
| **Límite de firmas** | Por tier (ver §2.6) | Por dosificación SIN (rango autorizado) |
| **Auditoría** | ctx_id + audit_log (Loki) | ctx_id + audit_log_fiscal (Loki + WORM) |

---

## 5. CUÁNDO USAR CADA MOTOR

```
¿El documento va a salir del ecosistema SBOS?
  │
  ├── NO → MOTOR INTERNO
  │   • Firmar sagas, estados, eventos CDC
  │   • Firmar logs de auditoría interna
  │   • Firmar contratos entre tenants SBOS
  │   • Firmar JWT para M2M
  │   • Firmar respuestas JSON-RPC entre daemons
  │
  └── SÍ → ¿Es para el SIN o entidad gubernamental boliviana?
        │
        ├── SÍ → MOTOR EXTERNO (obligatorio por ley)
        │   • Factura electrónica SIN
        │   • Nota de crédito/débito fiscal
        │   • Documentos de exportación (NITEX, SENAVEX)
        │   • Declaraciones juradas (IVA, IT, IUE)
        │   • Licitaciones públicas (SICOES)
        │
        └── NO → MOTOR EXTERNO (recomendado para validez legal)
            • Contratos con proveedores externos
            • Documentos para clientes (factura PDF)
            • Comunicaciones oficiales con entidades privadas
```

---

## 6. INTEGRACIÓN CON EL CATÁLOGO DE ROLES

### 6.1 Roles autorizados para firma

| Rol | Motor Interno | Motor Externo | Notas |
|-----|-------------|--------------|-------|
| `ROL-SYS-BOS-AGENT` (S020) | INT-T, INT-JWS | No | Firma sagas y estados |
| `ROL-SYS-BKERNEL-DAEMON` (S028) | INT-T, INT-JWS | No | Firma eventos CDC |
| `ROL-SYS-BIEDATA-DAEMON` (S031) | INT-T, INT-JWS | No | Firma respuestas JSON-RPC |
| `ROL-SYS-CTX-ORCHESTRATOR` (S045) | INT-LT, INT-JWS | No | Firma logs inmutables |
| `ROL-SYS-ADMIN-TENANT` (S016) | INT-B | EXTERNO (todos) | Admin de tenant gestiona certificados |
| `ROL-SYS-ADMIN-FACT-TENANT` (S019) | No | EXTERNO (SIN) | Dueño de facturación electrónica |
| `ROL-FACTURADOR-ELECTRONICO` | No | EXTERNO (SIN) | Emite facturas firmadas |
| `ROL-GERENTE-GENERAL` | INT-B | EXTERNO (contratos) | Firma contratos y documentos oficiales |

### 6.2 Plantilla de configuración en RolTemplate

```json
"digital_signature_config": {
  "internal_engine": {
    "enabled": true,
    "profiles": ["INT-B", "INT-T"],
    "daily_limit": 100,
    "formats": ["PAdES", "XAdES"]
  },
  "external_engine": {
    "enabled": false,
    "profiles": [],
    "daily_limit": 0,
    "requires_dual_approval": false
  }
}
```

---

## 7. API DE FIRMA — JSON-RPC 2.0

Ambos motores se exponen vía la interface dual de bAuth (WebSocket RPC + JSON-RPC 2.0)
sobre el Unix socket `/run/bos/bauth.sock`.

### 7.1 Métodos del Motor Interno

| Método | Descripción |
|--------|------------|
| `bauth.sign.internal.document` | Firmar documento interno (PDF, XML, binario) |
| `bauth.sign.internal.jwt` | Firmar JWT para M2M |
| `bauth.sign.internal.verify` | Verificar firma interna |
| `bauth.sign.internal.certificate` | Obtener certificado del firmante |

### 7.2 Métodos del Motor Externo

| Método | Descripción |
|--------|------------|
| `bauth.sign.external.factura_sin` | Firmar factura electrónica para SIN |
| `bauth.sign.external.document` | Firmar documento para entidad externa |
| `bauth.sign.external.verify` | Verificar firma externa contra ADSIB |
| `bauth.sign.external.certificate_status` | Consultar estado del certificado ADSIB |
| `bauth.sign.external.renew_certificate` | Iniciar renovación de certificado ADSIB |

---

*SKULL · SBOS · SBOS-BAUTH-DIGITAL-SIGNATURE-ENGINES-v1_0 · Junio 2026*
*Estándares: ETSI EN 319 102/122/132/142 · X.509 RFC 5280 · Ley 164 Bolivia · DS 1793/3527 · NIST SP 800-186 · eIDAS EU N° 910/2014 · SIN RND 102100000011*
*Documentos compañeros: BAUTH-CATALOGO-ROLES-EMPRESARIALES.md v2.0 · SBOS-ROLTEMPLATE-v6_0 · Authentication_Framework.json v3.0.0*
