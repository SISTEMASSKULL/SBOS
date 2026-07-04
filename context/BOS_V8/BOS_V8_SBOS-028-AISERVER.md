# SBOS-028-AISERVER
## aiserver: Servidor de Inteligencia Artificial Soberana — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Identidad

| Campo | Valor |
|---|---|
| Nombre | aiserver — Servidor de IA Soberana |
| Servidor lógico | S15 |
| Criticality | false (todas las fichas — stack funciona sin él) |
| Fichas | Ollama, Open WebUI, Qdrant, Embedding Worker, Langfuse, Flowise |
| Principio | aiserver NO decide → INFIERE. bCompass decide qué preguntar. |

No tiene lógica de negocio propia. Es infraestructura de IA que bCompass y bSearch consumen como herramienta.

## 2. 6 Principios

P1: Soberanía total (datos nunca salen, sin OpenAI/Anthropic/Google, funciona offline). P2: Criticality false (stack funciona sin él). P3: Infraestructura, no lógica de negocio. P4: Aislamiento por realm en todo nivel (Qdrant colecciones, Langfuse proyectos). P5: Modelos son archivos re-descargables, no código. P6: Flowise = banco de pruebas, no producción.

## 3. Stack de 6 Fichas

| # | Ficha | Función | Perfil | Licencia |
|---|---|---|---|---|
| 1 | **Ollama** | Runtime LLM local. API :11434 OpenAI-compatible | A | MIT |
| 2 | **Open WebUI** | Chat soberano power users. RAG nativo. KC OIDC | A | MIT |
| 3 | **Qdrant** | BD vectorial. Colecciones por realm. Hybrid search. Rust | A | Apache 2.0 |
| 4 | **Embedding Worker** | Daemon SKULL. bKernel → Redis → embeddings → Qdrant | A | MIT (SKULL) |
| 5 | **Langfuse** | Observabilidad LLM. Trazas, prompts versionados. PG backend | B | MIT |
| 6 | **Flowise** | Constructor visual agentes. Solo prototipado interno | A | Apache 2.0 |

### Dependencias
```
ollama ← open-webui, flowise, bcompass, bsearch (Schema Discoverer)
qdrant ← embedding-worker, bcompass (qdrant_search), bsearch (Fase 4)
redis  ← embedding-worker (ai:embed_queue)
keycloak ← open-webui, langfuse
```

## 4. Embedding Worker — Pipeline bKernel → Qdrant

```
bKernel detecta cambio → XADD ai:embed_queue → Embedding Worker consume
→ Modelo embeddings local (multilingual-e5-base) → UPSERT Qdrant
→ Colección: realm_{realm_id}_{entity_type}s
→ bCompass qdrant_search disponible / bSearch Fase 4 hybrid search
```

### Colecciones (meta-patrón: daemon + unidades declarativas)
```
/etc/embedding-worker/collections/
├── tryton_contracts/     ← manifest.yml + mapping.yml
├── orangehrm_employees/
├── zammad_tickets/
├── nextcloud_documents/
└── espocrm_accounts/
```

### manifest.yml de colección
```yaml
identity:
  id: "tryton_contracts"
  entity_type: "contract"
  source_app: "tryton"
trigger:
  queue: "ai:embed_queue"
  consumer_group: "embedding_worker"
  filter: { entity_type: "contract", source_app: "tryton" }
embedding:
  model: "multilingual-e5-base"    # Perfil A (~500 MB)
  dimensions: 768
qdrant:
  collection_template: "realm_{realm_id}_contracts"
  upsert_key: "entity_id"
governance:
  realm_from: event_payload
  max_batch_size: 50
  max_lag_seconds: 5
```

### mapping.yml
```yaml
text_template: |
  Contrato {reference} - {party_name}
  Estado: {state} | Monto: {amount} {currency}
  Fecha: {start_date} - {end_date}
fields:
  - name: reference   source: event.payload.reference
  - name: party_name  source: event.payload.party.name
  - name: state       source: event.payload.state  transform: human_readable
metadata:
  - name: entity_id   source: event.entity_id
  - name: realm_id    source: event.realm_id
  - name: deep_link   template: "/tryton/contract/{entity_id}"
```

