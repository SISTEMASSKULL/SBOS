# BNOTIFY-000-INDEX — Índice de Documentación de bChat (BnotifyAgent)
## Mapa de navegación completo · SBOS · Julio 2026

**Versión:** 2.0.0 · **Fecha:** 2026-07-05 · **Autor:** bauth-developer
**Propósito:** Guía de navegación entre todos los documentos de diseño y desarrollo
del subsistema de notificaciones y mensajería del ecosistema SBOS.
**Producto:** bChat — mensajería soberana tipo WeChat gobernada por SBOS.
**Corrección v2.0:** bAuth OIDC Provider nativo. Keycloak backup. REST API interna vetada.

---

## REGLA DE USO

> Antes de escribir una sola línea de código o SQL, leer en el orden indicado.
> El orden no es sugerencia — es la secuencia lógica de comprensión.

---

## SECCIÓN 1 — VISIÓN Y ARQUITECTURA (leer primero)

| # | Documento | Propósito | Leer cuando |
|---|-----------|-----------|-------------|
| 1 | `BNOTIFY-001-VISION.md` | **PUNTO DE PARTIDA.** Qué es bChat, por qué Rocket.Chat como base, cómo bAuth reemplaza EE, arquitectura general | SIEMPRE PRIMERO |
| 2 | `BNOTIFY-002-LAS-ETAPAS-RUMBO-A-WECHAT.md` | Las 5 etapas concretas para transformar Rocket.Chat → bChat. Qué se hace en cada etapa, criterios de aceptación | Al planificar trabajo |
| 3 | `BNOTIFY-ARQUITECTURA.md` | Arquitectura del daemon bnotify: flujo de notificaciones, integración con Redis Streams, bKernel, biedata | Al implementar bnotify |
| 4 | `BNOTIFY-ROCKETCHAT-INTEGRACION.md` | Cómo bnotify gobierna Rocket.Chat vía REST API + OIDC. Mapeo de roles, canales, usuarios | Al implementar integración |

---

## SECCIÓN 2 — INTEGRACIÓN CON EL ECOSISTEMA

| # | Documento | Propósito |
|---|-----------|-----------|
| 5 | `../../context/contracts/BNOTIFY-BAUTH-CONTRATOS.md` | Contrato bilateral bnotify ↔ bAuth. Métodos JSON-RPC, obligaciones mutuas |
| 6 | `../../servers/S10-commsserver/rocketchat/manifest.yml` | Ficha de despliegue de bChat (Rocket.Chat 8.5.0 + MongoDB 8.0) |
| 7 | `../../servers/S06-appsserver/sbos-notifier/manifest.yml` | Ficha de despliegue de bnotify (daemon de notificaciones) |

---

## SECCIÓN 3 — DISEÑO DE DOMINIO (átomos y políticas)

| # | Documento | Propósito |
|---|-----------|-----------|
| 8 | `../BauthAgent/context/plandeaccion/REPARACIONBAUTH/07-incrementos-bauth-para-mensajeria.md` | 9 incrementos requeridos en bAuth para gobernar mensajería. Átomos bchat.*, clases de auditoría A/B/C, KYC tiers |
| 9 | `../BauthAgent/context/plandeaccion/REPARACIONBAUTH/BAUTH-CATALOGO-ATOMOS-D00-CRUD.md` | 120 átomos CRUD D00 — incluye átomos de identidad para actores externos |
| 10 | `../BauthAgent/context/plandeaccion/REPARACIONBAUTH/EVALUACION-INTEGRAL-BAUTH-2026-07-05.md` | Evaluación integral del plan REPARACIONBAUTH + investigación de estándares |

---

## SECCIÓN 4 — REFERENCIAS EXTERNAS VERIFICADAS

| # | Fuente | Dato verificado |
|---|--------|----------------|
| R1 | GitHub Rocket.Chat releases | Server 8.5.0 (mayo 2026), Node 22.16.0, Deno 1.43.5, MongoDB 8.0 |
| R2 | Rocket.Chat docs — Identity Management EE vs CE | EE: LDAP role mapping, SAML field mapping, OAuth role assign, auto-join. CE: basic OIDC login solamente |
| R3 | NIST SP 800-63B-4 Final (ago 2025) | SMS OTP = restricted authenticator. FIDO2/WebAuthn baseline AAL2+ |
| R4 | EDPB Guidelines 02/2025 (abr 2025) | "Hash, don't store" PII on-chain. Off-chain PII with granular access control |
| R5 | OpenID CAEP 1.0 Final (sep 2025) | 8 event types. session-revoked, assurance-level-change |

---

## SECCIÓN 5 — ESTRUCTURA DEL PROYECTO BNOTIFYAGENT

```
BnotifyAgent/
├── CLAUDE.md                           ← propósito propio del daemon
├── PROPOSITO.md                        ← contrato de consulta para hermanos
├── Cargo.toml                          ← dependencias Rust (por crear)
├── src/
│   ├── main.rs                         ← entry point (por crear)
│   ├── config/mod.rs                   ← carga de configuración (por crear)
│   └── server/
│       ├── mod.rs                      ← Interface Dual ADR-020 (por crear)
│       ├── jsonrpc.rs                  ← dispatcher JSON-RPC 2.0 (por crear)
│       └── websocket.rs                ← WebSocket RPC para CLI (por crear)
├── context/
│   ├── BNOTIFY-000-INDEX.md            ← ESTE DOCUMENTO
│   ├── BNOTIFY-001-VISION.md           ← Visión de bChat
│   ├── BNOTIFY-002-LAS-ETAPAS-RUMBO-A-WECHAT.md ← Roadmap
│   ├── BNOTIFY-ARQUITECTURA.md         ← Arquitectura del daemon (por crear)
│   └── BNOTIFY-ROCKETCHAT-INTEGRACION.md ← Integración bnotify↔bChat (por crear)
└── tests/                              ← tests de integración (por crear)
```

---

## ADVERTENCIAS

```
⚠️  bChat ES UN PRODUCTO NUEVO — no confundir con Rocket.Chat vanilla
⚠️  MongoDB ES OBLIGATORIO — Rocket.Chat no soporta PostgreSQL
⚠️  bAuth REEMPLAZA EE, NO LO COMPLEMENTA — sin licencia Enterprise
⚠️  TODA afirmación requiere evidencia AA-1 (C12)
⚠️  ESPAÑOL OBLIGATORIO en documentación, código, commits
```

---

*Generado: 2026-07-05 · BnotifyAgent/context/ · bauth-developer*
