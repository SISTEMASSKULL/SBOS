# PROPOSITO.md — biedata

## QUÉ es
Daemon host que implementa el **Orquestador JSON-RPC 2.0** del ecosistema SBOS — la "aduana de datos" soberana que unifica el acceso a todos los servicios del sistema bajo un protocolo único.

## POR QUÉ existe
El ecosistema SBOS tiene múltiples daemons (bauth, bkernel, bsearch, bnotify) con APIs propias. Sin biedata, cada cliente externo (frontend, agente IA, integración ERP) tendría que conocer y mantener conexiones individuales a cada daemon. biedata centraliza esta complejidad: un único socket JSON-RPC 2.0, un único protocolo, cero acoplamiento directo entre consumidores y productores.

## PARA QUÉ sirve
- Expone métodos `biedata.*` sobre Unix socket `/run/bos/biedata.sock`
- Enruta solicitudes al daemon correcto del ecosistema SBOS
- Aplica políticas de autorización (vía bauth) antes de despachar
- Normaliza respuestas en formato JSON-RPC 2.0 uniforme
- Provee a: agentes IA, bCompass, bos (IAM Installer), integraciones externas

## QUIÉN la declara / usa
- **Declara:** biedata-developer (BiedataAgent/)
- **Instala:** bos (IAM Installer)
- **Consume:** bCompass, agentes IA, dashboard frontend, ERP (Tryton)

## DEPENDENCIAS
| Dependencia | Motivo |
|-------------|--------|
| postgresql | Persistencia de estado de orquestación |
| redis | Cache de respuestas y rate limiting |
| bauth | Validación de tokens y autorización de métodos |
| bkernel | Fuente de eventos CDC para enrutamiento reactivo |

## SERVIDOR y MOTIVO
**S00-hostserver** — es un daemon del plano de control soberano del host. Como bos y bkernel, no es una app K8s sino un proceso systemd que corre directamente en el host para tener acceso nativo a todos los sockets Unix del ecosistema (ADR-022, SBOS-050 P9).
