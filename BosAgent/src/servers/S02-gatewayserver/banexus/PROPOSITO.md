# bNexus Agent — PROPÓSITO

> Ficha declarativa del daemon bNexus Agent.
> Servidor lógico: `S02-gatewayserver` · `execution_order: 149`
> BC-10 (PLAN-IMPLEMENTACION-BOS-VDI.md)

## Qué es

**bNexus Agent** (`banexus`) es el daemon centinela que corre en cada nodo edge
(VPS, estación corporativa, chapa física) y se conecta al bNexus Host (`bhnexus`)
via TLS mutual en `127.0.0.1:9444`.

Reporta el estado del hardware local — lectores NFC, biométricos, estado de red —
y recibe comandos de apertura/cierre de chapas desde el bus de identidad.

## Tipo de despliegue

`SystemdService` en el **host** — binario Rust estático de ~1.2 MB.
Depende de `bhnexus.service` (`Requires` en el unit): si bhnexus cae, banexus se detiene.

## Dependencias

| Dependencia | Para qué |
|-------------|---------|
| `bhnexus` | Conexión TLS mutual — canal de comunicación con el hub |

## Puertos

| Puerto | Protocolo | Uso |
|--------|-----------|-----|
| `127.0.0.1:9446` | TCP | Puerto local del agente (solo localhost) |

## Criterio de salud

```bash
systemctl is-active banexus.service
```

## Notas

- El certificado de cliente TLS se genera automáticamente en la instalación,
  firmado por la CA de bhnexus (`/etc/bhnexus/dev/ca.crt`).
- `node_id` se deriva de `hostname + machine-id` — único por nodo.
- En producción los certs vienen de Vault vía `BANEXUS_CLIENT_CERT` / `BANEXUS_CLIENT_KEY`.
