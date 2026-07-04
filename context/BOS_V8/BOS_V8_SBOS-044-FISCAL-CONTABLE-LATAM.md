# SBOS-044-FISCAL-CONTABLE-LATAM
## Contabilidad y Facturacion Electronica por Jurisdiccion — Estandar HUMAN-DOC
### SKULL · SBOS · V8 Enriquecido · Mayo 2026

---

## 1. Proposito y Vision

La contabilidad y la facturacion electronica son las dos caras de la misma moneda regulatoria. Mientras que el 90% del SBOS es universal (identidad, comunicaciones, BI, IA, infraestructura), estas dos areas son intrinsecamente locales — estan ligadas a las leyes, normas y organismos reguladores de cada pais. No se puede facturar sin el plan de cuentas correcto, y no se puede contabilizar sin el documento fiscal valido.

**Principio de diseno:** cada jurisdiccion es una caja biedata independiente (facturacion) + un modulo Tryton localizado (contabilidad). Instalar o desinstalar una jurisdiccion no afecta las demas. Un SBOS puede operar en Bolivia y Argentina simultaneamente — cada realm KC tiene su configuracion fiscal.

### Arquitectura de dos capas

```
CAPA CONTABLE (Tryton ERP — S04 erpserver)
  ├── Plan de cuentas → por normativa nacional (PUCT/PUC/NIF/PCGA)
  ├── Periodos fiscales → por legislacion (anual, trimestral)
  ├── Impuestos → configuracion por pais (IVA/IUE/IT/Ganancias/ISR)
  ├── Reportes fiscales → formatos del organismo regulador
  └── Modulos Tryton localizados → account_bo, account_ar, account_mx, account_co

CAPA FACTURACION (biedata — daemon host)
  ├── Cajas por jurisdiccion → /etc/bos/blibs/biedata/boxes/{pais}/
  ├── Box Engine → 6 fases (Authenticate→Extract→Transform→Load→Update→Audit)
  ├── Conexion al organismo → SIAT/AFIP/SAT/DIAN
  └── Circuit breaker independiente por caja

VINCULO:
  Tryton escribe factura → WAL → bKernel → Redis Stream → biedata ejecuta caja
  biedata recibe autorizacion → WAL → bKernel → actualiza Tryton con codigo fiscal
```

### Enriquecimiento Smart Tax: Arquitectura de integracion SmartTax + biedata

SmartTax (SBOS Smart Tax) es la capa administrativa que proporciona la interfaz de usuario para configuracion, visualizacion de estado y gestion del ciclo de vida fiscal. Se integra con biedata como motor de ejecucion:

```
Core UI → SmartTax → [configuracion y visualizacion]
                ↕
biedata_db (estado facturas, autorizaciones)
                ↕
biedata.service ← Redis ← bKernel ← WAL ← Tryton
      ↕
APIs tributarias (SIAT/AFIP/SAT/DIAN)
```

SmartTax define invariantes fiscales verificables (SBOS_TAX_E1_INVARIANTES_FISCALES.md) que garantizan la correccion de las facturas antes de ser enviadas a organismos externos. Estos invariantes son reglas de assertion que el Box Engine de biedata debe verificar en la fase TRANSFORM antes de la fase LOAD.

## 2. Jurisdicciones — Mapa Regulatorio

### 2.1 Bolivia 🇧🇴

| Dimension | Detalle |
|---|---|
| **Organismo regulador** | SIN (Servicio de Impuestos Nacionales) |
| **Plan de cuentas** | PUCT (Plan Unico de Cuentas Tributario) — RND 101800000004. Estructura: Clase→Grupo→Subgrupo→Cuenta Principal→Cuenta Analitica. Los niveles 1-4 son cerrados por el SIN; solo el 5° (analitico) es libre. Modificar nivel 4 requiere autorizacion formal del SIN |
| **Facturacion electronica** | SIAT (Sistema de Facturacion en Linea). Obligatorio desde Dic 2021 (implementacion progresiva por grupos, 12 grupos hasta Oct 2025). Modalidades: En Linea, Computarizada en Linea, Fuera de Linea (SFC), Contingencia |
| **Impuestos principales** | IVA 13% (credito fiscal), IUE 25% (utilidades empresas), IT 3% (transacciones), RC-IVA |
| **Protocolo tecnico** | SOAP/REST. CUIS + CUFD + CUF. Certificado digital ADSIB/DIGICERT. 52 sectores fiscales con XSDs |
| **Modulo Tryton** | account_bo — PUCT completo, Libro C/V IVA, F-110, IEDGE, Balance de Sumas y Saldos |
| **Caja biedata** | bolivia-siat/ con box_engine.yml + box_catalog.so (Rust) |
| **Reportes fiscales** | JasperSoft Studio 6.18.1 CE: Libro C/V SIN, F-110, PUCT digital |

