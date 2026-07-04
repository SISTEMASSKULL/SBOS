# CLAUDE.md — BpayAgent (bpay)
<!-- nivel: microservicio (3) · hereda de: SBOS + Fábrica ORQUESTA -->

## Propósito propio
**bpay** — SmartPay — procesamiento de pagos y transacciones (QR, Tigo Money)

## Producto que desarrolla
SmartPay — procesamiento de pagos y transacciones (QR, Tigo Money) · **Plano:** Pagos · **Stack:** por definir

## Interfaz (ADR-020 — Interface Dual)
- Unix socket `/run/bos/bpay.sock` (0660, grupo `bos`): WebSocket RPC + JSON-RPC 2.0.
- Namespace JSON-RPC `bpay.*`. **NUNCA HTTP/TCP entre daemons** (SBOS-050 P9).

## Fronteras (ORQUESTA-051)
- **Escribo solo aquí** (`BpayAgent`). Consulto a los hermanos por su contrato (`PROPOSITO.md`/JSON-RPC), en solo lectura.
- Uso los recursos compartidos de SBOS (`context/`, `DDLs/`, `servers/`) en lectura; sus cambios → HITL.

## Reglas comunes (heredadas del proyecto)
Interface Dual · `ctx_id` (SBOS-049) · systemd en host · puertos SBOS-050 · ISO 27001 (SBOS-047).

> ⚠️ Propósito **derivado del nombre** — pendiente de ratificar con la doc de dominio del humano.
