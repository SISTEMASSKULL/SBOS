# S14-opsserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
CI/CD y backup/DR. Se configura al final (necesita todo el stack).

## Criticidad
**ALTA**

## Unidad de migración
Al crecer, `S14-opsserver/` se lleva entero a un VPS dedicado (`tipo=opsserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: cicdserver + backupserver (BASE 8900).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| GitLab HTTP | 80→8900 | ⬜ falta | Código + CI/CD |
| GitLab Registry | 5050→8904 | ⬜ falta | Registro OCI |
| GitLab SSH | 22→NodePort 2222 | ⬜ falta | Git over SSH |
| Bareos Director | 9101→8910 | ⬜ falta | Orquestador de backup |
| Bareos Storage | 9103→8913 | ⬜ falta | Almacenamiento de backup |
| Bareos WebUI | 9100→8914 | ⬜ falta | Panel Bareos |
| SearXNG | 8080→8920 | ⬜ falta | Metabuscador soberano |
| Trivy | 4954→8930 | ⬜ falta | Escaneo de imágenes |
| Velero / pgBackRest / K6 / Goss | — | ⬜ falta | DR y validación (sin puerto de servicio) |

## Fichas existentes ratificadas
_(ninguna todavía)_  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