#### Enriquecimiento Smart Tax: Algoritmo CUF Bolivia (SBOS_TAX_C1)

El CUF (Codigo Unico de Facturacion) es el identificador unico de cada factura electronica en Bolivia. Su estructura es:

| Campo | Longitud | Padding | Descripcion |
|---|---|---|---|
| NIT emisor | 13 | str_pad($nit, 13, '0', LEFT) | NIT del contribuyente |
| Fecha/Hora | 17 | YmdHis + ms 3 digitos | yyyyMMddHHmmssSSS |
| Sucursal | 4 | str_pad($suc, 4, '0', LEFT) | 0=Casa Matriz |
| Modalidad | 1 | sin padding | 1=Electronica, 2=Computarizada, 3=Portal |
| Tipo Emision | 1 | sin padding | 1=Online, 2=Offline, 3=Masiva |
| Tipo Factura | 1 | sin padding | 1=Con CF, 2=Sin CF, 3=Ajuste |
| Tipo Doc. Sector | 2 | str_pad($ds, 2, '0', LEFT) | codigoDocumentoSector |
| Numero Factura | 10 | str_pad($nf, 10, '0', LEFT) | correlativo |
| POS | 4 | str_pad($pos, 4, '0', LEFT) | 0=sin POS |
| **Subtotal** | **53** | — | **INVARIANTE_009: cadena base debe medir exactamente 53 caracteres** |
| Digito Mod11 | 1 | calculado | autoverificador |
| **Total base** | **54** | — | se convierte a HEX |
| codigoControl | variable | sin padding | del CUFD vigente |
| **CUF final** | variable | — | HEX + codigoControl |

**Paso a paso de implementacion:**
1. Padding de campos (NIT 13 chars, fecha 17 chars, sucursal 4 chars, etc.)
2. Concatenacion (debe ser exactamente 53 chars)
3. Calculo del digito Modulo 11
4. Conversion a hexadecimal
5. Concatenacion con codigoControl del CUFD vigente

**Invariante critico:** `len(cadena_base) == 53` ANTES del Modulo 11. Si la cadena no mide 53 chars exactos, el CUF es incorrecto. Sin excepcion.

#### Enriquecimiento Smart Tax: Protocolo de empaquetado (SBOS_TAX_C2)

**Regla 1 — Emision individual en linea:**
```
XML UTF-8 → GZIP(nivel 9) → SHA-256(GZIP) → campo `archivo` SOAP
```

**INVARIANTE_001:** `hash('sha256', $paqueteFinal) == $hashArchivo` donde `$paqueteFinal` es SIEMPRE el resultado comprimido, NUNCA el XML plano. Este es el bug mas comun del sistema legado — el hash debe calcularse sobre el GZIP, no sobre el XML.

**Regla 2 — Paquete de contingencia (≤500 facturas):**
Multiples facturas en un solo XML con envoltura de paquete, comprimido como GZIP, hash del GZIP completo. Aplica para modalidad Fuera de Linea (SFC).

#### Enriquecimiento Smart Tax: Protocolo XMLDSig (SBOS_TAX_C3)

La firma digital XMLDSig es obligatoria para facturacion electronica en Bolivia. SmartTax implementa:
- Canonicalizacion XML exclusivo C14N (nunca C14N con comentarios)
- Transform enveloped signature
- Algoritmo SHA-256 para DigestValue
- Certificado digital vigente (no expirado, no revocado)

