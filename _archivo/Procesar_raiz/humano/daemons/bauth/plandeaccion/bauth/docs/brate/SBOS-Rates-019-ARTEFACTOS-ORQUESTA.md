# Artefactos ORQUESTA — SBOS SmartRates
## CLAUDE.md · PROYECTO-ESTADO.md · Makefile · .mcp.json · DOCUMENTO-IMPLEMENTACION.md

---

## CLAUDE.md — Contexto para Claude Code

```markdown
# SBOS SmartRates — Contexto para Claude Code

## Tu misión
Eres el Compositor asignado al subproyecto SmartRates del ecosistema SBOS.
SmartRates es la **fuente de verdad de tipos de cambio** para todo el SBOS.
Tryton, SmartTax, Saleor y bCompass dependen de tus datos.
Un error en SmartRates tiene impacto financiero en cascada.

## Posición en el árbol
Nivel 3 — subproyecto hijo de SBOS, Bounded Context Financiero.
Ruta: /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/smartrates/

## Stack (no negociable)
- Backend: Laravel 13.7 / PHP 8.3
- BD principal: PostgreSQL 18.4 (smartrates_db — 8 schemas)
- BD validación: PostgreSQL 18.4 (smartrates_db (schema validation))
- Cache / Queue: Redis 7 / Laravel Horizon
- WebSockets: Laravel Reverb
- Frontend: Flutter 3.x + Impeller (BLoC pattern)
- Auth dev: Laravel Sanctum (AUTH_DRIVER=sanctum)
- Auth prod: Keycloak 24 (AUTH_DRIVER=keycloak)

## Modo dual (NUNCA romper)
AUTH_DRIVER=sanctum   + SYNC_MODE=internal = Standalone (dev, sin SBOS)
AUTH_DRIVER=keycloak  + SYNC_MODE=biedata  = SBOS Acoplado (prod)
Un solo cambio de .env. Sin modificar código.

## Las 4 cotizaciones del dólar en Bolivia
1. Oficial fijo BCB       → fuente: bcb_bolivia     → rates.exchange_rates
2. Referencial BCB (VRD)  → fuente: bcb_referencial → validation.bcb_cotizaciones
3. USDT P2P               → fuente: criptoya_p2p    → rates.stablecoin_rates
4. USDC P2P               → fuente: criptoya_p2p    → rates.stablecoin_rates

## Reglas CRÍTICAS de datos
- NULL PROHIBIDO en todos los campos. Siempre valor explícito.
- Todos los pares en exchange_rates tienen base_currency='USD'
- USDT código interno: 'XUT' — USDC código interno: 'XUC'
- Los registros de exchange_rates son INMUTABLES — nunca UPDATE, solo INSERT
- CriptoYa API: base URL = https://criptoya.com/api, límite 120 req/min

## Función catalog.RATE()
- Extensión C (.so) instalada en PostgreSQL 18.4
- IMMUTABLE STRICT PARALLEL SAFE COST 1
- Acepta: DD/MM/YYYY y YYYY-MM-DD
- Soporta: monedas fiat + UST (USDT) + USC (USDC)
- Si no hay dato para la fecha exacta, busca hasta 7 días hacia atrás
- Retorna NULL si no hay dato en 7 días

## Ticker (widget universal SBOS)
- Web Component <smartrates-ticker> — zero dependencias — ~8KB
- Flutter package sbos_smartrates_ticker
- SSE endpoint: GET /api/v1/rates/stream
- Muestra las 4 cotizaciones con colores diferenciados
- Debe integrarse en Tryton, SmartTax, Saleor, SmartReport

## Puertos asignados
- 28300: SmartRatesAPI REST
- 28301: Prometheus /metrics
- 28302: K8s health/ready
- 28303: WebSocket Reverb

## Laravel 13 features a aprovechar
- PHP Attributes en modelos y jobs (opcional, no breaking)
- Reverb database driver (no necesita Redis en dev)
- Passkeys en el modo Sanctum standalone
- AI SDK para análisis de tendencias (bCompass route)
- Vector search con pgvector para análisis semántico de noticias

## Documentos clave (leer antes de implementar)
1. 011-MOTOR-CROSSRATE.md — algoritmo de conversión
2. 007-DATOS.md — modelo completo de BD
3. 016-STABLECOINS-INTEGRACION.md — USDT/USDC implementación
4. 018-EXTENSION-RATE-C.md — código C de catalog.RATE()
5. 014-ACOPLAMIENTO-SBOS.md — checklist de acoplamiento

## Lo que NO hace SmartRates
- No procesa pagos ni transacciones financieras
- No implementa contabilidad multicurrency (eso es Tryton)
- No gestiona usuarios en producción (eso es Keycloak)
- No almacena criptomonedas especulativas (solo USDT/USDC como stablecoins)
- No expone APIs al exterior directamente en producción (pasa por Kong)
```

