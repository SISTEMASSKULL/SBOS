# BOS-REPAIR-14 — Especificación de Desarrollo: sbos-client
## El agente soberano del VDI Layer — spec de implementación
## SKULL · SBOS · v2.0 · Junio 2026
## Fuentes: SBOS-052 §4 (definición canónica) · SBOS-NEXUS v3.0 §8 (protocolo WS) · SBOS-MANUAL-ACOPLAMIENTO §18

**Por qué existe este anexo:** SBOS-052 define QUÉ es el sbos-client y su ciclo
de vida; SBOS-NEXUS define el protocolo WebSocket de bhnexus. Este anexo
consolida ambos en la spec de desarrollo que el agente sigue en F16.5-F16.9.

---

## 1. Identidad del componente (según SBOS-052 §4.1)

```
Nombre:        sbos-client
Tipo:          daemon Go — "el par de banexus para entornos sin hardware
               físico, y el complemento de banexus en entornos físicos"
Vive en:       (a) cada pod fedora-logico  (b) cada Fedora Físico  (c) WSL2
Ubicación:     MONOREPO del bos — src/cmd/sbos-client/
               (NO repo separado: reutiliza internal/wslib, internal/paths,
                internal/audit y los estándares BOS-REPAIR ya construidos)
Comunicación:  WebSocket mTLS hacia bhnexus :9444 — MISMO protocolo que banexus
Responsable:   registrar el nodo con el Context Plane (dctx_id) y APLICAR el
               BitMask recibido en el ambiente local del usuario
```

**Lo que NO hace:** no instala fichas, no toca K8s, no decide permisos (eso
es el BitMask que recibe), no guarda datos del usuario en disco local (P1),
no habla con bAuth ni con Keycloak directamente (topología vetada — todo
pasa por bhnexus, igual que banexus).

## 2. Estructura en el monorepo

```
src/
├── cmd/sbos-client/
│   ├── main.go            ≤150 líneas — señales + orquestación de modos
│   └── README.md          modos, config, troubleshooting (patrón F7.5)
├── internal/sbosclient/
│   ├── mode/              autodetección PHYSICAL / LOGICAL / WSL
│   ├── link/              WebSocket mTLS a bhnexus (sobre internal/wslib)
│   │                      reconexión backoff 1→5→15→30→60s (patrón banexus)
│   ├── identity/          device_uuid persistente + registro dctx_id
│   ├── session/           manejo de context.promoted / context.expired
│   ├── desktop/           políticas dconf GNOME según BitMask
│   ├── home/              montaje/desmontaje del home Nextcloud
│   └── config/            /etc/sbos/client.toml
└── packaging/sbos-client/
    ├── sbos-client.service   systemd unit (Fedora Físico)
    └── pod-supervisor.conf   supervisión dentro del pod (Fedora Lógico)
```

DoD estructural: doc.go ADR-003 en cada paquete · CI con -race -count=10 ·
SFP-01..06 · godoc completo.

## 3. Modos de operación (SBOS-052 §4.2 — autodetección al arranque)

```
MODE_PHYSICAL → Fedora físico con banexus presente
                coordina con banexus para el BitMask
                hardware_type: "physical"
MODE_LOGICAL  → pod Fedora Lógico (dentro de K8s)
                opera solo · hardware_type: "logical_pod"
MODE_WSL      → Fedora sobre WSL2 (desarrolladores/administradores SKULL)
                opera solo · hardware_type: "wsl"

Detección: banexus.service activo → PHYSICAL · /run/.containerenv o
serviceaccount K8s → LOGICAL · /proc/version contiene "microsoft" → WSL
```

## 4. Configuración — /etc/sbos/client.toml (canónica de SBOS-052 §4.3)

```toml
server_url  = "wss://bhnexus.{tenant}.sksistemas.com:9444"
tenant      = "skull"
device_uuid = "{UUID persistente — generado en el primer arranque}"
cert        = "/etc/sbos/certs/client.crt"   # mTLS de Vault PKI
key         = "/etc/sbos/certs/client.key"
ca          = "/etc/sbos/certs/ca.crt"
```

## 5. Protocolo con bhnexus (patrón banexus — SBOS-NEXUS §8)

### Conexión
```
sbos-client → bhnexus :9444 : WSS upgrade con mTLS
  Headers: X-Node-ID, X-Agent-Version, X-Agent-Cert-Fingerprint
bhnexus verifica: cert contra CA interna · nodo registrado · versión semver
  compatible · fingerprint — FAIL → 403 + log + alerta
```