## 5. Modelo Multiempresarial por Realm

### Qdrant — separación física
```
realm_empresa_a_contracts, realm_empresa_a_employees, realm_empresa_a_tickets
realm_empresa_b_contracts, realm_empresa_b_products
```
No es filtro — es separación física. Sin posibilidad de fuga.

### Ollama — sin aislamiento necesario (stateless, modelos son archivos públicos)

### Langfuse — proyectos por realm con API keys en Vault

## 6. Política de Modelos

### Criterios: español 30% + licencia libre 25% + eficiencia RAM Q4 25% + razonamiento 20%

### Qwen3 = modelo oficial (Llama 3.2 descartado por rendimiento inferior en español)

| Benchmark | Qwen3-8B | Llama 3.2-8B | Ventaja |
|---|---|---|---|
| MGSM (matemáticas) | 87.4% | 72.1% | +21% |
| XQuAD-es (comprensión) | 91.2% | 81.3% | +12% |
| FLORES-200 (traducción) | 38.4 BLEU | 31.7 BLEU | +21% |

### Modelos por caso de uso

| Caso | Modelo | RAM Q4 | Perfil | Licencia |
|---|---|---|---|---|
| Agente empleado | qwen3:4b-q4 | ~3 GB | A | Apache 2.0 |
| Agente admin | qwen3:8b-q4 | ~6 GB | A | Apache 2.0 |
| Razonamiento | deepseek-r1:32b-distill-qwen-q4 | ~20 GB | B | MIT |
| Chat avanzado | qwen3:32b-q4 | ~20 GB | B | Apache 2.0 |
| MoE eficiente | qwen3:30b-a3b-q4 | ~8 GB activos | B | Apache 2.0 |
| Schema Discoverer | qwen3-coder:30b | ~48 GB | B+ | Apache 2.0 |
| GPU multi-usuario | llama3.3:70b-q4 | ~35 GB VRAM | C | Llama 3.3 |

### Modelos embeddings

| Modelo | RAM | Perfil | Dimensiones |
|---|---|---|---|
| multilingual-e5-base | ~500 MB | A | 768 |
| qwen3-embedding:0.6b | ~2 GB | B | 1024 |
| qwen3-embedding:8b | ~8 GB | C | 4096 |

### Ciclo de vida
Revisión trimestral. Actualización nunca automática. Validación: disponibilidad Ollama + benchmark español + RAM + licencia + regresión 3 rutas bCompass. Rollback inmediato (< 30s, cambiar manifest + SIGHUP). Modelos nunca en backups (re-descargables).

## 7. Perfiles de Hardware

| Perfil | RAM | GPU | Modelos |
|---|---|---|---|
| A (mínimo) | 32-48 GB | Sin GPU | qwen3:4b/8b + e5-base |
| B (recomendado) | 64-96 GB | Sin GPU | + qwen3:32b + deepseek-r1:32b |
| C (óptimo) | 128+ GB | GPU 24+ GB VRAM | + llama3.3:70b + qwen3-embedding:8b |

Detección automática: `detect_and_pull.sh` en post_install de Ollama.

## 8. Flowise — Banco de Pruebas

```
Fase 1 DISEÑO: Flowise visual → probar agente → iterar rápido
Fase 2 MIGRACIÓN: Flowise → route_engine.yml + route_catalog.so
Fase 3 PRODUCCIÓN: bCompass (daemon estable, governance KC, auditoría)
```

No en producción: fugas memoria, actualizaciones disruptivas, sin governance KC nativo, sin auditoría datos.

## 9. Integraciones Ecosistema