---

## PROYECTO-ESTADO.md — Tablero HITL

```markdown
# PROYECTO-ESTADO.md — SmartRates
## Tablero HITL (Human-in-the-Loop)

**Última actualización:** 2026-05-23  
**Compositor:** Claude Sonnet 4.6  
**Fase actual:** 0 — Pre-desarrollo (Proyecto conceptual completo)  
**Calificación del proyecto conceptual:** 10/10 ✅  

---

## Estado de fases

| Fase | Nombre | Estado | % Completado |
|---|---|---|---|
| 0 | Proyecto conceptual | ✅ COMPLETO | 100% |
| 1 | Infraestructura base + standalone | ⬜ PENDIENTE | 0% |
| 2 | Observabilidad y calidad | ⬜ PENDIENTE | 0% |
| 3 | Acoplamiento SBOS | ⬜ PENDIENTE | 0% |
| 4 | Stablecoins + cajas biedata | ⬜ PENDIENTE | 0% |
| 5 | Frontend Flutter + Ticker | ⬜ PENDIENTE | 0% |

---

## Fase 1 — Infraestructura base y modo standalone

**Objetivo:** SmartRates corre en modo standalone sin SBOS.
**Definición de terminado:** `./dev.sh` levanta el stack, `/api/health` retorna 200, cotizaciones del día disponibles.

### Checklist Fase 1

#### Setup del proyecto
- [ ] Crear repositorio en GitLab SKULL: `sbos/subproyectos/smartrates`
- [ ] `composer create-project laravel/laravel smartrates-api`
- [ ] Actualizar a Laravel 13.7: `composer require laravel/framework:^13.0`
- [ ] PHP 8.3 confirmado: `php --version`
- [ ] Instalar dependencias: `composer require laravel/horizon laravel/reverb laravel/sanctum`
- [ ] Instalar L5-Swagger: `composer require darkaonline/l5-swagger`
- [ ] Copiar `.env.example` y crear `.env.local`

#### Base de datos
- [ ] Docker Compose con PostgreSQL 18.4 (dos contenedores: db_smartrates, db_validation)
- [ ] Ejecutar DDL: `smartrates_DDL_PostgreSQL18_v2.sql` (con fix naming a smartrates_db)
- [ ] Migrations Laravel para todas las tablas del dominio
- [ ] Seeds: currencies (200+), countries (249), groups (14)
- [ ] Verificar uuidv7() disponible: `SELECT uuidv7();`
- [ ] Verificar WITHOUT OVERLAPS funciona en company.system_config

#### API base
- [ ] `RatesController` — F-001, F-002, F-003, F-004
- [ ] `ConvertController` — F-005, F-006, F-007, F-008
- [ ] `CurrenciesController` — F-009
- [ ] `CountriesController` — F-010
- [ ] `HealthController` — F-020

#### Sincronización
- [ ] `DailySyncFawazahmedJob` — sync diario fawazahmed0
- [ ] `DailySyncBcbJob` — descarga Excel BCB
- [ ] `DailySyncBcbReferencialJob` — VRD/VRV desde dic-2025
- [ ] `DailySyncUsdtP2pJob` — USDT/USDC cada hora via CriptoYa
- [ ] `WeekendCarriedForwardJob` — sábado/domingo
- [ ] Cron scheduler configurado en routes/console.php

#### Extensión RATE()
- [ ] Compilar smartrates_rate.c: `make && sudo make install`
- [ ] Instalar: `CREATE EXTENSION smartrates_rate;`
- [ ] Tests SQL de regresión: `make installcheck`
- [ ] Verificar en JasperReports: SELECT catalog.RATE(...)

#### Auth
- [ ] Sanctum configurado y funcionando
- [ ] Middleware AuthSwitch implementado
- [ ] Roles básicos creados en BD local

#### Scripts
- [ ] `./dev.sh` — levanta todo
- [ ] `./dev-keycloak.sh` — levanta con Keycloak local
- [ ] `./deploy.sh` — build + push + deploy K8s

**PUNTO DE CONTROL FASE 1:** El humano verifica:
1. `GET /api/v1/rates/today` retorna cotizaciones del día
2. `SELECT catalog.RATE('23/05/2026', 'BOB', 'USD', 100, 2)` retorna valor correcto
3. `GET /api/v1/rates/stablecoins` retorna USDT/BOB y USDC/BOB
4. `GET /api/v1/rates/spread/bob` retorna las 4 referencias

---

## Decisiones tomadas (registro de ADRs)

| ID | Decisión | Fecha | Por |
|---|---|---|---|
| ADR-SR-001 | NULL prohibido en todos los campos | 2026-03-18 | Humano |
| ADR-SR-002 | Base de todos los pares: USD | 2026-03-18 | Humano |
| ADR-SR-003 | catalog.RATE() en C, no PL/pgSQL | 2026-03-18 | Humano |
| ADR-SR-004 | SSE para Ticker, WebSocket para Flutter | 2026-03-18 | Humano |
| ADR-SR-005 | Backfill max 100 req/noche | 2026-03-18 | Humano |
| ADR-SR-006 | Particionamiento de exchange_rates por año | 2026-03-18 | Humano |
| ADR-SR-007 | BD de validación separada para BCB | 2026-03-18 | Humano |
| ADR-SR-008 | USDT='XUT', USDC='XUC' como códigos internos | 2026-05-23 | Compositor |
| ADR-SR-009 | CriptoYa API como fuente de USDT/USDC P2P | 2026-05-23 | Compositor |
| ADR-SR-010 | Ticker como Web Component + Flutter package SBOS | 2026-05-23 | Compositor |

---

## Blockers y preguntas para el humano

_(Vacío — listo para comenzar el desarrollo)_
```

