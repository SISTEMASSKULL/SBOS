# PROPOSITO.md — bnotify

## QUÉ es
Daemon host Rust/gRPC que implementa el sistema de **notificaciones soberanas SBOS**: Push MFA, alertas del sistema y mensajería bChat — sin dependencia de servicios externos (Firebase, Twilio, AWS SNS).

## POR QUÉ existe
El MFA push y las notificaciones de seguridad son parte crítica del flujo de autenticación de bauth. Si estas notificaciones dependen de servicios externos (Google FCM, Apple APNs), la soberanía se rompe: un corte de internet o una decisión de un tercero bloquea el acceso de todos los usuarios. bnotify resuelve esto entregando notificaciones directamente al cliente nativo o web sin ningún intermediario externo.

## PARA QUÉ sirve
- Entrega push MFA a la app desktop SBOS (banexus como transport)
- Emite alertas del sistema (vencimiento de tokens, detección de anomalías)
- Provee la capa de transporte de bChat (mensajería interna soberana)
- Expone métodos gRPC sobre Unix socket `/run/bos/bnotify.sock`
- Provee a: bauth (MFA challenges), dashboard desktop, bChat clients

## QUIÉN la declara / usa
- **Declara:** bnotify-developer (BnotifyAgent/)
- **Instala:** bos (IAM Installer)
- **Consume:** bauth (push MFA), clientes desktop SBOS (bChat), monitoring

## DEPENDENCIAS
| Dependencia | Motivo |
|-------------|--------|
| postgresql | Persistencia de subscripciones y canales de notificación |
| redis | Cola de mensajes pendientes y pub/sub de tiempo real |
| bauth | Validación de identidad del receptor antes de entregar push |

## SERVIDOR y MOTIVO
**S03-identityserver** — bnotify es parte del plano de identidad: el push MFA es inseparable del flujo de autenticación. Vive en el mismo servidor que bauth y Keycloak para minimizar la latencia en el camino crítico de autenticación y compartir la red de identidad. Como daemon systemd (no K8s pod), opera con latencia mínima sobre Unix socket.
