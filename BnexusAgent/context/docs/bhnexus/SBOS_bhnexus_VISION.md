# VISION — SBOS Nexus Host (bhnexus)

## Proposito Fundamental

bhnexus es el **Proxy de Hardware Universal** del ecosistema SBOS. Traduce eventos fisicos (QR, NFC, huella, tarjeta) en consultas de autorizacion y ejecuta comandos de actuadores (cerraduras, reles, alarmas) en tiempo real.

Actua como el **punto de conectividad** entre el mundo fisico y el plano de identidad digital de SBOS.

## Que es bhnexus

- Un broker central WebSocket que gestiona 10,000+ conexiones concurrentes con agentes banexus
- Un Hardware Bridge que normaliza 6 protocolos fisicos (OSDP, MQTT, ONVIF, Wiegand, USB HID, HTTP)
- Un Auth Cache que almacena BitMasks en memoria con TTL 30s para respuesta sub-5ms
- Un gestor de Device Fichas YAML que declaran dispositivos, protocolos y actuadores
- Un implementador de la HAL (Hardware Abstraction Layer) para drivers de dispositivo

## Que hace permanentemente

1. Mantiene conexiones WebSocket mTLS con todos los agentes banexus del ecosistema
2. Recibe auth_requests de agentes y los resuelve contra bauth (o cache)
3. Normaliza eventos de hardware en formato CredentialEvent estandar
4. Gestiona cache de BitMasks con TTL configurable y politica LRU
5. Envia policy_updates a agentes cuando cambian roles o permisos
6. Monitorea salud de dispositivos fisicos via health checks periodicos
7. Expone metricas Prometheus detalladas en puerto 9445
8. Mantiene el mapa de agentes con sus estados (connected/disconnected/suspended/terminated)

## Que NO hace

- No ejecuta logica de negocio
- No almacena biometria de forma permanente
- No realiza autenticacion primaria (eso es Keycloak via bauth)
- No gestiona sesiones de usuario
- No expone API REST publica (solo WebSocket mTLS + metricas)

## Posicionamiento entre los 8 Daemons Soberanos

| Daemon | Rol |
|---|---|
| bos | Control plane - crea device fichas, recibe health |
| bkernel | Data plane - lee audit_events desde WAL |
| bauth | Identity plane - evalua BitMask via Unix socket |
| banexus | Edge plane - agente cliente que conecta a bhnexus |
| **bhnexus** | **Connectivity plane - broker central de todos los agentes** |
| bsearch | Search plane - indexa eventos de autenticacion |

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS1-2, V5-SS1, V7-SS7_