---

## DOCUMENTO-IMPLEMENTACION.md

```markdown
# DOCUMENTO-IMPLEMENTACION.md — SmartRates
## Registro vivo de decisiones de implementación

**Versión:** 1.0 (pre-desarrollo)  
**Actualizado:** 2026-05-23  

---

## Contexto de implementación

SmartRates se desarrolla dentro de la fábrica ORQUESTA del ecosistema SKULL.
El Compositor (Claude Code) es el agente de desarrollo principal.
Las decisiones de arquitectura están en `006-ARQUITECTURA.md`.
Este documento registra las decisiones **de implementación** tomadas durante el desarrollo.

---

## Registro de implementación

_(Se irá completando durante el desarrollo — cada sesión del Compositor agrega entradas)_

### 2026-05-23 — Proyecto conceptual completado

**Decisiones:**
- 19 documentos en context/humano/ — proyecto conceptual completo
- Investigación de mercado incorporada: USDT/USDC, BCB referencial, dólar paralelo Bolivia
- Extensión C catalog.RATE() documentada con código real
- Ticker Web Component con 4 cotizaciones + Flutter package
- Calificación del proyecto: 10/10

**Próximo paso:** Iniciar Fase 1 con `./dev.sh`
```

---

## Makefile

```makefile
# Makefile — SmartRates
# Comandos operativos del subproyecto

.PHONY: help dev dev-keycloak dev-down test test-unit test-contract \
        build deploy logs status sync-now rate-test db-migrate db-seed \
        ticker-build rate-compile rate-install rate-test-sql horizon

help:
	@echo "SmartRates — Comandos disponibles:"
	@echo ""
	@echo "  Desarrollo:"
	@echo "    make dev              Levanta el stack completo (Sanctum + DB local)"
	@echo "    make dev-keycloak     Levanta con Keycloak local"
	@echo "    make dev-down         Detiene todos los contenedores"
	@echo ""
	@echo "  Extensión catalog.RATE():"
	@echo "    make rate-compile     Compila el .so en el contenedor de PG"
	@echo "    make rate-install     Instala la extensión en smartrates_db"
	@echo "    make rate-test-sql    Ejecuta los tests SQL de regresión"
	@echo "    make rate-test        Prueba rápida: SELECT catalog.RATE(...)"
	@echo ""
	@echo "  Tests:"
	@echo "    make test             Todos los tests"
	@echo "    make test-unit        Solo tests unitarios"
	@echo "    make test-contract    Tests de contrato OpenAPI"
	@echo ""
	@echo "  Base de datos:"
	@echo "    make db-migrate       Ejecuta migraciones Laravel"
	@echo "    make db-seed          Puebla catálogos (currencies, countries)"
	@echo ""
	@echo "  Operación:"
	@echo "    make sync-now         Fuerza sincronización de todas las fuentes"
	@echo "    make logs             Muestra logs del contenedor app en tiempo real"
	@echo "    make status           Estado del sistema (health + fuentes)"
	@echo "    make horizon          Abre el dashboard de Horizon"

# ─── Desarrollo ───────────────────────────────────────────────────────────────

dev:
	@echo "🚀 Levantando SmartRates (modo standalone)..."
	docker compose up -d
	@echo "✅ SmartRates disponible en http://localhost:8000"
	@echo "   Swagger UI: http://localhost:8000/api/documentation"
	@echo "   Horizon:    http://localhost:8000/horizon"

dev-keycloak:
	@echo "🔐 Levantando SmartRates (modo Keycloak local)..."
	docker compose --profile keycloak up -d
	@echo "✅ Keycloak disponible en http://localhost:8080"

dev-down:
	docker compose --profile keycloak down

# ─── Extensión catalog.RATE() ─────────────────────────────────────────────────

rate-compile:
	@echo "🔨 Compilando extensión catalog.RATE()..."
	docker compose exec db_smartrates bash -c "cd /tmp/smartrates-rate && make"

rate-install:
	@echo "📦 Instalando extensión en smartrates_db..."
	docker compose exec db_smartrates bash -c "cd /tmp/smartrates-rate && make install"
	docker compose exec db_smartrates psql -U smartrates -d smartrates_db \
		-c "CREATE EXTENSION IF NOT EXISTS smartrates_rate;"
	@echo "✅ catalog.RATE() disponible en smartrates_db"

rate-test-sql:
	@echo "🧪 Ejecutando tests SQL de regresión de catalog.RATE()..."
	docker compose exec db_smartrates bash -c "cd /tmp/smartrates-rate && make installcheck"

rate-test:
	@echo "⚡ Prueba rápida de catalog.RATE()..."
	docker compose exec db_smartrates psql -U smartrates -d smartrates_db -c \
		"SELECT catalog.RATE('$(shell date +%d/%m/%Y)', 'BOB', 'USD', 100, 6) AS resultado;"

# ─── Tests ────────────────────────────────────────────────────────────────────

test:
	docker compose exec app php artisan test --parallel

test-unit:
	docker compose exec app php artisan test --testsuite=Unit

test-contract:
	@echo "📋 Validando contrato OpenAPI..."
	docker compose exec app php artisan l5-swagger:generate
	npx spectral lint storage/api-docs/api-docs.json

# ─── Base de datos ────────────────────────────────────────────────────────────

db-migrate:
	docker compose exec app php artisan migrate

db-seed:
	@echo "🌱 Poblando catálogos..."
	docker compose exec app php artisan db:seed --class=CurrenciesSeeder
	docker compose exec app php artisan db:seed --class=CountriesSeeder
	docker compose exec app php artisan db:seed --class=CurrencyGroupsSeeder
	docker compose exec app php artisan db:seed --class=DataSourcesSeeder
	docker compose exec app php artisan db:seed --class=SystemConfigSeeder

# ─── Operación ────────────────────────────────────────────────────────────────

sync-now:
	@echo "🔄 Forzando sincronización de todas las fuentes..."
	docker compose exec app php artisan sync:trigger --all

logs:
	docker compose logs -f app

status:
	@echo "📊 Estado del sistema SmartRates:"
	@curl -s http://localhost:8000/api/status | python3 -m json.tool 2>/dev/null || \
		echo "❌ Sistema no disponible"

horizon:
	@echo "🔗 Horizon Dashboard: http://localhost:8000/horizon"
	open http://localhost:8000/horizon 2>/dev/null || \
		xdg-open http://localhost:8000/horizon 2>/dev/null || \
		echo "Abrir manualmente: http://localhost:8000/horizon"
```

