# S08-docserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
Gestión documental: captura, OCR, flujo, firma, archivo.

## Criticidad
**ALTA**

## Unidad de migración
Al crecer, `S08-docserver/` se lleva entero a un VPS dedicado (`tipo=docserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: catalogserver + workflowserver + esignserver (BASE 8550).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| Paperless-NGX | 8000→8550 | ⬜ falta | Archivo documental + indexación |
| Apache Solr | 8983→8560 | ⬜ falta | Búsqueda documental (backend Kimios) |
| DocuSeal | 3000→8570 | ⬜ falta | Firma digital |
| Kimios DMS | 80→8580 | ⬜ falta | Flujo documental + aprobación |
| Tesseract/Tabula/Camelot | — | ⬜ falta | OCR y extracción (sin puerto de servicio) |

## Fichas existentes ratificadas
_(ninguna todavía)_  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
