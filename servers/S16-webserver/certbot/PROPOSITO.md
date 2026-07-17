# PROPOSITO — Certbot (S16)

**Ficha:** `certbot` · **Servidor:** S16-webserver · **Versión:** 2.x (ACME v2)
**Criticidad:** ALTA · **Namespace:** sbos-web · **Tipo:** CronJob

## Qué es

Gestor automático de certificados SSL/TLS por dominio personalizado de cliente,
usando Let's Encrypt (ACME v2). Emite y renueva un certificado individual por cada
dominio de tenant registrado en SBOS.

## Por qué existe — diferencia con S02/certbot

El certbot de S02 gestiona certificados de la **infraestructura interna** de SBOS
(wildcard `*.sbos.internal`, dominio del API gateway). Este certbot en S16 gestiona
los **dominios personalizados de cada cliente** (ej. `erp.miempresa.com`) — uno por uno,
con ciclo de vida independiente por tenant.

## Para qué sirve

- Emite certificados Let's Encrypt al aprovisionar un nuevo dominio de cliente
- Renueva automáticamente (cron) antes del vencimiento (90 días Let's Encrypt)
- Notifica a nginx (S16) cuando un certificado se renueva (reload sin downtime)
- Si el dominio usa DNS personalizado, gestiona el challenge DNS-01 o HTTP-01

## Flujo de aprovisionamiento de un nuevo cliente

```
1. Administrador SBOS registra el dominio del cliente en website-engine
2. website-engine llama a certbot: emitir cert para "erp.miempresa.com"
3. certbot ejecuta challenge HTTP-01 (nginx sirve el archivo de validación)
4. Let's Encrypt valida → certbot recibe y almacena el certificado
5. certbot notifica a nginx → nginx recarga la configuración TLS
6. El dominio del cliente ya sirve HTTPS en segundos
```

## Quién la declara

`bos` (IAM Installer) la instala como CronJob de K8s.
`website-engine` la invoca al registrar o eliminar un dominio de cliente.

## Dependencias

- `nginx` (S16) — necesita que nginx esté levantado para el challenge HTTP-01
- `website-engine` (S16) — dispara la emisión al registrar un nuevo tenant/dominio

## Servidor y motivo

Vive en S16-webserver porque gestiona los certificados de los dominios públicos
de los clientes, no los de la infraestructura interna. Un certificado de cliente
no tiene por qué existir en el gateway interno (S02).