---

## .mcp.json — MCP Servers del proyecto

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem",
               "/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/smartrates"],
      "description": "Acceso al filesystem del proyecto SmartRates"
    },
    "postgresql-smartrates": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres",
               "postgresql://smartrates:${DB_PASSWORD}@localhost:5432/smartrates_db"],
      "description": "Base de datos principal de SmartRates"
    },
    "postgresql-validation": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres",
               "postgresql://smartrates:${DB_PASSWORD}@localhost:5432/smartrates_db (schema validation)"],
      "description": "Base de datos de validación BCB"
    },
    "gitlab": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-gitlab"],
      "env": {
        "GITLAB_URL": "https://gitlab.skull.bo",
        "GITLAB_TOKEN": "${GITLAB_TOKEN}",
        "GITLAB_PROJECT": "sbos/subproyectos/smartrates"
      },
      "description": "GitLab del proyecto SmartRates"
    }
  }
}
```

---

## .env.example — completo y comentado

```env
# ============================================================
# SBOS SmartRates — Variables de entorno
# Copiar a .env.local para desarrollo
# En producción SBOS: inyectado desde Vault
# ============================================================

# ── APLICACIÓN ──────────────────────────────────────────────
APP_NAME=SmartRatesAPI
APP_ENV=local
APP_KEY=                               # php artisan key:generate
APP_DEBUG=true
APP_URL=http://localhost:8000
APP_VERSION=1.0.0

