# PROPOSITO — BnotifyAgent (bnotify)

**Rol:** bnotify — Sistema de Notificaciones Universales
**Plano:** Notificación · **Stack:** por definir (Rust/Go) — daemon nativo en concepción · **Doc:** `context/BOS_V8/BOS_V8_SBOS-Partitura-Maestra (en concepción).md`

## Contrato de consulta (lo que los hermanos pueden leer de mí)
- **Qué hago:** Push MFA, alertas y mensajes a clientes. Ficha sbos-notifier — CRÍTICA (el MFA de bAuth depende de ella). Estado: en concepción (Partitura Maestra).
- **Socket:** `/run/bos/bnotify.sock` · **Namespace JSON-RPC:** `bnotify.*` · **Puerto:** 28200-28205 (S06)
- **Métodos principales:**
  - `bnotify.mfa.challenge`
  - `bnotify.alert.send`

Los hermanos me consultan por este contrato — nunca por mi código interno (ORQUESTA-051 §6).
