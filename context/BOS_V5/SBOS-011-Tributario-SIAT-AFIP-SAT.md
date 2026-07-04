# SBOS-011-EXT — Integración Tributaria: Bolivia SIAT, Argentina AFIP, México SAT
## Extensión de SBOS-011 — SBOS Data Integration SBOS Data Integration: Federated Batch Exchange

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-011-EXT-TRIBUTARIO
**Versión:** 1.0
**Estado:** ACTIVO
**Extiende:** SBOS-011-INEXDATA-v3_0
**Clasificación:** Especificación Técnica — Integración Tributaria

---

## Índice

1. [Arquitectura de la capa tributaria en SBOS Data Integration](#1-arquitectura-capa-tributaria)
2. [Flujo completo de facturación electrónica en SBOS](#2-flujo-facturacion)
3. [Bolivia — SIAT (SIN)](#3-bolivia-siat)
4. [Argentina — AFIP Factura Electrónica](#4-argentina-afip)
5. [México — SAT CFDI 4.0](#5-mexico-sat)
6. [Estrategia de reintentos y circuit breaker](#6-reintentos-circuit-breaker)
7. [Gestión de credenciales en Vault](#7-credenciales-vault)
8. [Tabla de códigos de error por jurisdicción](#8-codigos-error)

---

## 1. Arquitectura de la Capa Tributaria en SBOS Data Integration

### 1.1 Principio de diseño: una caja por jurisdicción

Cada integración tributaria es una **caja SBOS Data Integration** independiente, ubicada en `/etc/bos/blibs/biedata/boxes/{pais}/`. Las cajas son completamente intercambiables — se pueden instalar o desinstalar sin afectar las demás integraciones.

```
/etc/bos/blibs/biedata/boxes/
  ├── bolivia-siat/
  │   ├── manifest.yml          → identidad de la caja
  │   ├── box_engine.yml        → flujo de integración con el SIN
  │   ├── box_catalog.so        → lógica compilada Rust
  │   └── resources/
  │       ├── siat_schema.xsd   → esquema XML del SIN
  │       ├── error_codes.yaml  → tabla de errores SIAT
  │       └── endpoints.yaml    → URLs prod/sandbox del SIN
  ├── argentina-afip/
  │   └── ...
  └── mexico-sat/
      └── ...
```

### 1.2 Relación con SmartTax de S05

S05 devserver incluye **SmartTax** (Strategic Tax Compliance & Management). Esta es la **interfaz administrativa** — permite al usuario configurar parámetros de facturación y ver el estado de las facturas enviadas. SBOS Data Integration es la **capa de ejecución** — hace las llamadas reales a los endpoints del SIN/AFIP/SAT.

```
Core UI (S07) → SmartTax (S05) → [configuración y visualización]
                        ↕
              biedata_db (estado de facturas, autorizaciones)
                        ↕
biedata.service ← Redis Stream ← bKernel ← WAL ← Tryton (S04)
      ↕
APIs tributarias (SIAT/AFIP/SAT)
```

Las dos capas son complementarias: SmartTax maneja la UX y la configuración; SBOS Data Integration maneja la comunicación en tiempo real con la autoridad tributaria.

### 1.3 Configuración de la caja por jurisdicción

```toml
# /etc/bos/blibs/biedata/boxes/bolivia-siat/config.toml

[box]
name        = "bolivia-siat"
version     = "1.2.0"
country     = "BO"
tax_agency  = "SIN"
criticality = true   # Si esta caja falla, alertar con severity=high

[endpoints]
mode        = "production"   # sandbox | production
sandbox_url = "https://pilotosiat.impuestos.gob.bo/ServiciosFacturacion/FacturacionCero/"
prod_url    = "https://siat.impuestos.gob.bo/ServiciosFacturacion/FacturacionCero/"
timeout_seconds = 30
max_retries     = 3

[credentials]
vault_path  = "secret/biedata/bolivia-siat"
# Vault guarda: NIT, certificado_digital_path, certificado_password, codigo_sistema

[circuit_breaker]
failure_threshold    = 5      # Errores consecutivos antes de abrir el circuito
recovery_timeout_sec = 300    # 5 minutos antes de intentar cerrar el circuito
```

---

## 2. Flujo Completo de Facturación Electrónica en SBOS

### 2.1 Diagrama del flujo end-to-end

```
USUARIO en Core UI / Tryton
         ↓
Crea factura en Tryton ERP (BC-01 Finanzas)
         ↓
PostgreSQL WAL: INSERT en account_invoice (tryton_db)
         ↓
bKernel CDC Engine detecta el evento
bKernel Rule Engine evalúa regla: invoice_tributaria.yml
         ↓ (condición: state = 'posted' AND requiere_factura_electronica = true)
bKernel escribe en Redis Stream: biedata:invoices:{pais}
         ↓
biedata.service consume el stream de Redis
SBOS Data Integration selecciona la caja tributaria según invoice.country
         ↓
SBOS Data Integration ejecuta box_engine.yml de la caja:
  1. Leer credenciales de Vault
  2. Construir el XML/JSON según el esquema de la autoridad tributaria
  3. Llamar al endpoint de autorización (SIAT/WSFE/PAC)
  4. Recibir respuesta: código de autorización (CUFD/CAE/UUID-SAT)
  5. Escribir resultado en biedata_db.invoice_authorizations
         ↓
bKernel detecta la escritura en biedata_db via WAL
bKernel escribe el código de autorización de vuelta en tryton_db.account_invoice
         ↓
Tryton muestra la factura autorizada con número de autorización
Usuario puede imprimir el documento fiscal
```

### 2.2 Regla YAML del bKernel para triggering tributario

```yaml
# /etc/bos/blibs/bkernel/rules/tryton/invoice_tributaria_trigger.yml

rule:
  name: "trigger_biedata_facturacion_electronica"
  version: "1.0"

  trigger:
    source: tryton_db
    table: account_invoice
    operations: [UPDATE]
    condition: "NEW.state = 'posted' AND OLD.state != 'posted'"

  conditions:
    - field: "NEW.tax_country"
      operator: "in"
      values: ["BO", "AR", "MX"]

  actions:
    - type: redis_stream_publish
      stream: "biedata:invoices:{NEW.tax_country}"
      payload:
        invoice_id:     "{NEW.id}"
        invoice_number: "{NEW.number}"
        country:        "{NEW.tax_country}"
        nit_emisor:     "{NEW.nit}"
        amount_total:   "{NEW.amount_total}"
        amount_tax:     "{NEW.amount_tax}"
        party_id:       "{NEW.party}"
        invoice_date:   "{NEW.invoice_date}"
        invoice_type:   "{NEW.invoice_type}"   # credit_fiscal | sin_derecho_cf | nota_credito
```

---

## 3. Bolivia — SIAT (Servicio de Impuestos Nacionales)

### 3.1 Modalidades de facturación SIAT

SBOS Data Integration soporta las siguientes modalidades del SIN:

| Modalidad | Descripción | Cuándo usar |
|---|---|---|
| **Facturación en Línea** | Conexión directa al SIN en tiempo real | Cuando hay conectividad estable |
| **Facturación Fuera de Línea (SFC)** | Genera facturas sin conexión con CUFD local | Ante caída temporal del SIN |
| **Modo Contingencia** | Facturas manuales con Código de Control generado localmente | Ante indisponibilidad prolongada del SIN |

### 3.2 Migración de sandbox a producción

```yaml
# Proceso de alta en producción con el SIN:

paso_1_homologacion:
  descripcion: "Completar el proceso de homologación con el SIN"
  requisitos:
    - NIT de la empresa activo y al día
    - Certificado digital CSD emitido por el SIN para la empresa
    - Código de Sistema asignado por el SIN (se obtiene en la plataforma de homologación)
    - Código de Punto de Venta configurado en el SIN
  duracion_estimada: "5-15 días hábiles"

paso_2_credenciales_vault:
  descripcion: "Cargar credenciales en Vault"
  comando: |
    vault kv put secret/biedata/bolivia-siat \
      nit="1234567890" \
      codigo_sistema="SBOS-{EMPRESA}" \
      certificado_path="/etc/bos/blibs/biedata/certs/bolivia-siat/cert.p12" \
      certificado_password="${CERT_PASSWORD}" \
      codigo_punto_venta="1"

paso_3_cambiar_a_produccion:
  descripcion: "Actualizar config.toml a modo production"
  comando: |
    sed -i 's/mode = "sandbox"/mode = "production"/' \
      /etc/bos/blibs/biedata/boxes/bolivia-siat/config.toml
    kill -SIGUSR1 $(systemctl show biedata --property=MainPID | cut -d= -f2)

paso_4_prueba_factura_real:
  descripcion: "Emitir primera factura real y verificar autorización"
  verificacion: |
    # El CUFD debe aparecer en biedata_db.invoice_authorizations
    psql -U biedata -d biedata_db -c \
      "SELECT * FROM invoice_authorizations WHERE country = 'BO' ORDER BY created_at DESC LIMIT 1;"
```

### 3.3 Casos de uso implementados

**Caso 1: Factura con Derecho a Crédito Fiscal**

```xml
<!-- Estructura XML enviada al SIN (simplificada) -->
<solicitudServicioRecepcionFactura>
  <cabecera>
    <nitEmisor>{NIT}</nitEmisor>
    <codigoSucursal>0</codigoSucursal>
    <codigoPuntoVenta>{CODIGO_PV}</codigoPuntoVenta>
    <codigoDocumentoSector>1</codigoDocumentoSector>  <!-- 1 = Factura -->
    <codigoEmision>1</codigoEmision>  <!-- 1 = En línea -->
    <codigoModalidad>2</codigoModalidad>  <!-- 2 = Computarizada en línea -->
    <cufd>{CUFD_ACTIVO}</cufd>
    <tipoCambio>1</tipoCambio>
    <moneda>1</moneda>  <!-- 1 = Bolivianos -->
  </cabecera>
  <detalle>
    <nitComprador>{NIT_COMPRADOR}</nitComprador>
    <nombreRazonSocial>{NOMBRE_COMPRADOR}</nombreRazonSocial>
    <!-- ... -->
    <montoTotal>{MONTO_TOTAL}</montoTotal>
    <descuentoAdicional>0</descuentoAdicional>
    <codigoControl>{CODIGO_CONTROL}</codigoControl>
  </detalle>
</solicitudServicioRecepcionFactura>
```

**Caso 2: Nota de Crédito/Débito**

```yaml
# box_engine.yml — paso de nota de crédito
- step: nota_credito
  action: call_siat_webservice
  service: "FacturacionNotaCreditoDebito"
  params:
    cuf_original: "{invoice.cuf_original}"  # CUF de la factura a anular
    tipo_nota: "1"  # 1 = Nota de Crédito, 2 = Nota de Débito
    motivo_anulacion: "{invoice.motivo}"
```

### 3.4 Códigos de error SIAT y manejo

| Código | Descripción | Acción SBOS Data Integration |
|---|---|---|
| 908 | NIT del comprador no existe | Alerta al operador — factura no enviada |
| 909 | CUFD expirado o inválido | Solicitar nuevo CUFD automáticamente y reintentar |
| 910 | Error en el Código de Control | Recalcular Código de Control y reintentar |
| 911 | Factura ya registrada (duplicado) | Verificar si existe en biedata_db — si sí, marcar como ya autorizada |
| 960 | Sistema SIN no disponible | Circuit breaker activo — cambiar a modo contingencia automáticamente |
| 970 | Error de certificado digital | Alerta crítica — no reintentar — requiere renovación de certificado |

---

## 4. Argentina — AFIP Factura Electrónica

### 4.1 Servicios WSFE y WSMTXCA

AFIP provee dos servicios de facturación electrónica:

| Servicio | Uso | Comprobantes |
|---|---|---|
| **WSFE** (Facturación Electrónica) | La mayoría de empresas | A, B, C. Nota de Crédito/Débito A, B, C |
| **WSMTXCA** (Clave Fiscal) | Empresas con sectores específicos (transporte, hotelería) | Comprobantes con ítems detallados obligatorios |

SBOS Data Integration usa **WSFE por defecto**. WSMTXCA se activa configurando `service: "wsmtxca"` en el manifest.yml de la caja.

### 4.2 Proceso de autenticación AFIP (WSAA)

AFIP usa un sistema de tickets de autenticación (TA) que expiran cada 12 horas. SBOS Data Integration renueva el TA automáticamente:

```rust
// Lógica de autenticación AFIP en box_catalog.so (Rust)
// El TA se almacena en biedata_db.afip_auth_tokens y se renueva antes de expirar

async fn get_valid_ticket(db: &Pool) -> Result<AuthTicket> {
    let stored = db.query_opt(
        "SELECT ta_token, ta_sign, expires_at FROM afip_auth_tokens
         WHERE expires_at > NOW() + INTERVAL '10 minutes'
         ORDER BY expires_at DESC LIMIT 1",
        &[]
    ).await?;

    if let Some(row) = stored {
        return Ok(AuthTicket { token: row.get(0), sign: row.get(1) });
    }

    // Ticket expirado o próximo a expirar — solicitar nuevo al WSAA
    let new_ticket = wsaa_client.login("wsfe", &cert, &private_key).await?;
    db.execute(
        "INSERT INTO afip_auth_tokens (ta_token, ta_sign, expires_at) VALUES ($1, $2, $3)",
        &[&new_ticket.token, &new_ticket.sign, &new_ticket.expires_at]
    ).await?;
    Ok(new_ticket)
}
```

### 4.3 Flujo de solicitud de CAE

```yaml
# box_engine.yml — caja argentina-afip

steps:
  - step: 1
    name: "obtener_ticket_autenticacion"
    action: wsaa_authenticate
    params:
      service: "wsfe"
      cert_vault_path: "secret/biedata/argentina-afip/certificado"
      private_key_vault_path: "secret/biedata/argentina-afip/clave_privada"

  - step: 2
    name: "solicitar_cae"
    action: wsfe_fecae_solicitar
    params:
      cuit_emisor:       "{credentials.cuit}"
      punto_venta:       "{credentials.punto_venta}"
      tipo_cbte:         "{invoice.tipo_comprobante}"  # 1=A, 6=B, 11=C
      fecha_cbte:        "{invoice.invoice_date | format YYYYMMDD}"
      imp_total:         "{invoice.amount_total}"
      imp_tot_conc:      "{invoice.amount_untaxed}"
      imp_neto:          "{invoice.amount_net}"
      imp_iva:           "{invoice.amount_tax}"
      cuit_comprador:    "{invoice.party_tax_id}"
    capture_response:
      cae:              "response.cae"
      cae_fch_vto:      "response.cae_fch_vto"   # Fecha de vencimiento del CAE (10 días)

  - step: 3
    name: "almacenar_cae"
    action: db_write
    destination: biedata_db
    table: invoice_authorizations
    mapping:
      invoice_id:        "{invoice.invoice_id}"
      country:           "AR"
      authorization_code: "{saga_context.cae}"
      expires_at:        "{saga_context.cae_fch_vto}"
      raw_response:      "{response_json}"
```

### 4.4 Tipos de comprobante AFIP

| Código | Tipo | Responsable | Destinatario |
|---|---|---|---|
| 1 | Factura A | Responsable Inscripto | Responsable Inscripto |
| 6 | Factura B | Responsable Inscripto | Consumidor Final / Monotributista |
| 11 | Factura C | Monotributista | Cualquier destinatario |
| 3 | Nota de Crédito A | Responsable Inscripto | Responsable Inscripto |
| 8 | Nota de Crédito B | Responsable Inscripto | Consumidor Final |
| 13 | Nota de Crédito C | Monotributista | Cualquier destinatario |

Tryton determina el tipo de comprobante según el perfil tributario del comprador (Responsable Inscripto / Consumidor Final / Monotributista). SBOS Data Integration recibe el tipo ya calculado.

### 4.5 Proceso de homologación AFIP

```yaml
homologacion:
  entorno_prueba: "https://wswhomo.afip.gov.ar/wsmtxca/services/MTXCAService"
  entorno_prod:   "https://servicios1.afip.gov.ar/wsmtxca/services/MTXCAService"
  
  requisitos:
    - CUIT activo en AFIP
    - Certificado digital CSD generado desde el portal AFIP (Administrador de Relaciones)
    - Punto de venta habilitado en AFIP para Facturación Electrónica
    - Aprobación del proceso de homologación (AFIP provee un set de casos de prueba)
  
  vault_secrets:
    - "secret/biedata/argentina-afip/cuit"
    - "secret/biedata/argentina-afip/punto_venta"
    - "secret/biedata/argentina-afip/certificado"   # .p12 o .crt
    - "secret/biedata/argentina-afip/clave_privada" # .key
```

---

## 5. México — SAT CFDI 4.0

### 5.1 Diferencias CFDI 4.0 vs 3.3 que impactan la implementación

| Cambio | CFDI 3.3 | CFDI 4.0 | Impacto en SBOS Data Integration |
|---|---|---|---|
| RFC del receptor | Opcional en algunos casos | **Obligatorio siempre** | Tryton debe almacenar RFC del cliente obligatoriamente |
| Nombre del receptor | Opcional | **Obligatorio** | Validar que Tryton tiene nombre completo del cliente |
| Domicilio fiscal del receptor | No requerido | **Obligatorio (código postal)** | Nuevo campo obligatorio en la ficha del cliente en Tryton |
| Exportación | Campo simple | **Catálogo ampliado** | Actualizar catálogo de tipos de exportación |
| Uso del CFDI | Catálogo simple | **Catálogo extendido por tipo de persona** | La lógica de selección del `UsoCFDI` es más compleja |
| Versión XSD | 3.3 | **4.0** | La caja usa el XSD de CFDI 4.0 para validación local antes de enviar al PAC |

### 5.2 Proceso con PAC (Proveedor Autorizado de Certificación)

En México, el SAT no recibe CFDIs directamente — los emisores deben contratar un PAC certificado:

```
Tryton → SBOS Data Integration → PAC → SAT → (respuesta) → PAC → SBOS Data Integration → Tryton
```

SBOS Data Integration actúa como cliente del PAC. La caja `mexico-sat` es configurable para trabajar con cualquier PAC que soporte el estándar de timbrado:

```toml
# /etc/bos/blibs/biedata/boxes/mexico-sat/config.toml

[pac]
provider       = "finkok"    # finkok | facturama | sw-sapien | trazo — PAC contratado por el cliente
api_endpoint   = "https://demo-facturacion.finkok.com/servicios/soap/stamp.wsdl"
vault_path_user = "secret/biedata/mexico-sat/pac_user"
vault_path_pass = "secret/biedata/mexico-sat/pac_password"

[sat]
regimen_fiscal  = "601"   # 601 = General de Ley Personas Morales
uso_cfdi_default = "G03"  # G03 = Gastos en general (default cuando no se especifica)
```

### 5.3 Gestión del CSD (Certificado de Sello Digital)

El CSD del SAT expira anualmente. SBOS Data Integration monitorea la fecha de expiración y alerta con 30 días de anticipación:

```yaml
# Alerta Alertmanager para expiración de CSD México
- alert: MexicoCSDExpiringSoon
  expr: |
    (biedata_cert_expiry_timestamp{country="MX"} - time()) < 2592000
  labels:
    severity: high
    component: biedata
  annotations:
    summary: "CSD SAT México expira en menos de 30 días"
    description: "Renovar el CSD en el portal del SAT antes de {{ $value | humanizeDuration }}"
```

Proceso de renovación del CSD:

```bash
# PASO 1: El cliente genera nuevo CSD en el portal del SAT (portal.sat.gob.mx)
# El SAT entrega: {rfc}.cer (certificado) + {rfc}.key (clave privada cifrada)

# PASO 2: Actualizar en Vault
vault kv put secret/biedata/mexico-sat \
  rfc="{RFC_EMPRESA}" \
  cer_path="/etc/bos/blibs/biedata/certs/mexico-sat/{RFC}.cer" \
  key_path="/etc/bos/blibs/biedata/certs/mexico-sat/{RFC}.key" \
  key_password="${KEY_PASSWORD}" \
  pac_user="${PAC_USER}" \
  pac_password="${PAC_PASSWORD}"

# PASO 3: Hot-reload de SBOS Data Integration
sudo kill -SIGUSR1 $(systemctl show biedata --property=MainPID | cut -d= -f2)
```

### 5.4 Cancelación de CFDI

La cancelación de un CFDI en CFDI 4.0 requiere la aceptación del receptor para montos superiores a $1,000 MXN:

```yaml
# box_engine.yml — flujo de cancelación CFDI 4.0

steps:
  - step: 1
    name: "solicitar_cancelacion_al_pac"
    action: pac_cancel_cfdi
    params:
      uuid:           "{invoice.sat_uuid}"
      rfc_emisor:     "{credentials.rfc}"
      rfc_receptor:   "{invoice.party_rfc}"
      total:          "{invoice.amount_total}"
      motivo:         "{invoice.cancel_reason}"  # 01=Comprobante emitido con errores con relación, 02=Comprobante emitido con errores sin relación
      folio_sustitucion: "{invoice.folio_sustitucion}"  # Solo si motivo=01

  - step: 2
    name: "verificar_aceptacion_receptor"
    condition: "{invoice.amount_total} >= 1000"
    action: poll_cancelation_status
    params:
      uuid:      "{invoice.sat_uuid}"
      max_polls: 10
      interval_seconds: 300   # Verificar cada 5 minutos — el receptor tiene hasta 72h para aceptar
    expected_status: "Cancelado"   # O "Cancelado sin aceptación" si el receptor no responde en 72h

  - step: 3
    name: "actualizar_estado_en_tryton"
    action: db_write
    destination: tryton_db
    table: account_invoice
    operation: UPDATE
    set:
      state: "cancel"
      sat_cancel_date: "NOW()"
    where: "sat_uuid = '{invoice.sat_uuid}'"
```

---

## 6. Estrategia de Reintentos y Circuit Breaker

### 6.1 Estrategia de reintentos por tipo de error

No todos los errores merecen el mismo tratamiento de reintento:

| Tipo de error | ¿Reintentar? | Estrategia | Máximo |
|---|---|---|---|
| Timeout de red | Sí | Backoff exponencial: 10s, 30s, 90s | 3 intentos |
| HTTP 500 del servicio tributario | Sí | Backoff exponencial: 60s, 300s, 600s | 3 intentos |
| Error de credenciales (401/403) | No | Alerta inmediata a operador | 1 intento |
| Error de validación de datos (400) | No | Marcar factura con error, notificar | 1 intento |
| Duplicado (factura ya enviada) | No | Recuperar autorización existente | 1 intento |
| Servicio tributario en mantenimiento | Sí | Reintento programado cada 30 min | Ilimitado durante ventana |

### 6.2 Circuit Breaker por caja

Cada caja tributaria tiene su propio circuit breaker independiente. Si el SIAT está caído, el circuit breaker de `bolivia-siat` se abre sin afectar las cajas de Argentina o México:

```
Estado CLOSED (normal):
  Todas las solicitudes pasan → si N fallos consecutivos → OPEN

Estado OPEN (circuito abierto):
  Todas las solicitudes fallan inmediatamente → alert severity=high
  Timer de recovery: {recovery_timeout_sec} segundos
  → Timer expirado → HALF-OPEN

Estado HALF-OPEN:
  1 solicitud de prueba pasa → si éxito → CLOSED
                             → si fallo → OPEN (reiniciar timer)
```

### 6.3 Modo contingencia Bolivia

Cuando el SIAT está caído, SBOS Data Integration activa automáticamente el modo contingencia:

```toml
[contingencia]
auto_activate = true        # Activar contingencia automáticamente al abrir circuit breaker
max_contingencia_hours = 8  # Tiempo máximo en contingencia antes de alertar severity=critical

# En contingencia: se generan facturas con Código de Control local (CUFD precargado)
# El SIN acepta estas facturas para sincronización posterior en los próximos 24h
```

---

## 7. Gestión de Credenciales en Vault

### 7.1 Estructura de secretos en Vault por jurisdicción

```
secret/biedata/
  ├── bolivia-siat/
  │   ├── nit                    → NIT de la empresa
  │   ├── codigo_sistema         → Código asignado por el SIN
  │   ├── certificado_path       → Ruta al certificado .p12
  │   ├── certificado_password   → Password del certificado
  │   └── codigo_punto_venta     → Código del punto de venta
  ├── argentina-afip/
  │   ├── cuit                   → CUIT de la empresa
  │   ├── punto_venta            → Número de punto de venta habilitado
  │   ├── certificado            → Certificado .crt en base64
  │   └── clave_privada          → Clave privada .key en base64
  └── mexico-sat/
      ├── rfc                    → RFC de la empresa
      ├── cer_b64                → Certificado .cer en base64
      ├── key_b64                → Clave privada .key en base64
      ├── key_password           → Password de la clave privada
      ├── pac_user               → Usuario en el PAC contratado
      └── pac_password           → Password en el PAC contratado
```

### 7.2 SBOS Data Integration accede a Vault solo en startup y hot-reload

SBOS Data Integration no consulta Vault en cada factura — carga las credenciales en memoria al iniciar y las renueva solo ante SIGUSR1 o expiración del lease de Vault:

```rust
// SBOS Data Integration - bootstrap de credenciales
async fn load_tax_credentials(vault: &VaultClient, country: &str) -> Result<TaxCredentials> {
    let path = format!("secret/biedata/{}", country.to_lowercase().replace("-", "/"));
    let secret = vault.read_secret(&path).await?;
    
    // Las credenciales se guardan en memoria — sin acceso a Vault por cada factura
    // Vault lease default: 24h — SBOS Data Integration renueva automáticamente antes de expirar
    Ok(TaxCredentials::from_vault_response(secret))
}
```

---

## 8. Tabla de Códigos de Error por Jurisdicción

### 8.1 Bolivia SIAT

| Código | Descripción | Acción automática |
|---|---|---|
| 908 | NIT comprador inválido | Marcar factura con error — notificar operador |
| 909 | CUFD inválido o expirado | Solicitar nuevo CUFD — reintentar |
| 910 | Código de Control incorrecto | Recalcular — reintentar 1 vez |
| 911 | Factura duplicada | Recuperar autorización existente de base |
| 960 | Sistema SIN no disponible | Activar circuit breaker — modo contingencia |
| 970 | Error certificado digital | Alerta crítica — no reintentar |

### 8.2 Argentina AFIP

| Código | Descripción | Acción automática |
|---|---|---|
| 10016 | El campo Fecha no es válido | Error de validación — notificar operador |
| 10048 | El CUIT del receptor no existe | Error de datos — notificar operador |
| 500 | Error del servicio AFIP | Reintento con backoff |
| 501 | Servicio en mantenimiento | Circuit breaker — reintentar en 30 min |
| 601 | CAE rechazado | Analizar mensaje — puede requerir corrección de datos |

### 8.3 México SAT/PAC

| Código PAC | Descripción | Acción automática |
|---|---|---|
| 301 | XML no válido conforme al XSD | Error de datos — validar con schema local |
| 302 | CSD vencido o revocado | Alerta crítica — requiere renovación de CSD |
| 304 | RFC del emisor no existe en el SAT | Error de configuración — notificar |
| 307 | CFDI rechazado por el SAT | Revisar error específico en payload |
| 7008 | PAC no disponible | Reintento con backoff — circuit breaker si persiste |

---

## 9. Referencias Cruzadas

- **SBOS-011** — SBOS Data Integration (arquitectura base del daemon y sistema de cajas)
- **SBOS-010** — bKernel (triggering via WAL → Redis Stream)
- **SBOS-016** — Servidores lógicos (S05 devserver con SmartTax)
- **SBOS-003** — Stack (Vault en S02 gatewayserver — gestión de credenciales tributarias)
- **SBOS-024** — Operaciones (alertas para fallos tributarios — severity=high)

---

## 10. Registro de Cambios

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| 1.0 | Marzo 2026 | SKULL SBOS Data Integration Team | Documento inicial — arquitectura de capa tributaria, flujo end-to-end, Bolivia SIAT completo, Argentina AFIP WSFE + WSMTXCA, México SAT CFDI 4.0 con PAC |

---

*SKULL · SBOS · SBOS-011-EXT-TRIBUTARIO · v1.0 · Marzo 2026*
*Extiende: SBOS-011-INEXDATA-v3_0*
*Mercados: Bolivia (SIAT), Argentina (AFIP), México (SAT CFDI 4.0)*
