# S16-webserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Puertos: `SBOS-050-PORT-CATALOG`.

## Qué es

Plataforma web pública multi-tenant: sirve los sitios web, portales y aplicaciones
web de cada cliente/tenant del ecosistema SBOS, con dominios propios, TLS por dominio
y renderizado dinámico por empresa, sucursal o configuración regional.

## Por qué existe — diferencia con S02-gatewayserver

S02 es la puerta de la **infraestructura interna** de SBOS: enruta tráfico hacia Kong,
Vault, daemons internos. Es la capa de seguridad del sistema operativo.

S16 es la puerta del **producto visible para el usuario final**: sirve las webs públicas
de los tenants, gestiona dominios personalizados, certificados por cliente y renderizado
por marca. Son instancias separadas con responsabilidades distintas.

## Criticidad

**ALTA** — es el único punto de contacto web del cliente con el sistema.
Sin S16 no hay portal web, no hay acceso al dashboard, no hay dominio propio.

## Unidad de migración

Al crecer, `S16-webserver/` se lleva entero a un VPS dedicado (`tipo=webserver`).
Todos sus certificados, configuraciones de dominio y el motor de renderizado migran
como bloque. Las bases de datos que necesita (configuración de tenant, plantillas)
permanecen en S01-dataserver.

## Aplicaciones

| App | Propósito | Estado |
|-----|-----------|:------:|
| `nginx` | Reverse proxy + TLS termination + wildcard/custom domains por tenant | 🆕 declarada |
| `certbot` | Certificados SSL por dominio (Let's Encrypt) — un cert por dominio de cliente | 🆕 declarada |
| `modsecurity` | WAF (Web Application Firewall) — protección OWASP Top-10 para tráfico web público | 🆕 declarada |
| `weblate` | Plataforma web de gestión de traducciones — **pod K8s**, herramienta de apoyo a `bi18nd` (no el daemon). Edición web de FTL/TOML. Requiere PostgreSQL + Redis en S01. | 🆕 declarada |

## Relación con otros servidores

| Servidor | Relación |
|----------|----------|
| S01-dataserver | Configuración de tenants, plantillas web, rutas de dominio |
| S02-gatewayserver | S16 delega autenticación a Kong (S02) — no valida tokens por sí mismo |
| S03-identityserver | El usuario autenticado en S16 tiene su sesión gestionada por bAuth (S03) |
| S06-appsserver | S16 puede servir como capa de presentación para apps internas de S06 |
| S10-commsserver | El motor de correo de notificaciones (S10) puede incluir URLs de S16 |

## Fichas declaradas

`nginx` · `certbot` · `modsecurity` · `weblate`

Las completa el daemon responsable bajo `servers.yml`
(manifest.yml + task_catalog.sh + resources/ + PROPOSITO.md propio).