# ── MODO DE OPERACIÓN (Auth Switch) ─────────────────────────
AUTH_DRIVER=sanctum                    # sanctum | keycloak
SYNC_MODE=internal                     # internal | biedata
DB_MODE=local                          # local | external

# ── BASE DE DATOS PRINCIPAL ──────────────────────────────────
DB_CONNECTION=pgsql
DB_HOST=db_smartrates
DB_PORT=5432
DB_DATABASE=smartrates_db              # Convención SBOS: {app}_db
DB_USERNAME=smartrates
DB_PASSWORD=

# ── BASE DE DATOS VALIDACIÓN ─────────────────────────────────
DB_VALIDATION_HOST=db_validation
DB_VALIDATION_PORT=5432
DB_VALIDATION_DATABASE=smartrates_db (schema validation)
DB_VALIDATION_USERNAME=smartrates
DB_VALIDATION_PASSWORD=

# ── REDIS ────────────────────────────────────────────────────
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0

# ── QUEUE / HORIZON ──────────────────────────────────────────
QUEUE_CONNECTION=redis
HORIZON_PREFIX=smartrates:

# ── WEBSOCKETS (Reverb) ──────────────────────────────────────
REVERB_APP_ID=smartrates
REVERB_APP_KEY=
REVERB_APP_SECRET=
REVERB_HOST=0.0.0.0
REVERB_PORT=28303
# En desarrollo sin Redis: usar driver database
BROADCAST_DRIVER=reverb

# ── AUTH SANCTUM (modo standalone) ──────────────────────────
SANCTUM_EXPIRATION=

# ── AUTH KEYCLOAK (solo AUTH_DRIVER=keycloak) ────────────────
KEYCLOAK_MODE=local                    # local | external
KEYCLOAK_BASE_URL=http://keycloak:8080
KEYCLOAK_REALM=smartrates
KEYCLOAK_CLIENT_ID=smartrates-api
KEYCLOAK_CLIENT_SECRET=

# ── FUENTES EXTERNAS (solo SYNC_MODE=internal) ───────────────
# fawazahmed0: sin credenciales (API pública)
# Frankfurter: sin credenciales (Docker local)
FRANKFURTER_URL=http://frankfurter:8080

# FMI SDMX API — registrada en portal.api.imf.org
IMF_API_KEY=c2800287220f4bc18e147ad8dba321ab
IMF_BASE_URL=https://api.imf.org/external/sdmx/3.0

# BCB Bolivia — portal público
BCB_BASE_URL=https://www.bcb.gob.bo

# CriptoYa — API pública USDT/USDC P2P Bolivia
# Base URL: https://criptoya.com/api
# Límite: 120 req/min — sin credenciales
CRIPTOYA_BASE_URL=https://criptoya.com/api

