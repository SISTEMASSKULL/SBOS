# bNexus Host — PROPÓSITO

> Ficha declarativa del daemon bNexus Host.
> Servidor lógico: `S02-gatewayserver` · `execution_order: 148`
> BC-10 (PLAN-IMPLEMENTACION-BOS-VDI.md)

## Qué es

**bNexus Host** (`bhnexus`) es el proxy de hardware universal de SBOS.
Actúa como puerta de entrada TLS mutual para todos los clientes de hardware:
chapas NFC, lectores biométricos, estaciones VDI y el cliente Flutter desktop.

Escucha en `:9444` y autentica cada conexión contra bAuth via JWKS
(`/tmp/bauth/bauth.sock`), reencaminando las solicitudes autenticadas al
bus de eventos interno.

## Tipo de despliegue

`SystemdService` en el **host** — binario Rust estático de ~1.8 MB.
Expone también un socket Unix `/run/bos/bhnexus.sock` para control interno.

## Dependencias

| Dependencia | Para qué |
|-------------|---------|
| `bauth` | JWKS para validar tokens de clientes hardware |
| `kong` | Proxy inverso público — expone `:9444` al exterior |
| `vault` | Certificados TLS de la CA interna |

## Puertos

| Puerto | Protocolo | Uso |
|--------|-----------|-----|
| `:9444` | TCP/TLS mutual | Clientes banexus, Flutter desktop |
| `/run/bos/bhnexus.sock` | Unix | Control BOS/bosctl |

## Criterio de salud

```bash
systemctl is-active bhnexus.service && test -S /run/bos/bhnexus.sock
```
