# PROPOSITO.md — bsearch

## QUÉ es
Daemon host que implementa el **motor de búsqueda soberano SBOS** sobre PostgreSQL 18+ — búsqueda full-text, vectorial y semántica de entidades del ecosistema sin depender de Elasticsearch ni ningún motor externo.

## POR QUÉ existe
La búsqueda es una operación universal en SBOS: buscar usuarios, roles, fichas, documentos, logs de auditoría. La alternativa obvia (Elasticsearch) requiere infraestructura separada, licencias adicionales y fuga de datos a un motor externo. PostgreSQL 18 incorpora capacidades de búsqueda full-text, `pgvector` para embeddings, y rangos temporales que hacen posible un motor soberano sin deuda operativa adicional.

## PARA QUÉ sirve
- Búsqueda full-text sobre entidades SBOS (usuarios, roles, fichas, eventos)
- Búsqueda vectorial/semántica con embeddings (integración con S15-aiserver)
- Búsqueda temporal (PERIOD/WITHOUT OVERLAPS — PG18)
- Expone métodos `bsearch.*` sobre Unix socket `/run/bos/bsearch.sock`
- Provee a: dashboard desktop, bosctl CLI, bCompass (queries), agentes IA

## QUIÉN la declara / usa
- **Declara:** bsearch-developer (BintelligenceAgent/)
- **Instala:** bos (IAM Installer)
- **Consume:** dashboard frontend, bosctl, bCompass, agentes IA

## DEPENDENCIAS
| Dependencia | Motivo |
|-------------|--------|
| postgresql | Motor subyacente — FTS, pgvector, PERIOD (PG18) |
| redis | Cache de resultados frecuentes y sesiones de búsqueda |
| bauth | Filtrado de resultados según BitMask de permisos del usuario |

## SERVIDOR y MOTIVO
**S09-searchserver** — el servidor de búsqueda ya aloja Elasticsearch y RabbitMQ. bsearch vive aquí porque su función (búsqueda) es la del servidor lógico, aunque su motor sea PostgreSQL (en S01). La separación es por función del daemon, no por ubicación del motor subyacente (SBOS-016, regla #3: ubicación por función del daemon, no del motor que consume).
