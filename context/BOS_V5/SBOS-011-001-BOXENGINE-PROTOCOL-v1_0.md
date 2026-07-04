# SBOS-011-001
## Anexo: Box Engine, Ciclo de Vida y Protocolo con Sistemas Externos
### Especificación de Nivel de Código para SBOS Data Integration

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-011-001
**Complementa:** SBOS-011-INEXDATA-v3_0.md, SBOS-011-Tributario-SIAT-AFIP-SAT.md

---

## 1. Box Engine — Motor de Ejecución de Cajas

### 1.1 Fases del Engine

Cada Caja (Box) se ejecuta en 6 fases secuenciales. Si una fase falla, el engine evalúa la política de error antes de continuar.

```
FASE 1: VALIDATE
  Lee box_engine.yml + manifest.yml
  Valida esquema, campos requeridos, credenciales disponibles
  FALLA → ABORT (caja malformada, no se ejecuta)

FASE 2: AUTHENTICATE
  Obtiene credenciales del sistema externo desde Vault
  Ejecuta autenticación (OAuth2, API key, certificado mTLS)
  FALLA → RETRY con exponential backoff (max 3 intentos)
  FALLA definitiva → DLQ + alerta

FASE 3: EXTRACT
  Descarga datos del sistema externo
  Para import: API call / SFTP download / webhook receive
  Para export: query a PostgreSQL local
  Almacena en buffer temporal (/tmp/biedata/<job_id>/)
  FALLA → RETRY (servicio externo puede estar caído)

FASE 4: TRANSFORM
  Aplica reglas de transformación definidas en box_engine.yml
  Mapeo de campos, conversión de tipos, validación de esquema
  Genera archivo en formato destino (JSON, XML, CSV)
  FALLA → ABORT (datos inválidos, no se puede transformar)

FASE 5: LOAD
  Para import: escribe en PostgreSQL (INSERT/UPSERT)
    → bkernel detecta vía WAL y propaga automáticamente
  Para export: envía al sistema externo (API POST / SFTP upload)
  FALLA → RETRY para envío externo / ABORT para escritura local

FASE 6: AUDIT
  Registra resultado en biedata_audit_log
  Emite evento Redis: biedata:job_completed
  Limpia buffer temporal
  SIEMPRE se ejecuta (incluso si fase anterior falló)
```

### 1.2 Formato del box_engine.yml

```yaml
# /etc/bos/blibs/biedata/boxes/siat_invoice_export/box_engine.yml
box:
  id: "SIAT-EXPORT-001"
  name: "Exportación de Facturas a SIAT"
  type: "export"                    # import | export
  schedule: "0 */4 * * *"          # cron: cada 4 horas
  enabled: true
  priority: 10

  authenticate:
    method: "certificate"           # oauth2 | api_key | certificate | basic
    vault_path: "secret/biedata/siat/certificate"
    endpoint: "https://siat.impuestos.gob.bo/api/v2/auth"

  extract:
    source: "postgresql"
    database: "tryton_db"
    query: |
      SELECT i.number, i.date, i.total, i.tax_amount, p.vat_number
      FROM account_invoice i
      JOIN party_party p ON i.party = p.id
      WHERE i.state = 'posted'
      AND i.siat_submitted IS NULL
      AND i.date >= :last_run

  transform:
    - map:
        nroFactura: .number
        fechaEmision: '.date | strftime("%Y-%m-%dT%H:%M:%S")'
        montoTotal: .total
        montoImpuesto: .tax_amount
        nitCliente: .vat_number
    - validate:
        field: nitCliente
        regex: '^\d{7,15}$'
        on_fail: "skip_row"
    - format: "xml"
      template: "resources/siat_factura_template.xml"

  load:
    method: "api_post"
    endpoint: "https://siat.impuestos.gob.bo/api/v2/facturas/envio"
    headers:
      Content-Type: "application/xml"
    response_map:
      cuf: .codigoUnicoFactura
      status: .estado
    on_success:
      update:
        table: "account_invoice"
        set: { siat_submitted: true, siat_cuf: ":cuf" }
        where: "number = :nroFactura"

  error_handling:
    max_retries: 3
    retry_delay_ms: [5000, 15000, 60000]
    circuit_breaker:
      failure_threshold: 5           # abrir circuito tras 5 fallos consecutivos
      recovery_timeout_seconds: 300  # 5 min antes de reintentar
      half_open_requests: 1          # 1 request de prueba en half-open
    on_max_retries: "dlq"
    dlq_table: "biedata_dlq"

  audit:
    log_table: "biedata_audit_log"
    retain_days: 365
    notify_on_failure: true
    notify_channel: "redis:biedata:alerts"
```

