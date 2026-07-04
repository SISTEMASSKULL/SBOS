# CLAUDE.md — BauthAgent (bAuth)
<!-- nivel: microservicio (3) · hereda de: SBOS + Fábrica ORQUESTA -->
<!-- Doc de dominio: context/BOS_V8/BOS_V8_SBOS-021-DAEMON-BAUTH.md · Registro: SBOS/paths.yml → microservicios -->

## Propósito propio
**bAuth** — Identity Control Plane — Orquestador central de identidad. Enruta credenciales a los motores (Keycloak OIDC/SAML/WebAuthn, Vault PKI/Ed25519, Besu ECDSA), aplica BitMask Dual 64-bit + DomainRegistry 12 dominios + PolicyChain + SoD + DAG, y emite JWT unificado con RolBitMask + ctx_id + firma. Doble motor de firmas (Vault Ed25519 interno + ADSIB RSA-SHA256 externo). PAP/PIP/PDP/PEP. 47 handlers JSON-RPC.

## Producto que desarrolla
Identity Control Plane — Orquestador central de identidad · **Plano:** Identidad · **Stack:** Rust 1.85+ (MUSL) + Java 21 (5 SPIs)

## Interfaz (ADR-020 — Interface Dual)
- Unix socket `/run/bos/bauth.sock` (0660, grupo `bos`): **WebSocket RPC** (humanos/CLI) + **JSON-RPC 2.0** (otros daemons).
- Namespace JSON-RPC `bauth.*` · Puerto: 9450-9453
- **NUNCA HTTP/TCP entre daemons** (SBOS-050 P9). Servidor 3 capas (ORQUESTA-043).

## Fronteras (ORQUESTA-051 · ADR-014)
- **Escribo solo aquí** (`BauthAgent`). No toco el código de otros daemons.
- **Consulto a los hermanos por su contrato** (bos (fichas + Context Plane) · biedata (datos)) — su `PROPOSITO.md` / JSON-RPC, en solo lectura.
- Uso los **recursos compartidos** de SBOS (`context/`, `DDLs/`, `servers/`) en lectura; sus cambios → HITL.

## Reglas comunes (heredadas del proyecto)
Interface Dual · `ctx_id` en toda operación (SBOS-049) · systemd en el host (no pods) · puertos SBOS-050 · ISO 27001 (SBOS-047).

## Skills sugeridas (a poblar en `.claude/skills/`)
- `bauth-bitmask-64bit`
- `bauth-token-4capas`
- `bauth-policychain-sod`
- `bauth-firma-dual`
