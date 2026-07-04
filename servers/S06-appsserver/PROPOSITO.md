# S06-appsserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
Apps de negocio open source: e-commerce, RRHH, CRM, proyectos, helpdesk.

## Criticidad
**ALTA**

## Unidad de migración
Al crecer, `S06-appsserver/` se lleva entero a un VPS dedicado (`tipo=appsserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: appserver-apps + projectserver + helpdeskserver (BASE 8400).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| Saleor | 8000→8400 | ⬜ falta | E-commerce |
| OrangeHRM | 80→8410 | ⬜ falta | Recursos humanos |
| EspoCRM | 80→8420 | ⬜ falta | CRM |
| Zammad | 3000→8430 | ⬜ falta | Help desk |
| Wiki.js | 3000→8440 | ⬜ falta | Base de conocimiento |
| Taiga | 9000→8450 | ⬜ falta | Gestión ágil de proyectos |
| OpenProject | 8080→8460 | ⬜ falta | Gestión de proyectos |
| Cal.com | 3000→8470 | ✅ existe | Agendamiento (ficha 'calcom') |
| LimeSurvey | 80→8480 | ⬜ falta | Encuestas |
| Vaultwarden | 80→8490 | ⬜ falta | Gestor de contraseñas |
| Authelia | 9091→8491 | ⬜ falta | MFA / portal auth |
| TastyIgniter | 80→8492 | ⬜ falta | Restaurantes |
| GNU Health | 8000→8493 | ⬜ falta | Salud (criticality:false) |
| Directus | 8055→8494 | ⬜ falta | Headless CMS/API |
| sbos-notifier | — | ✅ existe | Notificaciones (daemon bnotify) |
| novu | — | ✅ existe | Motor de notificaciones (bnotify) |
| ferretdb | — | ✅ existe | Compat MongoDB para notificaciones (bnotify) |
| mattermost | 8065 | ⚠️ revisar | HOY también en S10; su daemon dedup/ratifica |

## Fichas existentes ratificadas
`Cal.com`, `sbos-notifier`, `novu`, `ferretdb`, `mattermost`  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