| Flujo | Detalle |
|---|---|
| bKernel → Embedding Worker → Qdrant | enqueue_embedding → Redis ai:embed_queue → modelo local → UPSERT Qdrant |
| bCompass → Ollama | llm_prompt en route_engine.yml → :11434 |
| bSearch → Ollama | Schema Discoverer (qwen3-coder:30b) |
| bCompass → Qdrant | qdrant_search en route_engine.yml → colecciones realm |
| Open WebUI → Keycloak | OIDC con scopes ai.chat.use, ai.admin, ai.observability |

## 10. Licenciamiento

Cero componentes con restricciones. Todos MIT o Apache 2.0 para Perfiles A/B. n8n explícitamente vetado (Sustainable Use License).

## 11. 7 Fronteras Inviolables

| # | Regla | Consecuencia |
|---|---|---|
| A1 | Modelos solo locales (Ollama sin endpoints externos) | Datos enviados a terceros |
| A2 | Realm del JWT/evento, nunca hardcoded | Fuga cross-tenant |
| A3 | Embedding Worker solo escribe en Qdrant | Modificación datos negocio |
| A4 | Flowise no en producción | Inestabilidad, sin auditoría |
| A5 | Qdrant no es fuente de verdad (proyección con lag) | Decisiones sobre datos desactualizados |
| A6 | aiserver no escribe en BDs del stack | Corrupción datos |
| A7 | Langfuse no almacena datos sensibles (sanitizar prompts) | Exposición datos personales |

---

## §12 — ENRIQUECIMIENTO V5: Arquitectura y Modelos (desde SBOS-015 v2.0)

### V5-1: Posición Arquitectónica Completa (desde SBOS-015 v2.0)

```
╔══════════════════════════════════════════════════════════════════╗
║                         S15 · aiserver                           ║
║                    (criticality: false en todas las fichas)       ║
║                                                                   ║
║  ┌──────────────────────────────────────────────────────────┐    ║
║  │                CAPA DE INFERENCIA                          │    ║
║  │                                                             │    ║
║  │   ┌──────────────┐     ┌──────────────────────────────┐    │    ║
║  │   │   Ollama      │◄────│         bCompass              │    │    ║
║  │   │  :11434       │     │  rutas agent/flow/analyst     │    │    ║
║  │   │  API OpenAI   │     │  llm_prompt → Ollama          │    │    ║
║  │   │  Qwen3 / DSR1 │     │  qdrant_search → Qdrant      │    │    ║
║  │   │  Sin internet  │     └──────────────────────────────┘    │    ║
║  │   └───────┬───────┘                                          │    ║
║  │           │◄──── bSearch Schema Discoverer                   │    ║
║  │           │       (qwen3-coder:30b)                          │    ║
║  │   ┌───────▼───────┐                                          │    ║
║  │   │  Open WebUI   │                                          │    ║
║  │   │  :3000        │                                          │    ║
║  │   │  KC OIDC      │                                          │    ║
║  │   └───────────────┘                                          │    ║
║  └──────────────────────────────────────────────────────────┘    ║
║                                                                   ║
║  ┌──────────────────────────────────────────────────────────┐    ║
║  │              CAPA DE MEMORIA SEMÁNTICA                      │    ║
║  │                                                             │    ║
║  │   ┌──────────────┐     ┌──────────────────────────────┐    │    ║
║  │   │    Qdrant     │◄────│     Embedding Worker          │    │    ║
║  │   │  :6333/:6334  │     │  multilingual-e5 / qwen3      │    │    ║
║  │   │  Colecciones  │     │  Consume: Redis ai:embed_queue│    │    ║
║  │   │  por realm    │     │  Escribe: Qdrant realm_X_*    │    │    ║
║  │   └──────────────┘     └──────────────────────────────┘    │    ║
║  └──────────────────────────────────────────────────────────┘    ║
║                                                                   ║
║  ┌──────────────────────────────────────────────────────────┐    ║
║  │         CAPA DE OBSERVABILIDAD (Perfil B+)                │    ║
║  │   ┌────────────────────────────────────────────┐          │    ║
║  │   │              Langfuse                       │          │    ║
║  │   │  :3001 · PostgreSQL backend                 │          │    ║
║  │   │  Trazas bCompass + Open WebUI              │          │    ║
║  │   │  Prompts versionados · Proyectos por realm │          │    ║
║  │   └────────────────────────────────────────────┘          │    ║
║  └──────────────────────────────────────────────────────────┘    ║
╚══════════════════════════════════════════════════════════════════╝
```

