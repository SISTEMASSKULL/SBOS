# SBOS-024-DAEMON-BIEDATA
## SBOS Data Integration: Federated Batch Exchange — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026
### ENRIQUECIDO V8 — con V5 + Smart* Enrichment

---

## 1. Identidad del Daemon

| Campo | Valor |
|---|---|
| Nombre | SBOS Data Integration: Federated Batch Exchange |
| Daemon | `biedata` |
| Servicio | `biedata.service` |
| Lenguaje | **Rust 1.85+ (Edition 2024)** |
| Unidad declarativa | Caja (Box) |
| Directorio | `/etc/bos/blibs/biedata/boxes/<import|export>/<nombre_box>/` |
| Config | `/etc/bos/blibs/biedata/biedata.toml` |
| BD propia | `biedata_db` (historial de ejecuciones) |

Metáfora: SBOS Data Integration es la **aduana soberana** del SBOS. Todo dato que entra o sale pasa por SBOS Data Integration. Las cajas declaran las reglas, la aduana las ejecuta.

## 2. Separación con bKernel

| bKernel | biedata |
|---|---|
| Observa cambios internos (WAL) | Ingesta desde fuentes externas |
| Sincroniza apps del stack entre sí | Conecta stack con mundo exterior |
| Opera de forma continua (loop infinito) | Opera por eventos (schedule, file_watch, manual) |
| Conocimiento en YAML | Conocimiento en YAML + .so compilados |

Import: biedata escribe en BDs del stack con `origin='biedata'` → bKernel detecta vía WAL y propaga.
Export: biedata lee del stack con credenciales SELECT-only → entrega al sistema externo.

## 3. Principios Arquitectónicos

| # | Principio | Consecuencia si viola |
|---|---|---|
| P1 | Un daemon, dos direcciones (import/export) | — |
| P2 | La caja es la unidad de conocimiento | Motor no sabe qué es FoxPro/SIAT |
| P3 | box_engine.yml = intención. box_catalog.so = lógica | — |
| P4 | Firma de origen obligatoria en import (origin='biedata') | bKernel no puede distinguir datos biedata de apps |
| P5 | Export es solo lectura (SELECT only) | Modificación accidental datos producción |
| P6 | Idempotencia obligatoria (UPSERT) | Duplicados al re-ejecutar |
| P7 | Binario = motor, .so = conocimiento | Recompilar para nueva integración |
| P8 | Auditoría completa en biedata_db | Sin trazabilidad fiscal/compliance |

## 4. Modelo de Cajas

```
/etc/bos/blibs/biedata/boxes/
├── import/
│   ├── clientes_excel/           ← manifest.yml + box_engine.yml + box_catalog.so + resources/
│   ├── items_foxpro/
│   ├── empleados_mysql/
│   └── productos_api_proveedor/
└── export/
    ├── facturas_siat/
    ├── nomina_banco/
    └── reporte_auditoria/
```

Agregar integración #50 = crear carpeta en boxes/. Motor no cambia.

### 4 Contratos de una Caja

| Contrato | Archivo | Función |
|---|---|---|
| Identidad | manifest.yml | Qué es, cómo se dispara, qué necesita |
| Temporal | box_engine.yml | Fases en orden declarativo |
| Lógica | box_catalog.so | Tareas específicas (dlopen) |
| Conocimiento | resources/ | Mappings, plantillas, schemas validación |

## 5. manifest.yml — Especificación Completa

### Export (facturas SIAT)
```yaml
identity:
  id: "export_facturas_siat"
  name: "Exportar Facturas al SIAT Bolivia"
  version: "1.2"
  direction: "export"
  category: "fiscal"
trigger:
  type: schedule
  cron: "0 8 1 * *"
source:
  app: tryton
  credentials: readonly
destination:
  type: http_api
  url_env: "SIAT_API_URL"
  auth: certificate
requirements:
  depends_on: [{ type: ficha, target: tryton, state: installed }]
  env_vars: [SIAT_API_URL, SIAT_CERT_PATH, SIAT_KEY_PATH, EMPRESA_NIT]
governance:
  category: 2
  notify_on: [success, failure]
health:
  last_execution_max_age_hours: 36
```

### Import (clientes Excel)
```yaml
identity:
  id: "import_clientes_excel"
  direction: "import"
  category: "crm"
trigger:
  type: file_watch
  watch_path: "/mnt/biedata/incoming/clientes/"
  pattern: "clientes_*.xlsx"
destination:
  app: espocrm
  table: accounts
  upsert_key: email
  origin: biedata
governance:
  category: 1
  notify_on: [success, partial, failure]
```