---

## 2. Circuit Breaker para Sistemas Externos

```
Estado: CLOSED (normal)
  │
  ├── Request exitosa → reset failure_count
  ├── Request fallida → increment failure_count
  │     ├── failure_count < threshold → RETRY
  │     └── failure_count >= threshold → cambiar a OPEN
  │
Estado: OPEN (circuito abierto — no enviar requests)
  │
  ├── Todas las requests van a DLQ directamente
  ├── Timer: recovery_timeout_seconds
  └── Timer expira → cambiar a HALF_OPEN
  │
Estado: HALF_OPEN (probando reconexión)
  │
  ├── Enviar half_open_requests de prueba
  ├── Request exitosa → cambiar a CLOSED
  └── Request fallida → volver a OPEN
```

---

## 3. Tabla de Auditoría

```sql
CREATE TABLE biedata_audit_log (
    id              BIGSERIAL PRIMARY KEY,
    job_id          UUID NOT NULL,
    box_id          VARCHAR(50) NOT NULL,
    box_type        VARCHAR(10) NOT NULL,     -- import | export
    started_at      TIMESTAMPTZ NOT NULL,
    completed_at    TIMESTAMPTZ,
    status          VARCHAR(20) NOT NULL,      -- success | partial | failed
    rows_processed  INT DEFAULT 0,
    rows_succeeded  INT DEFAULT 0,
    rows_failed     INT DEFAULT 0,
    error_summary   TEXT,
    external_system VARCHAR(100),
    external_endpoint VARCHAR(500),
    duration_ms     INT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 4. Protocolo con Sistemas Tributarios

### 4.1 Bolivia — SIAT (SIN)

```
Autenticación: Certificado digital + NIT empresa
Endpoint: https://siat.impuestos.gob.bo/api/v2/
Formato: XML según esquema XSD del SIN
Operaciones:
  - /facturas/envio → enviar factura (retorna CUF)
  - /facturas/anulacion → anular factura
  - /eventos/significativos → registrar eventos
  - /sincronizacion/catalogo → sincronizar catálogos
Retry: Máximo 3 intentos con backoff
Horario SIAT: 24/7 pero con ventanas de mantenimiento dominicales
```

### 4.2 Argentina — AFIP

```
Autenticación: WSAA (Web Service de Autenticación y Autorización)
  → Requiere certificado X.509 + clave privada
  → Token válido por 12 horas
Endpoint: https://wswhomo.afip.gov.ar/ (homologación) | https://servicios1.afip.gov.ar/ (producción)
Formato: XML SOAP
Operaciones:
  - WSFEv1/FECAESolicitar → solicitar CAE (Código de Autorización Electrónica)
  - WSFEv1/FECompUltimoAutorizado → último comprobante autorizado
Retry: Máximo 3 intentos (AFIP tiene rate limiting estricto)
```

### 4.3 México — SAT

```
Autenticación: e.firma (certificado CSD) + contraseña CIEC
Endpoint: Proveedor PAC (Proveedor Autorizado de Certificación)
Formato: CFDI 4.0 (XML con firma XADES-EPES)
Operaciones:
  - Timbrado → enviar CFDI al PAC → recibir timbre fiscal (UUID)
  - Cancelación → enviar solicitud de cancelación
Retry: Depende del PAC (cada uno tiene sus límites)
```

---

## 5. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Box Engine con 6 fases (validate/authenticate/extract/transform/load/audit), formato completo de box_engine.yml, circuit breaker con 3 estados, tabla de auditoría, y protocolo detallado con SIAT (Bolivia), AFIP (Argentina) y SAT (México).

---

*SKULL · SBOS · SBOS-011-001 · Anexo 001 · v1.0 · Marzo 2026*
