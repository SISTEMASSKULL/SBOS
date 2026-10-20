# S04-erpserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
Motor ERP — Tryton, fuente de verdad de negocio. Nodo aislado.

## Criticidad
**MÁXIMA**

## Unidad de migración
Al crecer, `S04-erpserver/` se lleva entero a un VPS dedicado (`tipo=erpserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: appserver-Tryton (BASE 8250).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| Tryton ERP | 8000→8250 | ⚠️ revisar | Núcleo ERP. HOY ficha 'tryton' en S01; su daemon ratifica/reubica |
| RabbitMQ AMQP | 5672→8260 | ⬜ falta | Mensajería Tryton↔apps |
| RabbitMQ TLS | 5671→8261 | ⬜ falta | AMQP sobre TLS |
| RabbitMQ Management | 15672→8264 | ⬜ falta | Admin RabbitMQ |

## Fichas existentes ratificadas
`Tryton ERP`  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