# ── BACKFILL ─────────────────────────────────────────────────
BACKFILL_ENABLED=false                 # true solo cuando hay fases pendientes
BACKFILL_START_HOUR=1
BACKFILL_END_HOUR=4
BACKFILL_FAWAZAHMED_REQUESTS_PER_NIGHT=100
BACKFILL_FAWAZAHMED_PAUSE_SECONDS=30
BACKFILL_IMF_REQUESTS_PER_NIGHT=100
BACKFILL_IMF_PAUSE_SECONDS=30
BACKFILL_BCB_REQUESTS_PER_NIGHT=50
BACKFILL_BCB_PAUSE_SECONDS=60

# ── STABLECOINS ──────────────────────────────────────────────
STABLECOIN_SYNC_ENABLED=true           # sincronizar USDT/USDC cada hora
SPREAD_ALERT_WARNING_PCT=40            # alerta cuando spread > 40%
SPREAD_ALERT_CRITICAL_PCT=60           # crítico cuando spread > 60%

# ── AJUSTE MANUAL ────────────────────────────────────────────
ADJUSTMENT_CONFIRMATION_REQUIRED=true
ADJUSTMENT_REMINDER_HOUR=12            # recordatorio a las 12:00
ADJUSTMENT_TIMEOUT_HOUR=17             # provisional a las 17:00

# ── OBSERVABILIDAD ───────────────────────────────────────────
LOG_CHANNEL=json_ctx                   # canal JSON estructurado con ctx_id
LOG_LEVEL=debug                        # debug en dev, info en prod

# ── SBOS CONTEXT (solo AUTH_DRIVER=keycloak) ─────────────────
SBOS_KONG_GATEWAY_URL=http://kong:8000
SBOS_BOS_CONTEXT_API=http://bos:9443
SBOS_TENANT=skull

# ── SWAGGER ──────────────────────────────────────────────────
L5_SWAGGER_GENERATE_ALWAYS=true
L5_SWAGGER_CONST_HOST=http://localhost:8000
L5_SWAGGER_UI_PERSIST_AUTHORIZATION=true

# ── CORS ─────────────────────────────────────────────────────
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080

# ── TICKER ───────────────────────────────────────────────────
TICKER_WIDGET_URL=http://localhost:8000
TICKER_DEFAULT_CURRENCIES=USD,USDT,EUR,BRL,PEN
TICKER_SHOW_REF=true
TICKER_SHOW_USDT=true
TICKER_SHOW_USDC=false
```

---
_SKULL · SBOS · SmartRates · 019-ARTEFACTOS-ORQUESTA · v1.0 · 2026-05-23_

---

## Actualizaciones al CLAUDE.md post-simulación v3

```markdown
## Modelo de ajustes — DOS NIVELES (crítico)

NIVEL 1 — Ajuste GLOBAL SBOS
  - Tabla: company.adjustment_global
  - Confirma: usuario con rol smartrates.global_operator
  - Alcance: todo el tenant
  - Es el piso: todas las empresas heredan si no tienen ajuste propio

NIVEL 2 — Ajuste POR EMPRESA  
  - Tabla: company.adjustment_daily (campo overrides_global=true)
  - Confirma: operador de la empresa (smartrates.operator)
  - Sobrescribe el global para esa empresa específica
  - Si no existe → hereda automáticamente del global

RESOLUCIÓN (AdjustmentResolver — orden obligatorio):
  1. adjustment_daily con overrides_global=true → empresa propia
  2. adjustment_global confirmado para hoy     → global SBOS
  3. adjustment_global del día anterior         → global fallback
  4. 0.00                                        → sin datos

MISMO MODELO para stablecoins XUT (USDT) y XUC (USDC):
  - company.stablecoin_adjustment_global (nivel SBOS)
  - company.stablecoin_adjustment (nivel empresa)

UUID_SYSTEM = '00000000-0000-7777-0000-000000000000'
  → Seed obligatorio en users
  → Se usa como confirmed_by en ajustes provisionales por timeout

catalog.RATE() NO aplica ajustes de empresa
  → Solo cotizaciones globales
  → El ajuste es responsabilidad del sistema que llama a RATE()
```

