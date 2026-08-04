# SEGURIDAD — SBOS Nexus Agent (banexus)

## Modelo de Seguridad

### Captura Antes del SO

banexus usa libusb para capturar datos de dispositivos USB **antes** de que evdev genere eventos de teclado.

**Proteccion:** Evita inyeccion de eventos maliciosos via /dev/input/*. Un keylogger a nivel de SO no puede interceptar los datos del lector porque banexus los captura en crudo desde el dispositivo USB.

### mTLS Obligatorio

Toda comunicacion con bhnexus via WebSocket requiere:

- Certificado TLS valido
- Node-ID registrado
- Version compatible

Sin mTLS -> no hay conexion -> no hay operacion.

### HMAC en Payload

Cada auth_request incluye firma HMAC-SHA256 del payload para garantizar integridad y autenticidad. bhnexus verifica la firma antes de procesar.

### Cache Cifrado AES-256-GCM

El policy cache local esta cifrado con AES-256-GCM. La clave se deriva del certificado mTLS del agente via HKDF. Sin el certificado original, el cache es ilegible.

### Fail-Secure (Nunca Fail-Open)

| Condicion | Comportamiento |
|---|---|
| Cache HIT + TTL valido | GRANTED |
| Cache MISS + conectado | Consulta bhnexus |
| Cache MISS + desconectado | DENIED |
| Cache HIT + TTL expirado | DENIED |
| bhnexus no responde | DENIED (excepto Shell Sentinel) |

**Unica excepcion:** Shell Sentinel timeout -> PAM_SUCCESS para no bloquear terminal del usuario. Pero el resultado se cachea localmente y la decision final se registra para auditoria.

### Shell Sentinel (PAM)

```bash
# /etc/pam.d/sudo
auth       requisite    pam_banexus.so
```

- Comandos sensibles interceptados: apt-get, dnf, systemctl, rm -rf, sudo, passwd
- Si PAM module no responde -> timeout -> PAM_SUCCESS (fail-open controlado)
- El resultado se evalua contra cache local antes de permitir
- Todos los intentos se registran en audit.log

### Seguridad Offline

```
1. Sin conexion -> disconnected state
2. Cache local con TTL maximo 4h
3. TTL por entrada: max 30s (lo que restaba del original)
4. Cache miss -> DENIED
5. Reconexion -> invalidar cache, recibir resumen offline
6. No se re-evaluan decisiones offline (ya fueron fail-secure)
```

### 8 Alertas Wazuh Relacionadas

| Regla | Descripcion | Severidad |
|---|---|---|
| NEXUS-001 | Multiples denied desde mismo agente | Alta |
| NEXUS-002 | Conexion perdida > 30 min | Media |
| NEXUS-005 | Offline fail-secure activo para zona critica | Critica |
| NEXUS-007 | Heartbeat con anomalias | Media |
| NEXUS-008 | Actuador ejecutado sin auth_request previo | Critica |

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS5-6, V5-SS3, V7-SS5-6_