#### Enriquecimiento Smart Tax: Invariantes fiscales (SBOS_TAX_E1)

Las invariantes son reglas de assertion verificables que garantizan que cada factura cumple con la normativa:

| ID | Invariante | Descripcion |
|---|---|---|
| INVARIANTE_001 | SHA-256 del GZIP | Hash sobre el paquete comprimido, no sobre el XML plano |
| INVARIANTE_002 | Milisegundos 3 digitos | str_pad ms a 3 digitos en fecha CUF |
| INVARIANTE_003 | NIT padding 13 | str_pad izquierda con ceros |
| INVARIANTE_004 | Cadena base 53 chars | 13+17+4+1+1+1+2+10+4 = 53 exactos |
| INVARIANTE_005 | Redondeo HALF-UP | En CADA operacion monetaria |
| INVARIANTE_006 | Importe no negativo | Ningun monto puede ser negativo |
| INVARIANTE_007 | cuisValido() | CUIS activo en cache; si expirado, renovar antes de enviar |
| INVARIANTE_008 | cufdValido() | CUFD activo (no mas de 48h desde emision) |
| INVARIANTE_009 | cadenaBaseCUF == 53 chars | Pre-modulo 11 |
| INVARIANTE_010 | digitoMod11 correcto | Calculo verificado con 10 vectores de prueba |

#### Enriquecimiento Smart Tax: Matriz de notas de ajuste (SBOS_TAX_B3)

Las notas de ajuste no son facturas. No tienen `montoTotal`, `montoTotalSujetoIva` ni `metodoPago`. Referencian siempre una factura original mediante `numeroAutorizacionCuf`. Plazo maximo: 540 dias (18 meses) desde la fecha de emision de la factura original.

51 sectores fiscales, 4 tipos de nota:
- **Nota 24:** Ajuste de precio — aplica a 50/51 sectores
- **Nota 29:** Devolucion/Anulacion — aplica a 50/51 sectores  
- **Nota 47:** Ajuste de precio especifico — aplica a 48/51 sectores
- **Nota 48:** Nota sector especial 14 (hoteles) — solo aplica al sector 14

#### Enriquecimiento Smart Tax: Formulas por sector (SBOS_TAX_A3)

Smart Tax define formulas especificas por cada uno de los 52 sectores fiscales de Bolivia. Cada sector tiene reglas particulares para calculo de montos, ICE (Impuesto al Consumo Especifico), descuentos condicionados y tipos de documento de sector. La implementacion debe seleccionar la formula segun el `codigoDocumentoSector` de la factura.

#### Enriquecimiento Smart Tax: Referencia legado (SBOS_TAX_LEGADO_REFERENCIA)

El sistema legado SmartTax (PHP Laravel) contiene bugs criticos documentados que la implementacion V8 debe evitar:
1. **Bug #1:** SHA-256 del XML plano en lugar del GZIP (causa rechazo SIN codigo 969)
2. **Bug #2:** Milisegundos sin padding a 3 digitos (CUF de 53 chars en lugar de 54)
3. **Bug #3:** Modulo 11 implementado incorrectamente para ciertos valores de NIT
4. **Bug #4:** Cache de CUIS sin renovacion automatica (vence cada 48h)
5. **Bug #5:** Manejo incorrecto de facturas con cero en ICE

### 2.2 Argentina 🇦🇷

| Dimension | Detalle |
|---|---|
| **Organismo regulador** | AFIP (Administracion Federal de Ingresos Publicos) |
| **Plan de cuentas** | PCGA (Principios de Contabilidad Generalmente Aceptados) + RT (Resoluciones Tecnicas FACPCE). Argentina no tiene un PUC nacional obligatorio unico como Bolivia o Colombia — cada empresa define su plan segun las RT, pero debe cumplir con estructura NIIF para empresas del Grupo 1 |
| **Facturacion electronica** | WSFE (Web Service Facturacion Electronica) y WSMTXCA. CAE (Codigo de Autorizacion Electronico) con vencimiento 10 dias. Autenticacion via WSAA (ticket de autenticacion 12h) |
| **Impuestos principales** | IVA 21% (general), Ganancias (escalas), Ingresos Brutos (provincial), Monotributo |
| **Protocolo tecnico** | SOAP. CUIT + Certificado CSD + Clave Privada. Punto de venta habilitado en AFIP |
| **Tipos comprobante** | A (RI→RI), B (RI→CF/Mono), C (Mono→todos). Notas Credito/Debito A/B/C |
| **Modulo Tryton** | account_ar — plan de cuentas RT, retenciones IVA/Ganancias, percepciones IIBB |
| **Caja biedata** | argentina-afip/ con WSFE + WSAA autenticacion automatica |

