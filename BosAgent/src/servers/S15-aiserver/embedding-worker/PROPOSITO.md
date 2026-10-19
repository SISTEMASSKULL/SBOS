# PROPOSITO — Embedding Worker

**Ficha:** `embedding-worker` - **Servidor:** S15-aiserver - **Version:** 1.0
**Criticidad:** False - **Namespace:** sbos-ai - **Tipo:** Deployment
**Orden de instalacion:** 420

## Que es
Consumes ai:embed_queue -> Qdrant (MIT SKULL)

## Dependencias
redis, qdrant, ollama

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
