# CLAUDE.md — BauthAgent (bAuth)
<!-- nivel: microservicio (3) · hereda de: SBOS + Fábrica ORQUESTA -->
<!-- Doc de dominio: context/BOS_V8/BOS_V8_SBOS-021-DAEMON-BAUTH.md · Registro: SBOS/paths.yml → microservicios -->

## Propósito propio
**bAuth** — Identity Control Plane — Orquestador central de identidad. Valida credenciales en su **motor de métodos nativo** (OIDC/SAML/WebAuthn en Rust — **sin Keycloak**, ADR-010) y consulta a Vault (PKI/Ed25519) y Besu (ECDSA, dominio blockchain); aplica BitMask Dual 64-bit + DomainRegistry 12 dominios + PolicyChain + SoD + DAG, y emite JWT unificado con RolBitMask + ctx_id + firma. Doble motor de firmas (Vault Ed25519 interno + ADSIB RSA-SHA256 externo). PAP/PIP/PDP/PEP. ~147 métodos JSON-RPC.

## Producto que desarrolla
Identity Control Plane — Orquestador central de identidad · **Plano:** Identidad · **Stack:** Rust 1.85+ (MUSL) — autosuficiente (las SPIs Java fueron eliminadas, ADR-010)

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
- **Formato de documentos: Markdown (.md) obligatorio.** Todo documento, informe, demo, especificación o artefacto escrito se genera en `.md`. HTML solo se desarrolla a pedido explícito del humano. Por defecto, siempre `.md`.

## ⚠️ C12 — EVIDENCIA OBLIGATORIA (AA-1 REFORZADO) — NO NEGOCIABLE
**Toda afirmación verificable DEBE adjuntar evidencia firmada.** PROHIBIDO afirmar:
- "X compila sin errores" sin haber ejecutado `cargo check` y mostrado la salida
- "Y tiene N archivos" sin haber ejecutado `find`/`ls` y mostrado la salida
- "grep Z retorna 0 resultados" sin haber ejecutado `grep` y mostrado la salida

**Herramienta obligatoria:** `scripts/verificar_afirmacion.sh "<desc>" <comando>`
La salida incluye timestamp + SHA256 del comando y su resultado. Se adjunta al informe.

**Sin evidencia AA-1 = RECHAZO automático del Revisor.** Reincidencia = tarea devuelta.

## Parámetros operativos (proyecto SBOS)
- **UUID del proyecto SBOS (para RPC al Coordinador):** `4c697f66-d204-45a5-ac36-c104f07c7046`
  - Todo método JSON-RPC del Coordinador que requiera `proyecto_id` DEBE usar este UUID.
  - Los strings tipo `"sbos-bauth"` causan error PostgreSQL: `invalid input syntax for type uuid`.
- **Python:** usar `python3` — `python` no existe en el host (código 127).
- **Contrato BOS ↔ bAuth:** `../context/contracts/BOS-BAUTH-CONTRATOS.md` (nivel proyecto — bilateral, NO dentro de un solo daemon).
- **Comunicación tmux:** `source scripts/agente_enviar.sh && agente_enviar <pane> "<mensaje>"` (shim → script canónico de fábrica).

## Skills sugeridas (a poblar en `.claude/skills/`)
- `bauth-bitmask-64bit`
- `bauth-token-4capas`
- `bauth-policychain-sod`
- `bauth-firma-dual`
