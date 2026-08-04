# A.01 — Flujo Soberano Completo de bNexus
## Tres flujos end-to-end con timestamps exactos

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Fuente:** SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md §5  
**Respalda:** `1.01_MANUAL-TOPOLOGIA-NEXUS.md`  

---

## 1. Qué es el flujo soberano

El flujo soberano es la secuencia completa de eventos que ocurren desde que un usuario presenta una credencial física hasta que la puerta (o actuador) responde. Se llama "soberano" porque:

- Todo el procesamiento ocurre **dentro del servidor del cliente** — ningún dato sale
- No hay servicios externos (Keycloak, Auth0, servicios cloud) involucrados
- La cadena de custodia es 100% trazable con ctx_id en cada paso

---

## 2. Flujo A — QR Dinámico en Punto de Venta (POS)

**Escenario:** Empleado de caja presenta QR desde su app SBOS para registrar apertura de caja.  
**Hardware:** banexus-daemon en terminal POS Fedora, lector QR USB, cajón de dinero serial.  
**Resultado esperado:** cajón abre, apertura registrada en auditoría.

```
USUARIO:     María García (cajera, ROL_CAJERO, zona PHY_ZONE_VENTAS sl=2)
HORA:        Lunes 08:15 AM
CREDENCIAL:  QR generado por Core UI SBOS (TTL 30s)
ctx_id:      00-4a3b2c1d0e5f6a7b8c9d0e1f2a3b4c5d-9f8e7d6c5b4a3-01

T+0ms    [bAuth] La app Core UI solicita un QR para María
         bAuth genera el QR:
           URI = sbos://auth/a1b2c3d4-e5f6-7890-abcd-ef1234567890/1754295300/hmac
           HMAC = HMAC-SHA256(hmac_key_maria, uuid+ts)
         QR mostrado en pantalla del teléfono de María

T+1ms    [Física] María acerca el teléfono al lector QR USB en la caja 3

T+2ms    [banexus-daemon] El lector USB envía los bytes del QR por HID
         banexus parsea la URI: input_type="qr", payload="sbos://auth/..."
         banexus construye auth_request:
           {
             "type":            "auth_request",
             "request_id":      "req-uuid-001",
             "node_id":         "Caja-03",
             "user_credential": {"input_type":"qr","payload":"sbos://auth/..."},
             "ctx_id":          "00-4a3b...-01",
             "timestamp":       "2026-08-04T08:15:00.002Z"
           }
         Envía por WebSocket mTLS → bhnexus:9444

T+4ms    [bhnexus] Recibe auth_request
         CACHE MISS (primer acceso de María en Caja-03 hoy)
         Extrae el user_uuid del QR URI
         Construye bitmask_request → bAuth (sub-canal A TLV)

T+6ms    [bhnexus → bAuth] Envía bitmask_request:
           {
             "type":            "bitmask_request",
             "request_id":      "req-uuid-001",
             "user_id":         "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
             "node_id":         "Caja-03",
             "domain":          "D14",
             "operation":       "pos.drawer.open",
             "credential_type": "qr",
             "ctx_id":          "00-4a3b...-01",
             "timestamp":       "2026-08-04T08:15:00.006Z"
           }

T+8ms    [bAuth] Recibe bitmask_request
         1. Valida QR: verifica HMAC-SHA256, verifica TTL (now - ts = 8s < 30s) ✅
         2. Consulta SBOSDB: María tiene ROL_CAJERO, átomos: pos.drawer.open ✅
         3. Verifica schedule: L-V 07:00-20:00, ahora L 08:15 ✅
         4. Verifica LoA requerido: QR = LoA 2, zona sl=2 requiere LoA ≥ 2 ✅
         5. Calcula SAM-128:
            WORD-A = 0x0000000100000000 (bit zona_ventas=1, bit cajero=1)
            WORD-B = 0x0000000000007800 (TTL 30s, flags=0, LoA=2)
         6. Construye actuator_commands:
            [{target:"DRAWER_01", action:"OPEN", duration_ms:200}]
         Retorna bitmask_response en el TLV del sub-canal A

T+11ms   [bhnexus] Recibe bitmask_response
         Almacena en Auth Cache: (María, Caja-03) → SAM-128 (TTL 30s)
         Construye auth_response para banexus:
           {
             "status":           "granted",
             "sam128": {...},
             "actuator_commands": [{"target":"DRAWER_01","action":"OPEN","duration_ms":200}],
             "ctx_id":            "00-4a3b...-01",
             "timestamp":         "..."
           }
         Envía por Puerta 1 → banexus (Caja-03)

T+13ms   [banexus-daemon] Recibe auth_response
         Verifica el framing (tag autenticación implícita en TLS)
         Extrae: actuator_commands → {target: DRAWER_01, action: OPEN, duration_ms: 200}
         Abre el puerto serial del cajón de dinero
         Envía comando RS-232: 0x77 (apertura estándar)
         Registra audit_event:
           {
             "user_id":     "a1b2c3d4...",
             "device_id":   "Caja-03",
             "action":      "pos.drawer.open",
             "result":      "granted",
             "credential":  "qr",
             "ctx_id":      "00-4a3b...-01",
             "ts":          "...",
             "loa":         2,
             "offline":     false
           }

T+14ms   [Física] El cajón de caja se abre

TOTAL: 14ms puerta a puerta
       8ms de los cuales son bAuth evaluando (incluye SBOSDB query)
       El próximo acceso de María en < 30s: ~3ms (cache hit)
```

