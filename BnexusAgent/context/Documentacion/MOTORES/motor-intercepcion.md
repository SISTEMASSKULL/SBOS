# Motor 5 — Interceptación (Interceptar-Inputs)
## Input Hooking + Shell Sentinel: captura soberana antes de evdev y PAM

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Motor en MOTORES-INDEX:** `M-05`  
**Respalda:** `4.01_MANUAL-INPUT-HOOKING.md` + `4.02_MANUAL-SHELL-SENTINEL.md` + `4.04_MANUAL-INTEGRIDAD-BANEXUS.md`

---

## Responsabilidad del motor

El Motor de Interceptación es el componente de banexus que **captura los inputs antes de que lleguen al sistema operativo o a otras aplicaciones**. Opera en dos planos: hardware USB y sesiones de shell.

**Verbo central:** `Interceptar` — captura credenciales físicas y sesiones shell antes de que escapen al OS.

## Las dos funciones de interceptación

### Función A — Input Hooking (USB/NFC/QR)

**Problema resuelto**: sin hooking, cualquier proceso del usuario puede leer del lector NFC/QR via evdev.

**Mecanismo**:
1. Regla udev: `ATTR{authorized}="0"` previene carga del driver `usbhid` → dispositivo no aparece en `/dev/input/eventN`
2. banexus abre el dispositivo en modo raw via `libusb.claim_interface(0)`
3. banexus es el **único** proceso que lee los datos del lector

**Anti-inyección**: 4 vectores bloqueados:
- No hay superficie evdev (Vector 1)
- Socket `0660 grupo banexus` (Vector 2)
- Bloom filter anti-replay (Vector 3)
- TOCTOU: eventos con >5s de antigüedad descartados (Vector 4)

### Función B — Shell Sentinel (PAM)

**Problema resuelto**: un usuario con credenciales Unix puede hacer SSH/sudo sin autorización de bAuth.

**Mecanismo**:
1. `pam_banexus.so` en stack PAM (sshd, sudo, login, su, gdm)
2. `fail_open=false` obligatorio — si bhnexus no responde → DENY
3. `SBOS_CTX_ID` inyectado en la sesión SSH autorizada
4. Auditoría de comandos via LD_PRELOAD (sl < 4) o eBPF (sl = 4)
5. Comandos críticos congelados hasta aprobación de bAuth

### Función C — Integrity Monitor (banexus)

**Problema resuelto**: un atacante con acceso al host puede modificar el binario de banexus.

**Mecanismo**:
1. SHA-256 del binario cada 300s
2. Comparado contra hash canónico firmado con Ed25519 (Vault PKI)
3. Si discrepancia → `emergency_shutdown()` con `process::exit(99)`
4. systemd `RestartPreventExitStatus=99` — no reinicia el binario comprometido

## Lo que NO hace

- No autentica al usuario (eso es pam_unix.so + bAuth)
- No decide si la sesión está autorizada (eso es bAuth)
- No monitorea el tráfico de red (eso está fuera del alcance de bNexus)

---

*SKULL · SBOS · bNexus · MOTORES/motor-intercepcion · v1.0.0 · Agosto 2026*
