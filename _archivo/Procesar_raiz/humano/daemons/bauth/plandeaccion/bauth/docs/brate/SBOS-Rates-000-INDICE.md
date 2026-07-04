# Índice de Documentos — SBOS SmartRates
## Exchange Rate Management System — Proyecto Conceptual Completo

**Proyecto:** SBOS Smart Rates  
**Última actualización:** 2026-05-23  
**Documentos:** 19 archivos  
**Calificación:** 10/10 ✅  
**Stack:** Laravel 13.7 · PostgreSQL 18.4 · PHP 8.3 · Flutter 3.x · Redis 7  

---

## Tabla de documentos

| Archivo | Contenido | Estado |
|---|---|---|
| `001-VISION.md` | Problema, propuesta de valor, alcance, restricciones | ✅ |
| `002-DOMINIO.md` | Glosario 35+ términos, entidades, reglas RN-001…RN-030 | ✅ |
| `003-USUARIOS.md` | 5 perfiles con casos de uso y criterios de éxito | ✅ |
| `004-FUNCIONALIDADES.md` | F-001…F-030 con criterios de aceptación verificables | ✅ |
| `005-INTEGRACIONES.md` | Fuentes externas + integraciones SBOS documentadas | ✅ |
| `006-ARQUITECTURA.md` | Stack, modos, ADRs, Laravel 13 features aprovechadas | ✅ |
| `007-DATOS.md` | 8 schemas, 23+ tablas, PG18 features, USDT/USDC | ✅ |
| `008-SEGURIDAD.md` | Auth Switch, RBAC, BitMask, catálogo SR-XXX | ✅ |
| `009-OPERACION.md` | SLA, Prometheus, scheduler, runbooks, purga | ✅ |
| `010-GLOSARIO-TECNICO.md` | 50+ términos: stack, cripto, SBOS, financieros | ✅ |
| `011-MOTOR-CROSSRATE.md` | Algoritmos, función RATE(), stablecoins en cross-rate | ✅ |
| `012-BACKFILL-HISTORICO.md` | Plan 3 fases, 100 req/noche, cronograma | ✅ |
| `013-FRONTEND-FLUTTER.md` | SmartRatesUI: BLoC, pantallas, Ticker widget SBOS | ✅ |
| `014-ACOPLAMIENTO-SBOS.md` | Modo dual, cajas biedata, manifest.yml, checklist | ✅ |
| `015-CRYPTO-USDT-BLACKRATE.md` | Investigación Bolivia 2026: USDT, USDC, paralelo, VRD | ✅ |
| `016-STABLECOINS-INTEGRACION.md` | USDT + USDC: fuentes, DB, jobs, API endpoints completos | ✅ |
| `017-TICKER-WIDGET-SBOS.md` | Ticker universal SBOS: Web Component + Flutter package | ✅ |
| `018-EXTENSION-RATE-C.md` | Código C real catalog.RATE(), compilación, tests PG18 | ✅ |
| `019-ARTEFACTOS-ORQUESTA.md` | CLAUDE.md, PROYECTO-ESTADO.md, Makefile, .mcp.json | ✅ |

---

## Decisiones técnicas no negociables

| Decisión | Valor | Razón |
|---|---|---|
| Backend | Laravel 13.7 (PHP 8.3) | Stack SKULL. AI SDK estable, passkeys, vector search nativo |
| Base de datos | PostgreSQL 18.4 | uuidv7 / VIRTUAL / WITHOUT OVERLAPS / BRIN / io_uring AIO |
| Cache / Queue | Redis 7 | Cache cotizaciones + sessions + Horizon jobs |
| WebSockets | Laravel Reverb (driver DB en dev) | Broadcast tiempo real. Driver DB = sin Redis en dev |
| Queue workers | Laravel Horizon | Sync jobs + backfill nocturno |
| Frontend | Flutter 3.x + Impeller | Web / Android / iOS / Desktop — un solo codebase |
| Ticker | Web Component SSE + Flutter package | Universal: 2 líneas en cualquier app del SBOS |
| Auth dev | Laravel Sanctum | Sin fricción |
| Auth prod | Keycloak 24 (Apache 2.0) | SSO del ecosistema SBOS |
| Función DB | catalog.RATE() extensión C .so | Nanosegundos/llamada. IMMUTABLE+SPI. 50.000 conv. en 50ms |
| Stablecoins | USDT + USDC vía CriptoYa API | Gratuita, 120 req/min, USDT/BOB y USDC/BOB tiempo real |
| Paralelo BOB | Mediana Binance P2P + CriptoYa | El termómetro más preciso del valor real del boliviano |
| Referencial BCB | VRD/VRV publicado desde dic-2025 | Operaciones reales EIF — mercado mayorista formal Bolivia |

---

## Las 4 cotizaciones del dólar en Bolivia (2026)

```
1. Oficial fijo BCB       Bs 6.86 compra / 6.96 venta   → fuente: bcb_bolivia (Excel diario)
2. Referencial BCB (VRD)  Bs 8.x-9.x variable diario    → fuente: bcb_referencial (desde dic-2025)
3. USDT P2P paralelo      Bs ~10.05 (mediana Binance)    → fuente: criptoya_p2p (cada hora)
4. USDC P2P               Bs ~10.02 (ligeramente menor)  → fuente: criptoya_p2p (cada hora)
```

## Modos de operación

```
AUTH_DRIVER=sanctum   + SYNC_MODE=internal + DB_MODE=local    → Standalone (dev)
AUTH_DRIVER=keycloak  + SYNC_MODE=biedata  + DB_MODE=external → SBOS Acoplado (prod)
```

## Restricciones no negociables

- NULL prohibido en todos los campos — siempre valor explícito
- `catalog.RATE()` implementada como extensión C `.so` — no PL/pgSQL
- Backfill solo entre 01:00–04:00, máximo 100 req/noche por fuente
- USDT y USDC se almacenan como `is_stablecoin=true`, no como monedas fiat ISO
- SLA: 99.5% disponibilidad, RTO 2h, RPO 24h
- El sistema funciona completo en modo standalone sin ninguna dependencia del SBOS

---
_SKULL · SBOS · SmartRates · 000-INDICE · v2.0 · 2026-05-23_
