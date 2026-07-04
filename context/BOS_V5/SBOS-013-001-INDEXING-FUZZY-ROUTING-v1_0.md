# SBOS-013-001
## Anexo: Motor de Indexación, Fuzzy Search y Smart Routing
### Especificación de Nivel de Código para SBOS Data RAG

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-013-001
**Complementa:** SBOS-013-bSearch-v4_0.md

---

## 1. Motor de Indexación

### 1.1 Arquitectura

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
