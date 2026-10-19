# PROPOSITO — ModSecurity WAF (S16)

**Ficha:** `modsecurity` · **Servidor:** S16-webserver · **Versión:** 3.x + OWASP CRS 4.x
**Criticidad:** ALTA · **Namespace:** sbos-web · **Tipo:** módulo nginx (no pod separado)

## Qué es

Web Application Firewall (WAF) que protege el tráfico web público de los clientes
contra los ataques del OWASP Top-10 (SQLi, XSS, CSRF, path traversal, etc.).
Corre como módulo de nginx (S16) — no es un pod independiente sino una capa
de inspección dentro del mismo proceso.

## Por qué existe — diferencia con S02/modsecurity

El modsecurity de S02 (aún pendiente según PROPOSITO.md de S02) protege la
infraestructura interna de SBOS. El de S16 protege el **tráfico web público de cada
cliente** — el que entra desde internet por sus dominios personalizados. Son perfiles
de reglas distintos: S02 protege APIs JSON-RPC; S16 protege formularios web, uploads
de documentos, portales de cliente.

## Para qué sirve

- Inspecciona cada petición HTTP/HTTPS antes de llegar al website-engine
- Bloquea ataques OWASP Top-10: SQLi, XSS, RFI, LFI, CSRF, command injection
- Detecta y bloquea bots maliciosos y escaners automatizados
- Registra intentos de ataque con ctx_id para trazabilidad (ISO 27001 A.8.15)
- Permite excepciones por tenant cuando un flujo legítimo activa una regla (falso positivo)

## Perfil de reglas

| Conjunto | Nivel | Propósito |
|----------|-------|-----------|
| OWASP CRS 4.x (base) | Paranoia 2 | Protección estándar — balance seguridad/falsos positivos |
| Reglas SBOS custom | Complementario | Protección específica para formularios ERP y uploads de documentos |
| Exclusiones por tenant | Por ruta | Whitelisting de flujos legítimos que activan reglas del CRS |

## Quién la declara

`bos` (IAM Installer) la instala como módulo de nginx.
La configuración de exclusiones por tenant la gestiona `website-engine`.

## Dependencias

- `nginx` (S16) — es un módulo del mismo proceso, no un servicio separado

## Servidor y motivo

Vive en S16-webserver porque su objetivo es el tráfico web público de los clientes.
Las reglas son distintas a las de S02 (APIs internas) — tienen que vivir separadas.

## Cumplimiento normativo

| Norma | Cómo la cumple |
|-------|----------------|
| ISO 27001:2022 A.8.20 | Controles de red — inspección de tráfico entrante |
| OWASP Top-10 2021 | Cobertura completa con CRS 4.x |
| PCI DSS 4.0 req. 6.4 | WAF como control de seguridad para aplicaciones web |