## 6. box_engine.yml — Fases Declarativas

### 6 Fases del Motor

```
VALIDATE    → esquema, campos, credenciales. Falla → ABORT
AUTHENTICATE → Vault credentials, OAuth2/API key/mTLS. Falla → RETRY 3x → DLQ
EXTRACT     → API call / SFTP / query SQL / webhook. Falla → RETRY
TRANSFORM   → mapping, conversión, validación esquema. Falla → ABORT
LOAD        → Import: UPSERT con origin. Export: POST/SFTP. Falla → RETRY/ABORT
AUDIT       → Registra en biedata_db. SIEMPRE se ejecuta.
```

### Ejemplo completo: export facturas SIAT
```yaml
phases:
  prepare:
    tasks:
      - task: "validate_env_vars"          # GLOBAL
        params: { required: [SIAT_API_URL, SIAT_CERT_PATH] }
      - task: "siat_validate_certificate"  # ESPECÍFICA (box_catalog.so)
  read:
    tasks:
      - task: "siat_query_facturas"        # ESPECÍFICA
        params: { mapping: "resources/mapping.yml" }
        output: facturas_data
  transform:
    tasks:
      - task: "apply_mapping"              # GLOBAL
        params: { data: "{facturas_data}", mapping: "resources/mapping.yml" }
        output: facturas_mapped
      - task: "siat_render_xml"            # ESPECÍFICA
        params: { data: "{facturas_mapped}", template: "resources/format.xml" }
        output: facturas_xml
  validate:
    tasks:
      - task: "siat_validate_xml_schema"   # ESPECÍFICA
        on_failure: abort
  deliver:
    tasks:
      - task: "siat_post_facturas"         # ESPECÍFICA
        output: siat_response
  finalize:
    tasks:
      - task: "store_response"             # GLOBAL
      - task: "notify_completion"          # GLOBAL
```

## 7. Box API — Contrato Motor ↔ .so (C ABI)

```c
typedef struct {
    const char* name;
    const char* version;
    const char* direction;
    InExResult (*execute_task)(const char* task_name, const InExContext* ctx, const InExHandles* handles);
    InExResult (*validate)(const InExHandles* handles);
} BiedataBox;

typedef struct {
    const char* box_id;
    const char* run_id;
    const char* params_json;
    const char* outputs_json;
    const char* resources_path;
} InExContext;

BiedataBox* biedata_box_init();  // punto de entrada dlsym()
```

### Tareas globales del motor

| Tarea | Dirección | Descripción |
|---|---|---|
| validate_env_vars | ambas | Variables requeridas existen |
| check_source_connection | ambas | Conexión a app origen |
| detect_incoming_file | import | Detecta archivo en watch_path |
| apply_mapping | ambas | Aplica mapping.yml |
| validate_rows | import | Valida según validation_rules.yml |
| upsert_with_origin | import | INSERT...ON CONFLICT con origin='biedata' |
| store_response | export | Guarda respuesta en biedata_db |
| notify_completion | ambas | Notifica al canal del manifest |
| archive_file | import | Mueve a carpeta archivado |
| log_execution | ambas | Registra ejecución en biedata_db |

## 8. Resources — Conocimiento Cristalizado

### mapping.yml
```yaml
# Export SIAT:
field_map:
  NumeroFactura: source.numero_factura
  MontoTotal: "format_decimal(source.monto_total, 2)"
  NIT: source.nit_cliente

# Import Excel:
field_map:
  name: source.razon_social
  email: "lower(source.correo)"
lookups:
  vendedor_map:
    "Juan Pérez": "juan.perez@empresa.com"
```

### validation_rules.yml
```yaml
rules:
  - field: correo
    required: true
    format: email
  - field: nit
    pattern: "^[0-9]{7,10}$"
```

## 9. biedata_db — Esquema

