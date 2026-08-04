# Motor 1 — Conectividad de Agentes (Recibir-Agentes)
## Puerta 1: WebSocket mTLS banexus ↔ bhnexus

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Motor en MOTORES-INDEX:** `M-01`  
**Respalda:** `2.01_MANUAL-PUERTA-1-AGENTES.md` + `2.04_MANUAL-SAGAS-NEXUS.md`

---

## Responsabilidad del motor

El Motor de Conectividad de Agentes gestiona **todas las conexiones WebSocket mTLS** entre bhnexus y los nodos banexus distribuidos. Es la Puerta 1 del sistema.

**Verbo central:** `Recibir-Agentes` — acepta conexiones, autentica nodos, mantiene canales vivos.

## Qué hace

1. **Acepta** conexiones WebSocket en TCP 9444 (Puerta 1)
2. **Autentica** el nodo mediante SPIFFE ID en el certificado mTLS cliente
3. **Verifica** que el nodo está registrado en `idn_identity_entity` con estado ACTIVE
4. **Gestiona** el ciclo de vida de la conexión: CONNECTING → AUTHENTICATING → CONNECTED → RECONNECTING → CLOSED
5. **Recibe** heartbeats cada 30s y actualiza el estado del nodo
6. **Reenvía** policy_update cuando bAuth invalida el cache
7. **Detecta** nodos sin heartbeat >5min y emite `node_offline` al sub-canal B

## Lo que NO hace

- No decide si el nodo puede acceder a zonas (eso es bAuth)
- No almacena el policy cache del nodo (eso es el Motor de Cache)
- No procesa credenciales de hardware (eso es el Motor de Hardware)

## Parámetros de operación

| Parámetro | Valor |
|-----------|-------|
| Puerto | TCP 9444 |
| TLS mínimo | TLS 1.3 |
| Cipher | TLS_AES_256_GCM_SHA384 |
| Heartbeat timeout | 90s sin heartbeat → node_offline |
| Reconexión | 60s ventana para reconectar con mismo node_id |
| Max nodos concurrentes | 10,000 |

## Sagas relevantes

- **S-01**: Establecimiento de conexión mTLS (6 pasos, compensaciones por paso)
- **S-02**: Backoff exponencial de reconexión (1→5→15→30→60s)
- **S-03**: Push de policy update (6 pasos, ~72ms total de propagación)
- **S-04**: Recuperación offline (snapshot completo al reconectar con cache expirado)

---

*SKULL · SBOS · bNexus · MOTORES/motor-conectividad-agentes · v1.0.0 · Agosto 2026*