### V5-2: Dependencias entre Fichas del aiserver (desde SBOS-015 v2.0)

```
ollama
  depends_on: dataserver.minio (modelos almacenados en MinIO en producción)

open-webui
  depends_on: ollama
  depends_on: qdrant (degraded mode si no está — RAG vectorial deshabilitado)
  depends_on: identityserver.keycloak

qdrant
  depends_on: datos locales (colecciones en disco)

embedding-worker
  depends_on: redis (ai:embed_queue)
  depends_on: qdrant (escritura)
  depends_on: ollama (modelo de embeddings)

langfuse
  depends_on: postgresql (backendsb)
  depends_on: identityserver.keycloak

flowise
  depends_on: ollama
```

### V5-3: Justificación de Qwen3 vs Llama 3.2 (desde SBOS-015 v2.0)

El stack SBOS opera primariamente en mercados iberoamericanos (Bolivia, Perú, México, Argentina, España, Brasil). La selección de modelos responde a tres criterios obligatorios: (1) rendimiento real documentado en español y portugués, (2) licencia libre (MIT o Apache 2.0), y (3) eficiencia en CPU sin GPU para los Perfiles A y B.

Qwen3 supera a Llama 3.2 en español en benchmarks comparativos 2025-2026:
- MGSM (matemáticas multilingüe): Qwen3-8B 87.4% vs Llama 3.2-8B 72.1% (+21.2%)
- XQuAD-es (comprensión lectora español): Qwen3-8B 91.2% vs Llama 3.2-8B 81.3% (+12.2%)
- FLORES-200 (traducción es-en): Qwen3-8B 38.4 BLEU vs Llama 3.2-8B 31.7 BLEU (+21.1%)

Llama 3.2 fue entrenado con énfasis en inglés. Su corpus multilingüe es significativamente menor que el de Qwen3, que incluye entrenamiento extenso en español, portugués, y lenguas latinoamericanas.

---

## §13 — ENRIQUECIMIENTO V7: aiserver en el Contexto de los 3 Dominios

### V7-1: aiserver como Infraestructura de los 3 DomainMasks (desde V7 Dominios)

El aiserver provee la capa de inferencia para todos los dominios del BitmaskBundle:

| DomainMask | Consumo de aiserver | Modelo |
|---|---|---|
| PhysicalDomainMask | bCompass analiza patrones de uso del escritorio | qwen3:8b-q4 |
| LogicalDomainMask | bCompass evalúa acceso lógico, bSearch indexa datos | qwen3:8b-q4, qwen3-coder:30b |
| FinancialDomainMask | bCompass detecta anomalías financieras | deepseek-r1:32b (razonamiento) |

### V7-2: Colecciones Qdrant por Zona Lógica (desde V7 Dominios)

Las colecciones de Qdrant se organizan según las zonas del LogicalDomainMask:

```
Colecciones Qdrant → Mapeo a Zonas Lógicas:
  realm_X_contracts       → ZONE_CONTABILIDAD
  realm_X_invoices        → ZONE_CONTABILIDAD
  realm_X_employees       → ZONE_RRHH
  realm_X_tickets         → ZONE_SOPORTE
  realm_X_products        → ZONE_VENTAS
  realm_X_documents       → ZONE_CONTABILIDAD, ZONE_RRHH (multi-zona)
```

El Embedding Worker escribe siempre con realm_id, y el LogicalDomainEvaluator filtra qué colecciones puede consultar cada usuario según sus zonas activas.

---

## §14 — ENRIQUECIMIENTO Smart* (V8)