### 2.3 Mexico 🇲🇽

| Dimension | Detalle |
|---|---|
| **Organismo regulador** | SAT (Servicio de Administracion Tributaria) |
| **Plan de cuentas** | NIF (Normas de Informacion Financiera emitidas por CINIF). Codigo Agrupador del SAT para catalogo de cuentas (obligatorio en contabilidad electronica). Estructura: naturaleza→subcuenta→naturaleza especifica |
| **Facturacion electronica** | CFDI 4.0 (Comprobante Fiscal Digital por Internet). Obligatorio via PAC (Proveedor Autorizado de Certificacion). El SAT NO recibe CFDIs directamente — el PAC los timbra |
| **Impuestos principales** | IVA 16%, ISR (escalas por regimen), IEPS (especiales) |
| **Protocolo tecnico** | REST/SOAP via PAC. CSD (Certificado de Sello Digital) anual. e.firma (FIEL). RFC obligatorio. XSD CFDI 4.0 |
| **Cambios CFDI 4.0 vs 3.3** | RFC receptor obligatorio siempre, nombre receptor obligatorio, domicilio fiscal (CP) obligatorio, catalogo exportacion ampliado, UsoCFDI por tipo persona |
| **Cancelacion** | Requiere aceptacion receptor para >$1,000 MXN (72h para aceptar/rechazar) |
| **Modulo Tryton** | account_mx — NIF, catalogo SAT, retenciones ISR, complementos de pago |
| **Caja biedata** | mexico-sat/ con PAC configurable (Finkok, Facturama, SW-Sapien, Trazo) |

### 2.4 Colombia 🇨🇴

| Dimension | Detalle |
|---|---|
| **Organismo regulador** | DIAN (Direccion de Impuestos y Aduanas Nacionales) |
| **Plan de cuentas** | PUC (Plan Unico de Cuentas) — Decreto 2650/1993. Estructura: Clase(1)→Grupo(2)→Cuenta(4)→Subcuenta(6)→Auxiliar. Obligatorio para todas las personas obligadas a llevar contabilidad. Convergencia NIIF (Ley 1314/2009, Decreto 2420/2015) |
| **Facturacion electronica** | Factura Electronica de Venta. UBL 2.1 (Universal Business Language). Resolucion 000042/2020 DIAN. Obligatoria para todos los contribuyentes |
| **Impuestos principales** | IVA 19% (general), Renta (35% sociedades), ICA (municipal), GMF (4x1000) |
| **Protocolo tecnico** | REST. NIT + Certificado digital. Firma XML con XAdES-BES. Representacion grafica obligatoria |
| **Modulo Tryton** | account_co — PUC completo, NIIF, retenciones ICA/Renta/IVA |
| **Caja biedata** | colombia-dian/ [roadmap Q4 2026] |

### 2.5 Peru 🇵🇪 y Chile 🇨🇱 (roadmap)

| Pais | Organismo | Plan cuentas | Facturacion | Estado |
|---|---|---|---|---|
| Peru | SUNAT | PCGE (Plan Contable General Empresarial) | CPE (Comprobante de Pago Electronico) UBL 2.1 | Roadmap 2027 |
| Chile | SII | PCGA Chile (convergencia IFRS) | DTE (Documento Tributario Electronico) XML | Roadmap 2027 |

## 3. Flujo End-to-End (Universal para toda jurisdiccion)