```sql
CREATE TABLE box_executions (
    id BIGSERIAL PRIMARY KEY,
    box_id TEXT NOT NULL,
    direction TEXT NOT NULL,
    trigger_type TEXT NOT NULL,
    run_id UUID NOT NULL,
    status TEXT NOT NULL,      -- running|success|partial|failed
    records_total INTEGER,
    records_success INTEGER,
    records_failed INTEGER,
    duration_ms INTEGER,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    finished_at TIMESTAMPTZ,
    operator TEXT
);

CREATE TABLE box_row_errors (
    id BIGSERIAL PRIMARY KEY,
    execution_id BIGINT REFERENCES box_executions(id),
    row_number INTEGER,
    phase TEXT,
    field TEXT,
    error TEXT,
    raw_data JSONB
);

CREATE TABLE box_responses (
    id BIGSERIAL PRIMARY KEY,
    execution_id BIGINT REFERENCES box_executions(id),
    response_code INTEGER,
    response_body TEXT,
    delivered_at TIMESTAMPTZ DEFAULT NOW()
);
```

## 10. Motor Binario — Estructura

```
biedata (binario Rust)
├── Event Listener   — Redis Stream, file_watch (inotify), cron, manual
├── Box Resolver     — dado evento → encuentra caja en boxes/
├── Box Loader       — carga manifest + box_engine + box_catalog.so (dlopen)
├── Engine Executor  — ejecuta fases en orden
│   ├── Task Dispatcher — GLOBAL (motor) vs ESPECÍFICA (box_catalog.so)
│   ├── Context Manager — pipeline de outputs entre tareas
│   └── Error Handler   — skip_row | abort | continue
├── Result Emitter   — registra en biedata_db, notifica
└── Hot-Reload (SIGUSR1) — recarga cajas sin reiniciar
```

## 11. Servicio systemd

```ini
[Unit]
Description=SBOS Data Integration — Sovereign Data Integration Engine
After=network.target postgresql.service

[Service]
Type=notify
ExecStart=/usr/local/bin/biedata --config /etc/bos/blibs/biedata/biedata.toml
ExecReload=/bin/kill -USR1 $MAINPID
Restart=always
RestartSec=5
User=biedata
WatchdogSec=60

[Install]
WantedBy=multi-user.target
```

## 12. Stack Tecnológico

| Componente | Crate | Propósito |
|---|---|---|
| Lenguaje | Rust 1.85+ (Edition 2024) | Daemon principal |
| Async | tokio 1.x | Concurrencia I/O |
| Excel reader | calamine 0.32 | XLSX/XLS sin GC pauses (9.4x más rápido que openpyxl) |
| Excel writer | rust_xlsxwriter 0.7 | Reportes XLSX |
| CSV | csv 1.3 + serde | Archivos CSV |
| HTTP | reqwest 0.12 (async) | APIs REST externas |
| XML/SOAP | quick-xml 0.36 | SIAT, AFIP, SAT |
| SFTP | russh 0.44 | Transferencia archivos |
| PostgreSQL | tokio-postgres + deadpool | Escritura con origin |
| Redis | redis-rs (tokio) | Comandos desde bkernel |
| TLS | rustls 0.23 | mTLS para SIAT/AFIP |
| Plugins .so | libloading 0.8 | box_catalog.so |
| Config | toml + serde_yaml | box_engine.yml |
| Logging | tracing | Audit trail |
| Build | cargo --release (MUSL) | Binario estático |

## 13. Catálogo de Cajas de Ejemplo

### Caja 1 — Import: Clientes desde Excel
prepare → read (calamine) → transform (mapping) → validate (email, razón social) → write (UPSERT origin='biedata') → finalize (archivar, notificar). Post-import: bKernel detecta → sincroniza en Tryton.

### Caja 2 — Export: Facturas SIAT Bolivia
prepare (certificado digital) → read (query Tryton posted) → transform (XML SIAT) → validate (XSD oficial) → deliver (POST mTLS) → finalize (registrar respuesta). SIAT requiere XML firmado con certificado AEMP.

### Caja 3 — Import: RRHH desde sistema legacy
prepare → read (MySQL/MSSQL/API) → transform (mapping) → validate → write (UPSERT OrangeHRM) → finalize. Post-import: bKernel → bauth crea usuario KC.

### Caja 4 — Export/Import: Pasarela de Pagos
Export: Tryton → JSON pasarela (Culqi/PayU/MercadoPago) → POST API Key.
Import: webhook confirmación → UPSERT account.payment state. bKernel detecta → libera inventario.

### Flujo A: Migración FoxPro
3,000 items DBF → box_catalog.so abre DBF → mapping → 47 errores (precio=0) skip_row → 2,953 UPSERTs Tryton → bKernel → Saleor + bSearch automático.