### V8-1: Smart Portfolio — Motor de Aprendizaje Continuo y Pipeline ML (desde SBOS-Portfolio-017-MOTOR-APRENDIZAJE-CONTINUO.md)

El Motor de Aprendizaje Continuo de bportfolio se integra con el aiserver como consumidor de inferencia y generador de datos de entrenamiento:

**4 estados de conocimiento como pipeline de madurez del modelo:**
| Estado | Nivel | Rango confianza | Acción en aiserver |
|---|---|---|---|
| Terra Incognita | 0 | 40-65% | Modelo base qwen3:8b, RAG con supervisión |
| Reconocimiento Parcial | 1 | 65-80% | Fine-tuning ligero, active learning |
| Competencia | 2 | 80-92% | Modelo fine-tuned, inferencia autónoma |
| Maestría | 3 | 95%+ | Modelo especializado por dominio |
| Generalización | 4 | Cross-dominio | Modelo multi-dominio con transfer learning |

**Pipeline de entrenamiento en aiserver:**
```
bKernel → ai:embed_queue → Embedding Worker → Qdrant (FASE 1 RAG)
  ↓
Bibliotecario selecciona contexto (6000 tokens) → prompt + respuesta
  ↓
training_examples DDL almacena pares (prompt, response, domain, industry)
  ↓
QLoRA fine-tuning en Ollama (FASE 2) → Modelfile con adaptadores
  ↓
Modelo fine-tuned desplegado como nuevo endpoint en Ollama
```

**5 componentes del motor que corren sobre aiserver:**
1. `DetectorEstado` — Evalúa nivel de conocimiento usando métricas de Langfuse
2. `Modo Exploración` — Mapa del documento: procesa documento nuevo con Embedding Worker, indexa en Qdrant
3. `GestorTransferencia` — Transfiere pesos fine-tuned entre dominios relacionados
4. `EvaluadorCalidad` — Evalúa respuestas contra ground truth en bCompass
5. `GeneradorSintetico` — Genera ejemplos sintéticos usando qwen3:32b para dominios con pocos datos

**8 KPIs monitoreados desde Langfuse:** accuracy, coverage, latency P50/P95/P99, user satisfaction (feedback implícito), learning velocity, hallucination rate, correction rate.

### V8-2: Smart Portfolio — Estrategia de Entrenamiento en 3 Fases (desde SBOS-Portfolio-021-ENTRENAMIENTO-IA.md)

La estrategia de entrenamiento define cómo evolucionan los modelos en aiserver:

| Fase | Timeline | Modelo | Técnica | Dataset mínimo |
|---|---|---|---|---|
| F1 | Ahora | qwen3:8b-q4 (Perfil A) | RAG + Active Learning | < 100 ejemplos |
| F2 | 6-12 meses | Qwen2-VL-7B 4-bit (Perfil B) | QLoRA, r=16, Unsloth | 1,000+ ejemplos |
| F3 | 12-24 meses | Specialist model (Perfil C) | Full fine-tuning | 10,000+ ejemplos |

**Active Learning priority scoring para selección de ejemplos:**
- Uncertainty (alta varianza entre modelos): 40 pts
- New error type (patrón de error no visto antes): 35 pts
- Industry coverage (sector sub-representado): 20 pts
- Image quality (solo para VLMs): 8 pts

**Dataset Format:** ChatML para VLMs. Split estratificado: 40% train, 30% validation, 30% test.

**Ollama Modelfile para modelos fine-tuned:**
```dockerfile
FROM qwen3:8b
# Los adaptadores QLoRA se montan como volumen separado
# El modelo base nunca se modifica
PARAMETER temperature 0.7
PARAMETER top_p 0.9
TEMPLATE "{{ .Prompt }}"
```

**Evaluation benchmarks:** precisión, recall, F1, exact match en extracción de campos. Evaluación periódica automática contra test set.

### V8-3: Smart Portfolio — Formatos de Entrada Soportados (desde SBOS-Portfolio-018-FORMATOS-ENTRADA.md)

