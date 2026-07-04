# PROPOSITO — besu-qbft

**Ficha:** `besu-qbft` - **Servidor:** S02-gatewayserver - **Version:** 24.12.0
**Criticidad:** True - **Namespace:** - - **Tipo:** pod
**Orden de instalacion:** 135

## Que es
Hyperledger Besu 24.12.0 — Red blockchain soberana QBFT (Proof of Authority) 1 validador. SettlementEngine.sol + AuditAnchor.sol. RPC :8545, WS :8546, P2P :30303. Chain ID 1337. Consumido por bAuth D12.

## Dependencias
postgresql, vault

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
