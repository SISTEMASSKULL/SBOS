# Mapa de Integracion

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-008-INTEGRATION (v6), SBOS-BAUTH-CONCEPTUALIZACION-v5_0 (bauth), SBOS-002-ARCH (v6)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## Bus de eventos -- WAL de PostgreSQL

El SBOS NO usa Kafka, RabbitMQ, Redis Streams ni n8n. El Write-Ahead Log (WAL) de PostgreSQL es el bus de eventos nativo.

| Propiedad | PostgreSQL WAL |
|---|---|
| Cero invasion a las apps | Si -- apps solo escriben en su BD, WAL hace el resto |
| Ordering estricto | Si (LSN) |
| Durabilidad nativa | Si (WAL es la base de PG) |
| Infraestructura adicional | Ninguna |
| CDC nativo | pgoutput |

### 3 Replication Slots WAL
| Slot | Daemon | Escucha |
|---|---|---|
| bkernel_slot | bKernel | Cambios en TODAS las apps del stack |
| biedata_slot | biedata | Triggers de integracion con exterior |
| bcompass_slot | bCompass | Eventos para analisis de inteligencia |

## Integracion de identidad (PRECEDENCIA BAUTH)

bAuth opera como el **unico punto de integracion de identidad**:

```
Core UI (PAP) → bAuth REST API → RolTemplate → PrivilegeEngine → BitmaskBundle
  → KC Admin API: Composite Roles, Auth Flows, SPIs
  → Tryton XML-RPC: ir.model.access, ir.rule, ir.model.button, ir.action.groups
  → bhnexus Unix socket: policy_update push
```

### Triangulo KC -- bAuth -- Tryton
KC sincroniza RolTemplate a objetos nativos ANTES del login. En login time, KC solo lee su base de datos interna -- sin depender de bAuth. Patron PAP/PIP/PDP/PEP completo.

## APIs externas consumidas

| Servicio | Proposito | Autenticacion |
|---|---|---|
| SIN Bolivia (SIAT) | Facturacion electronica | Certificado digital (biedata) |
| AFIP Argentina | Facturacion electronica | Certificado digital (biedata) |
| SAT Mexico (CFDI 4.0) | Facturacion electronica | Certificado digital (biedata) |
| Anthropic Messages API | IA (Claude) | ANTHROPIC_API_KEY |
| DeepSeek Anthropic API | IA (DeepSeek) | DEEPSEEK_API_KEY |

## Contratos de integracion entre daemons

| Origen | Destino | Protocolo | Autenticacion |
|---|---|---|---|
| banexus | bhnexus | WebSocket mTLS | Certificados cliente |
| bhnexus | bAuth | Unix socket /run/bos/bauth.sock | Grupo bos, permisos 0660 |
| bAuth | Keycloak | HTTPS REST (Admin API) | JWT client_credentials |
| bAuth | Tryton | XML-RPC HTTP | Usuario/password interno |
| bAuth | Redis | TCP con password | Password desde Vault |
| bKernel | PostgreSQL | WAL (pgoutput) | Autenticacion BD |
| bCompass | Ollama | HTTP REST (localhost) | Red local |

## Fronteras invariantes
| Frontera | Propiedad protegida |
|---|---|
| sbos_k8s_core() es el unico kubectl apply | Trazabilidad |
| bKernel NO ejecuta DDL en BDs de apps | Cero invasion |
| Fichas no se llaman entre si | Desacoplamiento |
| IAM Installer NO es pod K8s | Independencia |
| biedata es el UNICO con acceso a red exterior | Control exfiltracion |
| bCompass es el UNICO que invoca Ollama | Trazabilidad LLM |
| banexus → bhnexus → bAuth (nunca salto) | Invariante NEXUS |