```
USUARIO crea factura en Tryton (S04)
  │
  ▼ PostgreSQL WAL: UPDATE account_invoice SET state='posted'
  ▼ bKernel: regla invoice_tributaria_trigger.yml
  ▼ Condicion: state=posted AND tax_country IN ['BO','AR','MX','CO']
  ▼ bKernel → Redis Stream: biedata:invoices:{tax_country}
  │
  ▼ biedata.service consume stream
  ▼ Selecciona caja por country → boxes/{pais}/box_engine.yml
  │
  ├── FASE 1 AUTHENTICATE: credenciales de Vault → auth contra organismo
  ├── FASE 2 EXTRACT: leer factura + datos cliente de PostgreSQL
  ├── FASE 3 TRANSFORM: construir XML/JSON segun XSD del organismo
  ├── FASE 4 LOAD: POST al endpoint (SIAT/WSFE/PAC/DIAN)
  ├── FASE 5 UPDATE: almacenar codigo autorizacion en biedata_db
  └── FASE 6 AUDIT: log en biedata_audit_log
  │
  ▼ bKernel detecta escritura en biedata_db via WAL
  ▼ bKernel actualiza tryton_db.account_invoice con codigo fiscal
  │
  ▼ Tryton muestra factura autorizada con numero de autorizacion
```

### Enriquecimiento Smart Tax: Invariantes en el flujo

El flujo de biedata se enriquece con verificaciones de invariantes fiscales de SmartTax:

```
  ├── FASE 2 EXTRACT: leer factura + datos cliente de PostgreSQL
  │   → Verificar INVARIANTE_006 (importe no negativo)
  │   → Verificar INVARIANTE_005 (redondeo HALF-UP en montos)
  │
  ├── FASE 3 TRANSFORM: construir XML/JSON segun XSD del organismo
  │   → Verificar INVARIANTE_001 (SHA-256 del GZIP, no del XML)
  │   → Verificar INVARIANTE_004 (cadena base CUF = 53 chars)
  │   → Verificar INVARIANTE_009 (digito Mod11 correcto)
  │   → Aplicar formula de sector segun codigoDocumentoSector
  │   → Aplicar nota de ajuste segun tipo (24/29/47/48) si corresponde
  │   → Firmar XML con XMLDSig (canonicalizacion C14N, SHA-256)
```

## 4. Estrategia de Resiliencia

### Circuit Breaker por jurisdiccion
Cada caja tiene circuit breaker independiente. SIAT caido no afecta AFIP ni SAT.
```
CLOSED (normal) → N fallos consecutivos → OPEN
OPEN → alert severity=high → timer recovery → HALF-OPEN
HALF-OPEN → 1 solicitud prueba → exito=CLOSED | fallo=OPEN
```

### Reintentos por tipo de error
| Error | ¿Reintento? | Estrategia |
|---|---|---|
| Timeout red | Si | Backoff: 10s→30s→90s (3 intentos) |
| HTTP 500 organismo | Si | Backoff: 60s→300s→600s (3 intentos) |
| Error credenciales 401/403 | No | Alerta inmediata |
| Error validacion datos 400 | No | Marcar factura con error |
| Duplicado | No | Recuperar autorizacion existente |
| Mantenimiento organismo | Si | Cada 30 min (ilimitado) |

### Contingencia Bolivia
Auto-activacion cuando circuit breaker SIAT abre. Facturas con CUFD precargado (Codigo de Control local). SIN acepta sincronizacion posterior en 24h. Maximo 8h en contingencia antes de alerta critical.

### Enriquecimiento Smart Tax: Cache y renovacion

Smart Tax define politicas de cache para credenciales fiscales:
- **CUIS:** Cache local con TTL 48h. Renovacion automatica 1h antes del vencimiento.
- **CUFD:** Cache local con TTL 48h. Renovacion automatica 1h antes del vencimiento.
- **Certificados digitales:** Verificacion de expiracion con 30 dias de anticipacion. Alerta severity=high cuando quedan <30 dias. Renovacion manual via ADSIB/DIGICERT.
- **Tokens AFIP WSAA:** Cache con TTL 12h. Renovacion automatica 30min antes del vencimiento.

## 5. Credenciales en Vault

```
secret/biedata/
├── bolivia-siat/   → NIT, codigo_sistema, certificado .p12, punto_venta
├── argentina-afip/ → CUIT, punto_venta, certificado .crt, clave_privada .key
├── mexico-sat/     → RFC, CSD .cer, clave .key, PAC user/password
└── colombia-dian/  → NIT, certificado digital, token software [roadmap]
```

