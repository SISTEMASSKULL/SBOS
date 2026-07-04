# SBOS-013 — bSearch: Motor de Búsqueda Federada
## Especificación Técnica · v5.0

### SKULL · SBOS — Sovereign Business Operating System
### Marzo 2026

---

| Campo | Valor |
|---|---|
| **Documento** | SBOS-013 |
| **Título** | bSearch — Motor de Búsqueda Federada |
| **Versión** | v5.0 |
| **Estado** | ACTIVO |
| **Anterior** | SBOS-014-BSEARCH v3.5 (BORRADOR EN REVISIÓN — SUPERSEDED) |

---

## Tabla de Contenidos

1. [Fundamento Conceptual](#1-fundamento-conceptual)
2. [Qué es bSearch](#2-qué-es-bsearch)
3. [El Widget bSearch](#3-el-widget-bsearch)
4. [Motor de Relevancia — Las Siete Capas](#4-motor-de-relevancia--las-siete-capas)
5. [Patrones de Búsqueda — El Conocimiento Estructural](#5-patrones-de-búsqueda--el-conocimiento-estructural)
6. [Contrato con las Fichas: bsearch_config](#6-contrato-con-las-fichas-bsearch_config)
7. [Esquema del Evento bKernel → bSearch](#7-esquema-del-evento-bkernel--bsearch)
8. [bSearch Schema Discoverer — Generación Idempotente de Patrones](#8-bsearch-schema-discoverer--generación-idempotente-de-patrones)
9. [Search Learning Engine — Autocorrección con Autorización](#9-search-learning-engine--autocorrección-con-autorización)
10. [Integración con bCompass — Las Cuatro Rutas de Inteligencia](#10-integración-con-bcompass--las-cuatro-rutas-de-inteligencia)
11. [Arquitectura General del Daemon](#11-arquitectura-general-del-daemon)
12. [Multi-Tenant y Seguridad](#12-multi-tenant-y-seguridad)
13. [Fronteras que bSearch Nunca Cruza](#13-fronteras-que-bsearch-nunca-cruza)
14. [Calidad de Búsqueda — Evaluación y Hoja de Mejora](#14-calidad-de-búsqueda--evaluación-y-hoja-de-mejora)
15. [Posicionamiento en la Industria](#15-posicionamiento-en-la-industria)
16. [Factibilidad Técnica](#16-factibilidad-técnica)
17. [Hoja de Ruta de Desarrollo](#17-hoja-de-ruta-de-desarrollo)
18. [Registro de Cambios](#18-registro-de-cambios)

---

## 1. Fundamento Conceptual

### 1.1 El problema que bSearch resuelve

Una empresa que corre SBOS tiene más de 110 aplicaciones operando simultáneamente. Un empleado de contabilidad busca el comprobante 3451. Ese número puede estar registrado como factura en Tryton, referenciado en un ticket en Zammad, mencionado en un correo en Roundcube, y ligado a una orden de compra en Saleor. El usuario no sabe — ni debería saber — en cuál de los 15 servidores lógicos vive ese dato. Y una vez que lo encuentra, necesita abrirlo directamente, no navegar manualmente por una lista de URLs.

El problema tiene tres dimensiones que deben resolverse juntas:

- **Dimensión 1 — Búsqueda universal:** encontrar un dato en cualquier aplicación del stack con una sola consulta, sin importar en qué sistema reside.
- **Dimensión 2 — Routing a entidad:** una vez encontrado, llevar al usuario directamente al formulario correcto en la aplicación correcta.
- **Dimensión 3 — Búsqueda por pista de investigación:** el usuario no siempre sabe qué es lo que busca. Tiene una pista — un monto que no cuadra, un número que aparece en un reporte, un nombre que no reconoce — y necesita saber en qué documentos, de qué tipo, en qué aplicaciones aparece ese dato. bSearch no investiga por él: le da el mapa de dónde está esa pista en el universo del stack para que él decida por dónde empezar.

La primera sin la segunda produce resultados que el usuario no puede accionar. La segunda sin la primera requiere que el usuario sepa dónde buscar. Sin la tercera, el usuario que tiene un síntoma pero no su causa no tiene punto de entrada. bSearch resuelve las tres simultáneamente.

### 1.2 La unidad central: la entidad

Todo en bSearch gira alrededor del concepto de **entidad** — un objeto de negocio con identidad única que puede existir en múltiples aplicaciones simultáneamente. Una entidad no es una fila de base de datos — es un objeto de negocio accionable:

| Tipo | Puede vivir en | Identificador de negocio |
|---|---|---|
| `person` | OrangeHRM (empleado), EspoCRM (contacto), Zammad (usuario), Tryton (party) | Nombre, cédula, email |
| `organization` | EspoCRM (cuenta), Zammad (org.), Tryton (party empresa), Saleor (customer) | Nombre, NIT/RUC |
| `product` | Tryton (producto), Saleor (producto), WooCommerce | SKU, nombre, código |
| `document` | Tryton (factura, comprobante), Saleor (orden), Nextcloud (archivo) | Número de documento |
| `ticket` | Zammad (soporte), GitLab (issue), OpenProject (tarea) | Número, asunto |
| `transaction` | Tryton (asiento, comprobante), Saleor (pago) | Número de transacción |

Cuando un usuario busca "3451", bSearch devuelve **entidades accionables** — no filas de base de datos. Por cada entidad: el conjunto de apps donde existe, el deep-link directo a cada formulario (protocolo `sbos://` — ver SBOS-012 §23), y el indicador de frescura del dato indexado.

### 1.3 Por qué bSearch es un daemon separado del bKernel

El bKernel tiene una responsabilidad única e indivisible: sincronizar el estado de datos entre aplicaciones en tiempo real. Añadir búsqueda al bKernel significaría competir por CPU entre hilos de sincronización e hilos de indexación, acoplar ciclos de vida distintos, e impedir el escalado horizontal del API de búsqueda.

La solución es el patrón estándar de la industria: sistemas de ingesta y sistemas de consulta son componentes separados, comunicados por una cola. El bKernel produce eventos de indexación a Redis; bSearch los consume de forma completamente independiente. Si bSearch cae, el bKernel sigue sincronizando. Cuando bSearch se recupera, retoma la cola desde el último offset sin pérdida de datos.

---

## 2. Qué es bSearch

### 2.1 El tercer daemon soberano del SBOS

bSearch es el **motor de búsqueda federada del SBOS**. Es un daemon soberano — igual que el bKernel y el IAM Installer — que arranca con el servidor, opera permanentemente, y no tiene interfaz gráfica. Es el tercer componente del trío de daemons soberanos del ecosistema SKULL:

| Daemon | Servicio systemd | Dominio | Escucha | Actúa sobre |
|---|---|---|---|---|
| IAM Installer | `sbos-installer.service` | INFRAESTRUCTURA | Filesystem `servers/` | Cluster K8s, fichas, salud del stack |
| bKernel | `bkernel.service` | DATOS | WAL PostgreSQL (CDC) | Sincronización entre apps, cola de indexación |
| bSearch | `bsearch.service` | BÚSQUEDA | Redis Stream + BDs apps (SELECT) | Índice Meilisearch, API de consulta, aprendizaje |

El mismo meta-patrón une a los cinco daemons del ecosistema. Cada uno tiene su unidad declarativa que el motor ejecuta:

| Daemon | Unidad declarativa | El motor ejecuta | Agregar capacidad nueva |
|---|---|---|---|
| IAM Installer | **Ficha** en `servers/` | `00_MASTER_INSTALL.sh` | Crear carpeta en `servers/` |
| bKernel | **Regla** en `rules/` | Rule Engine | Crear archivo YAML en `rules/` |
| biedata | **Caja** en `boxes/` | Box Engine | Crear carpeta en `boxes/` |
| bCompass | **Ruta** en `router/` | Route Engine | Crear carpeta en `router/` |
| **bSearch** | **Patrón** en `patterns/` | **Search Engine** | **Crear carpeta en `patterns/`** |

> **Nota de terminología:** la unidad declarativa de bSearch se denomina **patrón de búsqueda** — no "ficha", término reservado exclusivamente para el IAM Installer. Un patrón describe con precisión lo que es: la declaración de cómo buscar, presentar y rutear una entidad de negocio en una aplicación específica.

### 2.2 Los dos modos de búsqueda

bSearch opera en dos modos según el scope desde donde se origina la consulta:

| Modo | Cuándo se usa | Cómo funciona | Latencia |
|---|---|---|---|
| **Indexado** (Meilisearch) | Búsqueda global — scope Nivel 0 | Índice Meilisearch pre-construido por el INDEXER vía bKernel | < 50ms |
| **Directo** (SQL SELECT) | Widget dentro de una app — scope Nivel 1+ | `SELECT` de solo lectura a la PostgreSQL de la app vía `pg_trgm` | Tiempo real — cero lag |

La lectura directa a las bases de datos de las aplicaciones es **no invasiva**: las credenciales tienen permisos exclusivamente de `SELECT` — nunca `DDL` ni `DML`. Si una app actualiza su versión y cambia su esquema, bSearch actualiza su patrón YAML. La app nunca sabe que bSearch existe.

### 2.3 Responsabilidades del daemon

- Consumir el Redis Stream `bkernel:index_queue` y mantener el índice Meilisearch actualizado.
- Ejecutar consultas SQL `SELECT` de solo lectura cuando opera en modo directo.
- Mantener el **Registro de Deep-Links** — el mapa de cómo navegar a cada entidad en cada app via protocolo `sbos://`.
- Gestionar el scope contextual por sesión activa del SBOS VDI.
- Ejecutar el **Search Learning Engine** — detectar ambigüedades, aprender con autorización explícita, detectar errores en datos almacenados.
- Emitir eventos a bCompass para reparación de datos, análisis de calidad, y reescritura NLU.
- Garantizar aislamiento multi-tenant estricto por realm vía Keycloak JWT.

---

## 3. El Widget bSearch

### 3.1 Definición

El widget bSearch es el textbox a través del cual el usuario interactúa con el daemon. Es un objeto de interfaz completamente agnóstico al contexto en que opera — no tiene lógica de búsqueda propia. El comportamiento visual sigue el modelo de **Windows 11 Search**: al escribir se despliega un panel flotante con resultados agrupados por tipo de entidad, y un panel lateral que muestra el detalle y las acciones del resultado seleccionado. Navegación completa por teclado: `↑↓` navegan, `Enter` abre, `Esc` cierra.

El widget opera en dos modos que se activan automáticamente según la naturaleza de la consulta:

| Modo | Cuándo se activa | Qué hace |
|---|---|---|
| **Modo estándar** | La consulta tiene coincidencia de alta confianza en un tipo específico de entidad | Muestra resultados agrupados por app, ordenados por relevancia |
| **Modo investigación** | La consulta no tiene dueño claro — número ambiguo, monto, pista de texto libre — o el usuario activa `Ctrl+Shift+K` | Busca la pista en **todos los campos de todos los tipos de entidad** y presenta el mapa completo de coincidencias agrupadas por tipo de documento |

El modo investigación es la respuesta directa al problema de trazabilidad: el usuario no sabe qué es ese número, ese monto, ese nombre. bSearch no lo sabe tampoco — pero sí sabe en qué documentos aparece. Eso es suficiente para dar inicio a la investigación.

### 3.2 Los tres puntos de anclaje en el SBOS VDI

#### Anclaje 1 — Barra de tareas KDE · `Meta+Space` (Nivel 0: Global)

Activado desde cualquier punto del escritorio. Scope global: busca en todas las apps del stack instaladas en el realm activo.

```
Meta+Space → widget como overlay sobre el escritorio
Scope: GLOBAL — todas las apps del realm activo
Resultado → sbos:// deep link → ventana nativa KDE
```

#### Anclaje 2 — sbos-app-container · `Ctrl+K` (Nivel 1: Aplicación)

Inyectado por el `sbos-app-container` al abrir cualquier app del stack. El container conoce qué app sirve y declara el scope al inyectar el widget. El usuario ve **únicamente resultados de esa app** — ninguna otra.

```
Ctrl+K dentro de OrangeHRM → scope: orangehrm — solo resultados de OrangeHRM
Ctrl+K dentro de Tryton    → scope: tryton    — solo resultados de Tryton
Ctrl+K dentro de EspoCRM   → scope: espocrm   — solo resultados de EspoCRM
```

#### Anclaje 3 — Core UI · Header (Administrador, Nivel 0: Global)

Header del Core UI del IAM Installer. Scope global para el realm del administrador. Permite diagnóstico: ver en cuántas apps existe un registro, cuándo fue indexado por última vez, cobertura de patrones por app.

### 3.3 Regla del scope — el anfitrión declara, el widget obedece

El scope se hereda y restringe hacia niveles más profundos — **nunca se amplía desde adentro**. Un widget dentro de OrangeHRM no puede solicitar resultados de Tryton.

| Anfitrión del widget | Nivel | Índices consultados |
|---|---|---|
| SBOS VDI escritorio (`Meta+Space`) | 0 — Global | Todos los índices del realm activo |
| `sbos-app-container` → OrangeHRM | 1 — Aplicación | Solo índices `*_orangehrm_*` |
| `sbos-app-container` → Tryton | 1 — Aplicación | Solo índices `*_tryton_*` |
| `sbos-app-container` → EspoCRM | 1 — Aplicación | Solo índices `*_espocrm_*` |
| Core UI (administrador) | 0 — Global | Todos los índices del realm activo |

### 3.4 Panel de cobertura — transparencia obligatoria

El widget informa siempre al usuario en qué apps se buscó, cuáles quedaron fuera, y por qué:

```
Resultados en:   Tryton ERP · EspoCRM · OrangeHRM · Zammad
No buscado en:   Snipe-IT (patrón pendiente de aprobación)
                 WooCommerce (patrón en borrador — sin aprobar)
                 [Notificar al administrador →]
```

### 3.5 Freshness indicator — frescura del dato indexado

Cada tarjeta de resultado muestra cuándo fue indexado por última vez el dato que presenta:

```
┌─────────────────────────────────────────────────────┐
│  INV-3451 · Constructora Andina SRL                 │
│  Bs. 45,200 · Contabilizado · 15/02/2026            │
│                                                     │
│  Tryton ERP  ●  Actualizado hace 18 segundos        │
└─────────────────────────────────────────────────────┘
```

### 3.6 El panel de resultados en modo investigación

Cuando el modo investigación se activa, el panel de resultados agrupa por **tipo de documento** — porque el usuario no sabe en qué app está la pista, pero sí puede reconocer el tipo de documento cuando lo ve.

**Ejemplo: el usuario busca `12,450` sin saber qué es ese monto**

```
Búsqueda: "12450"   [modo investigación]   Realm: empresa_abc

  FACTURAS                        (3 coincidencias)
  ─────────────────────────────────────────────────
  ● INV-2891  ·  Toyota S.A.          ·  Bs. 12,450.00  ·  Contabilizado
    Tryton ERP  ●  Actualizado hace 4 segundos             [Abrir →]

  ● INV-3102  ·  Constructora Andina  ·  Bs. 12,450.00  ·  Borrador
    Tryton ERP  ●  Actualizado hace 4 segundos             [Abrir →]

  ASIENTOS CONTABLES              (5 coincidencias)
  ─────────────────────────────────────────────────
  ● JE-2026-0341  ·  Cuenta transitoria 1150  ·  Db 12,450.00
    Tryton ERP  ●  Actualizado hace 4 segundos             [Abrir →]
  [+ 4 más →]

  ÓRDENES DE COMPRA               (1 coincidencia)
  ─────────────────────────────────────────────────
  ● PO-0512  ·  Proveedor Nacional  ·  Bs. 12,450.00  ·  Aprobada
    Tryton ERP  ●  Actualizado hace 4 segundos             [Abrir →]

  TICKETS DE SOPORTE              (1 coincidencia)
  ─────────────────────────────────────────────────
  ● #4521  ·  "Ajuste de monto 12,450 en liquidación"
    Zammad  ●  Actualizado hace 2 minutos                  [Abrir →]

───────────────────────────────────────────────────
Buscado en:  Tryton ERP · Saleor · Zammad · OrangeHRM · EspoCRM
No buscado:  WooCommerce (patrón pendiente de aprobación)
```

**La misma lógica aplica para cualquier tipo de pista:**

```
Búsqueda: "3451"         → grupos: FACTURAS · COMPROBANTES · ASIENTOS · OC · TICKETS
Búsqueda: "Toyota"       → grupos: ORGANIZACIONES · FACTURAS · OC · CONTRATOS
Búsqueda: "15/02/2026"   → grupos: FACTURAS · ASIENTOS · PAGOS · CONTRATOS · TICKETS
Búsqueda: "transitoria"  → grupos: ASIENTOS · NOTAS · TICKETS · DOCUMENTOS
```

---

## 4. Motor de Relevancia — Las Siete Capas

bSearch no es un `ILIKE`. Es un pipeline de siete capas superpuestas que trabajan en secuencia para cada consulta. Cada capa agrega inteligencia sobre la anterior.

### Capa 0 — Normalización por tipo de dato

Antes de cualquier búsqueda, el motor clasifica la consulta y aplica el normalizador correspondiente a su tipo.

| `field_type` | Normalizador | Ejemplo de entrada | Forma buscable |
|---|---|---|---|
| `text` | Minúsculas + unaccent + puntuación | `"Pérez S.A."` | `"perez sa"` |
| `numeric` | Elimina separadores de miles, símbolo de moneda | `"Bs. 12.450,00"` | `12450.00` |
| `date` | Normaliza formatos a ISO 8601 | `"15/02/26"` | `2026-02-15` |
| `code` | Elimina guiones, barras, espacios — case-insensitive | `"INV-3451"` | `inv3451` |
| `reference` | Búsqueda de contenido parcial | `"3451"` | encuentra `INV-3451`, `JE-3451-A` |
| `free_text` | Tokenización + stopwords + stemming básico | `"diferencia cambiaria marzo"` | tokens: `diferencia`, `cambiaria`, `marzo` |

Clasificación automática del tipo:

```
¿Solo dígitos con separadores numéricos?     → numeric + reference (paralelo)
¿Formato de fecha reconocible?               → date
¿Prefijo alfanumérico + número?              → code + reference (paralelo)
¿Texto libre sin patrón especial?            → text + free_text (paralelo)
¿Mezcla tipos? ("Toyota 12450")              → text para parte textual + numeric para numérica
```

### Capa 1 — Pre-procesamiento y normalización de texto

La parte textual de la consulta se normaliza: minúsculas, eliminación de acentos (`unaccent`), normalización de puntuación. `"Pérez"` y `"Perez"` son equivalentes. `"S.A."` y `"SA"` son equivalentes.

### Capa 2 — Expansión semántica (diccionarios)

La consulta normalizada se expande usando los diccionarios de conocimiento del negocio:

- `synonyms/business.yml` — abreviaturas confirmadas: `"cxc"` → `"cuentas por cobrar"`, `"oc"` → `"orden de compra"`
- `synonyms/discovered.yml` — aliases descubiertos en uso real y aprobados
- `corrections/business_states.yml` — lenguaje natural a valores de BD: `"pendiente"` → `["draft","validated","posted"]`
- `corrections/data_errors.yml` — errores de captura confirmados como puentes temporales

### Capa 3 — Tolerancia a errores tipográficos (Damerau-Levenshtein)

Algoritmo **Damerau-Levenshtein** — incluye transposición de caracteres adyacentes (`"tayota"` → `"toyota"`). La configuración es granular por tipo de campo:

| Tipo de campo | `typo_tolerance` | Razón |
|---|---|---|
| Nombre de persona / organización | `true` — hasta 2 errores | Los nombres admiten variaciones |
| Número de documento (`INV-3451`) | `false` | Un número diferente es un documento diferente |
| NIT / RUC / cédula | `false` | Un dígito diferente es otra entidad legal |
| Código de producto / SKU | `false` | Un código diferente es otro producto |
| Descripción / notas | `true` — hasta 1 error | Texto libre — admite typos |

### Capa 4 — Keyboard Distance Model

Complementa Damerau-Levenshtein con una matriz de adyacencia física de teclas. Las sustituciones entre teclas físicamente cercanas (`q`/`a`, `n`/`m`) reciben mayor peso de similitud. Aplica tanto a distribución QWERTY como española.

### Capa 5 — pg_trgm en modo directo

En modo directo (SQL `SELECT`), la tolerancia a typos se implementa vía la extensión `pg_trgm` de PostgreSQL:

```sql
SELECT * FROM party_party
WHERE  similarity(name, 'tayota') > 0.30
ORDER  BY similarity(name, 'tayota') DESC;
```

Campos de alta precisión (números de documento, NITs) no usan `pg_trgm` — usan coincidencia exacta con `=`.

### Capa 6 — Ranking de resultados

Los resultados se ordenan por cascada de criterios:

1. Coincidencia exacta en campo de alta prioridad
2. Coincidencia exacta en campos secundarios
3. Fuzzy con 1 error tipográfico — campo alta prioridad
4. Fuzzy con 2 errores tipográficos — campo alta prioridad
5. Coincidencia por sinónimo o alias del diccionario
6. Coincidencia por prefijo o contenido parcial (modo `reference`)
7. Recencia del documento como criterio de desempate

---

## 5. Patrones de Búsqueda — El Conocimiento Estructural

### 5.1 La unidad declarativa de bSearch

Un **patrón de búsqueda** es el conjunto de contratos YAML que define completamente cómo bSearch interactúa con una aplicación del stack: cómo conectarse a su base de datos, qué entidades buscar, cómo presentar los resultados, y cómo rutear al formulario correcto.

Agregar soporte de búsqueda para una nueva app = crear su carpeta en `/etc/bsearch/patterns/` con sus cuatro contratos. El daemon detecta la nueva carpeta vía `inotify` (hot-reload), la carga sin reiniciar, y esa app es inmediatamente buscable.

### 5.2 Estructura de patrones

```
/etc/bsearch/
├── bsearch.yml
├── synonyms/
│   ├── business.yml
│   └── discovered.yml
├── corrections/
│   ├── data_errors.yml
│   └── business_states.yml
└── patterns/
    ├── tryton/
    │   ├── manifest.yml
    │   ├── connection.yml
    │   ├── entities/
    │   │   ├── invoices.yml
    │   │   ├── parties.yml
    │   │   ├── products.yml
    │   │   ├── journal_entries.yml
    │   │   ├── account_moves.yml
    │   │   └── purchase_orders.yml
    │   └── forms/
    │       └── invoice_form.yml
    ├── orangehrm/  ...
    ├── espocrm/    ...
    ├── zammad/     ...
    ├── saleor/     ...
    └── unified/
        ├── people.yml
        └── organizations.yml
```

### 5.3 Los cuatro contratos de un patrón

#### Contrato 1 — `manifest.yml`

```yaml
app_id:    tryton
app_label: "Tryton ERP"
app_icon:  calculator
pod:       sbos-erp
status:    ACTIVE          # DRAFT | APPROVED | ACTIVE

search_modes:
  direct:  true
  indexed: true

coverage:
  entities_detected:       11
  entities_with_pattern:   8
  coverage_pct:            72.7
  missing_entities:
    - hr_payslip
    - hr_leave
    - hr_contract

supported_versions: ["7.0", "7.2", "7.4"]
```

#### Contrato 2 — `connection.yml`

```yaml
db_host:         localhost
db_name:         tryton
db_user:         bsearch_readonly   # GRANT SELECT únicamente — nunca DDL ni DML
db_password_env: BSEARCH_TRYTON_PG_PASSWORD
pg_extensions:
  pg_trgm:   true
  unaccent:  true
```

#### Contrato 3 — `entities/invoices.yml`

```yaml
entity_type:    document
entity_subtype: invoice
source:
  table: account_invoice
  joins:
    - table: party_party
      on:    "account_invoice.party = party_party.id"

fields:
  - name:            number
    column:          account_invoice.number
    field_type:      code
    weight:          10
    typo_tolerance:  false
    searchable:      true

  - name:            party_name
    column:          party_party.name
    field_type:      text
    weight:          8
    typo_tolerance:  true
    searchable:      true

  - name:            total_amount
    column:          account_invoice.total_amount
    field_type:      numeric
    weight:          5
    typo_tolerance:  false
    searchable:      true
    display:         true

  - name:            invoice_date
    column:          account_invoice.invoice_date
    field_type:      date
    weight:          3
    searchable:      true
    display:         true

  - name:            state
    column:          account_invoice.state
    field_type:      text
    searchable:      false
    display:         true
    filterable:      true

routing:
  display_label: "Factura en ERP"
  uri_pattern:   "sbos://erp/open/invoice?id={id}"
  breadcrumb:    ["ERP", "Contabilidad", "Facturas"]
```

#### Contrato 4 — `forms/invoice_form.yml`

```yaml
display:
  title_field:    number
  subtitle_field: party_name
  meta_fields:
    - field: total_amount   format: currency
    - field: state          format: badge
      map:
        draft:     { label: "Borrador",      color: gray    }
        validated: { label: "Validado",      color: blue    }
        posted:    { label: "Contabilizado", color: green   }
        paid:      { label: "Pagado",        color: emerald }
        cancelled: { label: "Anulado",       color: red     }
    - field: invoice_date   format: date

  quick_actions:
    - label:   "Abrir Factura"
      uri:     "sbos://erp/open/invoice?id={id}"
      primary: true
    - label:     "Ver Cliente en CRM"
      uri:       "sbos://espocrm/account?party={party_id}"
      condition: "espocrm.installed"
```

---

## 6. Contrato con las Fichas: bsearch_config

### 6.1 El vínculo entre fichas e índices de búsqueda

Cada ficha del IAM Installer puede declarar en su `manifest.yml` un bloque `bsearch_config` que le indica al bSearch qué entidades de esa aplicación deben ser indexadas y cómo. Este bloque es la **fuente de verdad declarativa** que le dice al Schema Discoverer de bSearch qué priorizar al generar los patrones de esa app.

El `bsearch_config` no reemplaza los patrones YAML de bSearch — los orienta. El Schema Discoverer lee el `bsearch_config` de la ficha como punto de partida para saber qué entidades son críticas, y genera los patrones completos en `/etc/bsearch/patterns/<app>/` con ese conocimiento de partida.

### 6.2 Especificación del bloque bsearch_config

```yaml
# Dentro del manifest.yml de cualquier ficha del IAM Installer

bsearch_config:
  enabled: true                    # false = esta app no participa en bSearch
  priority: high                   # high | medium | low — afecta el orden de indexación
  schema_discoverer: auto          # auto | manual
                                   # auto: Schema Discoverer genera los patrones
                                   # manual: el administrador crea los patrones directamente

  index_entities:
    - entity: invoice              # nombre semántico de la entidad
      table: account_invoice       # tabla principal en la BD de la app
      primary_field: number        # campo que identifica la entidad en la UI (ej: INV-3451)
      display_fields:              # campos que se muestran en la tarjeta del widget
        - number
        - party
        - amount_total
      searchable_fields:           # campos en los que bSearch indexa y busca
        - number                   # field_type: code (auto-detectado)
        - party                    # field_type: text (auto-detectado)
        - amount_total             # field_type: numeric (auto-detectado)
      routing:
        uri_pattern: "sbos://erp/open/invoice?id={id}"

    - entity: party
      table: party_party
      primary_field: name
      display_fields: [name, tax_identifier]
      searchable_fields: [name, tax_identifier]
      routing:
        uri_pattern: "sbos://erp/open/record?model=party.party&id={id}"

    - entity: product
      table: product_product
      primary_field: name
      display_fields: [name, code, list_price]
      searchable_fields: [name, code]
      routing:
        uri_pattern: "sbos://erp/open/record?model=product.product&id={id}"
```

### 6.3 Valores válidos del bloque

| Campo | Tipo | Valores válidos | Descripción |
|---|---|---|---|
| `enabled` | boolean | `true` / `false` | Si `false`, la app no es indexada por bSearch |
| `priority` | string | `high` / `medium` / `low` | Orden de indexación cuando el INDEXER tiene cola |
| `schema_discoverer` | string | `auto` / `manual` | `auto` genera patrones vía LLM; `manual` requiere que el administrador los cree |
| `index_entities[].entity` | string | nombre semántico | Nombre legible de la entidad (ej: `invoice`, `party`, `product`) |
| `index_entities[].table` | string | nombre de tabla PostgreSQL | Tabla principal de la entidad en la BD de la app |
| `index_entities[].primary_field` | string | nombre de columna | Campo que identifica la entidad en la interfaz de usuario |
| `index_entities[].display_fields` | list | nombres de columna | Campos visibles en la tarjeta del widget de búsqueda |
| `index_entities[].searchable_fields` | list | nombres de columna | Campos en los que bSearch construye el índice |
| `index_entities[].routing.uri_pattern` | string | URI `sbos://` | Deep link para abrir la entidad desde el resultado de búsqueda |

### 6.4 Ejemplo completo para una ficha de producción — Tryton ERP

```yaml
# servers/erpserver/tryton/manifest.yml (fragmento relevante)

name: "tryton"
server: "erpserver"
version: "7.4.0"
description: "Tryton ERP — Motor de contabilidad y gestión empresarial"
criticality: true

bsearch_config:
  enabled: true
  priority: high
  schema_discoverer: auto

  index_entities:
    - entity: invoice
      table: account_invoice
      primary_field: number
      display_fields: [number, party, total_amount, state, invoice_date]
      searchable_fields: [number, party, total_amount, invoice_date]
      routing:
        uri_pattern: "sbos://erp/open/invoice?id={id}"

    - entity: party
      table: party_party
      primary_field: name
      display_fields: [name, tax_identifier, active]
      searchable_fields: [name, tax_identifier]
      routing:
        uri_pattern: "sbos://erp/open/record?model=party.party&id={id}"

    - entity: product
      table: product_product
      primary_field: name
      display_fields: [name, code, list_price]
      searchable_fields: [name, code]
      routing:
        uri_pattern: "sbos://erp/open/record?model=product.product&id={id}"

    - entity: journal_entry
      table: account_move
      primary_field: number
      display_fields: [number, date, description, amount]
      searchable_fields: [number, date, description, amount]
      routing:
        uri_pattern: "sbos://erp/open/record?model=account.move&id={id}"

    - entity: purchase_order
      table: purchase_purchase
      primary_field: number
      display_fields: [number, party, total_amount, state]
      searchable_fields: [number, party, total_amount]
      routing:
        uri_pattern: "sbos://erp/open/record?model=purchase.purchase&id={id}"
```

### 6.5 Fichas que no participan en bSearch

Algunas fichas del stack no exponen entidades buscables — no contienen objetos de negocio que el usuario deba encontrar por búsqueda:

```yaml
# servers/infraserver/redis/manifest.yml (fragmento)
bsearch_config:
  enabled: false    # Redis es infraestructura — no tiene entidades de negocio indexables
```

```yaml
# servers/vdiserver/sbos-vdi/manifest.yml (fragmento)
bsearch_config:
  enabled: false    # el SBOS VDI no expone entidades indexables en bSearch
```

---

## 7. Esquema del Evento bKernel → bSearch

### 7.1 El canal de comunicación

El bKernel y bSearch se comunican a través de un **Redis Stream** dedicado. El bKernel actúa como productor: cada vez que detecta un cambio en una tabla que una ficha ha declarado como relevante para indexación, escribe un evento en el stream. bSearch actúa como consumidor: un worker del daemon lee continuamente el stream y ejecuta las actualizaciones de índice correspondientes.

```
Tryton: UPDATE account_invoice SET state = 'posted' WHERE id = 3451
    ↓ (WAL change, < 100ms)
bKernel detecta cambio en account_invoice (tabla declarada en bsearch_config)
    ↓
bKernel escribe evento en Redis Stream: bkernel:index_queue
    ↓
bSearch INDEXER consume el evento
    ↓
bSearch actualiza el documento en el índice Meilisearch correspondiente
    ↓
Widget muestra "Actualizado hace 3 segundos"
```

### 7.2 Nombre y estructura del stream

```
Stream: bkernel:index_queue
Consumer Group: bsearch_indexer
Consumer Name:  bsearch-worker-{hostname}
```

El uso de Consumer Groups de Redis garantiza que si hay múltiples instancias de bSearch (escalado horizontal), cada evento es procesado por exactamente un worker — sin duplicados ni pérdidas.

### 7.3 Esquema del evento

Cada mensaje en el stream tiene la siguiente estructura:

```json
{
  "event_id":    "bk-1741891234567-0",
  "event_type":  "index_update",
  "timestamp":   "2026-03-11T14:25:34.567Z",

  "source": {
    "app_id":     "tryton",
    "table":      "account_invoice",
    "operation":  "UPDATE",
    "record_id":  3451,
    "realm":      "empresa_abc"
  },

  "payload": {
    "before": {
      "state": "validated"
    },
    "after": {
      "id":            3451,
      "number":        "INV-3451",
      "party":         "Constructora Andina SRL",
      "total_amount":  45200.00,
      "state":         "posted",
      "invoice_date":  "2026-02-15"
    },
    "changed_fields": ["state"]
  },

  "index_hints": {
    "entity_type":  "invoice",
    "index_name":   "document_invoice_empresa_abc",
    "action":       "upsert"
  }
}
```

### 7.4 Campos del esquema — descripción completa

| Campo | Tipo | Valores posibles | Descripción |
|---|---|---|---|
| `event_id` | string | `bk-{timestamp}-{seq}` | Identificador único del evento — secuencial en Redis |
| `event_type` | string | `index_update` / `index_delete` / `index_create` / `schema_change` | Tipo de operación requerida |
| `timestamp` | string | ISO 8601 | Momento en que el bKernel detectó el cambio en el WAL |
| `source.app_id` | string | id de app del stack | Aplicación que origina el cambio |
| `source.table` | string | nombre de tabla PostgreSQL | Tabla donde ocurrió el cambio |
| `source.operation` | string | `INSERT` / `UPDATE` / `DELETE` | Tipo de operación SQL en la BD de la app |
| `source.record_id` | integer/string | PK del registro | Identificador primario del registro modificado |
| `source.realm` | string | realm de Keycloak | Tenant al que pertenece el registro — determina el índice Meilisearch destino |
| `payload.before` | object / null | campos y valores | Estado anterior del registro — `null` en INSERT |
| `payload.after` | object / null | campos y valores | Estado nuevo del registro — `null` en DELETE |
| `payload.changed_fields` | array | nombres de columna | Campos que cambiaron — permite indexación parcial selectiva |
| `index_hints.entity_type` | string | tipo declarado en bsearch_config | Tipo de entidad — determina el patrón a usar |
| `index_hints.index_name` | string | `{entity_type}_{realm}` | Nombre del índice Meilisearch destino |
| `index_hints.action` | string | `upsert` / `delete` / `rebuild` | Acción a ejecutar en el índice |

### 7.5 Tipos de evento

#### `index_update` — modificación de un registro existente

El evento más frecuente. El INDEXER actualiza el documento en Meilisearch usando los campos del bloque `after`. Si `changed_fields` solo contiene campos no indexados (ej: `updated_at`), el INDEXER descarta el evento sin procesar.

#### `index_delete` — eliminación de un registro

El bloque `after` es `null`. El INDEXER elimina el documento del índice Meilisearch usando `source.record_id`.

#### `index_create` — nuevo registro

El bloque `before` es `null`. El INDEXER crea un nuevo documento en Meilisearch.

#### `schema_change` — cambio en el esquema de la tabla

La app fue actualizada y una tabla cambió su estructura. El INDEXER lanza el Schema Discoverer para regenerar el patrón correspondiente. El índice existente se mantiene activo hasta que el nuevo patrón sea aprobado.

### 7.6 Manejo de errores y reconexión

```
bSearch INDEXER falla al procesar un evento
    ↓
Redis Consumer Group: el evento queda en estado PENDING
    ↓
bSearch reinicia o recupera el consumer
    ↓
Redis: entrega de nuevo el evento PENDING (XAUTOCLAIM)
    ↓
Si el evento falla N veces consecutivas (configurable, default: 3):
    → Mover al stream dead-letter: bkernel:index_queue:dead
    → Notificar al administrador en Core UI
    → bSearch continúa con los demás eventos sin bloqueo
```

---

## 8. bSearch Schema Discoverer — Generación Idempotente de Patrones

### 8.1 Propósito

El Schema Discoverer es el subcomponente del daemon responsable de generar automáticamente los patrones de búsqueda al instalar una nueva app, y de actualizarlos cuando la versión de la app cambia. Es **idempotente**: puede ejecutarse N veces sin efectos secundarios. Si nada cambió, no hace nada. Si la versión cambió, actualiza únicamente lo que es diferente. Nunca sobreescribe secciones marcadas con `human_edited: true`.

### 8.2 El LLM del aiserver es el parser universal

El Schema Discoverer **no tiene parsers manuales por lenguaje**. El LLM del **aiserver** (SBOS-015) es el parser universal. Lee código fuente en cualquier lenguaje de programación y entiende su semántica de negocio.

bSearch **consume** el aiserver que ya existe en el stack — no lo redefine ni duplica. Si el aiserver no está disponible, el Schema Discoverer opera en modo degradado (`structural_only`).

| Modelo (aiserver) | Lenguajes soportados | Uso principal en bSearch |
|---|---|---|
| Qwen3-Coder | 119 lenguajes | Análisis principal de código fuente de apps |
| DeepSeek-R1 distil-Qwen | Razonamiento estructural | Inferencia de relaciones semánticas complejas |
| Qwen3:8b | 100+ lenguajes | Fallback ligero para análisis rápido |

Todos los lenguajes del stack del SBOS están cubiertos sin excepción (Python, PHP, Ruby, JavaScript/TypeScript, Go, Dart, C++, Rust).

### 8.3 Las cinco fases

#### Fase 1 — Detección de cambio (idempotencia)

```
Lee /etc/bsearch/patterns/<app>/manifest.yml
  ¿Existe?  NO  → ejecutar las 5 fases desde cero
  ¿Existe?  SÍ  → comparar app_version registrada
               ¿Sin cambio?  → salir — no hacer nada
               ¿Cambió?      → continuar respetando human_edited: true
```

El flag `human_edited: true` en cualquier sección indica que el administrador realizó ajustes manuales. El Discoverer **nunca toca esas secciones**.

#### Fase 2 — Extractor estructural determinístico (pg_catalog)

Sin LLM. Consulta el catálogo del sistema de PostgreSQL para obtener: todas las tablas, todos los campos con sus tipos, todas las relaciones (claves foráneas), índices existentes, y comentarios de columna.

#### Fase 3 — Análisis semántico (aiserver · Ollama local soberano)

El LLM recibe el mapa estructural de pg_catalog más el código fuente relevante de la app y produce:

- Labels en español para cada campo
- Pesos de relevancia por campo
- Identificación de campos buscables vs campos solo de display
- Patrones de routing extraídos del código del router
- Tipos de entidad de negocio (`"hrm_employee"` → tipo `person`)
- Sugerencias de quick_actions por tipo de entidad

```yaml
# Configuración del aiserver en bsearch.yml
ai_integration:
  schema_discoverer:
    ollama_url:  "http://localhost:11434"   # aiserver ya instalado en el stack
    models:
      preferred:  "qwen3-coder:30b"
      fallback_1: "deepseek-r1:32b"
      fallback_2: "qwen3:8b"
  criticality:   false
  fallback_mode: structural_only
```

#### Fase 4 — Generación de patrones YAML

Deposita los cuatro contratos en `/etc/bsearch/patterns/<app>/` con `status: DRAFT`. Los patrones en estado `DRAFT` son **ignorados completamente** por el daemon de búsqueda.

#### Fase 5 — Notificación al administrador

```
Core UI notifica al administrador:
  📋 Schema Discoverer: patrones generados para Tryton ERP v7.4
     Entidades detectadas: 11
     Patrones DRAFT creados: 11
     Estado: DRAFT — requieren revisión y aprobación
     [Revisar patrones →]
```

### 8.4 Triggers del Schema Discoverer

| Evento | Acción |
|---|---|
| IAM Installer instala una nueva app | Ejecuta las 5 fases completas |
| IAM Installer actualiza versión de una app | Ejecuta desde Fase 1 — actualiza solo secciones sin `human_edited` |
| Administrador ejecuta manualmente desde Core UI | Ejecuta las 5 fases completas |

---

## 9. Search Learning Engine — Autocorrección con Autorización

### 9.1 El principio fundamental

> **El sistema aprende únicamente de confirmaciones explícitas del usuario. Un error de escritura del usuario se descarta completamente — nunca contamina el diccionario de conocimiento.**

### 9.2 El diálogo de clarificación

Cuando el motor encuentra candidatos aproximados pero ninguna coincidencia exacta:

```
No encontré coincidencia exacta para "tpiota"
Resultados aproximados:

  ○  Toyota S.A.     (similitud alta)
  ○  Tosyosa S.A.    (similitud media)
  ○  Ninguno de estos
```

### 9.3 La distinción fundamental — dos clases de error

| | **Caso A — Error de teclado del usuario** | **Caso B — Error en el dato almacenado** |
|---|---|---|
| Lo que se buscó | `"tpiota"` — el usuario escribió mal | `"toyota"` — el usuario escribió bien |
| El dato en la BD | `"Toyota S.A."` — correcto | `"tpiota"` — incorrecto |
| ¿Qué aprende el sistema? | **Nada — el error fue del usuario** | El dato tiene un error de captura |
| Acción sobre el diccionario | **Ninguna — no contaminar** | Agregar a `data_errors.yml` como puente |
| Acción sobre la BD | Ninguna | Ofrecer reparación vía bCompass |

### 9.4 El segundo diálogo — identificación del tipo de error

```
Confirmaste: buscabas Toyota S.A.

¿Qué pasó exactamente?

[A] Yo escribí mal al buscar
    "tpiota" fue un error de teclado mío
    El dato en el sistema está correcto

[B] El dato en el sistema está mal guardado
    Alguien lo registró como "tpiota"
    Quiero corregir ese registro

[C] No sé / solo quiero el resultado
```

### 9.5 Las rutas de respuesta

**Ruta A — Error de teclado:** el sistema **descarta el término mal escrito completamente**. No lo registra en ningún diccionario. Reemplaza el textbox con `"Toyota S.A."` y ejecuta la búsqueda correcta.

**Ruta B — Error en el dato almacenado:** registra en `corrections/data_errors.yml` con `status: pending_repair`. Ofrece corrección al usuario con notificación en Core UI si no tiene permisos. bSearch emite evento `data_repair_request` a bCompass.

**Ruta C — Ambiguo:** registra sin acción inmediata. Si el mismo patrón se acumula con 3+ usuarios → bCompass propone adición al diccionario al administrador.

### 9.6 Los tres tipos de conocimiento acumulable

| Tipo | Origen | Archivo destino | Ejemplo |
|---|---|---|---|
| Alias de entidad | Usuario confirma que `"IBM"` es la razón social completa | `synonyms/discovered.yml` | Nombres cortos vs razón social |
| Abreviatura de negocio | Patrón: mismo término selecciona mismo resultado 5+ veces, 90%+ | `synonyms/business.yml` | `oc`, `nc`, `cxc`, `rrhh` |
| Error de dato almacenado | Usuario confirma Caso B | `corrections/data_errors.yml` | `"tpiota"` → `"toyota"` en registro específico |

---

## 10. Integración con bCompass — Las Cuatro Rutas de Inteligencia

### 10.1 El principio de delegación

bSearch no tiene inteligencia autónoma para actuar sobre datos del negocio. Toda acción que implique modificar datos, analizar calidad, descubrir vocabulario, o interpretar lenguaje natural es **delegada a bCompass** mediante eventos.

```
bSearch detecta necesidad
        ↓
bSearch emite evento a bCompass
        ↓
bCompass selecciona la ruta correspondiente
        ↓
bCompass ejecuta con autorización apropiada
        ↓
bCompass notifica resultado a bSearch / Core UI / usuario
```

### 10.2 Las cuatro rutas que bSearch requiere en bCompass

#### Ruta 1 — `flow/bsearch_data_repair`

**Propósito:** ejecutar la reparación de un dato en la BD de una app cuando el usuario confirma un error de captura (Caso B del Search Learning Engine).

```yaml
# manifest.yml
identity:
  id:          "flow_bsearch_data_repair"
  name:        "Reparación de Dato Solicitada por bSearch"
  route_type:  "flow"

trigger:
  type:       event
  source:     bsearch
  event_type: data_repair_request

sources:
  - app: "{event.app}"
    access: write

governance:
  category_low_impact:  1       # corrección ortográfica → ejecuta directo
  category_high_impact: 2       # cambio de NIT, monto → aprobación humana
  notify_channel: "#bsearch-repairs"
```

#### Ruta 2 — `analyst/bsearch_quality_agent`

**Propósito:** detectar proactivamente errores de captura en los datos almacenados — antes de que el usuario los encuentre al buscar. Ejecuta nocturnamente comparando registros similares.

```yaml
identity:
  id:          "analyst_bsearch_quality_agent"
  route_type:  "analyst"

trigger:
  type: schedule
  cron: "0 3 * * *"   # diario a las 3:00 AM

output:
  type: suggestion
  suggestion_category: "data_quality"
  pending_review: true
```

#### Ruta 3 — `analyst/bsearch_synonym_discovery`

**Propósito:** descubrir abreviaturas y aliases del vocabulario real del negocio analizando los logs de búsqueda.

```yaml
identity:
  id:          "analyst_bsearch_synonym_discovery"
  route_type:  "analyst"

trigger:
  type: schedule
  cron: "0 4 * * 1"   # lunes a las 4:00 AM — semanal

output:
  type: suggestion
  suggestion_category: "search_vocabulary"
  pending_review: true   # administrador aprueba antes de agregar al diccionario
```

#### Ruta 4 — `agent/bsearch_nlu_rewriter`

**Propósito:** traducir consultas en lenguaje natural a filtros estructurados de Meilisearch.

```yaml
identity:
  id:          "agent_bsearch_nlu_rewriter"
  route_type:  "agent"

trigger:
  type:       event
  source:     bsearch
  event_type: nlu_rewrite_request

llm:
  model:               "qwen3:8b"
  response_format:     json

output:
  type:            structured_response
  max_latency_ms:  400   # si no responde en 400ms → bSearch busca sin NLU
```

**Ejemplo de transformación:**

```
Consulta: "facturas sin pagar del mes"
    ↓ bCompass NLU Rewriter
Filtros Meilisearch:
{
  "entity_type": "document",
  "filters": "state != paid AND state != cancelled",
  "date_filter": "invoice_date >= 2026-03-01",
  "sort": "invoice_date:desc"
}
```

### 10.3 Resumen de la integración

| Necesidad de bSearch | Tipo de ruta | Trigger | Impacto |
|---|---|---|---|
| Reparar dato en BD de una app | `flow` | Evento `data_repair_request` | Low/High según campo |
| Detectar duplicados proactivamente | `analyst` | Schedule diario 3:00 AM | Sugerencias pendientes |
| Descubrir vocabulario del negocio | `analyst` | Schedule semanal lunes | Sugerencias al diccionario |
| Traducir lenguaje natural a filtros | `agent` | Evento `nlu_rewrite_request` | Ninguno — solo reescribe |

---

## 11. Arquitectura General del Daemon

### 11.1 Las cuatro capas

```
CAPA 1 — CONOCIMIENTO ESTRUCTURAL
  /etc/bsearch/patterns/<app>/
  Generado por: Schema Discoverer (idempotente, 5 fases)
  Fuentes:      pg_catalog (determinístico) + aiserver/Ollama (semántico)
  Ciclo:        DRAFT → APPROVED → ACTIVE
  Hot-reload:   inotify — sin reinicio del daemon

CAPA 2 — CONOCIMIENTO SEMÁNTICO
  /etc/bsearch/synonyms/ + /etc/bsearch/corrections/
  Generado por: Schema Discoverer + Search Learning Engine + bCompass (rutas analyst)
  Contiene:     sinónimos · abreviaturas · correcciones confirmadas · estados de negocio
  Actualización: solo con aprobación humana explícita

CAPA 3 — MOTOR DE BÚSQUEDA (bsearch.service)
  INDEXER       — consume Redis Stream bKernel / SQL directo + aplica patrones
  MEILISEARCH   — índice full-text persistido (Tenant Tokens multi-tenant)
  API SERVER    — sirve consultas con scope + auth JWT Keycloak
  SCOPE REG.    — mantiene scope por sesión activa del SBOS VDI
  SCHEMA DISC.  — genera y actualiza patrones idempotentemente
  LEARNING ENG. — diálogo de clarificación + acumulación de conocimiento + eventos a bCompass

CAPA 4 — WIDGET DE USUARIO
  Textbox agnóstico · scope declarado por el anfitrión
  Meta+Space    → scope global (SBOS VDI escritorio)
  Ctrl+K        → scope por app (sbos-app-container)
  Core UI       → scope global (administrador)
```

### 11.2 Integración con el ecosistema SBOS

| Componente | Relación con bSearch | Dirección del flujo |
|---|---|---|
| bKernel | Produce eventos en Redis Stream `bkernel:index_queue` | bKernel → bSearch |
| IAM Installer | Dispara Schema Discoverer al instalar/actualizar apps | IAM Installer → bSearch |
| aiserver (Ollama) | Schema Discoverer consume Ollama para análisis semántico | bSearch → aiserver |
| bCompass | bSearch emite eventos; bCompass ejecuta las rutas | bSearch ↔ bCompass |
| Keycloak | JWT determina realm activo — scope multi-tenant | Keycloak → bSearch |
| Kong | API Gateway — valida JWT antes de la consulta | Kong → bSearch API |
| SBOS VDI (SBOS-012) | Consume la API de bSearch para el widget de escritorio | SBOS VDI → bSearch API |
| PostgreSQL de las apps | bSearch lee directamente en modo directo (solo `SELECT`) | bSearch → BDs apps |

---

## 12. Multi-Tenant y Seguridad

Los índices de Meilisearch se crean por combinación `entity_type + realm`. Esta es una **separación física de datos** — no un filtro en tiempo de consulta. Un usuario autenticado en el realm `empresa_abc` solo puede acceder a índices `*_empresa_abc`. No existe posibilidad de fuga accidental por un bug de filtro.

El realm se extrae siempre del JWT de Keycloak. El cliente nunca puede declarar su propio realm en los parámetros de la consulta — el API SERVER lo ignora si lo intenta. Como capa adicional de seguridad, bSearch usa **Tenant Tokens de Meilisearch**: un JWT firmado por la API key maestra que restringe qué índices puede usar una consulta.

---

## 13. Fronteras que bSearch Nunca Cruza

| Frontera | Regla | Consecuencia de violación |
|---|---|---|
| **B1 — Solo lectura en BDs de apps** | bSearch lee con `SELECT` — nunca ejecuta `DDL` ni `DML` | Modificación accidental de datos de negocio |
| **B2 — Cero escritura fuera del índice y patrones propios** | bSearch solo escribe en su índice Meilisearch y sus archivos YAML | Corrupción de datos en producción |
| **B3 — Realm del JWT, nunca del cliente** | El realm se extrae siempre del JWT de Keycloak | Fuga de datos cross-tenant |
| **B4 — Diccionario solo con datos válidos confirmados** | Errores de teclado del usuario (Caso A) nunca se registran en ningún diccionario | Contaminación del conocimiento con ruido |
| **B5 — El scope lo declara el anfitrión** | El widget no decide su universo de búsqueda — lo recibe del container | El widget devuelve resultados fuera de contexto |
| **B6 — El scope solo desciende** | Un widget en Nivel 1 no puede ampliar su scope al Nivel 0 | Resultados de apps fuera del contexto de trabajo |
| **B7 — Patrones DRAFT nunca activos** | Los patrones generados requieren aprobación humana antes de activarse | Búsqueda en estructuras no validadas |
| **B8 — Reparaciones vía bCompass, nunca directas** | bSearch emite eventos que bCompass procesa con autorización | Modificaciones sin trazabilidad |
| **B9 — aiserver con criticality false** | bSearch funciona en modo degradado sin el aiserver | La búsqueda queda bloqueada si el aiserver falla |
| **B10 — Cero fuente de verdad** | Los datos indexados son proyecciones con lag — siempre incluye deep-link a la app de origen | El usuario toma decisiones sobre datos potencialmente desactualizados |
| **B11 — Vocabulario del negocio vía bCompass** | Los diccionarios solo se actualizan mediante rutas `analyst` aprobadas por el administrador | Cambios no trazables en el diccionario de conocimiento |

---

## 14. Calidad de Búsqueda — Evaluación y Hoja de Mejora

### 14.1 Estado actual del sistema

| Dimensión | Nota | Fundamento |
|---|---|---|
| Búsqueda exacta | **10 / 10** | Perfecta — número, nombre, referencia, cualquier campo indexado |
| Typos del usuario | **9 / 10** | Damerau-Levenshtein resuelve ~95% — Keyboard Distance para el 1% restante |
| Errores en datos almacenados | **8 / 10** | Detectados vía diálogo (reactivo) — Quality Agent proactivo eleva a 10/10 |
| Abreviaturas y sinónimos | **8 / 10** | Diccionario base + descubrimiento — Synonym Discovery Agent eleva a 10/10 |
| Lenguaje natural con estados | **7 / 10** | `business_states.yml` configurado — NLU Rewriter (bCompass) eleva a 10/10 |
| Búsqueda cross-app multi-contexto | **10 / 10** | El caso de uso estrella — entidad unificada con N contextos y deep-links |
| Cobertura del universo BOS | **9 / 10** | Panel de cobertura informativo — Coverage Score por patrón eleva a 10/10 |
| Transparencia al usuario | **9 / 10** | Diálogo de clarificación + panel de cobertura — Freshness Indicator eleva a 10/10 |
| Tiempo real | **8 / 10** | Modo directo: tiempo real. Modo indexado: lag de segundos — Hybrid Query eleva a 10/10 |
| Routing a entidad | **10 / 10** | Deep-links `sbos://` correctos generados desde patrones YAML |
| Autocorrección y aprendizaje | **9 / 10** | Distingue Caso A vs Caso B — Quality Agent + Synonym Agent elevan a 10/10 |
| Búsqueda semántica vectorial | **0 / 10** | Fase 4 — integración con Qdrant del aiserver (SBOS-015) |

**Calificación global (v5.0): 8.8 / 10**

### 14.2 Hoja de mejora a 10/10

| Dimensión | Nota actual | Solución | Componente | Esfuerzo |
|---|---|---|---|---|
| Typos del usuario | 9/10 | **Keyboard Distance Model** | bSearch Motor | Bajo |
| Errores en datos | 8/10 | **Quality Agent proactivo** (bCompass) | bCompass | Medio |
| Abreviaturas y sinónimos | 8/10 | **Synonym Discovery Agent** (bCompass) | bCompass | Medio |
| Lenguaje natural | 7/10 | **NLU Query Rewriter** (bCompass + aiserver) | bCompass + aiserver | Medio-alto |
| Cobertura BOS | 9/10 | **Coverage Score por patrón** | bSearch Patrones | Bajo |
| Transparencia | 9/10 | **Freshness Indicator** en tarjeta | bSearch Widget | Bajo |
| Tiempo real | 8/10 | **Hybrid Query** para IDs exactos | bSearch Motor | Medio |
| Semántica vectorial | 0/10 | **Qdrant del aiserver** (SBOS-015) | bSearch + aiserver | Alto — Fase 4 |

**Con mejoras de Bajo y Medio esfuerzo: 9.8 / 10**
**Con búsqueda semántica vectorial (Fase 4): 10 / 10**

---

## 15. Posicionamiento en la Industria

| Sistema / Patrón | Lo que adopta bSearch | Lo que no adopta o supera |
|---|---|---|
| Glean / Guru | Índice centralizado, resultados multi-fuente, routing al origen | No usa polling — usa CDC (lag de segundos vs horas) |
| **Odoo Global Search** | **SQL SELECT directo de solo lectura a la BD de la app** | No limitado a una app — busca en 110+ apps del stack |
| Elasticsearch + Logstash | Motor dedicado, pipeline de indexación desacoplado | No usa JVM — Meilisearch + INDEXER propio |
| Microsoft Viva Search | Búsqueda unificada cross-app con routing al registro de origen | No es SaaS — soberano, en infraestructura del cliente |
| Windows 11 Search | Widget textbox + panel flotante + resultados clasificados + teclado completo | No busca en el SO local — busca en datos de negocio del realm |
| KRunner (KDE Plasma) | Búsqueda universal desde el escritorio, apertura directa | No busca en el filesystem — busca en el universo empresarial del SBOS |
| Google "Did you mean" | Detección de errores tipográficos y sugerencia de corrección | **Distingue error del usuario vs error del dato almacenado** |

---

## 16. Factibilidad Técnica

bSearch es **100% factible tecnológicamente**. Todo el stack necesario existe, está maduro, y tiene deployments en producción.

| Componente | Viable | Evidencia | Riesgo |
|---|---|---|---|
| Meilisearch + K8s | ✅ | Miles de deployments — Rust nativo, Tenant Tokens nativos | Cero |
| SQL SELECT directo + pg_trgm | ✅ | Extensión oficial PostgreSQL desde v9.1 — Odoo lo usa en millones de instancias | Cero |
| Redis Stream como cola de indexación | ✅ | El bKernel ya lo usa — bSearch es un consumer group adicional | Cero |
| inotify hot-reload de patrones YAML | ✅ | API del kernel Linux estable desde 2005 — el bKernel usa el mismo patrón | Cero |
| Multi-tenant con Tenant Tokens | ✅ | Mecanismo nativo de Meilisearch | Cero |
| LLM como parser universal (aiserver) | ✅ | Qwen3 cubre 119+ lenguajes — todas las apps del stack en corpus | Bajo |
| Schema Discoverer idempotente | ✅ | pg_catalog (determinístico) + LLM semántico + flag `human_edited` | Bajo |
| Search Learning Engine | ✅ | Relevance feedback con human-in-the-loop — implementado por Coveo, Algolia | Bajo |
| NLU Query Rewriter vía bCompass | ✅ | Qwen3:8b con prompt bien diseñado resuelve 90%+ de casos | Medio |
| Búsqueda semántica vectorial (Qdrant) | ✅ | Qdrant ya está en el aiserver — solo requiere integración de embeddings | Bajo — Fase 4 |

---

## 17. Hoja de Ruta de Desarrollo

| Fase | Período | Entregables principales |
|---|---|---|
| **Fase 1** — Indexación base y routing | Meses 3–5 | INDEXER + Meilisearch + API Server. Patrones YAML para 6 apps centrales (Tryton, OrangeHRM, EspoCRM, Zammad, Saleor, Nextcloud). Capa 0 de normalización. API REST completa. Multi-tenant por realm. Schema Discoverer Fases 1-4. |
| **Fase 2** — Modo directo, widget e investigación | Meses 6–7 | SQL SELECT directo con pg_trgm. Schema Discoverer Fase 5. Widget con modo investigación. Scope Registry. Keyboard Distance Model. Coverage Score. |
| **Fase 3** — Inteligencia con bCompass | Meses 8–10 | Search Learning Engine completo (Caso A / Caso B). Las 4 rutas bCompass. Hybrid Query. Search Quality Agent nocturno. |
| **Fase 4** — Búsqueda semántica vectorial | Mes 12+ | Integración con Qdrant del aiserver (SBOS-015). Embeddings por entidad. Búsqueda por similitud semántica. Calificación global: **10 / 10**. |

---

## 18. Registro de Cambios

### v5.0 — Marzo 2026 (este documento)

**Renumeración: SBOS-014-BSEARCH → SBOS-013.** El documento pasa a su número definitivo en la tabla de renumeración v5.0. Estado cambiado de BORRADOR EN REVISIÓN a ACTIVO.

**Sección 6 nueva — Contrato con las Fichas: bsearch_config.** Especificación completa del bloque `bsearch_config` del `manifest.yml` del IAM Installer: todos los campos con tipos y valores válidos, ejemplo funcional completo para Tryton ERP con 5 entidades, y ejemplos de fichas que declaran `enabled: false`.

**Sección 7 nueva — Esquema del Evento bKernel → bSearch.** Especificación formal del canal Redis Stream, esquema JSON completo del evento con todos sus campos, tipos y valores posibles, descripción de los cuatro tipos de evento (`index_update`, `index_delete`, `index_create`, `schema_change`), y manejo de errores con dead-letter stream.

**Actualización de modelos a familia Qwen3.** Referencias a modelos actualizadas en Schema Discoverer y NLU Rewriter: `qwen3-coder:30b` como modelo preferido, `deepseek-r1:32b` como fallback de razonamiento, `qwen3:8b` como fallback ligero. Eliminadas referencias a Llama 3.2.

**Integración con el protocolo sbos://.** Los `uri_pattern` de routing en los patrones usan la sintaxis del protocolo `sbos://` especificado en SBOS-012 §23. Actualizada referencia en §1.2.

**Actualización de referencias de numeración.** Todas las referencias actualizadas a la nueva numeración: SBOS-010 (bKernel), SBOS-014 (bCompass), SBOS-015 (aiserver), SBOS-006 (Sistema de Fichas).

### v3.5 — Marzo 2026

Incorpora la capacidad de búsqueda por pista de investigación — la tercera dimensión del problema. Modo investigación del widget. Panel de resultados agrupados por tipo de entidad. Capa 0 de normalización por tipo de dato (numeric, date, code, reference, free_text). Entidades contables de Tryton agregadas al catálogo base.

### v3.4 — Marzo 2026

Terminología corregida: "ficha" → "patrón". Capa 4 Keyboard Distance Model. Integración con bCompass — las cuatro rutas de inteligencia completas con contratos. Frontera B11. Hoja de mejora a 10/10.

### v3.3 — v3.0 — Marzo 2026

LLM como parser universal. Distinción Caso A vs Caso B. Daemon soberano. Tres anclajes del widget. Scope contextual. Schema Discoverer 5 fases. Search Learning Engine inicial.

---

*SKULL · SBOS · SBOS-013 · v5.0 · Marzo 2026*
*Reemplaza: SBOS-014-BSEARCH v3.5 (SUPERSEDED — borrador en revisión)*
-e 
---

## Motor de Indexación, Fuzzy Search y Smart Routing

> **Integrado desde SBOS-013-001 en v5.0.**


```
bkernel procesa evento WAL
  │
  ├── Regla con acción "enqueue" → target: "bsearch"
  │     └── Publica en Redis: bsearch:index_queue
  │
  ▼
bsearch Index Worker (loop continuo)
  │
  ├── Lee de Redis: bsearch:index_queue
  ├── Normaliza documento (lowercase, strip accents, tokenize)
  ├── Genera embedding via Embedding Worker (Ollama nomic-embed-text)
  ├── Indexa en Qdrant (vector) + Typesense (full-text)
  └── Confirma procesamiento (Redis ACK)
```

### 1.2 Estrategia de indexación por app

| Aplicación | Tabla/Entidad | Campos indexados | Frecuencia | Tipo |
|------------|---------------|-----------------|------------|------|
| Tryton | party.party | name, email, vat_number, phone | Evento WAL (real-time) | Incremental |
| Tryton | account.invoice | number, date, total, party_name | Evento WAL | Incremental |
| Tryton | sale.sale | number, date, party_name, total | Evento WAL | Incremental |
| Tryton | product.product | name, code, description, list_price | Evento WAL | Incremental |
| OrangeHRM | hs_hr_employee | emp_firstname, emp_lastname, emp_work_email | Evento WAL | Incremental |
| Saleor | product_product | name, description, slug | Evento WAL | Incremental |
| Paperless-NGX | documents_document | title, content (OCR), correspondent | Evento WAL | Incremental |
| Wiki.js | pages | title, content, path | Evento WAL | Incremental |
| Zammad | tickets | title, note, customer_name | Evento WAL | Incremental |

### 1.3 Reindexación completa

```bash
bosctl bsearch reindex --app=tryton          # reindexar una app
bosctl bsearch reindex --all                 # reindexar todo
bosctl bsearch reindex --app=tryton --since=2026-03-01  # desde fecha

# El proceso:
# 1. Marca índice como "reindexing" (búsquedas siguen funcionando con índice actual)
# 2. Crea índice temporal nuevo
# 3. Lee todos los registros de la BD fuente
# 4. Indexa batch por batch (1000 docs por batch)
# 5. Swap atómico: índice temporal → índice activo
# 6. Elimina índice anterior
# Tiempo estimado: ~5 min por 100k documentos
```

---

## 2. Fuzzy Search Multi-Capa

### 2.1 Pipeline de búsqueda

```
Query del usuario: "facura 345"
  │
  ▼
CAPA 1: Normalización
  ├── Lowercase: "facura 345"
  ├── Strip accents: "facura 345"
  └── Tokenize: ["facura", "345"]

CAPA 2: Corrección ortográfica
  ├── Diccionario de sinónimos: "facura" → ¿"factura"?
  │   Levenshtein distance("facura", "factura") = 1 → SÍ, corregir
  └── Query corregida: ["factura", "345"]

CAPA 3: Expansión de sinónimos
  ├── "factura" → ["factura", "fra", "fact", "comprobante", "invoice"]
  └── Query expandida: ["factura|fra|fact|comprobante|invoice", "345"]

CAPA 4: Heurística de teclado
  ├── Si Levenshtein no encuentra match:
  │   Generar variantes por proximidad de teclas
  │   "facyura" → "factura" (y→t son teclas adyacentes)
  └── Solo se aplica si las capas anteriores no resuelven

CAPA 5: Búsqueda federada
  ├── Typesense: full-text search con fuzzy en todos los índices
  ├── Qdrant: semantic search con embedding de la query
  └── Merge: combinar resultados por relevancia ponderada
```

### 2.2 Diccionario de sinónimos (configurable por idioma)

```yaml
# /etc/bos/blibs/bsearch/dictionaries/es.yml
synonyms:
  factura: ["fra", "fact", "comprobante", "invoice", "boleta"]
  cliente: ["customer", "comprador", "party"]
  producto: ["item", "artículo", "mercadería", "product"]
  empleado: ["trabajador", "staff", "employee", "colaborador"]
  pago: ["payment", "cobro", "abono", "transferencia"]
  venta: ["sale", "pedido", "order"]
  inventario: ["stock", "existencia", "almacén"]

abbreviations:
  nit: "número de identificación tributaria"
  cuf: "código único de facturación"
  ruc: "registro único de contribuyente"
```

### 2.3 Mapa de proximidad de teclado (QWERTY)

```
q: [w, a]
w: [q, e, a, s]
e: [w, r, s, d]
r: [e, t, d, f]
t: [r, y, f, g]
y: [t, u, g, h]
...

Uso: si Levenshtein distance > 2 y el carácter diferente es adyacente
en el teclado → considerar como error de dedo y proponer corrección
```

---

## 3. Smart Routing a Aplicaciones

### 3.1 Concepto

Cada resultado incluye un enlace directo al formulario de la aplicación propietaria del dato. El usuario hace clic y abre la pantalla exacta.

### 3.2 Formato de resultado con routing

```json
{
  "results": [
    {
      "score": 0.95,
      "source": {
        "app": "tryton",
        "database": "tryton_db",
        "table": "account.invoice",
        "field": "number",
        "record_id": 4521
      },
      "display": {
        "title": "Factura #345",
        "subtitle": "Cliente: ACME Corp · Total: Bs. 15,000.00 · Fecha: 2026-03-10",
        "highlight": "Factura <mark>345</mark> registrada en Contabilidad"
      },
      "routing": {
        "app_url": "https://skull.io/erp/#/model/account.invoice/4521",
        "app_name": "Tryton ERP",
        "module": "Contabilidad",
        "action": "view",
        "requires_permission": "APP_TRYTON"
      },
      "metadata": {
        "indexed_at": "2026-03-10T14:30:00Z",
        "last_modified": "2026-03-10T14:25:00Z",
        "match_type": "exact"       # exact | fuzzy | semantic
      }
    },
    {
      "score": 0.72,
      "source": {
        "app": "tryton",
        "table": "account.payment",
        "field": "amount",
        "record_id": 8910
      },
      "display": {
        "title": "Pago por Bs. 345.00",
        "subtitle": "Recibo #8910 · Proveedor: Distribuidora Norte · Fecha: 2026-03-08",
        "highlight": "Importe coincidente: Bs. <mark>345</mark>.00"
      },
      "routing": {
        "app_url": "https://skull.io/erp/#/model/account.payment/8910",
        "app_name": "Tryton ERP",
        "module": "Tesorería",
        "action": "view",
        "requires_permission": "APP_TRYTON"
      }
    }
  ],
  "query_info": {
    "original": "facura 345",
    "corrected": "factura 345",
    "correction_applied": true,
    "search_duration_ms": 45,
    "total_results": 2,
    "sources_searched": ["tryton", "saleor", "paperless"]
  }
}
```

### 3.3 Verificación de permisos

bsearch SIEMPRE verifica con bauth antes de mostrar un resultado. Si el usuario no tiene permiso para la app, el resultado aparece con routing deshabilitado:

```json
{
  "routing": {
    "app_url": null,
    "app_name": "Tryton ERP",
    "module": "Contabilidad",
    "action": "denied",
    "reason": "No tiene permiso APP_TRYTON"
  }
}
```

El dato se muestra (porque el usuario puede tener permiso de lectura general) pero el enlace no funciona. Esto sigue el principio de Zero Trust: bsearch no confía en que el frontend filtre — verifica en el backend.

---

## 4. Métricas Prometheus

```
bsearch_queries_total{correction="none|fuzzy|synonym|keyboard"}
bsearch_query_duration_seconds
bsearch_index_size{app="tryton"}
bsearch_reindex_duration_seconds{app="tryton"}
bsearch_embedding_queue_size
bsearch_results_per_query{bucket="0|1-5|6-20|20+"}
```

---

## 5. Registro de Cambios

### v1.0 — Marzo 2026

Motor de indexación incremental por evento WAL, pipeline de fuzzy search de 5 capas (normalización, Levenshtein, sinónimos, proximidad de teclado, búsqueda federada), smart routing con verificación de permisos, formato de resultados con metadata de trazabilidad, y protocolo de reindexación completa.

---

*SKULL · SBOS · SBOS-013-001 · Anexo 001 · v1.0 · Marzo 2026*
