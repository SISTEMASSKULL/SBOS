# PROPOSITO — BnexusAgent (bhnexus + banexus)

**Rol:** Nexus — Proxy de Hardware Universal + Centinela Edge
**Plano:** Conectividad / Edge · **Stack:** Go 1.22 · **Doc:** `context/BOS_V8/BOS_V8_SBOS-039-DAEMON-NEXUS.md`

## Contrato de consulta (lo que los hermanos pueden leer de mí)
- **Qué hago:** Nexus Host (bhnexus): WebSocket mTLS (10K+ conexiones), Hardware Bridge (OSDP/MQTT/ONVIF/Wiegand), Auth Cache in-memory (TTL 30s). Nexus Agent (banexus): centinela edge en Fedora VDI, interceptor USB/shell (udev+PAM+polkit), Policy Cache efímero (AES-256-GCM).
- **Socket:** `/run/bos/bhnexus.sock (+ /run/bos/banexus.sock)` · **Namespace JSON-RPC:** `bhnexus / banexus.*` · **Puerto:** 9444 (bhnexus)
- **Métodos principales:**
  - `bhnexus.auth.validate`
  - `banexus.device.intercept`

Los hermanos me consultan por este contrato — nunca por mi código interno (ORQUESTA-051 §6).
