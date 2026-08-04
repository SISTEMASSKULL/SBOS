# VISION — SBOS Nexus Agent (banexus)

## Proposito Fundamental

banexus es el **Edge Sentinel** del ecosistema SBOS. Se ejecuta en cada estacion de trabajo (Fedora) como systemd --user, intercepta eventos fisicos de hardware (QR, NFC, huella, tarjeta) y comandos de shell sensibles, y coordina con bhnexus la autorizacion en tiempo real.

Actua como el **punto de presencia fisico** de SBOS en cada estacion de trabajo.

## Que es banexus

- Un interceptor de inputs fisicos via udev + libusb que captura datos de dispositivos USB (QR, NFC, barcode) ANTES de que evdev genere eventos de teclado
- Un Shell Sentinel via modulo PAM que intercepta comandos sensibles (sudo, apt-get, rm -rf, systemctl)
- Un gestor de cache local con AES-256-GCM para operacion offline fail-secure
- Un ejecutor de comandos de actuadores (cerraduras, cajones, reles) via puerto serial
- Un cliente WebSocket mTLS que mantiene conexion permanente con bhnexus

## Que hace permanentemente

1. Captura datos de lectores USB (QR, NFC, barcode) en crudo antes del sistema operativo
2. Envia auth_requests firmados a bhnexus via WebSocket
3. Intercepta comandos shell sensibles via PAM y consulta autorizacion
4. Mantiene policy cache local cifrado con AES-256-GCM para modo offline
5. Ejecuta actuator_commands recibidos de bhnexus (apertura de cerraduras, reles)
6. Envia heartbeats periodicos a bhnexus con estado de sesiones activas
7. Gestiona reconexion con backoff exponencial cuando pierde conexion
8. Opera en modo fail-secure: sin conexion, toda decision no cacheada es DENY

## Que NO hace

- No almacena biometria de forma permanente
- No evalua autorizaciones (eso lo hace bhnexus + bauth)
- No expone puertos de red (solo conexion saliente WebSocket)
- No ejecuta logica de negocio
- No permite fail-open en ninguna circunstancia

## Posicionamiento en el Ecosistema

| Componente | Rol |
|---|---|
| banexus | Edge Sentinel, presencia fisica en cada estacion |
| bhnexus | Connectivity broker, proxy de hardware universal |
| bauth | Identity evaluator, decide la BitMask |
| bos | Control plane, despliega configuracion |
| bkernel | Data plane, registra eventos de auditoria |

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS1, SS5-6, V5-SS3, V7-SS5, V7-SS7_