---

## 3. Flujo B — Biométrico en Sala de Servidores

**Escenario:** Administrador de sistemas accede a la sala de servidores con huella dactilar.  
**Hardware:** banexus-daemon en servidor, lector OSDP biométrico ZKTeco SB1000, cerradura fail_secure.  
**Resultado esperado:** puerta abre (cerradura libera bolt), acceso registrado en auditoría ISO 27001.

```
USUARIO:     Carlos Mendoza (sysadmin, ROL_SYSADMIN, zona PHY_ROOM_SERVIDOR sl=4)
ZONA:        Sala de Servidores — security_level=4 (crítico)
POLÍTICA:    Requiere LoA=3 + factor biométrico
ctx_id:      00-9f8e7d6c5b4a3b2c1d0e5f6a7b8c9d0e-1f2a3b4c5b6c-01

T+0ms    [Física] Carlos coloca su dedo en el lector ZKTeco SB1000

T+1ms    [Lector OSDP] El chip del lector captura la imagen dactilar
         Template extraído LOCALMENTE en el enclave seguro del chip
         Hash calculado: PBKDF2-SHA256(template_bytes, salt=device_serial)
         Hash cifrado por el canal OSDP Secure Channel (AES-128)
         Transmitido por RS-485 al HAL de bhnexus (OSDP v2)

T+3ms    [bhnexus HAL — OSDP driver] Recibe el hash cifrado
         Descifra con la clave OSDP del lector (almacenada en Vault)
         Extrae el hash biométrico: sha256:a3f1c2d4e5...
         Construye bitmask_request para bAuth:
           {
             "type":            "bitmask_request",
             "user_id":         null,                  // desconocido — búsqueda por hash
             "query_type":      "biometric",
             "biometric_hash":  "sha256:a3f1c2d4...",
             "node_id":         "Servidor-Principal",
             "domain":          "D14",
             "operation":       "access.physical.zona_servidores",
             "ctx_id":          "00-9f8e...-01"
           }

T+5ms    [bAuth] Recibe bitmask_request
         1. Busca el hash biométrico en bauth.auth_biometric_template
            → Match: Carlos Mendoza (user_id: c4r3l0s-uuid)
         2. Consulta SBOSDB: Carlos tiene ROL_SYSADMIN, átomos: access.physical.zona_servidores ✅
         3. Verifica schedule: L-V 06:00-22:00 (con override para incidentes) ✅
         4. Verifica LoA: biométrico = LoA 3, zona sl=4 requiere LoA = 3 ✅
            (si fuera sl=4 con MFA: se requeriría step_up_required con segundo factor)
            (la política de esta sala acepta biométrico solo = LoA 3 + factor biométrico)
         5. Calcula SAM-128:
            WORD-A = 0x0000000800000000 (bit zona_servidores=1)
            WORD-B = 0x0003000000007800 (TTL 30s, flags ISO27001_audit, LoA=3)
         6. Construye actuator_commands:
            [{target:"LOCK_SERVIDOR", action:"OPEN", duration_ms:10000}]
            (10 segundos de apertura — puerta se cierra sola por resorte)
         7. Registra evento privilegiado en bauth.audit_events (A.8.15 ISO 27001)
         Retorna bitmask_response

T+10ms   [bhnexus] Recibe bitmask_response
         Sin cache hit previo → almacena en Auth Cache
         Nota: el Auth Cache para zona sl=4 tiene TTL reducido a 15s (configuración de zona)
         Envía auth_response con actuator_commands → banexus

T+13ms   [banexus-daemon] Recibe auth_response
         Verifica la respuesta
         Ejecuta: open_osdp_relay(LOCK_SERVIDOR, duration=10000ms)
         El driver OSDP envía comando de apertura a la cerradura electromagnética
         Registra audit_event:
           {
             "user_id":     "c4r3l0s-uuid",
             "device_id":   "lector-SB1000-sala-server",
             "action":      "access.physical.zona_servidores",
             "result":      "granted",
             "credential":  "biometric",
             "loa":         3,
             "ctx_id":      "00-9f8e...-01",
             "iso27001":    {"control": "A.8.15", "event_class": "physical_access_privileged"},
             "offline":     false
           }

T+15ms   [Física] La cerradura electromagnética libera el bolt
         La puerta se puede abrir durante 10 segundos
         Después de 10s, el bolt se reencaja automáticamente

TOTAL: 15ms puerta a puerta
       El raw biométrico nunca salió del chip del lector
       Trazabilidad completa: Carlos + sala + credencial + ctx_id + timestamp
```

