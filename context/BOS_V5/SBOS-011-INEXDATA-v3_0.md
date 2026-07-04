# SBOS-011
## SBOS Data Integration: Federated Batch Exchange
### Daemon biedata.service · Lenguaje: Rust

**SKULL · SBOS — Sovereign Business Operating System**
**v4.0 · Marzo 2026**

---

| Campo | Valor |
|-------|-------|
| **Nombre original** | SBOS Data Integration |
| **Nombre conceptual** | SBOS Data Integration: Federated Batch Exchange |
| **Daemon** | `biedata` |
| **Servicio systemd** | `biedata.service` |
| **Lenguaje** | Rust |
| **Unidad declarativa** | Caja |
| **Directorio** | `/etc/bos/blibs/biedata/boxes/<nombre_box>/` |

---

**Código:** SBOS-011
**Versión:** 3.0
**Estado:** ACTIVO
**Extensión:** SBOS-011-Tributario-SIAT-AFIP-SAT.md — SBOS-011-EXT-TRIBUTARIO (Integración SIAT/AFIP/SAT — Bolivia, Argentina, México — archivo separado permanente, 660+ líneas)
**Clasificación:** Especificación Técnica — Motor de Integración de Datos

---

## Tabla de Contenidos

1. [Qué es SBOS Data Integration](#1-qué-es-biedata)
2. [SBOS Data Integration en el Contexto de la Industria](#2-contexto-de-la-industria)
3. [Posición en el Ecosistema](#3-posición-en-el-ecosistema)
4. [Diagrama de Posición Arquitectónica](#4-diagrama-arquitectónico)
5. [Principios Arquitectónicos](#5-principios-arquitectónicos)
6. [El Modelo de Cajas](#6-el-modelo-de-cajas)
7. [Los Cuatro Contratos de una Caja](#7-los-cuatro-contratos-de-una-caja)
8. [El Contrato de Identidad: manifest.yml](#8-manifestyml)
9. [El Contrato Temporal: box_engine.yml](#9-box_engineyml)
10. [El Catálogo de Tareas: box_catalog.so](#10-box_catalogso)
11. [Los Resources: Conocimiento Cristalizado](#11-resources)
12. [El Motor Binario SBOS Data Integration](#12-el-motor-binario)
13. [La Box API — Contrato entre Motor y Caja](#13-box-api)
14. [Seguridad de los .so — Firma Criptográfica](#14-seguridad)
15. [Integración con el SBOS Data Kernel — El WAL como Canal](#15-integración-bkernel)
16. [La Base de Datos Propia: biedata_db](#16-biedata-db)
17. [Ciclo de Vida como Servicio systemd](#17-systemd)
18. [Catálogo de Cajas de Ejemplo](#18-catálogo-de-cajas)
19. [Flujos Completos de Integración](#19-flujos-completos)
20. [Fronteras que SBOS Data Integration Nunca Cruza](#20-fronteras)
21. [Hoja de Ruta de Desarrollo](#21-hoja-de-ruta)
22. [Registro de Cambios v4.0](#22-registro-de-cambios)

---

## 1. Qué es SBOS Data Integration

SBOS Data Integration es el **motor soberano de integración de datos del SBOS**. Es un daemon binario que conecta el mundo externo con el stack — moviendo datos hacia adentro (Import) y hacia afuera (Export) — transformando en el camino según cajas declarativas que encapsulan todo el conocimiento de cada proceso de integración.

El nombre describe exactamente lo que hace: **In** (importar) + **Ex** (exportar) + **Data** (datos).

```
SBOS Data Kernel:    escucha WAL        → procesa reglas YAML   → sincroniza apps internas
SBOS Data Integration (biedata): escucha eventos    → selecciona caja        → ejecuta box_engine.yml
                                                           + box_catalog.so
                                                        → emite hacia stack / mundo externo
```

SBOS Data Integration no tiene interfaz gráfica. No expone APIs REST al exterior. Es un procesador de datos autónomo y silencioso — idéntico en naturaleza al SBOS Data Kernel, pero orientado hacia el exterior del stack.

### La metáfora correcta

SBOS Data Integration es la **aduana soberana** del SBOS. Todo dato que entra o sale del stack pasa por SBOS Data Integration. La aduana no decide qué pasa — las cajas declaran las reglas. La aduana las ejecuta con precisión, deja registro de todo, y nunca deja pasar algo que no tenga caja registrada.

### Relación con otros documentos SBOS

| Documento | Relación |
|---|---|
| **SBOS-010** | SBOS Data Kernel es el daemon hermano — SBOS Data Integration escribe en sus BDs, SBOS Data Kernel detecta via WAL |
| **SBOS-002** | SBOS Data Integration aparece en el diagrama de arquitectura general |
| **SBOS-014** | SBOS AI Tools puede solicitar a SBOS Data Integration exportar datos a sistemas externos |

---

## 2. SBOS Data Integration en el Contexto de la Industria

### El problema de la integración empresarial

Las empresas medianas tienen datos valiosos atrapados en sistemas externos: clientes en Excel, empleados en sistemas legacy, inventarios en FoxPro, y obligaciones tributarias que requieren enviar datos a sistemas gubernamentales. La industria ofrece tres soluciones, todas con limitaciones severas para el mercado objetivo del SBOS:

**ETL tradicional (Airbyte, Talend):** Diseñado para mover datos a data warehouses analíticos. Sus escrituras van a tablas intermedias (`_airbyte_*`), no a las tablas nativas de las apps. Requieren infraestructura adicional. No integran con el WAL.

**iPaaS SaaS (Zapier, Make, Boomi):** Los datos pasan por servidores de terceros. Inaceptable para empresas con datos regulados (GDPR, normativa boliviana de protección de datos). Dependencia de conectividad a internet para operaciones críticas.

**Desarrollo a medida:** Scripts Python/Node ad-hoc por cada integración. Sin estructura, sin auditoría, sin reutilización. Cada desarrollador reinventa los mismos patrones.

### La solución de SBOS Data Integration

| Dimensión | ETL tradicional | SBOS Data Integration |
|---|---|---|
| Destino | Data warehouse analítico | BDs operacionales del stack SBOS |
| Escritura | Tablas intermedias `_airbyte_*` | Tablas nativas de cada app |
| Propagación | Ninguna — termina en el warehouse | SBOS Data Kernel detecta via WAL y propaga |
| Conocimiento | Conector genérico configurable | Caja soberana con lógica propia (.so) |
| Soberanía | Cloud-hosted opcional | 100% en servidor del cliente |
| Formato de destino | Schema del warehouse | Schema nativo de OrangeHRM, Tryton, EspoCRM |

---

## 3. Posición en el Ecosistema

SBOS Data Integration vive en el host Ubuntu como servicio systemd, junto al SBOS Data Kernel y SBOS AI Tools. No vive en Kubernetes porque necesita acceso directo a archivos del sistema (Excel en carpetas compartidas, DBF de FoxPro, certificados digitales del SIAT).

```
HOST UBUNTU (systemd — fuera de K8s)
  ├── SBOS IAM Installer (systemd)   → dominio: INFRAESTRUCTURA
  ├── SBOS Data Kernel (systemd)         → dominio: DATOS INTERNOS
  ├── SBOS Data Integration (systemd)        → dominio: INTEGRACIÓN EXTERNA  ← este documento
  └── SBOS AI Tools (systemd)        → dominio: ORQUESTACIÓN

KUBERNETES (pods)
  └── 110+ aplicaciones del stack
```

La separación entre SBOS Data Kernel e SBOS Data Integration es funcional y precisa:

| SBOS Data Kernel | SBOS Data Integration |
|---|---|
| Observa cambios internos (WAL) | Ingesta desde fuentes externas |
| Sincroniza apps del stack entre sí | Conecta el stack con el mundo exterior |
| Opera de forma continua (loop infinito) | Opera por eventos (schedule, file_watch, manual) |
| Conocimiento en YAML | Conocimiento en YAML + .so compilados |
| Siempre activo | Siempre activo como daemon, actúa solo cuando hay triggers |

---

## 4. Diagrama de Posición Arquitectónica

```
┌──────────────────────────────────────────────────────────────────┐
│  MUNDO EXTERIOR                                                   │
│                                                                   │
│  Excel/CSV  │  FoxPro DBF  │  APIs REST  │  SIAT Bolivia         │
│  MySQL legacy│  SQL Server  │  SFTP/FTP   │  Bancos               │
└──────────────────────────────────────────────────────────────────┘
                           │ IMPORT                  EXPORT │
                           ▼                                ▼
┌──────────────────────────────────────────────────────────────────┐
│  HOST UBUNTU                                                      │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  SBOS Data Integration (systemd — siempre activo)                        │  │
│  │                                                             │  │
│  │  Motor Binario                                              │  │
│  │    ├── Event Listener   (escucha eventos de integración)    │  │
│  │    ├── Box Resolver     (selecciona la caja correcta)       │  │
│  │    ├── Box Loader       (dlopen box_catalog.so)             │  │
│  │    ├── Engine Executor  (ejecuta box_engine.yml)            │  │
│  │    └── Result Emitter   (registra en biedata_db, notifica) │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  /etc/bos/blibs/biedata/boxes/                                             │
│    ├── import/clientes_excel/   ← CAJA                           │
│    ├── import/items_foxpro/     ← CAJA                           │
│    ├── export/facturas_siat/    ← CAJA                           │
│    └── export/nomina_banco/     ← CAJA                           │
│                                                                   │
│  biedata_db (PostgreSQL)  ← registro de ejecuciones             │
└──────────────────────────────────────────────────────────────────┘
         │ import: escribe con origin='biedata'
         ▼
┌─────────────────────────────┐
│  STACK SBOS (PostgreSQL)   │  ──► WAL ──► SBOS Data Kernel ──► propaga
│  OrangeHRM, Tryton, etc.    │
└─────────────────────────────┘
         ▲ export: solo lectura (SELECT)
```

**El flujo de import:** SBOS Data Integration escribe en las BDs del stack con `origin='biedata'`. El SBOS Data Kernel detecta esas escrituras vía WAL y las propaga al resto del stack según sus reglas. SBOS Data Integration no necesita saber qué hace el SBOS Data Kernel con los datos — esa es la separación de responsabilidades.

**El flujo de export:** SBOS Data Integration lee de las BDs del stack con credenciales de solo lectura y entrega los datos al sistema externo. Nunca escribe en el stack durante un export.

---

## 5. Principios Arquitectónicos

**P1 — Un daemon, dos direcciones.**
Un solo binario maneja import y export. La dirección está declarada en el `manifest.yml` de cada caja. El motor es el mismo.

**P2 — La caja es la unidad de conocimiento.**
Todo el conocimiento de un proceso de integración vive en su caja. El motor SBOS Data Integration no sabe que FoxPro existe, ni que el SIAT Bolivia tiene un formato XML específico. Las cajas saben. El motor ejecuta.

**P3 — box_engine.yml declara la intención. box_catalog.so implementa la lógica.**
El `box_engine.yml` es declarativo — dice qué fases ocurren y en qué orden, sin lógica. El `box_catalog.so` es imperativo — implementa las tareas que el YAML no puede expresar.

**P4 — Firma de origen obligatoria en import.**
Toda escritura de una caja de importación lleva `pg_replication_origin_session_setup('biedata')` antes del DML. El SBOS Data Kernel detecta estas escrituras vía WAL y las propaga normalmente — no las filtra. Solo filtra `origin='bkernel'` para prevenir sus propios loops.

**P5 — Export es solo lectura sobre el stack.**
Las cajas de exportación tienen credenciales PostgreSQL con permisos `SELECT` únicamente sobre las BDs del stack. Nunca escriben en ellas.

**P6 — Idempotencia obligatoria en import.**
Toda escritura usa `INSERT ... ON CONFLICT (upsert_key) DO UPDATE`. Ejecutar la misma caja dos veces produce el mismo resultado. Sin duplicados.

**P7 — Binario como motor, .so como conocimiento.**
El mismo meta-patrón del SBOS Data Kernel: el binario es estable y genérico. El conocimiento específico vive en los `.so` de cada caja — cargados dinámicamente con `dlopen()`. Agregar una nueva integración es crear una nueva caja. El motor no cambia.

**P8 — Auditoría completa.**
Toda ejecución de caja queda registrada en `biedata_db`: caja ejecutada, dirección, registros procesados, exitosos, fallidos, duración, operador.

---

## 6. El Modelo de Cajas

La caja es la unidad atómica de integración de SBOS Data Integration. Es el equivalente exacto de la ficha del SBOS IAM Installer — encapsula todo el conocimiento necesario para ejecutar un proceso de integración específico.

```
/etc/bos/blibs/biedata/
└── boxes/
    ├── import/                            ← cajas de importación
    │   ├── clientes_excel/                ← CAJA: importar clientes desde Excel
    │   │   ├── manifest.yml
    │   │   ├── box_engine.yml
    │   │   ├── box_catalog.so
    │   │   └── resources/
    │   │       ├── mapping.yml
    │   │       └── validation_rules.yml
    │   │
    │   ├── items_foxpro/                  ← CAJA: importar items desde FoxPro
    │   │   ├── manifest.yml
    │   │   ├── box_engine.yml
    │   │   ├── box_catalog.so
    │   │   └── resources/
    │   │       └── mapping.yml
    │   │
    │   ├── empleados_mysql/               ← CAJA: migrar empleados desde MySQL legacy
    │   │   ├── manifest.yml
    │   │   ├── box_engine.yml
    │   │   ├── box_catalog.so
    │   │   └── resources/
    │   │       └── mapping.yml
    │   │
    │   └── productos_api_proveedor/       ← CAJA: importar desde API externa
    │       ├── manifest.yml
    │       ├── box_engine.yml
    │       ├── box_catalog.so
    │       └── resources/
    │           ├── mapping.yml
    │           └── api_schema.json
    │
    └── export/                            ← cajas de exportación
        ├── facturas_siat/                 ← CAJA: exportar facturas al SIAT Bolivia
        │   ├── manifest.yml
        │   ├── box_engine.yml
        │   ├── box_catalog.so
        │   └── resources/
        │       ├── mapping.yml
        │       └── format.xml             ← plantilla XML del SIAT
        │
        ├── nomina_banco/                  ← CAJA: exportar nómina al banco
        │   ├── manifest.yml
        │   ├── box_engine.yml
        │   ├── box_catalog.so
        │   └── resources/
        │       ├── mapping.yml
        │       └── format_banco.txt       ← formato de texto fijo del banco
        │
        └── reporte_auditoria/             ← CAJA: generar reporte Excel de auditoría
            ├── manifest.yml
            ├── box_engine.yml
            ├── box_catalog.so
            └── resources/
                ├── mapping.yml
                └── template.xlsx
```

### La propiedad más importante

SBOS Data Integration Core no sabe que FoxPro existe. La caja `items_foxpro` no sabe cómo funciona el motor SBOS Data Integration. Esta ignorancia mutua es el diseño — no un accidente. Agregar la integración número 50 al SBOS es crear una carpeta en `boxes/`. Nada más cambia en el sistema.

---

## 7. Los Cuatro Contratos de una Caja

| Contrato | Archivo | Quién lo lee | Descripción |
|---|---|---|---|
| **Identidad** | `manifest.yml` | Motor SBOS Data Integration | Qué es la caja, cómo se dispara, qué necesita |
| **Temporal** | `box_engine.yml` | Motor SBOS Data Integration | Las fases de ejecución en orden declarativo |
| **Lógica** | `box_catalog.so` | Motor SBOS Data Integration (dlopen) | Tareas específicas de esta integración |
| **Conocimiento** | `resources/` | box_catalog.so | Mappings, plantillas, schemas de validación |

---

## 8. El Contrato de Identidad: manifest.yml

```yaml
# /etc/bos/blibs/biedata/boxes/export/facturas_siat/manifest.yml

identity:
  id:          "export_facturas_siat"
  name:        "Exportar Facturas al SIAT Bolivia"
  description: "Exporta las facturas del período al portal tributario SIAT"
  version:     "1.2"
  direction:   "export"        # "import" | "export"
  category:    "fiscal"        # fiscal | rrhh | inventario | contabilidad | custom

trigger:
  type: schedule               # schedule | event | manual | file_watch
  cron: "0 8 1 * *"           # Primer día de cada mes a las 8:00

source:                        # para export: de dónde leer
  app: tryton
  credentials: readonly        # solo lectura — siempre para export

destination:                   # para export: a dónde entregar
  type: http_api
  url_env: "SIAT_API_URL"
  auth: certificate

requirements:
  depends_on:
    - type: ficha
      target: tryton
      state: installed
  env_vars:
    - SIAT_API_URL
    - SIAT_CERT_PATH
    - SIAT_KEY_PATH
    - EMPRESA_NIT

governance:
  category: 2                  # 1=libre · 2=confirmación · 3=dual-control
  notify_channel: "#contabilidad"
  notify_on: [success, failure]

health:
  last_execution_max_age_hours: 36
  alert_channel: "#bdata-alerts"
```

```yaml
# /etc/bos/blibs/biedata/boxes/import/clientes_excel/manifest.yml

identity:
  id:          "import_clientes_excel"
  name:        "Importar Clientes desde Excel"
  description: "Importa clientes desde archivo Excel al stack SBOS"
  version:     "1.0"
  direction:   "import"
  category:    "crm"

trigger:
  type:        file_watch      # vigila carpeta de entrada
  watch_path:  "/mnt/biedata/incoming/clientes/"
  pattern:     "clientes_*.xlsx"

destination:                   # para import: a dónde escribir
  app:         espocrm
  table:       accounts
  upsert_key:  email
  origin:      biedata        # firma WAL obligatoria

requirements:
  depends_on:
    - type: ficha
      target: espocrm
      state: installed

governance:
  category: 1
  notify_channel: "#ventas-ops"
  notify_on: [success, partial, failure]
```

---

## 9. El Contrato Temporal: box_engine.yml

Las fases declarativas definen la intención de cada momento de la ejecución. No contienen lógica. Las tareas con nombre en el catálogo global del motor son **globales** (compiladas en el binario). Las demás se buscan en `box_catalog.so` de la caja.

```yaml
# /etc/bos/blibs/biedata/boxes/export/facturas_siat/box_engine.yml

phases:

  prepare:
    tasks:
      - task: "validate_env_vars"           # GLOBAL
        params:
          required: [SIAT_API_URL, SIAT_CERT_PATH, EMPRESA_NIT]
      - task: "check_source_connection"     # GLOBAL
        params:
          app: tryton
      - task: "siat_validate_certificate"   # ESPECÍFICA — en box_catalog.so
        params:
          cert_env: SIAT_CERT_PATH
          key_env:  SIAT_KEY_PATH

  read:
    tasks:
      - task: "siat_query_facturas"         # ESPECÍFICA
        params:
          mapping:   "resources/mapping.yml"
          date_from: "first_day_of_last_month()"
          date_to:   "last_day_of_last_month()"
        output: facturas_data

  transform:
    tasks:
      - task: "apply_mapping"               # GLOBAL
        params:
          data:    "{facturas_data}"
          mapping: "resources/mapping.yml"
        output: facturas_mapped
      - task: "siat_render_xml"             # ESPECÍFICA
        params:
          data:     "{facturas_mapped}"
          template: "resources/format.xml"
        output: facturas_xml

  validate:
    tasks:
      - task: "siat_validate_xml_schema"    # ESPECÍFICA
        params:
          xml: "{facturas_xml}"
        on_failure: abort

  deliver:
    tasks:
      - task: "siat_post_facturas"          # ESPECÍFICA
        params:
          xml:     "{facturas_xml}"
          url_env: SIAT_API_URL
        output: siat_response

  finalize:
    tasks:
      - task: "store_response"              # GLOBAL
        params:
          response: "{siat_response}"
      - task: "notify_completion"           # GLOBAL
        params:
          message: "Facturas SIAT: {result.total} registros. Código: {siat_response.codigo}"
```

---

## 10. El Catálogo de Tareas: box_catalog.so

Cada caja tiene su propio shared object con las funciones específicas de esa integración. El motor SBOS Data Integration lo carga dinámicamente con `dlopen()` antes de ejecutar la caja y lo libera al terminar.

### La Box API — Contrato entre el motor y el .so

```c
// biedata_box_api.h — distribuido por SKULL
// C ABI estable — compatible Rust y C++

typedef struct {
    const char* name;       // "export_facturas_siat"
    const char* version;    // "1.2.0"
    const char* direction;  // "import" | "export"

    // Función principal — ejecuta una tarea de la caja
    InExResult (*execute_task)(
        const char*        task_name,  // nombre de la tarea del box_engine.yml
        const InExContext* ctx,        // contexto de ejecución (params, outputs anteriores)
        const InExHandles* handles     // acceso a recursos del motor
    );

    // Validación en startup
    InExResult (*validate)(const InExHandles* handles);

} BiedataBox;

// Contexto de ejecución
typedef struct {
    const char* box_id;         // "export_facturas_siat"
    const char* run_id;         // UUID de la ejecución actual
    const char* params_json;    // params del box_engine.yml para esta tarea
    const char* outputs_json;   // outputs de tareas anteriores (pipeline)
    const char* resources_path; // path a resources/ de la caja
} InExContext;

// Punto de entrada
BiedataBox* biedata_box_init();
```

### Ejemplo de tarea en Rust

```rust
// En box_catalog.so de la caja export_facturas_siat
#[no_mangle]
pub extern "C" fn execute_task(
    task_name: *const c_char,
    ctx:       *const InExContext,
    handles:   *const InExHandles,
) -> InExResult {
    let task = unsafe { CStr::from_ptr(task_name).to_str().unwrap() };

    match task {
        "siat_validate_certificate" => task_validate_cert(ctx, handles),
        "siat_query_facturas"       => task_query_facturas(ctx, handles),
        "siat_render_xml"           => task_render_xml(ctx, handles),
        "siat_validate_xml_schema"  => task_validate_schema(ctx, handles),
        "siat_post_facturas"        => task_post_to_siat(ctx, handles),
        _                           => InExResult::TaskNotFound,
    }
}
```

### Catálogo global del motor (tareas universales)

Estas tareas están compiladas en el binario SBOS Data Integration y disponibles para cualquier caja:

| Tarea | Dirección | Descripción |
|---|---|---|
| `validate_env_vars` | ambas | Verifica que las variables requeridas existen |
| `check_source_connection` | ambas | Verifica conexión a la app origen |
| `detect_incoming_file` | import | Detecta archivo en watch_path |
| `apply_mapping` | ambas | Aplica mapping.yml a los datos de entrada |
| `validate_rows` | import | Valida filas según validation_rules.yml |
| `upsert_with_origin` | import | INSERT...ON CONFLICT con origin='biedata' |
| `store_response` | export | Guarda respuesta en biedata_db |
| `notify_completion` | ambas | Notifica al canal del manifest |
| `archive_file` | import | Mueve archivo procesado a carpeta de archivado |
| `log_execution` | ambas | Registra ejecución completa en biedata_db |

---

## 11. Los Resources: Conocimiento Cristalizado

Los archivos en `resources/` no son ejemplos. Son los artefactos exactos usados durante la ejecución — mappings probados en producción, plantillas validadas por el SIAT, schemas de validación reales.

### mapping.yml — transformación de campos

```yaml
# resources/mapping.yml para export/facturas_siat
# Mapeo del schema de Tryton al formato XML del SIAT

field_map:
  NumeroFactura: source.numero_factura
  FechaEmision:  "format_date(source.fecha, '%Y-%m-%d')"
  RazonSocial:   source.cliente
  NIT:           source.nit_cliente
  MontoTotal:    "format_decimal(source.monto_total, 2)"
  MontoIVA:      "format_decimal(source.iva, 2)"
  CodigoControl: source.codigo_control

---
# resources/mapping.yml para import/clientes_excel
# Mapeo de Excel → EspoCRM accounts

field_map:
  name:                 source.razon_social
  email:                "lower(source.correo)"
  phone:                source.telefono
  billing_address_city: source.ciudad
  account_type:         "'Customer'"
  assigned_user:        "lookup('vendedor_map', source.vendedor)"

lookups:
  vendedor_map:
    "Juan Pérez":   "juan.perez@empresa.com"
    "María García": "maria.garcia@empresa.com"
```

### validation_rules.yml

```yaml
# resources/validation_rules.yml para import/clientes_excel

rules:
  - field:      correo
    required:   true
    format:     email

  - field:      razon_social
    required:   true
    min_length: 2

  - field:      nit
    required:   false
    pattern:    "^[0-9]{7,10}$"
```

---

## 12. El Motor Binario SBOS Data Integration

### Estructura de una Caja

```
/etc/bos/blibs/biedata/boxes/<nombre_box>/
├── manifest.yml          ← identidad, sistema externo, schedule
├── box_engine.yml        ← flujo declarativo import/export
├── box_catalog.so        ← transformaciones y validaciones (C ABI)
└── resources/
    └── mappings.yml      ← mapeo de campos
```

Agregar un sistema externo nuevo = crear su carpeta en `/etc/bos/blibs/biedata/boxes/`.
El motor biedata no cambia. Hot-reload via inotify.

### Estructura del motor

```
SBOS Data Integration (binario)
├── Event Listener      — escucha vía Redis Stream, file_watch, cron, manual
├── Box Resolver        — dado el evento, encuentra la caja en /etc/bos/blibs/biedata/boxes/
├── Box Loader          — carga manifest.yml, box_engine.yml, box_catalog.so (dlopen)
├── Engine Executor     — ejecuta las fases de box_engine.yml en orden
│   ├── Task Dispatcher — distingue tarea GLOBAL (motor) vs ESPECÍFICA (box_catalog.so)
│   ├── Context Manager — gestiona el pipeline de outputs entre tareas
│   └── Error Handler   — on_failure: skip_row | abort | continue
├── Result Emitter      — registra en biedata_db, notifica al canal configurado
└── Hot-Reload (SIGUSR1)— recarga cajas nuevas o actualizadas sin reiniciar
```

### Lenguaje de implementación

SBOS Data Integration es un binario **Rust** — mismo criterio que el SBOS Data Kernel. Procesa integraciones que pueden involucrar archivos grandes (Excel de 50,000 filas, XML de 10MB), conexiones a BDs legacy, y llamadas HTTP con certificados digitales. El binario da rendimiento predecible y control de memoria determinista, y comparte la misma Plugin API (C ABI estable) con el SBOS Data Kernel.

---

## 12b. Stack Tecnológico del Daemon biedata

### Justificación técnica de Rust para ETL transaccional

SBOS Data Integration procesa archivos grandes — Excel de 50K+ filas, CSV de varios GB — como parte de integraciones con sistemas externos. El requisito crítico es: una importación de 50.000 filas de Excel debe completarse de principio a fin sin interrupciones por GC, y sin consumir más memoria de la estrictamente necesaria.

**Benchmark calamine (Rust) vs alternativas** — archivo XLSX de 1.000.001 filas y 41 columnas (~186 MB):

| Biblioteca | Lenguaje | Tiempo (1M filas) | Relativo | Notas |
|---|---|---|---|---|
| **calamine** | Rust | 25.3s | **1x (más rápido)** | Sin GC, memoria predecible |
| **excelize** | Go | 44.3s | 1.75x más lento | GC spikes en archivos grandes |
| **ClosedXML** | C# (.NET) | 178.3s | 7x más lento | GC overhead alto |
| **openpyxl** | Python | 238.6s | 9.4x más lento | Interpretado + GC |

Calamine es 9.4x más rápido que openpyxl (Python) y 7x más rápido que ClosedXML (.NET). **Polars** — DataFrame de Python de alta performance usado en producción para analytics a escala de GB — usa calamine como su motor de lectura de Excel por defecto, validando que es production-ready para archivos grandes.

**Por qué sin GC es crítico para ETL transaccional:** en biedata, una importación de Excel es una transacción: o importa todas las filas o no importa ninguna (rollback). Si el GC pausa el proceso durante la transacción, el estado de la BD puede quedar parcialmente escrito. Con Rust, el ownership garantiza que los recursos se liberan en el orden correcto y la transacción puede hacer rollback de forma atómica sin interferencia del runtime.

### Stack de dependencias

| Componente | Herramienta / Crate | Propósito |
|---|---|---|
| **Lenguaje** | Rust 1.85+ (Edition 2024) | Daemon principal |
| **Runtime async** | tokio 1.x | Concurrencia I/O para integraciones |
| **Excel reader** | calamine 0.32 | Lectura XLSX/XLS/ODS sin GC pauses |
| **Excel writer** | rust_xlsxwriter 0.7 | Generación de reportes XLSX |
| **CSV parsing** | csv 1.3 + serde | Procesamiento de archivos CSV |
| **HTTP client** | reqwest 0.12 (async) | Llamadas a APIs REST externas |
| **XML/SOAP** | quick-xml 0.36 | Integración con servicios SOAP/XML (SIAT, AFIP, SAT) |
| **SFTP** | russh 0.44 + tokio | Transferencia de archivos SFTP |
| **PostgreSQL client** | tokio-postgres + deadpool | Escritura en BD con `origin='biedata'` |
| **Redis client** | redis-rs (tokio) | Lectura de comandos desde bkernel |
| **TLS/Certificados** | rustls 0.23 | Conexiones HTTPS seguras (SIAT, AFIP, SAT) |
| **Config/Boxes** | toml + serde_yaml | Lectura de box_engine.yml |
| **Hot-reload .so** | libloading 0.8 | Carga de box_catalog.so |
| **Logging** | tracing + tracing-subscriber | Audit trail de integraciones |
| **Testing** | cargo test + mockall | Mocks de APIs externas |
| **Build** | cargo --release (MUSL) | Binario estático |

### Pipeline CI/CD — biedata

| Etapa | Comando | Criterio de éxito |
|---|---|---|
| **Format** | `cargo fmt --check` | Sin diffs de formato |
| **Lint** | `cargo clippy -- -D warnings` | 0 warnings |
| **Test** | `cargo test --all-features` | 100% tests pasan |
| **Audit** | `cargo audit` | Sin CVEs críticas |
| **Build** | `cross build --release --target x86_64-unknown-linux-musl` | Binario estático generado |
| **Sign** | ed25519 firma del binario | Firma verificable por bos |

---


## 13. La Box API — Contrato entre Motor y Caja

El contrato C ABI garantiza compatibilidad binaria entre cajas compiladas en Rust — el mismo principio del SBOS Data Kernel. El C ABI es la interfaz estable que permite actualizar el motor y las cajas de forma independiente. Ver §10 para el contrato completo.

---

## 14. Seguridad de los .so — Firma Criptográfica

```
DESARROLLO:
  Developer escribe box_catalog.rs usando la SBOS Data Integration Box API
  → cargo build --release --lib
  → genera libfacturas_siat.so (renombrado a box_catalog.so)

DESPLIEGUE:
  SBOS IAM Installer copia box_catalog.so a /etc/bos/blibs/biedata/boxes/export/facturas_siat/
  → envía SIGUSR1 al daemon SBOS Data Integration (hot-reload)
  → motor llama dlopen() + dlsym("biedata_box_init")
  → llama box.validate() para verificar entorno
  → registra la caja como disponible

ACTUALIZACIÓN:
  Nueva versión del .so → mismo proceso (SIGUSR1)
  Versión mayor distinta → requiere confirmación explícita del admin

SEGURIDAD:
  Firma criptográfica obligatoria — SBOS IAM Installer firma cada .so con clave SKULL
  Motor verifica firma antes de cargar — .so no firmados son rechazados
  Handles de solo lectura por defecto — db_write solo si direction='import'
  Timeout de ejecución: 30s por fase (configurable), evento va al error_log si excede
```

---

## 15. Integración con el SBOS Data Kernel — El WAL como Canal

La integración entre SBOS Data Integration y SBOS Data Kernel es indirecta, por diseño. Ninguno conoce al otro directamente.

```
Caja import/clientes_excel escribe en EspoCRM.accounts
  con origin='biedata' (pg_replication_origin)
         │
         │  PostgreSQL WAL:
         │  {origin:'biedata', table:'accounts', op:INSERT/UPDATE}
         ▼
SBOS Data Kernel detecta (origin='biedata' NO está filtrado — solo filtra 'bkernel')
         │
         ├── ESPO-001: sincroniza party en Tryton
         ├── CROSS-005: crea usuario en Keycloak si el empleado es nuevo
         └── ESPO-IDX-001: encola en SBOS Data RAG para indexación
```

SBOS Data Integration no conoce al SBOS Data Kernel. El SBOS Data Kernel no conoce a SBOS Data Integration. El WAL es el bus de comunicación soberano entre los dos daemons.

### Por qué esta separación es correcta

Si SBOS Data Integration llamara directamente al SBOS Data Kernel después de importar datos, los dos sistemas estarían acoplados. Un fallo del SBOS Data Kernel podría bloquear a SBOS Data Integration. Con el WAL como canal intermedio, SBOS Data Integration termina su trabajo (escribir en la BD del stack) y el SBOS Data Kernel hace el suyo de forma completamente independiente. Los dos sistemas pueden fallar y recuperarse de forma autónoma sin afectarse mutuamente.

---

## 16. La Base de Datos Propia: biedata_db

`biedata_db` es la base de datos PostgreSQL propia de SBOS Data Integration en el host. Contiene el estado operacional y el historial de todas las ejecuciones.

```sql
-- Ejecuciones de cajas
CREATE TABLE box_executions (
    id              BIGSERIAL PRIMARY KEY,
    box_id          TEXT NOT NULL,
    direction       TEXT NOT NULL,      -- import | export
    trigger_type    TEXT NOT NULL,      -- schedule | file_watch | manual | event
    trigger_detail  TEXT,               -- nombre del archivo, nombre del evento
    run_id          UUID NOT NULL,
    status          TEXT NOT NULL,      -- running | success | partial | failed
    records_total   INTEGER,
    records_success INTEGER,
    records_failed  INTEGER,
    duration_ms     INTEGER,
    started_at      TIMESTAMPTZ DEFAULT NOW(),
    finished_at     TIMESTAMPTZ,
    operator        TEXT                -- usuario Keycloak que disparó si fue manual
);

-- Errores por fila en import
CREATE TABLE box_row_errors (
    id              BIGSERIAL PRIMARY KEY,
    execution_id    BIGINT REFERENCES box_executions(id),
    row_number      INTEGER,
    phase           TEXT,
    field           TEXT,
    error           TEXT,
    raw_data        JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Respuestas de sistemas externos (para export)
CREATE TABLE box_responses (
    id              BIGSERIAL PRIMARY KEY,
    execution_id    BIGINT REFERENCES box_executions(id),
    response_code   INTEGER,
    response_body   TEXT,
    delivered_at    TIMESTAMPTZ DEFAULT NOW()
);
```

El administrador puede consultar `biedata_db` desde el Core UI o desde Grafana para ver el estado de todas las integraciones, las filas con error, y las respuestas de sistemas externos.

---

## 17. Ciclo de Vida como Servicio systemd

```ini
# /etc/systemd/system/biedata.service
[Unit]
Description=SBOS Data Integration — Sovereign Data Integration Engine (SBOS)
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=notify
ExecStart=/usr/local/bin/biedata --config /etc/bos/blibs/biedata/biedata.toml
ExecReload=/bin/kill -USR1 $MAINPID
Restart=always
RestartSec=5
User=biedata
WatchdogSec=60
NotifyAccess=main

[Install]
WantedBy=multi-user.target
```

### Log de ejemplo en operación

```
$ journalctl -u biedata -f

Mar 07 08:00:00 biedata[2341]: INFO  box.start  box=export_facturas_siat trigger=schedule run=abc123
Mar 07 08:00:01 biedata[2341]: INFO  phase.done phase=prepare duration_ms=120
Mar 07 08:00:03 biedata[2341]: INFO  phase.done phase=read records=147 duration_ms=1823
Mar 07 08:00:04 biedata[2341]: INFO  phase.done phase=transform duration_ms=340
Mar 07 08:00:05 biedata[2341]: INFO  phase.done phase=deliver response_code=200
Mar 07 08:00:05 biedata[2341]: INFO  box.done   box=export_facturas_siat total=147 success=147 duration_ms=2410

Mar 07 14:23:10 biedata[2341]: INFO  box.start  box=import_clientes_excel trigger=file_watch file=clientes_2026-03-07.xlsx
Mar 07 14:23:12 biedata[2341]: WARN  row.error  box=import_clientes_excel row=34 phase=validate error="email inválido"
Mar 07 14:23:13 biedata[2341]: INFO  box.done   box=import_clientes_excel total=312 success=311 failed=1 duration_ms=2910
```

---

## 18. Catálogo de Cajas de Ejemplo

Este catálogo proporciona cuatro cajas de referencia que cubren los casos de integración más comunes en el mercado iberoamericano. Son puntos de partida — cada cliente las adapta a su contexto específico.

### Caja 1 — Import: Clientes desde Excel

**Caso de uso:** Una empresa tiene su base de clientes en hojas Excel compartidas. El administrador quiere importar esta lista al CRM (EspoCRM) del stack SBOS para empezar a operar desde el nuevo sistema.

**Caja:** `import/clientes_excel/`

Flujo de ejecución:
1. **prepare:** Verifica que EspoCRM está disponible y el archivo Excel existe en la carpeta vigilada
2. **read:** box_catalog.so lee el Excel con openpyxl/calamine, itera filas, devuelve array de objetos
3. **transform:** `apply_mapping` convierte los campos del Excel a los campos de `accounts` de EspoCRM según `mapping.yml`
4. **validate:** `validate_rows` verifica email válido, razón social presente, NIT en formato correcto
5. **write:** `upsert_with_origin` hace UPSERT en `accounts` con `upsert_key=email` y `origin='biedata'`
6. **finalize:** Archiva el Excel en `/mnt/biedata/processed/`, notifica en `#ventas-ops` con resumen

Resultado post-import: el SBOS Data Kernel detecta los nuevos/actualizados `accounts` vía WAL y los sincroniza en Tryton como `party.party`.

---

### Caja 2 — Export: Facturas al SIAT Bolivia

**Caso de uso:** Obligación tributaria mensual. El sistema debe exportar todas las facturas emitidas en el período al portal SIAT del Servicio de Impuestos Nacionales de Bolivia. El SIAT requiere XML firmado con certificado digital.

**Caja:** `export/facturas_siat/`

Flujo de ejecución:
1. **prepare:** Valida certificado digital, verifica conectividad al portal SIAT
2. **read:** Query SQL en Tryton extrae facturas del período anterior en estado `posted`
3. **transform:** Convierte el schema de Tryton al formato XML SIAT según `mapping.yml` y renderiza la plantilla `format.xml`
4. **validate:** Valida el XML generado contra el XSD oficial del SIAT — si falla, aborta con alerta
5. **deliver:** POST al endpoint del SIAT con el XML y el certificado digital cliente
6. **finalize:** Registra el código de respuesta del SIAT en `biedata_db.box_responses`, notifica en `#contabilidad`

**Nota sobre el SIAT 2026:** La API del SIAT Bolivia opera sobre HTTPS con mutual TLS. El certificado digital es emitido por la Cámara de Comercio o una entidad certificada por AEMP (Autoridad de Fiscalización y Control de Empresas y Sociedades Comerciales). El formato XML del SIAT sigue la especificación de la versión vigente publicada por el SIN. Se recomienda verificar la especificación actual en el portal del SIN antes de construir la caja para un cliente específico, ya que el formato puede variar por tipo de factura (manual, computarizada, electrónica).

---

### Caja 3 — Import: Integración con Sistema de RRHH Externo

**Caso de uso:** Una empresa tiene empleados registrados en un sistema de RRHH externo (por ejemplo, un sistema legacy o un software que no forma parte del stack SBOS). Se quiere sincronizar los datos de empleados hacia OrangeHRM para tener el registro actualizado dentro del SBOS.

**Caja:** `import/empleados_rrhh_ext/`

Flujo de ejecución:
1. **prepare:** Verifica conexión a la base de datos del sistema externo (puede ser MySQL, SQL Server, o una API REST)
2. **read:** box_catalog.so consulta el sistema externo — obtiene la lista de empleados activos con sus datos básicos (nombre, cargo, departamento, fecha de ingreso)
3. **transform:** `apply_mapping` convierte los campos del sistema externo a los campos de `hs_hr_employee` de OrangeHRM
4. **validate:** Verifica que los campos obligatorios de OrangeHRM estén presentes
5. **write:** UPSERT en `hs_hr_employee` con `upsert_key=emp_work_email` y `origin='biedata'`
6. **finalize:** Notifica al administrador de RRHH con el resumen de altas, bajas, y modificaciones detectadas

Resultado post-import: el SBOS Data Kernel detecta los cambios en OrangeHRM vía WAL. Si un empleado es nuevo, el plugin `bauth_sync` crea su usuario en Keycloak con el RolTemplate correspondiente.

---

### Caja 4 — Export/Import: Integración con Pasarela de Pagos

**Caso de uso bidireccional:**
- **Export:** Tryton genera órdenes de pago y las envía a la pasarela (Culqi, PayU, MercadoPago)
- **Import:** La pasarela confirma el resultado del pago (aprobado, rechazado, pendiente) y SBOS Data Integration actualiza el estado en Tryton

**Cajas:** `export/pagos_pasarela/` + `import/confirmacion_pagos/`

La caja de export convierte órdenes de pago de Tryton al formato JSON de la pasarela y hace el POST con autenticación API Key.

La caja de import recibe el webhook de confirmación (o hace polling al endpoint de estado) y actualiza el campo `state` de `account.payment` en Tryton a `posted` (aprobado) o `failed` (rechazado).

El SBOS Data Kernel detecta el cambio de estado vía WAL y activa las reglas de negocio correspondientes (por ejemplo, liberar el inventario si el pago fue aprobado).

---

## 19. Flujos Completos de Integración

### Flujo A: Migración desde FoxPro legacy

```
SITUACIÓN: Empresa con 3,000 items en base FoxPro anterior al SBOS

1. Admin instala caja: boxes/import/items_foxpro/
2. Admin configura manifest.yml: ruta del DBF, credenciales
3. Admin ejecuta desde Core UI: "Ejecutar caja import_items_foxpro"

4. SBOS Data Integration:
   → prepare:   verifica conexión al archivo DBF
   → read:      box_catalog.so abre .DBF, lee 3,000 registros
   → transform: aplica mapping.yml (campos FoxPro → campos Tryton)
   → validate:  47 registros con precio=0 → skip_row, registrados en biedata_db
   → write:     2,953 UPSERTs en Tryton.product_product con origin='biedata'
   → finalize:  notifica "#operaciones" — "3,000 items: 2,953 ok, 47 errores"

5. WAL × 2,953 → SBOS Data Kernel:
   → sincroniza catálogo con Saleor automáticamente
   → encola en SBOS Data RAG → productos buscables inmediatamente

6. Admin revisa los 47 errores en Core UI y los corrige manualmente o ajusta el mapping
```

### Flujo B: Exportación fiscal mensual automatizada

```
SITUACIÓN: Primer día del mes, 8:00 AM

1. Cron del manifest.yml dispara: "Ejecutar caja export_facturas_siat"

2. SBOS Data Integration:
   → prepare:   valida certificado SIAT, verifica conectividad
   → read:      query Tryton: facturas posted de enero 2026
   → transform: mapping.yml + renderizar XML SIAT
   → validate:  XML válido contra XSD oficial
   → deliver:   POST con certificado → SIAT responde código 200, referencia ABC123
   → finalize:  registra respuesta, notifica "#contabilidad" — "147 facturas enviadas OK"

3. Si el SIAT devuelve error:
   → SBOS Data Integration registra el error en biedata_db.box_responses
   → Notifica ALERTA en "#contabilidad" con el código de error
   → Admin corrige el problema y re-ejecuta manualmente desde Core UI
```

---

## 20. Fronteras que SBOS Data Integration Nunca Cruza

| Frontera | Regla | Consecuencia de violación |
|---|---|---|
| **D1 — Export es solo lectura** | Las cajas de export tienen credenciales SELECT únicamente — nunca INSERT/UPDATE en el stack | Modificación accidental de datos de producción |
| **D2 — Idempotencia obligatoria en import** | Toda escritura usa UPSERT — nunca INSERT puro | Duplicados al re-ejecutar la misma caja |
| **D3 — origin='biedata' obligatorio** | Toda escritura de import lleva el origen marcado | El SBOS Data Kernel no puede distinguir datos de SBOS Data Integration de datos de las apps — confusión en auditoría |
| **D4 — Sin .so sin firma** | El SBOS IAM Installer firma cada .so — SBOS Data Integration rechaza los no firmados | Ejecución de código no auditado en el servidor del cliente |
| **D5 — Sin decisiones de negocio** | Si una fila tiene valor inesperado, SBOS Data Integration la registra y continúa — no decide qué hacer con los datos de negocio | Comportamiento no predecible y no auditado |
| **D6 — Sin modificación autónoma de cajas** | Las cajas las crea el administrador o SBOS AI Tools con aprobación humana — SBOS Data Integration solo las ejecuta | Cambios en las integraciones sin trazabilidad |
| **D7 — Auditoría en biedata_db** | Toda ejecución queda registrada — SBOS Data Integration nunca descarta resultados silenciosamente | Falta de trazabilidad para auditorías fiscales y de compliance |
| **D8 — Cero conocimiento en el binario** | El motor no sabe nada de OrangeHRM, Tryton, ni SIAT — todo el conocimiento está en las cajas | El binario tendría que recompilarse para cada nueva integración |

---

## 21. Hoja de Ruta de Desarrollo

### Fase 1 — Core del Motor (Meses 1-2)

Binario SBOS Data Integration completo. Event Listener (schedule, file_watch, manual, Redis event). Box Loader con dlopen y verificación de firma. Engine Executor con las 6 fases (prepare, read, transform, validate, write/deliver, finalize). Tareas globales: validate_env_vars, apply_mapping, validate_rows, upsert_with_origin, notify_completion, archive_file, log_execution. Schema `biedata_db`. Servicio systemd.

### Fase 2 — Cajas Base (Meses 3-4)

Cajas: `import_empleados_csv`, `import_clientes_excel`, `import_productos_excel`, `export_facturas_siat`, `export_nomina_banco`. Box API documentada para desarrollo de cajas externas. Firma criptográfica de .so implementada.

### Fase 3 — Cajas Legacy Bolivia y Pasarelas (Meses 5-6)

Cajas: `import_items_foxpro`, `import_empleados_mysql`, `import_clientes_mssql`. Conector SIAT Bolivia completo con validación XSD oficial según especificación vigente del SIN. Formatos bancarios Bolivia (Banco Unión, BNB, Banco Mercantil Santa Cruz). Cajas de pasarelas de pago: Culqi (Perú), PayU (Colombia/Ecuador), MercadoPago (Argentina/México).

---

## 22. Registro de Cambios v4.0

### Alineación con SBOS-DAEMON-STACK v1.0 en v4.0

**C1 — Lenguaje definitivo: Rust (§12, §13):**
La investigación de stack tecnológico (SBOS-DAEMON-STACK v1.0, Marzo 2026) establece que biedata se implementa en **Rust únicamente**. Se reemplaza la mención "Rust/C++" por "Rust" en la sección de lenguaje de implementación. El C ABI de la Plugin API no implica una implementación alternativa en C++ — es la interfaz de estabilidad binaria para plugins compilados en Rust.

**C2 — Stack de crates alineado con investigación:**
Versiones específicas documentadas: calamine 0.32, rust_xlsxwriter 0.7, csv 1.3, reqwest 0.12, quick-xml 0.36, russh 0.44, rustls 0.23, libloading 0.8. Benchmarks calamine vs alternativas (openpyxl 9.4x más lento, ClosedXML 7x más lento, excelize 1.75x más lento) documentados con contexto de importación transaccional.

**Contenido de v4.0 preservado íntegramente.**

---

*SKULL · SBOS · SBOS-011 — SBOS Data Integration · v4.0 · Marzo 2026*
*CONFIDENCIAL — Propiedad de SKULL Desarrollo de Software*
*Prohibida su reproducción total o parcial sin autorización*
-e 
---

## Box Engine, Circuit Breaker y Protocolo con Sistemas Externos

> **Integrado desde SBOS-011-001 en v4.0.**


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
