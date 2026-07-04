# S13-geoserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
Presencia física: GPS, logística, señalética, colas, tarjetas.

## Criticidad
**MEDIA**

## Unidad de migración
Al crecer, `S13-geoserver/` se lleva entero a un VPS dedicado (`tipo=geoserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: assettracking + logisticsserver + signageserver + queueserver + vcardserver (BASE 8850).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| Traccar Web | 8082→8850 | ⬜ falta | Geolocalización GPS (panel) |
| Traccar OsmAnd | 5055→8855 | ⬜ falta | Protocolo apps móviles GPS |
| Fleetbase | 8080→8860 | ⬜ falta | Gestión logística / despacho |
| Xibo CMS | 80→8870 | ⬜ falta | Señalética digital |
| Novo SGA | 8080→8880 | ⬜ falta | Colas de atención |
| CardMesh | 3000→8890 | ⬜ falta | Tarjetas digitales NFC/QR |

## Fichas existentes ratificadas
_(ninguna todavía)_  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
