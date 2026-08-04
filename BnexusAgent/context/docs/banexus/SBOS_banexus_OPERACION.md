# OPERACION — SBOS Nexus Agent (banexus)

## SLOs

| Operacion | SLO | Notas |
|---|---|---|
| Captura QR/NFC via libusb | < 1ms | Desde que lector recibe dato |
| Auth request a bhnexus | < 2ms | Firma HMAC + envio WebSocket |
| Ejecucion de actuador (rele) | < 2ms | Apertura via puerto serial |
| Cache hit local (offline) | < 1ms | Busqueda en SQLite cifrado |
| Heartbeat | Cada 15s | Ping/Pong con bhnexus |
| Reconexion backoff | 1s->5s->15s->30s->60s | Exponencial, max 60s |
| Deteccion de desconexion | < 30s | 2 heartbeats perdidos |

## Monitoreo

### Metricas (via bhnexus en puerto 9445)

| Metrica | Tipo | Descripcion |
|---|---|---|
| `nexus_agents_connected_total` | Gauge | Agentes actualmente conectados |
| `nexus_auth_results_granted_total` | Counter | Autenticaciones concedidas |
| `nexus_auth_results_denied_total` | Counter | Autenticaciones denegadas |
| `nexus_offline_sessions_seconds` | Gauge | Tiempo acumulado offline |
| `nexus_actuator_commands_total` | Counter | Comandos de actuador ejecutados |

### Logs

```bash
# Ver logs del agente
journalctl --user -u banexus.service -n 50

# Ver intentos de autenticacion
journalctl --user -u banexus.service | grep "auth_request"

# Ver decisiones offline
journalctl --user -u banexus.service | grep "offline"

# Ver errores de hardware
journalctl --user -u banexus.service | grep -E "hardware_error|usb_error|serial_error"
```

## Runbooks

### Diagnosticar Conexion Perdida

```bash
# Verificar estado del servicio
systemctl --user status banexus

# Ver intentos de reconexion
journalctl --user -u banexus.service -n 30 | grep -E "reconnect|WebSocket|disconnected"

# Verificar conectividad con bhnexus
ping sbos-server
curl -k https://sbos-server:9444/health 2>/dev/null || echo "bhnexus no responde"

# Verificar certificados
openssl x509 -in /etc/banexus/tls/agent.crt -text -noout | grep -E "Subject|Not After"
```

### Recovery de Cache Corrupto

```bash
# Detener agente
systemctl --user stop banexus

# Respaldar cache corrupto
cp /etc/banexus/cache/cache.db /tmp/cache.db.corrupt

# Eliminar cache
rm -f /etc/banexus/cache/cache.db

# Iniciar agente (creara cache nuevo)
systemctl --user start banexus

# Verificar que reconecto
journalctl --user -u banexus.service -n 10 | grep "connected"
```

### Verificacion de Lectores USB

```bash
# Listar dispositivos USB
lsusb

# Verificar grupos
ls -la /dev/banexus/

# Probar lectura QR
# (colocar QR frente al lector)
journalctl --user -u banexus.service -n 5 | grep "input_type.*qr"

# Verificar regla udev
udevadm info -a -n /dev/banexus/reader-0 | grep -E "idVendor|idProduct"
```

### Prueba de Actuador

```bash
# Verificar puerto serie
ls -la /dev/ttyUSB0

# Probar apertura manual
echo -n -e '\x01\x01' > /dev/ttyUSB0

# Ver comando en logs
journalctl --user -u banexus.service -n 5 | grep "actuator"
```

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS5-6, V5-SS3, V7-SS5-6_
