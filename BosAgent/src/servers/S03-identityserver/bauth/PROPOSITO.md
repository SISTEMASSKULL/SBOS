# bAuth — PROPÓSITO

> Ficha declarativa del daemon soberano de identidad SBOS.
> Servidor lógico: `S03-identityserver` · `execution_order: 148`
> Norma: `servers/servers.yml` · BC-09 (PLAN-IMPLEMENTACION-BOS-VDI.md)

## Qué es

**bAuth** es el orquestador central de identidad del ecosistema SBOS.
Implementa el modelo **BitMask 64-bit** — cada permiso atómico ocupa 1 bit —
y emite un **token unificado** que Kong, los daemons y las apps consumen
sin depender de Keycloak como PDP en runtime.

Keycloak sigue siendo el IdP para autenticación inicial (OIDC/SAML);
bAuth toma el relevo para autorización granular y contexto de sesión (SBOS-049).

## Tipo de despliegue

`SystemdService` en el **host** (no en K8s).
El binario estático Go/Rust se instala en `/usr/local/bin/bauth`.
Escucha en Unix socket `/tmp/bauth/bauth.sock` (grupo bosagent).

## Dependencias

| Dependencia | Para qué |
|-------------|---------|
| `postgresql` | Schema `bauth` en SBOSDB — fuente de verdad de identidad |
| `keycloak` | IdP externo para flujo de autenticación inicial |
| `vault` | Secretos (JWT signing key, credenciales BD) |
| `kong` | Plugin PEP — valida BitMask en cada request |

## Puerto / socket

| Recurso | Valor |
|---------|-------|
| Socket Unix | `/tmp/bauth/bauth.sock` |
| Protocolo | JSON-RPC 2.0 |
| Grupo | `bosagent` (permisos 0660) |

## Criterio de salud

```bash
systemctl is-active bauth.service && test -S /tmp/bauth/bauth.sock
```

## Notas

- El binario se distribuye via SKULL Release Plane (firma Ed25519).
- La configuración vive en `/etc/bos/bauth.toml` (generada por BOS en instalación).
- No hay puertos TCP externos — solo socket Unix (SBOS-050 P9).