## 14. Fronteras Inviolables

| # | Regla | Consecuencia |
|---|---|---|
| D1 | Export = solo lectura | Modificación accidental |
| D2 | Import = UPSERT siempre | Duplicados |
| D3 | origin='biedata' obligatorio | Confusión auditoría |
| D4 | Sin .so sin firma Ed25519 | Código no auditado |
| D5 | Sin decisiones de negocio | Comportamiento no predecible |
| D6 | Sin modificación autónoma de cajas | Sin trazabilidad |
| D7 | Toda ejecución en biedata_db | Sin trazabilidad fiscal |
| D8 | Cero conocimiento en binario | Recompilar para nueva integración |

---

## §15 — ENRIQUECIMIENTO V5: Integración Tributaria y Box Engine Protocol

### V5-1: Integraciones Tributarias LATAM (desde SBOS-011-Tributario-SIAT-AFIP-SAT)

**SIAT Bolivia (facturación fiscal):**
- XML firmado digitalmente con certificado AEMP (Autoridad de Entidad de Certificación)
- Modalidades: Computarizada (CC), Computarizada en Línea (CEL)
- Código de control: generado según algoritmo SIAT con llave de dosificación
- Eventos: envío de facturas, anulación, cierre de punto de venta

**AFIP Argentina:**
- RG 2485 (facturación electrónica): CAE + CAEA
- WSAA: autenticación con certificado digital (Token de Seguridad)
- WSFEv1: facturación electrónica con Código de Autorización Electrónico
- Libro IVA Digital: RG 3685 (compras y ventas)

**SAT México:**
- CFDI 4.0: Comprobante Fiscal Digital por Internet
- CSD (Certificado de Sello Digital) obligatorio
- PAC (Proveedor Autorizado de Certificación) para timbrado
- Complemento de comercio exterior (Carta Porte)

### V5-2: Box Engine Protocol (desde SBOS-011-001-BOXENGINE-PROTOCOL)

**Error handling extendido:**
```yaml
phases:
  validate:
    on_error:
      row_error: "skip_row"        # Salta fila, continúa
      connection_error: "retry"     # Reintenta conexión
      schema_error: "abort"         # Aborta toda la ejecución
```

**Manejo de archivos:**
- `archive_file`: mueve a `/mnt/biedata/archive/<caja>/<fecha>/`
- `quarantine_file`: mueve a `/mnt/biedata/quarantine/` si error de esquema
- `delete_after_import`: elimina archivo fuente (configurable)

### V5-3: INEXDATA como ancestro conceptual de biedata (desde SBOS-011-INEXDATA)

biedata hereda el modelo de integración externa de INEXDATA (SBOS-011 v3.0), formalizando:
- El modelo de cajas (antes "integración") como unidad declarativa
- El motor de 6 fases (antes fases implícitas)
- La C ABI para plugins .so (antes integraciones hardcodeadas)

---

## ENRIQUECIMIENTO Smart* (V8): Integración Tributaria — Especificación Técnica (desde SBOS Smart Tax)

### Smart*-1: Algoritmo CUF de 54 Dígitos (desde SBOS_TAX_C1)

El Código Único de Facturación (CUF) es el identificador fiscal único de cada factura en el sistema SIAT Bolivia. Su generación es responsabilidad de la caja SIAT en biedata.

**Algoritmo completo de 54 dígitos:**

```
PASO 1 — Construir base de 53 caracteres:
  base = nit_emisor                (13 dígitos, padding a 13)
       + nro_factura               (10 dígitos, padding a 10 con leading zeros)
       + nro_autorizacion          (14 dígitos, fijo)
       + fecha_emision             (YYYYMMDDHHmmSS, 14 dígitos)
       + monto_total               (variable, 1+ dígitos sin decimales, sin padding)
  → Total: exactamente 53 caracteres

  INVARIANTE_009: La base debe tener exactamente 53 caracteres.
  Si monto_total tiene más dígitos de los esperados, los caracteres
  sobrantes se toman de nro_autorizacion (acortándolo desde la derecha).

PASO 2 — Calcular dígito verificador (Módulo 11):
  Para i = 0 hasta 52:
    peso = (i % 10) + 1  # ciclo 1..10
    suma += digito(base[52 - i]) * peso
  resto = suma % 11
  digito = 11 - resto
  Si digito == 11 → digito = 0
  Si digito == 10 → digito = 1
  base_54 = base + str(digito)  # ahora 54 caracteres

PASO 3 — Convertir base_54 a hexadecimal (base10 → base16):
  REQUISITO CRÍTICO: Usar bcmath (PHP), NO base_convert()
  base_convert() trunca números > 2^31 — produce CUF inválido.
  cuf_hex = base10_to_base16(base_54, '0123456789ABCDEF')  # bcmath

PASO 4 — Concatenar código de control desde CUFD:
  cuf_final = cuf_hex + codigoControl   # 54 dígitos total
```

