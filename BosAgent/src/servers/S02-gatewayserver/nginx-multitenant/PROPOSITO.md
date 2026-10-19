# PROPOSITO — NGINX Web Server (S16)

**Ficha:** `nginx` · **Servidor:** S16-webserver · **Versión:** 1.26+
**Criticidad:** ALTA · **Namespace:** sbos-web · **Tipo:** Deployment

## Qué es

Reverse proxy + servidor web + TLS termination para la plataforma web pública
multi-tenant de SBOS. Sirve dominios personalizados por cliente (ej. `erp.miempresa.com`,
`portal.clinica.bo`) con certificados individuales gestionados por certbot.

## Por qué existe — diferencia con S02/nginx

El nginx de S02 enruta tráfico **interno** hacia Kong, Vault y los daemons de SBOS.
Este nginx en S16 enruta tráfico **externo de cliente final** hacia el website-engine
y las apps de negocio. Son instancias separadas con configuraciones distintas:

| | S02/nginx | S16/nginx |
|---|---|---|
| Tráfico | Infraestructura interna SBOS | Web pública de clientes/tenants |
| Dominios | `sbos.internal`, `api.empresa.com` | `erp.miempresa.com`, `portal.clinica.bo` |
| Upstream | Kong, daemons Unix socket | website-engine, apps S06 |
| Cert por dominio | Wildcard *.sbos | Un cert por dominio de cliente |

## Para qué sirve

- Recibe peticiones HTTPS de cada dominio de cliente
- Termina TLS con el certificado correspondiente (gestionado por certbot)
- Enruta al website-engine según el `Host:` header (multi-tenant por virtual host)
- Aplica rate limiting, headers de seguridad (HSTS, CSP, X-Frame-Options)
- Pasa tráfico de autenticación a Kong/S02 para validación de tokens

## Quién la declara

`bos` (IAM Installer) la instala. La configuración de virtual hosts por tenant
la genera `website-engine` al aprovisionar un nuevo cliente.

## Dependencias

- `certbot` (S16) — provee los certificados TLS por dominio
- `modsecurity` (S16) — módulo WAF cargado en este mismo proceso nginx
- `website-engine` (S16) — upstream principal
- `kong` (S02) — upstream de autenticación

## Servidor y motivo

Vive en S16-webserver porque su función es servir la web pública del cliente.
No pertenece a S02 (gateway interno) ni a S06 (apps de negocio).
