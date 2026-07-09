# SBOS — Motor de Firma Digital Regulatoria Oficial del Estado Boliviano
## Investigación Profesional: ADSIB, Ley 164, SIN, Facturación Electrónica
### SKULL · SBOS · Junio 2026 · v1.0

**Propósito:** Documentar la integración con la infraestructura de firma digital oficial del Estado Boliviano — ADSIB (Agencia para el Desarrollo de la Sociedad de la Información en Bolivia) — para firma con validez jurídica plena, facturación electrónica SIN, y cumplimiento regulatorio.

**Código:** SBOS-BAUTH-FIRMA-DIGITAL-REGULATORIA-BOLIVIA-v1.0
**Referencia:** B25 (Motores de Firma Digital) — Motor Externo

---

## 1. Marco Legal y Regulatorio

### 1.1 Leyes Fundamentales

| Norma | Fecha | Propósito |
|-------|-------|----------|
| **Ley N° 164** | 8/Agosto/2011 | Ley General de Telecomunicaciones, TIC — reconoce validez jurídica de firma digital |
| **Decreto Supremo N° 1793** | 13/Noviembre/2013 | Regula emisión y uso de firmas digitales avanzadas y cualificadas |
| **Ley N° 1036** | 2020 | Actualiza y fortalece el marco de firma electrónica, uso en administración pública |

### 1.2 Tipos de Firma Reconocidos

| Tipo | Nivel | Validez | Uso |
|------|-------|---------|-----|
| **Firma Electrónica Simple (SES)** | Básico | Valor probatorio (debe complementarse) | Contratos consensuales, acuerdos simples |
| **Firma Electrónica Avanzada / Firma Digital Certificada (AES/QES)** | Avanzado | **Mismo valor legal que firma manuscrita** | Facturación SIN, contratos, documentos legales |

### 1.3 Entidades Reguladoras

| Entidad | Rol |
|---------|-----|
| **ATT** (Autoridad de Regulación y Fiscalización de Telecomunicaciones y Transportes) | **Entidad Certificadora Raíz (ECR)** de Bolivia |
| **ADSIB** (Agencia para el Desarrollo de la Sociedad de la Información en Bolivia) | **Entidad Certificadora Pública (ECP)** — emite certificados a ciudadanos y empresas |
| **SIN** (Servicio de Impuestos Nacionales) | Regula y valida facturación electrónica |
| **AGETIC** (Agencia de Gobierno Electrónico y TIC) | Promueve gobierno electrónico |

---

## 2. Infraestructura PKI de Bolivia

### 2.1 Jerarquía de Certificación

