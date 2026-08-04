# SEGURIDAD — SBOS Nexus Host (bhnexus)

## Modelo de Seguridad

### mTLS Obligatorio

Toda conexion WebSocket entre banexus y bhnexus requiere:

- Certificado TLS valido (no expirado, firma OK)
- Node-ID registrado en devices registry
- Version del agente compatible (major version match)
- Certificado revocado? -> conexion rechazada + evento Wazuh NEXUS-003

Si FAIL -> 403 Forbidden + log de auditoria.

### Auth Cache Efimero

- BitMasks almacenadas con TTL maximo 30s
- Cache en memoria volatil (no persiste en disco)
- Eviccion LRU sin filtrado de datos sensibles
- Cache miss + bauth no disponible -> DENY (fail-secure)

### Sin Almacenamiento de Biometria

bhnexus NO almacena:

- Huellas dactilares
- Rostros (face)
- Patrones de voz
- Ningun dato biometrico permanente
Las credenciales biometricas se evaluan en el momento y se descartan.

### Seguridad por Capas

| Capa | Proteccion |
|---|---|
| mTLS | Autenticacion mutua dispositivo-servidor |
| Auth Cache | Cache volatil con TTL, sin persistencia |
| bauth Unix socket | Socket local, no expuesto a red |
| BitMask | Evaluacion triple (fisico+logico+financiero) |
| Policy Cache Efimero | AES-256-GCM en agentes offline |
| Wazuh | 8 reglas de deteccion de anomalias |

### Reglas Wazuh para Eventos NEXUS

| Regla | Descripcion | Severidad |
|---|---|---|
| NEXUS-001 | Multiples denied desde mismo agente (rate > 10/min) | Alta |
| NEXUS-002 | Conexion agente perdida > 30 min | Media |
| NEXUS-003 | Intento de auth con certificado invalido | Alta |
| NEXUS-004 | Error de hardware persistente (> 5 en 5 min) | Alta |
| NEXUS-005 | Offline fail-secure activo para zona critica | Critica |
| NEXUS-006 | Version de agente desactualizada | Baja |
| NEXUS-007 | Heartbeat con anomalias (uptime reiniciado sospechosamente) | Media |
| NEXUS-008 | Actuador ejecutado sin auth_request previo | Critica |

### Offline Fail-Secure

Cuando un agente pierde conexion con bhnexus:

1. Deteccion: No recibe PONG en 30s -> disconnected state
2. Cache local del agente con AES-256-GCM (TTL max 4h configurable)
3. TTL de cada BitMask: lo que restaba del original (max 30s)
4. Cache miss OR TTL expirado -> DENIED (fail-secure)
5. Nunca existe "fail-open" en NEXUS
6. Reconexion -> invalidar cache local, recibir resumen offline

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS3, V5-SS2, V7-SS5-6_
