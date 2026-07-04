# PROPOSITO — BosAgent (bos)

**Rol:** IAM Installer — Control Plane Soberano
**Plano:** Control · **Stack:** Go 1.22 + Bash + Python · **Doc:** `context/BOS_V8/BOS_V8_SBOS-018-DAEMON-BOS.md`

## Contrato de consulta (lo que los hermanos pueden leer de mí)
- **Qué hago:** Despliega y gobierna el plano de control: instala fichas (máquina de 18 estados, ADR-021), ejecuta sagas con compensación y es DUEÑO del Context Plane (crea/valida ctx_id). CLI bosctl (23 comandos), 112+ fichas.
- **Socket:** `/run/bos/bos.sock` · **Namespace JSON-RPC:** `bos.*` · **Puerto:** — (solo Unix socket)
- **Métodos principales:**
  - `bos.ficha.install`
  - `bos.saga.execute`
  - `bos.ctx.create`
  - `bos.ctx.validate`
  - `bos.bootstrap.start`

Los hermanos me consultan por este contrato — nunca por mi código interno (ORQUESTA-051 §6).
