# S11-vdiserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
Escritorio virtual soberano (SBOS VDI) y colaboración.

## Criticidad
**ALTA**

## Unidad de migración
Al crecer, `S11-vdiserver/` se lleva entero a un VPS dedicado (`tipo=vdiserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: vdiserver (BASE 8750).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| Nextcloud | 80→8750 | ⬜ falta | Archivos, CalDAV, CardDAV |
| OnlyOffice Docs | 80→8760 | ⬜ falta | Ofimática colaborativa |
| OnlyOffice WOPI | 8080→8768 | ⬜ falta | Integración Nextcloud (interno) |
| Kasm Workspaces | — | ⬜ falta | Escritorios en navegador |
| Fedora 43 KDE Plasma | — | ⬜ falta | Escritorio soberano (VDI) |

## Fichas existentes ratificadas
_(ninguna todavía)_  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