---

## 4. Flujo C — Shell Sentinel (acceso SSH remoto auditado)

**Escenario:** Sysadmin se conecta por SSH al servidor — bhnexus actúa como guardián.  
**Hardware:** Sin hardware físico. banexus-implicit en el servidor SSH.  
**Resultado esperado:** SSH session autorizada, comandos auditados con ctx_id.

```
USUARIO:     Carlos Mendoza (ROL_SYSADMIN, D09 Remote Access)
PROTOCOLO:   SSH (port 22), banexus-implicit en el servidor
ctx_id:      00-fe2a1b3c4d5e6f7a8b9c0d1e2f3a4b5c-a1b2c3d4e5f6-01

T+0ms    Carlos ejecuta: ssh carlos@servidor.skull.bo

T+1ms    [sshd] El daemon SSH recibe la conexión
         sshd NO verifica la credencial él mismo
         sshd llama al PAM module bauth-pam.so
         bauth-pam.so construye auth_request:
           {
             "type":            "auth_request",
             "node_id":         "Servidor-SSH-001",
             "user_credential": {
               "input_type":    "mtls_cert",
               "payload":       "<cert public key fingerprint de Carlos>"
             },
             "remote_ip":       "10.0.1.45",
             "ctx_id":          "00-fe2a...-01"
           }
         bauth-pam.so envía al socket /run/bos/bhnexus.sock (interface dual)

T+3ms    [bhnexus] Recibe auth_request via Unix socket (no Puerta 1 — es local)
         CACHE MISS (primer login de Carlos hoy)
         Consulta bAuth por sub-canal A:
           domain: "D09", operation: "remote_access.ssh"

T+7ms    [bAuth] Evalúa:
         Carlos tiene ROL_SYSADMIN, átomo: remote_access.ssh ✅
         Verifica IP de origen: 10.0.1.45 ∈ rango permitido para sysadmins ✅
         Verifica LoA: cert mTLS = LoA 3, D09 requiere LoA ≥ 2 ✅
         Crea ctx_id de sesión SSH (6 capas): user + device + tenant + session + trace
         Retorna SAM-128 con flag "shell_sentinel: true" en WORD-B

T+10ms   [bhnexus] Recibe respuesta, actualiza Auth Cache
         Retorna al bauth-pam.so: granted + session_ctx_id

T+11ms   [bauth-pam.so] Recibe "granted"
         Inyecta el ctx_id como variable de entorno de la sesión SSH:
           export SBOS_CTX_ID="00-fe2a...-01"
         PAM retorna PAM_SUCCESS → sshd permite la conexión

T+12ms   Carlos está en la sesión SSH con prompt

Durante la sesión:
  [Shell Sentinel / audit daemon]
  Cada comando que escribe Carlos es auditado:
  execve() hook captura:
    {
      "user_id":   "c4r3l0s-uuid",
      "ctx_id":    "00-fe2a...-01",
      "command":   "cat /etc/passwd",
      "cwd":       "/home/carlos",
      "ts":        "...",
      "pid":       12345
    }
  Enviado a bAuth audit_events via bhnexus (non-blocking, best-effort)
  Los comandos privilegiados (sudo, systemctl stop) generan alerta en SIEM (Wazuh)

Al cerrar sesión (exit o timeout):
  bhnexus recibe disconnect_event
  bAuth cierra la sesión de auditoría (audit trail completo)
  El ctx_id queda registrado como session closed

TOTAL establecimiento: 12ms
Trazabilidad: 100% — desde el handshake TCP hasta cada comando ejecutado
```

---

## 5. Tabla comparativa de flujos

| Aspecto | Flujo A (QR/POS) | Flujo B (Biométrico) | Flujo C (SSH) |
|---------|:----------------:|:--------------------:|:-------------:|
| Tipo de credencial | QR dinámico | Biométrico OSDP | mTLS X.509 |
| LoA | 2 | 3 | 3 |
| Canal banexus→bhnexus | Puerta 1 (TCP 9444) | HAL Directo→bhnexus | Unix socket |
| Cache utilizado | Auth Cache (bhnexus) | Auth Cache (bhnexus) | Auth Cache (bhnexus) |
| Latencia total | ~14ms | ~15ms | ~12ms |
| Raw biométrico viaja en red | No aplica | NUNCA — solo hash | No aplica |
| Auditoría | audit_event | audit_event + ISO 27001 | audit_event + shell commands |

---

*SKULL · SBOS · bNexus · A.01_FLUJO-SOBERANO-COMPLETO · v1.0.0 · Agosto 2026*
