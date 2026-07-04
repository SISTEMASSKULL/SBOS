# SBOS-036-NEXUS-AGENT
## SBOS Nexus Agent: Distributed Sovereign Edge Sentinel & Multi-Input Interceptor
### Daemon banexus.service (systemd --user) · Lenguaje: Go

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

| Campo | Valor |
|-------|-------|
| **Nombre** | SBOS Nexus Agent |
| **Nombre conceptual** | Distributed Sovereign Edge Sentinel & Multi-Input Interceptor |
| **Daemon** | `banexus` |
| **Servicio systemd** | `banexus.service` (systemd --user en Fedora) |
| **Lenguaje** | Go (concurrencia para interceptación de I/O + WebSocket) |
| **Comunicación** | WebSocket mTLS exclusivo con bhnexus |

---

## 1. Definición Ejecutiva

### ¿Qué es?

Es el componente de seguridad distribuida que opera en el borde (Edge) del ecosistema. Funciona como un interceptor de bajo nivel en el nodo local (estación Fedora o controlador de puerta). Su misión es capturar eventos de entrada (teclado, QR, huella, comandos de shell) y detener la ejecución hasta que el Nexus Host envíe la aprobación binaria.

### Lo que puede hacer

- **Input Hooking:** Captura señales de periféricos USB/serial (QR, NFC, código de barras) a nivel de bus, impidiendo que el dato llegue al SO sin sesión autorizada.
- **Shell Sentinel:** Congela procesos shell sensibles, consulta al Host, y solo libera si la BitMask tiene el bit activo.
- **Controlador de Actuadores Locales:** Ejecuta apertura de relés (puertas, cajones) tras recibir orden firmada del Host.
- **Policy Cache Efímero:** Almacena copia cifrada de la última política para accesos críticos durante desconexión.
- **Comunicación Monogámica:** Ignora cualquier tráfico que no provenga del Nexus Host verificado por certificado.

### Lo que NO puede hacer

- Gestión de identidad (SSO) — no tiene contacto con Keycloak
- Crear permisos nuevos — solo valida los que recibe
- Modificar el entorno del usuario — es un centinela pasivo

---

## 2. Integración con Fedora

### 2.1 Instalación

```bash
# El bos instala banexus como parte de la ficha SBOS VDI
# Se despliega como servicio systemd --user (no root)

# /etc/systemd/user/banexus.service
[Unit]
Description=SBOS Nexus Agent — Edge Sentinel
After=network-online.target

[Service]
Type=simple
ExecStart=/opt/banexus/banexus
Restart=always
RestartSec=5
Environment=BANEXUS_CONFIG=/etc/banexus/banexus.toml

[Install]
WantedBy=default.target
```

### 2.2 Interceptación de input USB

Mecanismo: **udev rules + libusb**

```bash
# /etc/udev/rules.d/99-banexus-intercept.rules
# Interceptar lectores QR/NFC/código de barras
SUBSYSTEM=="usb", ATTR{idVendor}=="<vendor_id>", ATTR{idProduct}=="<product_id>", \
  MODE="0660", GROUP="banexus", \
  SYMLINK+="banexus/reader-%k"
```

El agente monitorea `/dev/banexus/reader-*` y captura datos ANTES de que evdev los pase al sistema de input de Fedora.

### 2.3 Shell Sentinel

Mecanismo: **PAM module + polkit policy**

```
Usuario ejecuta comando sensible (configurado en banexus.toml)
  │
  ▼
PAM module pam_banexus.so intercepta
  │
  ├── Envía consulta a bhnexus via WebSocket:
  │   {"type":"shell_auth","node_id":"Ventas-01","command":"apt-get install","user":"maria"}
  │
  ├── Espera respuesta (timeout: 5s)
  │   ├── GRANTED (BitMask bit 1: SHELL_UNLOCK) → liberar comando
  │   ├── DENIED → bloquear comando + notificar al usuario
  │   └── TIMEOUT → consultar policy cache local
  │
  └── Log: "shell_command: apt-get install, user: maria, result: granted/denied"
```

---

## 3. Policy Cache Efímero

```
Cuando bhnexus envía una BitMask:
  banexus almacena en cache local:
    {
      user_id: "uuid",
      bitmask: 0x000000000003E627,
      received_at: "2026-03-14T10:30:00Z",
      ttl_seconds: 28800,
      encrypted: true   // AES-256-GCM con clave derivada del certificado mTLS
    }

Cuando la conexión con bhnexus se pierde:
  banexus consulta policy cache para decisiones
  Solo permite operaciones con BitMask en cache Y dentro de TTL
  Si TTL expirado → DENY todo (modo seguro)

Cuando la conexión se restablece:
  banexus invalida cache y solicita refresh
  Envía resumen de decisiones tomadas offline al Host
```

---

## 4. Control de Actuadores

```go
// Ejemplo: abrir relé de puerta vía GPIO/serial
func executeActuatorCommand(cmd ActuatorCommand) error {
    switch cmd.Target {
    case "RELAY_01":
        // Enviar señal al relé via serial/GPIO
        port, err := serial.Open(config.RelayPort, &serial.Mode{BaudRate: 9600})
        if err != nil { return err }
        defer port.Close()
        
        // Comando OPEN
        port.Write([]byte{0x01, 0x01})  // protocolo del relé
        
        // Timer para cerrar automáticamente
        time.AfterFunc(time.Duration(cmd.DurationMs)*time.Millisecond, func() {
            port.Write([]byte{0x01, 0x00})  // CLOSE
        })
        
        return nil
    }
    return fmt.Errorf("unknown actuator: %s", cmd.Target)
}
```

---

## 5. Configuración (banexus.toml)

```toml
[agent]
node_id = "Ventas-01"
host_url = "wss://sbos-server:9444"
tls_cert = "/etc/banexus/tls/agent.crt"
tls_key = "/etc/banexus/tls/agent.key"
tls_ca = "/etc/banexus/tls/ca.crt"

[input]
intercept_usb = true
reader_devices = ["/dev/banexus/reader-*"]
input_timeout_seconds = 30

[shell_sentinel]
enabled = true
sensitive_commands = ["apt-get", "dnf", "systemctl", "rm -rf", "dd", "fdisk"]
pam_module = "/usr/lib64/security/pam_banexus.so"

[actuators]
relay_port = "/dev/ttyUSB0"
relay_baud_rate = 9600

[cache]
enabled = true
max_entries = 100
encryption_key_source = "mTLS_cert"  # derivar clave del certificado

[health]
heartbeat_interval_seconds = 30
self_integrity_check_interval_seconds = 300
```

---

## 6. Auto-verificación de Integridad

Cada 5 minutos, banexus verifica que sus propios binarios no han sido alterados:

```
1. Calcular SHA-256 de /opt/banexus/banexus
2. Comparar contra hash almacenado en /etc/banexus/banexus.sha256
3. SI MATCH → OK
4. SI NO MATCH → alerta crítica a bhnexus + auto-shutdown
   (binario potencialmente comprometido)
```

---

## 7. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Especificación completa del SBOS Nexus Agent: integración systemd --user en Fedora, interceptación USB vía udev+libusb, shell sentinel vía PAM, policy cache efímero cifrado, control de actuadores vía serial/GPIO, auto-verificación de integridad.

---

*SKULL · SBOS · SBOS-036-NEXUS-AGENT · v1.0 · Marzo 2026*