### Frames (JSON tipados, mismo canal bidireccional)
```json
// sbos-client → bhnexus: registro al conectar
{ "type": "device_register", "device_uuid": "...", "tenant": "skull",
  "hardware_type": "logical_pod", "hostname": "...", "agent_version": "1.0.0" }

// bhnexus (via bos) → sbos-client: dctx_id creado
{ "type": "device_registered", "dctx_id": "...", "status": "pre-auth",
  "bitmask": "0x0000000000000000", "heartbeat_interval_s": 30 }
// (bos lo persiste en Redis + bkernel_db.context_sessions)

// bos → sbos-client (PUSH tras login Keycloak del usuario):
{ "type": "context.promoted", "ctx_id": "...", "bitmask": "0x...",
  "user_id": "...", "user_name": "...", "ttl_seconds": 28800 }

// bos → sbos-client (PUSH en logout / timeout KC / invalidación):
{ "type": "context.expired", "ctx_id": "...", "reason": "logout|ttl|admin" }

// sbos-client → bhnexus: heartbeat cada 30s (patrón banexus)
{ "type": "heartbeat", "device_uuid": "...", "dctx_id": "...",
  "uptime_seconds": 86400, "session_active": true, "integrity_ok": true }
```

### Resiliencia (fail-secure, patrón banexus)
```
Desconexión → reconectar con backoff 1→5→15→30→60s (máx, repite)
Sin conexión y sin sesión → pantalla de login con estado degradado
Sin conexión con sesión activa → la sesión local sigue hasta TTL;
  al expirar TTL sin reconexión → context.expired local (fail-secure)
Nunca crash-loop. El TTL del Context Plane (F6.5) es la red de seguridad.
```

## 6. Ciclo de vida completo (SBOS-052 §4.3)

```
Arranque (systemd en físico / supervisor en pod)
  → detectar modo → leer client.toml → WS mTLS a bhnexus :9444
  → device_register → dctx_id (pre-auth, bitmask 0x0)
  → heartbeat 30s · socket local /run/sbos/client.sock para el greeter
[ESPERA] usuario se autentica en Keycloak
  (físico: keycloak-oidc-pam en GNOME · lógico: login web del pod)
  → bos emite context.promoted → sbos-client recibe ctx_id + BitMask
  → APLICA:
     1. políticas dconf en GNOME (apps permitidas según BitMask)
     2. monta home del usuario desde Nextcloud (davfs2/nextcloud-desktop,
        uid de sesión, noexec, nosuid)
     3. variables de entorno con ctx_id
     4. MODE_PHYSICAL: notifica a banexus
[OPERACIÓN] — verificación C-12: ls ~/Documentos responde
Logout / timeout KC → bos emite context.expired
  → limpia dconf (GNOME vuelve al login) → desmonta home
    (verificación post-umount: disco local VACÍO — P1)
  → limpia env → pod lógico: vuelve al pool · físico: pantalla de login
Caída abrupta del pod → TTL del ctx expira solo (F6.5) · bos detecta dctx
  huérfano por ausencia de heartbeat (>3 intervalos) → invalida
```

## 7. Seguridad (alineado con BOS-REPAIR-15)

```
- mTLS SIEMPRE — certs de Vault PKI (TTL 24h, renovación automática)
- JWT/ctx solo en memoria · refresh en keyring del kernel (físico) /
  memoria (pod — la sesión muere con el pod)
- Home con uid de sesión, noexec, nosuid · cero datos locales (P1):
  TestUnmount_DiscoLocalVacio
- Audit JSONL append-only: REGISTER/PROMOTED/MOUNT/UNMOUNT/EXPIRED
  (ISO 27001 A.8.15 — reutiliza internal/audit del bos)
- Integrity monitor opcional (patrón banexus): SHA-256 del binario cada 5min
- Binario firmado en CI (cosign) — SLSA L2 igual que bos
```

## 8. DoD del sbos-client (átomos F16.5-F16.9)

```bash
go build ./... && go vet ./... && go test -race -count=10 ./...   # verde
# Contra bhnexus stub (servidor WS de prueba):
TestModeDetection_PhysicalLogicalWSL
TestRegister_RecibeDctxPreAuthEnMenosDe2s
TestPromoted_AplicaDconfYMontaHome
TestExpired_LimpiaDconfDesmontaDiscoVacio
TestReconexion_Backoff1a60SinCrashLoop
TestTTLVencidoSinConexion_FailSecure
# En staging real (cierra C-11/C-12/C-13):
kubectl get pods -l ficha=fedora-logico        # ≥2 Running
bosctl rpc bos.query.context                   # dctx de cada pod activo
bosctl exec fedora-logico -- ls /home/sbos-user/Documentos   # responde
```

## 9. Trazabilidad

| Sección | Fuente |
|---|---|
| Identidad, modos, ciclo de vida, client.toml | SBOS-052 §4 (canónico) |
| Protocolo WS, headers, frames, backoff, fail-secure | SBOS-NEXUS v3.0 §7-8 |
| Topología vetada (nunca bAuth/KC directo) | SBOS-MANUAL-ACOPLAMIENTO §18 |
| dctx_id pre-auth → promoted | SBOS-049 + F5.x implementado |
| TTL como red de seguridad | F6.5 (ErrContextExpired -32001) |
| Estándares de código | BOS-REPAIR (ADR-003, SFP, CI -race) |

---

*BOS-REPAIR-14 v2.0 · SKULL · SBOS · Junio 2026 — reemplaza v1.0 (que asumía REST y repo separado)*