El pipeline de procesamiento de documentos de bportfolio define 18 formatos de entrada que el Embedding Worker y el Schema Discoverer de bSearch deben manejar:

**Formatos y herramientas por tipo:**
| Formato | Herramienta | Uso en aiserver |
|---|---|---|
| PDF | Docling / pymupdf / MinerU | Documentos fiscales, contratos |
| DOCX | python-docx | Reportes, memorandos |
| XLSX | openpyxl / calamine | Estados financieros, planillas |
| PPTX | python-pptx | Presentaciones, propuestas |
| Images (PNG/JPG) | Pillow + EasyOCR | Facturas escaneadas, comprobantes |
| HEIC | pillow-heif | Fotos desde móviles |
| TIFF | pymupdf (multipágina) | Documentos escaneados lote |
| DOC | LibreOffice (conversión) | Documentos legacy |
| XLS | xlrd / LibreOffice | Planillas legacy |
| IDML | zipfile + XML | Documentos de InDesign |
| EPUB | ebooklib | Manuales, documentación |
| ZIP | Recursivo (contenedor) | Paquetes de documentos |

**Pipeline de pre-procesamiento:**
```
Orientación → Deskew → Contraste (CLAHE) → Denoising → Grayscale → OCR
```

Este pipeline corre como paso previo al Embedding Worker cuando el documento no es directamente procesable (imágenes escaneadas, fotos). Los archivos nativos (DOCX, XLSX, PDF texto) saltan el OCR y van directo a embeddings.

**No soportados:** CDR (CorelDRAW), INDD (InDesign). Estos requieren conversión manual previa.

### V8-4: Smart Report — Generación de Reportes desde aiserver (desde SBOS-REPORT-015-REPORTES-GLOBAL-LOCAL.md)

El aiserver puede consumir Smart Report como herramienta de generación de documentos estructurados desde bCompass:

**Integración JasperStarter con Ollama:**
```
bCompass route detecta tipo "report"
  → Solicita a Ollama inferencia de parámetros
  → Llama a JasperStarter API con parámetros inferidos
  → Smart Report genera PDF/XLSX/DOCX
  → resultado se sirve al usuario o se indexa en bSearch
```

**Jerarquía de plantillas JasperReports que aiserver puede usar para generar respuestas estructuradas:**
| Nivel | Ámbito | Ejemplo de uso desde aiserver |
|---|---|---|
| Global | Todo SBOS | Reportes estándar del sistema |
| App | Por aplicación | Reportes de Tryton, OrangeHRM |
| Tenant | Por tenant | Personalización multi-tenant |
| Empresa | Por organización | Formatos corporativos |
| Sucursal | Por sucursal | Reportes locales |
| Rol | Por perfil | Reportes por tipo de usuario |
| Usuario | Personal | Reportes personalizados por usuario |

**TemplateResolver desde bCompass:** La ruta de bCompass resuelve el template correcto ascendiendo desde el nivel más específico (usuario) hasta el más general (global). El resultado de la resolución es un .jrxml compilado que JasperStarter ejecuta con los parámetros inferidos por el LLM.

---

## Trazabilidad V8

| Sección | Fuente |
|---|---|
| §1-11 (V6 completo) | BOS_V6_SBOS-028-AISERVER.md |
| §12 V5-1 a V5-3 | BOS_V5_SBOS-015-aiserver-v2_0.md |
| §13 V7-1 a V7-2 | BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md |
| §14 V8-1 a V8-4 | SBOS Smart Portfolio (SBOS-Portfolio-017-MOTOR-APRENDIZAJE-CONTINUO.md, SBOS-Portfolio-021-ENTRENAMIENTO-IA.md, SBOS-Portfolio-018-FORMATOS-ENTRADA.md), SBOS Smart Report (SBOS-REPORT-015-REPORTES-GLOBAL-LOCAL.md) |

---

_SKULL · SBOS · SBOS-028-AISERVER · HUMAN-DOC V8 ENRIQUECIDO · Mayo 2026_