Acceso: biedata carga credenciales en memoria al startup. Hot-reload con SIGUSR1. Sin consulta a Vault por cada factura.

### Alertas de expiracion certificados
```yaml
- alert: TaxCertExpiringSoon
  expr: (biedata_cert_expiry_timestamp - time()) < 2592000   # 30 dias
  labels: { severity: high, component: biedata }
```

## 6. Codigos de Error por Jurisdiccion

### Bolivia SIAT
908: NIT invalido → notificar. 909: CUFD expirado → renovar+reintentar. 910: Codigo Control incorrecto → recalcular. 911: duplicado → recuperar. 960: SIN caido → circuit breaker. 969: hash incorrecto → verificar INVARIANTE_001. 970: certificado → alerta critica.

### Argentina AFIP
10016: fecha invalida → notificar. 10048: CUIT no existe → notificar. 500: error servicio → reintento. 501: mantenimiento → circuit breaker. 601: CAE rechazado → analizar mensaje.

### Mexico SAT/PAC
301: XML no valido → validar local. 302: CSD vencido → alerta critica. 304: RFC no existe → notificar. 307: CFDI rechazado → revisar payload. 7008: PAC caido → circuit breaker.

## 7. Relacion con SmartTax (S05)

SmartTax = interfaz administrativa (UX, configuracion, visualizacion estado facturas). biedata = capa de ejecucion (llamadas reales a organismos). Son complementarias:

```
Core UI → SmartTax → [configuracion y visualizacion]
                ↕
biedata_db (estado facturas, autorizaciones)
                ↕
biedata.service ← Redis ← bKernel ← WAL ← Tryton
      ↕
APIs tributarias (SIAT/AFIP/SAT/DIAN)
```

### Enriquecimiento Smart Tax: Decisiones de rama logica (SBOS_TAX_E2)

Smart Tax documenta decisiones de implementacion que afectan la logica de negocio fiscal:

1. **Revision de formula manual:** Solo el contador del cliente puede validar si una formula es correcta para su caso. SmartTax no asume automaticamente la formula — presenta la seleccion al HITL para validacion.
2. **Calculo secuencial:** Los impuestos se calculan en orden: base imponible → ICE (si aplica) → descuentos → IVA/debito fiscal → otros impuestos. El orden afecta el resultado final.
3. **Redondeo HALF-UP en cada paso:** Cada operacion monetaria debe redondearse individualmente con HALF-UP antes de pasar al siguiente paso. No redondear solo al final.
4. **Validacion de datos de cliente:** El NIT/CUIT/RFC del cliente se valida contra el organismo antes de emitir la factura. Si el cliente no existe o tiene problemas de registro, la factura no se emite.

### Enriquecimiento Tryton: Fiscalidad SIN (SBOSTRY AREA-09)

El modulo Tryton `account_bo` implementa:
- PUCT completo con los 5 niveles de estructura contable
- Libro de Compras y Ventas IVA (formato SIN)
- F-110 (Declaracion Jurada de IVA)
- IEDGE (Impuesto Especial a los Depósitos en/Giros al Exterior)
- Balance de Sumas y Saldos (formato PUCT)

### Enriquecimiento CMS: Impuestos y plan de cuentas Bolivia

Smart CMS (BOSCMS-A-02-IMPUESTOS-BO) define la configuracion de impuestos en el plan de cuentas Bolivia:
- Cuentas de IVA (credito fiscal y debito fiscal) mapeadas al PUCT
- Cuentas de IUE (25% sobre utilidades) con retenciones configuradas
- Cuentas de IT (3% sobre ingresos brutos)
- Cuentas de RC-IVA con periodicidad mensual
- Configuracion de tasas por tipo de transaccion (venta, compra, exportacion, importacion)

