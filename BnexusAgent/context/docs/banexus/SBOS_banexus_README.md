# README — SBOS Nexus Agent (banexus)

## Identidad Rapida

| Campo | Valor |
|---|---|
| Daemon | `banexus` |
| Servicio | `banexus.service` (systemd --user en Fedora) |
| Lenguaje | Go (concurrencia I/O + WebSocket) |
| Comunicacion | WebSocket mTLS exclusivo con bhnexus |
| Funcion | Edge Sentinel |
| Cache local | AES-256-GCM, TTL 4h max offline |
| Grupo sistema | `banexus` (permisos 0660 sobre dispositivos) |

## Dependencias

- **SBOS Nexus Host (bhnexus)**: conexion WebSocket mTLS obligatoria
- **udev**: reglas de interceptacion de dispositivos USB
- **libusb**: captura de datos de QR/NFC/barcode
- **PAM**: pam_banexus.so para Shell Sentinel
- **polkit**: hooks de autorizacion de comandos sensibles
- **Hardware**: lectores QR, NFC, barcode, fingerprint, teclados PIN

## Comandos basicos

```bash
# Estado del daemon
systemctl --user status banexus

# Ver conexion con bhnexus
journalctl --user -u banexus.service -n 20 | grep -E "connected|disconnected|WebSocket"

# Ver cache local
ls -la /etc/banexus/cache/

# Probar lector USB
lsusb | grep -E "QR|NFC|barcode"
```

## Relaciones con otros daemons

| Daemon | Relacion |
|---|---|
| SBOS Nexus Host (bhnexus) | WebSocket mTLS -> conecta como agente edge |
| SBOS Auth Enforce (bauth) | Indirecto via bhnexus (evaluacion BitMask) |
| SBOS IAM Installer (bos) | Configuracion de device fichas |
| SBOS Data Kernel (bkernel) | Eventos de auditoria via WAL |

---

_Fuente: BOS_V8_SBOS-039-DAEMON-NEXUS.md SS1, SS3, SS5, V5-SS3, V7-SS5_