**Ejemplo de test vector V01 (verificado contra SIAT):**
```
NIT: 1029889022 → padding a 13: 0001029889022
Número factura: 123 → padding a 10: 0000000123
Número autorización (CUFD): 28102024001 → padding 14: 00028102024001
Fecha emisión: 28/10/2024 13:06:40 → 20241028130640
Monto total: 25000 → sin padding: 25000
Base 53: 00010298890220000000123000281020240012024102813064025000
```

### Smart*-2: INVARIANTE_001 — SHA-256 sobre GZIP, NO sobre XML Raw (desde SBOS_TAX_E1)

**REGLA ABSOLUTA (bug confirmado en legado PHP/C#):**

```
INVARIANTE_001:
  El SHA-256 que firma la factura se calcula sobre el archivo GZIP,
  NO sobre el XML sin comprimir.

  CORRECTO:   sha256_file(gzencode(xml_content))  ✅
  INCORRECTO: sha256_file(xml_content)             ❌ ← bug legado
```

**Implementación en box_catalog.so para SIAT:**
```c
// En la tarea siat_render_xml → siat_validate_xml_schema
// 1. Generar XML
// 2. Firmar digitalmente (XMLDSig) sobre XML sin comprimir
// 3. Comprimir: gzencode(xml_firmado, 9)
// 4. SHA-256: hash('sha256', gz_output)  ← ESTE es el hash correcto
// El XMLDSig va DENTRO del XML (firmado antes de comprimir)
```

### Smart*-3: Protocolo de Empaquetado (desde SBOS_TAX_C2)

Cuatro reglas de empaquetado según modalidad de emisión:

| Regla | codigoEmision | Cantidad | Firma | Algoritmo | Almacenamiento |
|---|---|---|---|---|---|
| **Online** | 1 | 1 | No | GZIP simple | `Factura-{cuf}.xml.gz` |
| **Contingencia** | 2 | ≤500 | No | TAR → GZIP | `{cuf}.xml` dentro de `Paquete_{nro}.tar.gz` |
| **Masiva** | 2 | ≤1000 | No | TAR → GZIP | `{cuf}.xml` dentro de `Paquete_{nro}.tar.gz` |
| **XMLDSig** | 1 o 2 | cualquier | Sí | XMLDSig → GZIP | `Factura-{cuf}.xml.gz` (firmado) |

**INVARIANTE_FIRMA — Orden correcto:**
```
XMLDSig → GZIP  ✅ (firmar ANTES de comprimir)
GZIP → XMLDSig  ❌ (firmar después de comprimir rompe la validación SIAT)
```

**Regla de contingencia:** Si no hay conexión con SIAT tras 3 intentos, el sistema cambia automáticamente a `codigoEmision=2` y empaqueta en batches TAR+GZIP de hasta 500 facturas. Al restaurarse la conexión, los paquetes de contingencia se envían en orden cronológico.

### Smart*-4: Protocolo XMLDSig — Jacobitus Softoken (desde SBOS_TAX_C3)

**Arquitectura de firma digital:**

```
┌──────────────┐     REST localhost:9000      ┌──────────────────┐
│   biedata    │ ──────────────────────────►   │  Jacobitus       │
│  (caja)      │   POST /sign { xml }          │  Softoken        │
│              │ ◄────────────────────────────  │  (PKCS#11        │
│              │   { signed_xml, cert }        │   software)      │
└──────────────┘                               └──────────────────┘
```

- Jacobitus opera como REST service local en `localhost:9000`
- Softoken (token software) — obligatorio para cloud/SaaS. No requiere USB token físico.
- La llave privada NUNCA sale del softoken — firma via PKCS#11
- XMLDSig envolvente (enveloped): `<ds:Signature>` dentro del XML

**Proceso de adquisición de certificado (6 pasos con firmadigital.bo):**
```
1. Generar CSR (Certificate Signing Request)
2. Enviar CSR + documentos legales a firmadigital.bo (Autoridad de Certificación AEMP)
3. AC verifica identidad legal de la empresa (3-5 días hábiles)
4. AC emite certificado X.509v3 con cadena completa
5. Importar certificado al softoken (Jacobitus)
6. Verificar: openssl verify -CAfile cadena.pem cert.pem
```

**Implementación de referencia (PHP — para box_catalog.so equivalente):**
```php
class JacobitusSigner {
    public function sign(string $xml): string {
        $response = Http::post('http://localhost:9000/sign', [
            'xml' => base64_encode($xml),
            'signatureAlgorithm' => 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256',
            'digestAlgorithm' => 'http://www.w3.org/2001/04/xmlenc#sha256',
            'canonicalization' => 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315',
        ]);
        $signed = base64_decode($response['signed_xml']);
        // Verificar firma post-firma (validación interna)
        $dom = new DOMDocument();
        $dom->loadXML($signed);
        if (!$dom->getElementsByTagNameNS('http://www.w3.org/2000/09/xmldsig#', 'Signature')->length) {
            throw new RuntimeException("XMLDSig no encontrado en respuesta de Jacobitus");
        }
        return $signed;
    }
}
```

**Softoken vs Token USB:**

| Aspecto | Token USB | Softoken |
|---|---|---|
| Conexión | USB físico | REST localhost:9000 |
| PKCS#11 | Sí | Sí (emulado con OpenSC) |
| Cloud/SaaS | Incompatible | **Obligatorio** |
| Backup de llave | No posible | Exportable (cifrado con passphrase) |
| Costo | $30-80 USD | Gratuito (software) |
| Recomendación SBOS | Solo staging | **Producción** |

### Smart*-5: Invariantes Fiscales Universales (desde SBOS_TAX_E1)

Diez invariantes que toda caja SIAT en biedata debe implementar:

| ID | Invariante | Consecuencia si se viola |
|---|---|---|
| INVARIANTE_001 | SHA-256 sobre GZIP, no XML raw | Hash incorrecto → factura inválida |
| INVARIANTE_002 | Fecha de emisión debe ser ≤ fecha actual | Rechazo SIAT — fecha futura |
| INVARIANTE_003 | NIT debe cumplir algoritmo de módulo 11 | Rechazo SIAT — NIT inválido |
| INVARIANTE_004 | Importe de la factura debe coincidir con la suma de importes de detalle | Rechazo SIAT — inconsistencia |
| INVARIANTE_005 | El CUF calculado debe coincidir con el CUF registrado | Rechazo SIAT — manipulación |
| INVARIANTE_006 | La cantidad de facturas en contingencia no debe exceder 500 | Rechazo SIAT — límite excedido |
| INVARIANTE_007 | El código de control debe corresponder al CUFD + llave de dosificación | Rechazo SIAT — código inválido |
| INVARIANTE_008 | Los milisegundos en la fecha de emisión deben tener padding a 3 dígitos (001-999) | Rechazo SIAT — formato inválido |
| INVARIANTE_009 | La base para CUF debe tener exactamente 53 caracteres | CUF incorrecto |
| INVARIANTE_010 | Toda factura con monto > 0 debe tener al menos un detalle de línea | Rechazo lógico — factura vacía |

**Invariantes de sector:**
| ID | Sector | Regla |
|---|---|---|
| S14 | ICE (Impuesto al Consumo Específico) | El monto ICE debe calcularse por separado y no incluirse en el monto total del producto |
| S55 | Combustible No Subvencionado | factor_cf = 1.0000 (desde Ley 1718, 10/04/2026) |
| SF6 | factor_cf familia | El crédito fiscal se calcula como `total * factor_cf`, parametrizable por UPDATE SQL en `cat.tipo_documento_sector` |

**12 Reglas ABSOLUTAS para el agente IA (NUNCA violar):**
1. NUNCA modificar el algoritmo CUF sin aprobación SIAT
2. NUNCA modificar la secuencia de empaquetado (XMLDSig → GZIP)
3. NUNCA eliminar o modificar un XML firmado — solo anulación con nueva factura
4. NUNCA reenviar una factura ya aceptada por SIAT
5. NUNCA almacenar llaves privadas en texto plano
6. NUNCA generar facturas sin CUFD/CUF válido
7. NUNCA modificar el formato de fecha (YYYYMMDDHHmmSS)
8. NUNCA emitir factura con NIT no verificado
9. NUNCA modificar el cálculo del código de control
10. NUNCA omitir la verificación de integridad post-firma
11. NUNCA enviar peticiones paralelas al SIAT sin control de concurrencia
12. NUNCA modificar el hash SHA-256 de una factura ya firmada

### Smart*-6: factor_cf — Arquitectura Paramétrica de Crédito Fiscal (desde SBOS_TAX_A3)

El factor_cf es un parámetro en la tabla `cat.tipo_documento_sector` que determina el porcentaje de crédito fiscal aplicable. Su valor se modifica por SQL UPDATE — sin cambiar código.

**Valores por sector:**

| Documento Sector | Descripción | factor_cf |
|---|---|---|
| S12 | Factura con Derecho a Crédito Fiscal (Compras Gravadas) | 1.0000 |
| S37 | Factura de Exportación | 0.7000 |
| S38 | Factura de Venta de Activo Fijo | 1.0000 |
| S39 | Factura de Compras de Activo Fijo | 0.7000 |
| S55 | Combustible No Subvencionado (Ley 1718) | 1.0000 |

**Implementación en caja SIAT:**
```sql
-- Cambiar factor_cf sin desplegar código:
UPDATE cat.tipo_documento_sector 
SET factor_cf = 1.0000 
WHERE id_doc_sector = 'S55';  -- Ley 1718 (10/04/2026)

-- El motor calcula:
-- credito_fiscal = round(total * factor_cf, 2, HALF_UP)
```

### Smart*-7: Matriz de Notas de Ajuste (desde SBOS_TAX_B3)

51 sectores × 4 tipos de nota de ajuste. La caja SIAT en biedata debe implementar la matriz de decisión:

| Tipo de Nota | Código SIN | Propósito | Fórmula de ajuste |
|---|---|---|---|
| Nota 24 — Débito | 24 | Incrementar monto/deuda fiscal | `monto_original + diferencia` |
| Nota 29 — Crédito | 29 | Disminuir monto/disminuir deuda fiscal | `monto_original - diferencia` |
| Nota 47 — Anulación | 47 | Anular totalmente la factura | `monto_original * (-1)` |
| Nota 48 — Reemplazo | 48 | Reemplazar datos sin cambiar monto | Mismo monto, nuevos datos |

**Árbol de decisión para seleccionar nota:**
```
1. ¿La factura original tiene error?
   ├── Sí → ¿Error de monto?
   │   ├── Sí → ¿Aumentar? → Nota 24 (Débito)
   │   │            └── ¿Disminuir? → Nota 29 (Crédito)
   │   └── No (error de datos) → Nota 48 (Reemplazo)
   └── No → ¿Se necesita anular?
       └── Sí → Nota 47 (Anulación)
```

**Campos que NO existen en notas de ajuste (vs factura regular):**
- `codigoControl` — las notas NO tienen código de control
- `cuf` — las notas NO tienen CUF propio (referencian CUF original)
- `dosificacion` — las notas NO tienen dosificación (heredan de la factura original)
- `montoTotalSujetoIva` — no aplica (el ajuste es sobre el total)

### Smart*-8: Normativa Vigente 2026 (desde SBOS_TAX_A1)

La caja SIAT en biedata debe implementar los siguientes cambios regulatorios:

| RND | Fecha | Efecto | Acción en biedata |
|---|---|---|---|
| Ley 1718 | 10/04/2026 | Deroga Art.18 Ley 1356 — Sector 55 CF pasa de 70% a 100% | UPDATE factor_cf = 1.0000 en S55 |
| RND-102600000012 | 13/04/2026 | Implementa cambio S55 en SIAT | Validar CUF con nuevo factor_cf |
| RND-102600000006 | — | No crea nuevo sector — requisito operacional fronterizo | Ninguna (solo config export) |
| RND-102600000010 | — | IUE benefit para sectores tasa cero | Campos adicionales en XML SIAT |

**Estado de implementación (ADR-010):** Tasa Cero Ley 1613 declarado **OUT OF SCOPE** en ADR-010 Final. No implementar.

### Smart*-9: Implementación del Algoritmo CUF en box_catalog.so

**Especificación para la tarea `siat_render_xml` en box_catalog.so:**

```c
// Firma C ABI (compatible con Box API §7)
InExResult siat_render_xml(const char* task_name,
                           const InExContext* ctx,
                           const InExHandles* handles) {
    // 1. Obtener params del contexto
    const char* data = ctx->params_json;  // { facturas: [...], dosificacion: {...} }
    
    // 2. Para cada factura, generar XML + CUF + firmar
    for each factura:
        // 2a. Construir base 53 caracteres (INVARIANTE_009)
        // 2b. Módulo 11 → dígito verificador → base_54
        // 2c. base10→base16 con bcmath (NUNCA base_convert)
        // 2d. Concatenar codigoControl desde CUFD
        // 2e. Generar XML con CUF incluido
        // 2f. Firmar XML con Jacobitus (localhost:9000)
        // 2g. Comprimir: gzencode(xml_firmado, 9)
        // 2h. SHA-256 del GZIP (INVARIANTE_001)
    
    // 3. Si contingencia: empaquetar en TAR+GZIP (≤500)
    // 4. Si online: POST a SIAT inmediato
    
    return (InExResult){ .status = OK, .output = json_output };
}
```

**Variables de entorno requeridas en manifest.yml:**
```yaml
requirements:
  env_vars:
    - SIAT_API_URL              # URL del servicio SIAT
    - SIAT_CERT_PATH            # Ruta al certificado X.509
    - SIAT_KEY_PATH             # Ruta a llave privada
    - EMPRESA_NIT               # NIT del emisor
    - JACOBITUS_URL             # http://localhost:9000
    - CUFD_DOSIFICACION         # CUFD + llave de dosificación
```

### Smart*-10: Referencia a Documentos Smart Tax Restantes

Los siguientes documentos de SBOS Smart Tax proporcionan especificaciones complementarias para la implementación de cajas SIAT en biedata:
- **SBOS_TAX_E2_INVARIANTES_EXTENDIDOS.md** — Invariantes adicionales por sector y caso de borde
- **SBOS_TAX_D1_ALGORITMOS_UTILIZADOS.md** — Algoritmos complementarios (código de control, hash SIAT)
- **SBOS_TAX_F1_FACTURA_ELECTRONICA_GUIA.md** — Guía de facturación electrónica integral
- **SBOS_TAX_G1_SINCRONIZACION.md** — Sincronización de catálogos SIAT (productos, actividades)
- **SBOS_TAX_H1_LEGADO_REFERENCIA.md** — Bugs legacy PHP/C# documentados para no repetir
- **SBOS_TAX_I1_GUIA_INICIO_RAPIDO.md** — Guía de inicio rápido para implementación SIAT

---

## Trazabilidad V8

| Sección | Fuente |
|---|---|
| §1-14 (V6 completo) | BOS_V6_SBOS-024-DAEMON-BIEDATA.md |
| §15 V5-1 a V5-3 | BOS_V5_SBOS-011-INEXDATA-v3_0.md, BOS_V5_SBOS-011-001-BOXENGINE-PROTOCOL-v1_0.md, BOS_V5_SBOS-011-Tributario-SIAT-AFIP-SAT.md |
| Smart*-1 | Smart Tax — SBOS_TAX_C1_ALGORITMO_CUF_ESPECIFICACION.md |
| Smart*-2 | Smart Tax — SBOS_TAX_E1_INVARIANTES_FISCALES.md, SBOS_TAX_C2_PROTOCOLO_EMPAQUETADO.md |
| Smart*-3 | Smart Tax — SBOS_TAX_C2_PROTOCOLO_EMPAQUETADO.md |
| Smart*-4 | Smart Tax — SBOS_TAX_C3_PROTOCOLO_XMLDSIG.md |
| Smart*-5 | Smart Tax — SBOS_TAX_E1_INVARIANTES_FISCALES.md |
| Smart*-6 | Smart Tax — SBOS_TAX_A3_FORMULAS_POR_SECTOR_v2.md |
| Smart*-7 | Smart Tax — SBOS_TAX_B3_MATRIZ_NOTAS_AJUSTE.md |
| Smart*-8 | Smart Tax — SBOS_TAX_A1_NORMATIVA_VIGENTE_2026.md |
| Smart*-9 | Smart Tax — SBOS_TAX_C1, C2, C3 (especificación de implementación consolidada) |
| Smart*-10 | Smart Tax — documentos E2, D1, F1, G1, H1, I1 |

---

_SKULL · SBOS · SBOS-024-DAEMON-BIEDATA · HUMAN-DOC V8 ENRIQUECIDO · Mayo 2026_
