# PROPOSITO — Bi18nAgent (bi18n)

**Rol:** Orquestador Universal de Internacionalización
**Plano:** Infraestructura transversal · **Stack:** Rust 1.85+ (MUSL) · **Doc:** `context/i18n-orchestrator-rust.md`

## Contrato de consulta (lo que los hermanos pueden leer de mí)
- **Qué hago:** Proveo una API unificada de internacionalización para todo el ecosistema SBOS. Un solo `Locale` (BCP 47), una sola configuración regional por tenant, y una API que delega en las mejores librerías Rust para cada tarea: ICU4X (formato fecha/número/moneda/unidades/collation/bidi/calendarios), Fluent (traducción con plurales y género), jiff (instante temporal zone-aware), phonenumber (validación E.164), validator (email/URL/tarjetas). Registro extensible de reglas por país vía TOML. Pipeline de atributos: raw → validate → transform → format → mask → localize.
- **Socket:** `/run/bos/bi18n.sock` · **Namespace JSON-RPC:** `bi18n.*` · **Puerto:** 9470-9475
- **CLI:** `i18nctl` — subcomandos clap para todas las capacidades (format, validate, mask, attr, collate, locale, rules)
- **Métodos principales:**
  - `bi18n.format.date` / `bi18n.format.number` / `bi18n.format.money` / `bi18n.format.address` / `bi18n.format.name`
  - `bi18n.validate.phone` / `bi18n.validate.national_id` / `bi18n.validate.email` / `bi18n.validate.plate`
  - `bi18n.mask.value` / `bi18n.mask.pii`
  - `bi18n.locale.resolve`
  - `bi18n.enum.display`
  - `bi18n.attr.build` / `bi18n.attr.pipeline`
  - `bi18n.rules.list` / `bi18n.rules.validate_file`
  - `bi18n.collate.sort`

Los hermanos me consultan por este contrato — nunca por mi código interno (ORQUESTA-051 §6).
