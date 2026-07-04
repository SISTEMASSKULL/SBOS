# S02-gatewayserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
Seguridad perimetral: único punto de entrada externo + API Gateway + secretos.

## Criticidad
**MÁXIMA**

## Unidad de migración
Al crecer, `S02-gatewayserver/` se lleva entero a un VPS dedicado (`tipo=gatewayserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: proxyserver + apigateway + secretsvault (BASE 8150).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| NGINX HTTP | 80→8150 | ✅ existe | Reverse proxy — LoadBalancer 80 |
| NGINX HTTPS | 443→8151 | ✅ existe | TLS — LoadBalancer 443 |
| Kong Proxy | 8000→8160 | ✅ existe | API Gateway (HTTP) |
| Kong Proxy TLS | 8443→8161 | ✅ existe | API Gateway (HTTPS) |
| Kong Admin | 8001→8164 | ✅ existe | Admin API Kong (nunca externo) |
| Vault API | 8200→8170 | ✅ existe | Secretos dinámicos + PKI — RATIFICADO, no se mueve |
| Vault Cluster | 8201→8177 | ✅ existe | Raft cluster Vault |
| OAuth2-Proxy | 4180→8180 | ✅ existe | Puente auth para apps sin OIDC |
| Certbot | — | ✅ existe | Certificados SSL automáticos (sin puerto propio) |
| besu-qbft | — | ✅ existe | (ratificada — la reubica su daemon si procede) |
| ModSecurity + OWASP CRS | 80/443 | ⬜ falta | WAF Top-10 OWASP |
| Rate Limiting / DDoS | 80/443 | ⬜ falta | Control de tasa y mitigación DoS |

## Fichas existentes ratificadas
`NGINX HTTP`, `NGINX HTTPS`, `Kong Proxy`, `Kong Proxy TLS`, `Kong Admin`, `Vault API`, `Vault Cluster`, `OAuth2-Proxy`, `Certbot`, `besu-qbft`  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