```
┌─────────────────────────────────────────────────────────────┐
│             ATT — Entidad Certificadora Raíz (ECR)          │
│             CN = "Entidad Certificadora Raíz de Bolivia"    │
│             RSA-4096, SHA256withRSA                         │
│             Fuera de línea (offline)                         │
│             Solo firma CSRs de ADSIB                         │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│            ADSIB — Entidad Certificadora Pública (ECP)      │
│            CN = "Entidad Certificadora Pública ADSIB"        │
│            RSA-4096, SHA256withRSA                          │
│            Emite certificados a:                             │
│            ├── Personas Naturales                            │
│            ├── Personas Jurídicas (empresas)                 │
│            ├── Servidores / TLS                              │
│            └── Firma de documentos                           │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│            Suscriptores (Ciudadanos, Empresas)               │
│            Certificados X.509 v3 para firma digital         │
│            Clave privada: token criptográfico / archivo PFX  │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Perfil del Certificado ADSIB (X.509 v3, RFC 5280)

| Campo | Valor |
|-------|-------|
| **Versión** | 2 (X.509 v3) |
| **Algoritmo de firma** | SHA256withRSA |
| **Clave pública** | RSA-4096 bits |
| **Emisor** | CN = "Entidad Certificadora Pública ADSIB", O = "ADSIB", C = "BO" |
| **Período de validez** | 1-2 años (renovable) |
| **keyUsage** | digitalSignature, nonRepudiation, keyEncipherment |
| **extKeyUsage** | clientAuth, emailProtection |
| **CRL Distribution Point** | URL de la CRL de ADSIB |
| **OCSP** | URL del servicio OCSP de ADSIB |

### 2.3 Validación de Certificados

| Método | Estándar | Frecuencia | Uso |
|--------|---------|-----------|-----|
| **CRL** (Certificate Revocation List) | RFC 5280 | Diaria (descarga) | Validación offline |
| **OCSP** (Online Certificate Status Protocol) | RFC 6960 | Horaria / por transacción | Validación en tiempo real |
| **Respuesta OCSP** | Firmada por ADSIB | `id-kp-OCSPSigning` (1.3.6.1.5.5.7.3.9) | good / revoked / unknown |

### 2.4 Seguridad de la Infraestructura

- ECR (ATT) completamente **offline** en instalaciones de alta seguridad
- ADSIB opera con módulos criptográficos **FIPS 140-2**
- Sistemas de **detección de intrusos** implementados
- Auditorías periódicas de ATT sobre ADSIB

---

## 3. Facturación Electrónica SIN

### 3.1 Marco Normativo

| RND | Fecha | Propósito |
|-----|-------|----------|
| **RND 102100000011** | 11/08/2021 | Marco legal del Sistema de Facturación Virtual (SFV) |
| **RND 102600000007** | 25/03/2026 | Extiende plazo de obligatoriedad al 01/10/2026 |
| **RND 102500000036** | 11/09/2025 | Extensión previa al 31/03/2026 |

### 3.2 Modalidades de Facturación

| Modalidad | Sigla | ¿Requiere Firma ADSIB? | ¿Requiere SIN en tiempo real? |
|-----------|-------|----------------------|---------------------------|
| **En Línea Electrónica** | **EL** | ✅ **SÍ — Certificado ADSIB obligatorio** | ✅ Sí (modelo clearance) |
| **En Línea Computarizada** | **CL** | ❌ No — usa credenciales SIN | ✅ Sí |
| **Portal Web** | **PW** | ❌ No — usa usuario/contraseña SIN | ✅ Sí |

### 3.3 Códigos Únicos Obligatorios

| Código | Propósito | Formato |
|--------|----------|--------|
| **CUF** | Código Único de Factura — identifica cada factura individualmente | NIT + fecha/hora + sucursal + modalidad + tipo + punto de venta + dígito verificador módulo-11 + Base-16 |
| **CUFD** | Código Único de Facturación Diaria — solicitado al SIN diariamente | Vigencia 24 horas |
| **CUIS** | Código Único de Identificación del Sistema — vincula contribuyente con sistema | Emitido una vez por sistema autorizado |

### 3.4 Proceso de Emisión de Factura (Modalidad EL)

```
1. Obtener certificado digital ADSIB (RSA-4096, SHA256withRSA)
2. Solicitar CUFD diario al SIN
3. Generar XML de factura según esquema XSD del SIN
4. Firmar digitalmente el XML con certificado ADSIB (XAdES-BES)
5. Calcular CUF (módulo-11 + Base-16)
6. Enviar a SIN vía servicio web recepcionFactura
7. SIN valida en tiempo real (modelo clearance)
8. Recibir acuse de validación del SIN
9. Generar PDF con QR (NIT + CUF + número de factura)
10. Entregar representación gráfica al cliente
11. Archivar XML firmado por 5-10 años (retención fiscal)
```

---

## 4. Integración con bAuth (B25 — Motor Externo)

### 4.1 Flujo de Firma de Factura SIN

```
1. ERP (Tryton) genera XML de factura
2. Tryton → bAuth JSON-RPC: bauth.sign.external.factura_sin(xml_payload)
3. bAuth:
   a. Valida XML contra XSD del SIN
   b. Obtiene certificado ADSIB desde Vault KV
   c. Firma XML con XAdES-BES (RSA-SHA256)
   d. Calcula CUF
   e. Registra auditoría: sign_event (user_id, factura_id, cuf)
4. bAuth → Tryton: XML firmado + CUF + QR
5. Tryton → SIN: recepcionFactura(XML_firmado)
6. SIN → Tryton: acuse de validación
7. Tryton almacena XML firmado + acuse para retención fiscal
```

### 4.2 Gestión de Certificados ADSIB en Vault

```
Almacenamiento:
  vault write secret/bauth/adsib/{tenant_id}/cert \
    certificate=@cert.pem \
    private_key=@key.pem \
    csr=@request.csr

Renovación (cada 1-2 años):
  1. Generar nuevo CSR en Vault (RSA-4096)
  2. Enviar CSR a ADSIB (trámite presencial/online)
  3. ADSIB emite nuevo certificado
  4. vault patch secret/bauth/adsib/{tenant_id}/cert certificate=@new_cert.pem
  5. Ambos certificados válidos durante 24h (período de transición)
  6. Revocar anterior (si aplica)

Monitoreo:
  - Alertar 30 días antes de expiración del certificado
  - Verificar CRL diaria (descargar + parsear)
  - Verificar OCSP horario (para facturas de alto valor)