El plan de cuentas Bolivia completo (BOSCMS-A-01-PLAN-CUENTAS-BO) detalla la estructura PUCT con los 5 niveles y las cuentas analiticas abiertas.

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1 Vision | Investigacion web + conocimiento ecosistema | PUCT SIN Bolivia, PUC Colombia, NIF Mexico, PCGA Argentina |
| §2 Bolivia | SBOS-011-Tributario v1.0 + investigacion web | §3 (SIAT modalidades, XML, error codes) + PUCT RND 101800000004 |
| §2 Argentina | SBOS-011-Tributario v1.0 | §4 (AFIP WSFE/WSMTXCA, WSAA, tipos comprobante, homologacion) |
| §2 Mexico | SBOS-011-Tributario v1.0 | §5 (CFDI 4.0, PAC, CSD, cancelacion) |
| §2 Colombia | Investigacion web | PUC Decreto 2650/1993, DIAN UBL 2.1, NIIF Ley 1314/2009 |
| §3 Flujo | SBOS-011-Tributario v1.0 | §2 (diagrama end-to-end, regla YAML bKernel) |
| §4 Resiliencia | SBOS-011-Tributario v1.0 | §6 (circuit breaker, reintentos, contingencia Bolivia) |
| §5 Vault | SBOS-011-Tributario v1.0 | §7 (estructura secretos, hot-reload, alertas) |
| §6 Errores | SBOS-011-Tributario v1.0 | §8 (tablas por jurisdiccion) |
| §7 SmartTax | SBOS-011-Tributario v1.0 | §1.2 (relacion con S05) |

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Aportacion |
|---|---|---|
| V5 | /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-011-Tributario-SIAT-AFIP-SAT.md | Base tributaria original con detalles de SIAT, AFIP, SAT |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_A1_NORMATIVA_VIGENTE_2026.md | Normativa actualizada 2026, Ley 1718 derogacion 70% credito fiscal Sector 55 |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_A3_FORMULAS_POR_SECTOR_v2.md | Formulas de calculo por cada uno de los 52 sectores fiscales Bolivia |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_B3_MATRIZ_NOTAS_AJUSTE.md | Matriz de 51 sectores x 4 notas de ajuste (24, 29, 47, 48) |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_C1_ALGORITMO_CUF_ESPECIFICACION.md | Especificacion completa del algoritmo CUF con 10 vectores de prueba |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_C2_PROTOCOLO_EMPAQUETADO.md | Protocolo TAR+GZIP, XMLDSig y SHA-256 correcto (INVARIANTE_001) |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_C3_PROTOCOLO_XMLDSIG.md | Firma digital XMLDSig con canonicalizacion C14N y SHA-256 |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_E1_INVARIANTES_FISCALES.md | 10 invariantes fiscales verificables (assertions de codigo) |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_E2_DECISIONES_RAMA_LOGICA.md | Decisiones de implementacion: revision manual, calculo secuencial, redondeo, validacion cliente |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_algoritmos_utilizados.md | Algoritmos de facturacion electronica utilizados |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_factura_electronica.md | Guia de facturacion electronica Bolivia SIAT |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_sincronizacion_facturacion_electronica_codigos.md | Sincronizacion de codigos de facturacion electronica |
| Smart Tax | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Tax/context/SBOS_TAX_LEGADO_REFERENCIA_SMARTTAX.md | Bugs documentados del sistema legado a evitar |
| Tryton | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Tryton/context/SBOSTRY - AREA-09-FISCALIDAD-SIN.md | Modulo account_bo, PUCT, Libro C/V, F-110, IEDGE |
| Tryton | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Tryton/context/SBOSTRY - AREA-01-04-FACTURACION.md | Facturacion en Tryton y configuracion de modulos fiscales |
| CMS | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS CMS/context/BOSCMS-A-02-IMPUESTOS-BO.md | Configuracion de impuestos Bolivia en plan de cuentas |
| CMS | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS CMS/context/BOSCMS-A-01-PLAN-CUENTAS-BO.md | Plan de cuentas Bolivia PUCT completo (5 niveles) |
| Correlacion V8 | Integracion SmartTax + biedata + Tryton | Invariantes fiscales en el flujo biedata, cache de credenciales, arquitectura de 3 capas |

---

_SKULL · SBOS · SBOS-044-FISCAL-CONTABLE-LATAM · V8 Enriquecido · Mayo 2026_
