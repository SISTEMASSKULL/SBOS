# S15-aiserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
IA soberana (OPCIONAL). bCompass y bSearch la consumen como herramienta.

## Criticidad
**NINGUNA**

## Unidad de migración
Al crecer, `S15-aiserver/` se lleva entero a un VPS dedicado (`tipo=aiserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: aiserver (BASE 8950) — opcional.
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| Ollama | 11434→8950 | ⬜ falta | Motor de inferencia LLM |
| Open WebUI | 8080→8960 | ⬜ falta | Interfaz de chat |
| Qdrant HTTP | 6333→8970 | ⬜ falta | Memoria semántica vectorial |
| Qdrant gRPC | 6334→8972 | ⬜ falta | Vector DB gRPC |
| Langfuse | 3000→8980 | ⬜ falta | Observabilidad de modelos |
| Flowise | 3000→8990 | ⬜ falta | Constructor de flujos LLM |
| Embedding Worker | — | ⬜ falta | Generación de embeddings (worker Redis) |

## Fichas existentes ratificadas
_(ninguna todavía)_  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