```

### 4.3 Almacenamiento y Retención

| Requisito | Período | Fundamento |
|-----------|--------|-----------|
| XML firmado de factura | 5-10 años | SIN Bolivia, RND 102100000011 |
| Certificado ADSIB caducado | 10 años | Para verificación de firmas antiguas |
| Log de emisión de facturas | 10 años | Auditoría fiscal |
| Acuse de validación SIN | 5-10 años | Evidencia de cumplimiento |

---

## 5. API JSON-RPC del Motor Externo (B25.T07)

```
bauth.sign.external.factura_sin(xml, tenant_id) → {xml_firmado, cuf, qr_base64}
bauth.sign.external.documento(pdf, tenant_id) → {pdf_firmado, signature_id}
bauth.sign.external.verificar(xml_firmado) → {valido, certificado, fecha_firma}
bauth.sign.external.cert_status(cert_serial) → {status, ocsp_response, crl_date}
bauth.sign.external.renew_cert(tenant_id) → {csr, request_id}
```

---

## 6. Estándares Aplicables

| Estándar | Uso |
|----------|-----|
| **RFC 5280** | Perfil de certificados X.509 v3 + CRL |
| **RFC 6960** | OCSP — verificación de estado en línea |
| **XAdES-BES** (ETSI EN 319 132) | Firma XML de factura SIN |
| **PAdES-B-T** (ETSI EN 319 142-2 V1.2.1 Jul 2025) | Firma PDF para documentos legales |
| **FIPS 140-2** | Módulos criptográficos de ADSIB |
| **RSA-4096 + SHA256withRSA** | Algoritmo requerido por ADSIB |
| **ISO 3166** | Código de país C=BO |
| **PKCS#1** | RSA Cryptography Standard |
| **RFC 6238 / RFC 4226** | TOTP/HOTP para autenticación adicional en trámites SIN |

---

## 7. Integración con B25

| Átomo | Descripción | Estado |
|-------|------------|--------|
| **B25.T04** | Motor Externo — Firmar factura SIN (XAdES-BES en XML) | 🔴 |
| **B25.T05** | Motor Externo — Firmar documentos legales (PAdES para clientes) | 🔴 |
| **B25.T06** | Gestión de Certificados ADSIB en Vault | 🔴 |
| **B25.T07** | API JSON-RPC dual — 9 métodos de firma (4 internos + 5 externos) | 🔴 |
| **B25.T08** | Tests integrales — firma interna + externa end-to-end | 🔴 |

---

## 8. Referencias

- [Ley N° 164 — Ley General de Telecomunicaciones, TIC (2011)](https://www.lexivox.org/norms/BO-L-N164.xhtml)
- [Decreto Supremo N° 1793 (2013)](https://www.lexivox.org/norms/BO-DS-1793.xhtml)
- [Ley N° 1036 — Actualización firma electrónica (2020)](https://www.lexivox.org/)
- [ADSIB — Agencia para el Desarrollo de la Sociedad de la Información](https://www.adsib.gob.bo)
- [Firma Digital Bolivia — Portal Oficial](https://www.firmadigital.bo)
- [ADSIB — Declaración de Prácticas de Certificación v2.2 (2021)](https://www.firmadigital.bo/assets/declaracion-de-practicas-de-certificacion-2021.pdf)
- [SIN Bolivia — SIAT (Sistema de Impuestos Nacionales)](https://siat.impuestos.gob.bo)
- [RND 102100000011 — Sistema de Facturación Virtual (2021)](https://www.impuestos.gob.bo)
- [RND 102600000007 — Extensión plazo facturación electrónica (Mar 2026)](https://www.impuestos.gob.bo)
- [RFC 5280 — X.509 PKI Certificate and CRL Profile](https://datatracker.ietf.org/doc/html/rfc5280)
- [RFC 6960 — OCSP](https://datatracker.ietf.org/doc/html/rfc6960)
- [ETSI EN 319 132 — XAdES Digital Signatures](https://www.etsi.org/standards-search)
- [ETSI EN 319 142-2 V1.2.1 (Jul 2025) — PAdES Part 2](https://standards.iteh.ai/catalog/standards/etsi/69c69b76-f8c6-49ef-a5e5-f1ee75d94cd4/etsi-en-319-142-2-v1-2-1-2025-07)

---

*SKULL · SBOS · SBOS-BAUTH-FIRMA-DIGITAL-REGULATORIA-BOLIVIA-v1.0 · Junio 2026*
*Confidencial — Propiedad de SKULL Desarrollo de Software*
