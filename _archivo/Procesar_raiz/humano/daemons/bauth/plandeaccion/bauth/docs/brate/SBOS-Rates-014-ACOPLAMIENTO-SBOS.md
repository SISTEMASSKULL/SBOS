# Acoplamiento al Ecosistema SBOS — SBOS SmartRates

---

## Posición en el árbol SBOS

SmartRates es un **subproyecto de Nivel 3** del ecosistema SBOS, en el Bounded Context Financiero:

```
SBOS (ecosistema — Nivel 2)
└── subproyectos/
    ├── smarttax/
    ├── smartreport/
    └── smartrates/          ← Aquí. BC: Financiero.
```

**Ruta física en el sistema de archivos:**
```
/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/smartrates/
```

**Rol en el ecosistema:** SmartRates es la **fuente de verdad de tipos de cambio** para todo el SBOS. Tryton (contabilidad), SmartTax (tributación), Saleor (e-commerce) y bCompass (BI) la consumen. Un error en SmartRates tiene impacto financiero en cascada.

---

## El principio del modo dual

SmartRates opera en dos modos completamente funcionales. El cambio entre modos **no requiere modificar código** — solo cambiar variables de entorno y reiniciar.

```
AUTH_DRIVER=sanctum   + SYNC_MODE=internal + DB_MODE=local   = Modo Standalone
AUTH_DRIVER=keycloak  + SYNC_MODE=biedata  + DB_MODE=external = Modo SBOS Acoplado
```

**Garantía:** cada funcionalidad del sistema funciona en ambos modos sin degradación.

---

## Tabla de diferencias por modo

| Aspecto | Modo Standalone | Modo SBOS Acoplado |
|---|---|---|
| Autenticación | Laravel Sanctum — token personal en BD local | Keycloak OIDC — JWT firmado por Keycloak del tenant |
| Autorización | Roles simples en tabla `users` local | BitMask 64-bit del JWT, bits 20-22 |
| `ctx_id` en logs | `''` (string vacío — nunca NULL) | Header `X-SBOS-CtxId` inyectado por Kong |
| Entrada de tráfico | Directa a SmartRatesAPI (puerto 28300) | A través de Kong API Gateway |
| Sincronización externa | Jobs Laravel Horizon | Cajas biedata activadas por bKernel |
| Auditoría | `security.audit_log` local (sin ctx_id) | `security.audit_log` + `bkernel.audit_events` cruzados por ctx_id |
| Búsqueda | No indexado en bSearch | bSearch indexa desde el WAL automáticamente |
| Base de datos | PostgreSQL local en Docker | PostgreSQL Patroni HA del cluster SBOS |
| Secrets | `.env.local` (solo desarrollo, en .gitignore) | HashiCorp Vault — inyectado al iniciar el pod |
| Red | Sin restricciones | Calico NetworkPolicy default-deny + Linkerd mTLS |
| Métricas | `/metrics` disponible (Prometheus) | Stack LGTM del SBOS recolecta automáticamente |
| Fuentes externas | HTTP directo desde el job | biedata ejecuta las cajas (sin HTTP directo del pod) |

---

## Cómo llega la autenticación en modo SBOS

```
Usuario → Kong
  Kong verifica el JWT de Keycloak (RS256)
  Kong consulta la Context API del bos para validar el ctx_id
  Kong inyecta los siguientes headers en el request:

    X-SBOS-CtxId:    ctx-88291-a4f9      ← Identificador de la sesión
    X-SBOS-Tenant:   skull               ← Tenant (realm)
    X-SBOS-Empresa:  maya                ← Empresa del usuario
    X-SBOS-Sucursal: lapaz               ← Sucursal
    X-SBOS-User:     3397708             ← user_id
    X-SBOS-BitMask:  0x00000000000A3F21  ← Máscara de permisos

  Request llega a SmartRatesAPI (puerto 28300)
  Middleware SBOSContextInjector lee los headers y los pone en $request
  Middleware BitMaskAuthorize verifica los bits 20-22 para el endpoint
  Controller procesa
  AuditService escribe en security.audit_log con ctx_id
  Response vuelve a Kong → usuario
```

**En modo Standalone:** Kong no existe. El request llega directamente. El JWT es un token de Sanctum. ctx_id es `''`. No hay headers X-SBOS-*.

---

## Roles Keycloak requeridos

SmartRates debe registrar en el realm del tenant los siguientes roles:

| Rol | Descripción |
|---|---|
| `smartrates.admin` | Acceso completo — configuración, sync, audit, backfill |
| `smartrates.operator` | Operación diaria — confirmar ajuste, ver panel de sync |
| `smartrates.readonly` | Solo lectura de cotizaciones y conversión |
| `smartrates.api` | Service account — acceso API para integraciones |

**Archivo de configuración:** `resources/keycloak/smartrates-realm-roles.json`

---

## Integración con PostgreSQL y bKernel

### Naming de bases de datos (convención SBOS)

```sql
-- Nombre correcto para producción SBOS:
smartrates_db           -- base principal
smartrates_db (schema validation) -- base de validación
```

### Lo que bKernel captura automáticamente

bKernel escucha el WAL de PostgreSQL. Cada INSERT/UPDATE en SmartRates es capturado y registrado en `bkernel_db.audit_events` con el `ctx_id` del request que lo originó. SmartRates no necesita hacer nada especial.

**Regla anti-loop:** Si SmartRates recibe una escritura desde bKernel (identificada por `origin='bkernel'`), no la re-emite como evento propio. Esto previene bucles infinitos en el WAL.

---

## Cajas biedata requeridas

En modo `SYNC_MODE=biedata`, las siguientes cajas deben existir en el directorio del proyecto:

```
boxes/
└── import/
    ├── fawazahmed0_daily/    ← sync diario 200+ monedas
    │   └── box.yml
    ├── imf_sdmx_monthly/     ← sync mensual FMI
    │   └── box.yml
    ├── bcb_bolivia_daily/    ← descarga Excel BCB L-V
    │   └── box.yml
    └── frankfurter_fallback/ ← respaldo BCE cuando fawazahmed0 falla
        └── box.yml
```

**Flujo de una caja (ejemplo fawazahmed0_daily):**
```
Activador: cron SBOS 06:00 → bKernel → Redis Stream → biedata
VALIDATE:   ¿Ya existe cotización para hoy? → Si existe, abortar
AUTHENTICATE: No requiere (API pública)
EXTRACT:    GET https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/...
TRANSFORM:  Normalizar 200+ monedas al formato de rates.exchange_rates
LOAD:       UPSERT masivo en smartrates_db.rates.exchange_rates (source_code='fawazahmed0')
AUDIT:      INSERT en sync.sync_log con ctx_id del cron activador
```

---

## Patrones bSearch

SmartRates declara sus entidades buscables para que bSearch las indexe desde el WAL:

```yaml
# patterns/smartrates/currencies.yml
entity: catalog.currencies
fields_fulltext: [code, name_es_singular, name_es_plural, name_en_singular]
fields_semantic: [name_es_singular, name_en_singular]
tenant_isolation: true
```

```yaml
# patterns/smartrates/exchange_rates.yml
entity: rates.exchange_rates
fields_fulltext: [base_currency, quote_currency, source_code]
fields_numeric:  [rate_official, rate_buy, rate_sell, rate_mid]
date_field: rate_date
tenant_isolation: true
```

---

## Ruta bCompass

SmartRates declara una ruta de análisis para bCompass:

```yaml
# compass_routes/smartrates_volatility_analyst.yml
type: analyst
name: "Análisis de volatilidad de cotizaciones SmartRates"
governance: 1
schedule: "0 8 * * *"
query: |
  SELECT
    base_currency, quote_currency,
    STDDEV(rate_official)                         AS volatilidad_desv,
    MAX(rate_official) - MIN(rate_official)       AS volatilidad_rango,
    ROUND(AVG(rate_official), 8)                  AS promedio,
    COUNT(*)                                      AS dias_con_dato
  FROM rates.exchange_rates
  WHERE rate_date >= NOW() - INTERVAL '30 days'
    AND type_code   = 'official_daily'
    AND quality     = 'high'
  GROUP BY 1, 2
  HAVING STDDEV(rate_official) > 0.001
  ORDER BY volatilidad_desv DESC
  LIMIT 20
output: "Top 20 monedas con mayor volatilidad en los últimos 30 días vs USD"
```

---

## Ficha SBOS — manifest.yml

```yaml
name: smartrates
display_name: "SBOS Smart Rates"
version: "1.0.0"
description: "Exchange Rate Management System — fuente de verdad de cotizaciones"
bounded_context: financial
status: beta

ports:
  api:      28300    # SmartRatesAPI REST
  metrics:  28301    # Prometheus scrape
  health:   28302    # K8s liveness/readiness
  reverb:   28303    # WebSocket Laravel Reverb

databases:
  - name: smartrates_db
    engine: postgresql18
    schemas: [catalog, rates, company, sync, security, broadcast]
  - name: smartrates_db (schema validation)
    engine: postgresql18
    schemas: [validation, historical]

depends_on:
  - postgresql
  - redis
  - keycloak      # solo AUTH_DRIVER=keycloak
  - kong          # solo modo SBOS

vault_paths:
  - "secret/tenants/{realm}/smartrates/db"
  - "secret/tenants/{realm}/smartrates/redis"
  - "secret/tenants/{realm}/smartrates/keycloak"
  - "secret/tenants/{realm}/smartrates/imf-api-key"
  - "secret/tenants/{realm}/smartrates/bcb-config"

feature_flags:
  status: beta

resources:
  requests: {cpu: "250m", memory: "512Mi"}
  limits:   {cpu: "1000m", memory: "2Gi"}
```

---

## yaml_engine.yml — despliegue K8s

```yaml
image: registry.skull.bo/smartrates-api:1.0.0
replicas: 2
namespace: "{realm}-smartrates"

env_from:
  - configmap: smartrates-config
  - secret: smartrates-secrets

health_checks:
  liveness:  {path: /api/health, port: 28302, initial_delay: 30s, period: 10s}
  readiness: {path: /api/ready,  port: 28302, initial_delay: 15s, period: 5s}

network_policies:
  - allow_from: kong-gateway      # solo Kong puede enviar requests
  - allow_from: bkernel           # bKernel puede escribir en la BD
  - allow_to:   postgresql        # SmartRates escribe en PostgreSQL
  - allow_to:   redis             # SmartRates usa Redis
  - deny_all_other: true          # todo lo demás bloqueado por Calico
```

---

## Estructura de directorios del proyecto (ORQUESTA)

```
smartrates/
├── CLAUDE.md                        # Contexto para Claude Code
├── PROYECTO-ESTADO.md               # Tablero HITL
├── DOCUMENTO-IMPLEMENTACION.md
├── Makefile
├── .mcp.json
├── .env.example
├── .gitignore
│
├── context/
│   ├── humano/
│   │   ├── 000-INDICE.md
│   │   ├── 001-VISION.md
│   │   ├── 002-DOMINIO.md
│   │   ├── 003-USUARIOS.md
│   │   ├── 004-FUNCIONALIDADES.md
│   │   ├── 005-INTEGRACIONES.md
│   │   ├── 006-ARQUITECTURA.md
│   │   ├── 007-DATOS.md
│   │   ├── 008-SEGURIDAD.md
│   │   ├── 009-OPERACION.md
│   │   ├── 010-GLOSARIO-TECNICO.md
│   │   ├── 011-MOTOR-CROSSRATE.md
│   │   ├── 012-BACKFILL-HISTORICO.md
│   │   ├── 013-FRONTEND-FLUTTER.md
│   │   └── 014-ACOPLAMIENTO-SBOS.md  ← este documento
│   ├── ia/
│   └── sintetizado/
│
├── src/
│   └── smartrates-api/              # Laravel 13
│
├── boxes/                           # Cajas biedata
│   └── import/
│       ├── fawazahmed0_daily/
│       ├── imf_sdmx_monthly/
│       ├── bcb_bolivia_daily/
│       └── frankfurter_fallback/
│
├── patterns/                        # Patrones bSearch
│   └── smartrates/
│       ├── currencies.yml
│       └── exchange_rates.yml
│
├── compass_routes/                  # Rutas bCompass
│   └── smartrates_volatility_analyst.yml
│
├── resources/
│   ├── keycloak/
│   │   └── smartrates-realm-roles.json
│   ├── dashboard.json               # Grafana dashboard (obligatorio SBOS)
│   ├── kong-routes.yml
│   ├── manifest.yml                 # Ficha SBOS
│   └── yaml_engine.yml
│
└── tests/
    ├── smoke/
    ├── unit/
    ├── contract/
    └── regression/
```

---

## Checklist de acoplamiento SBOS

### Identidad
- [ ] Realm Keycloak configurado con 4 roles `smartrates.*`
- [ ] Middleware `SBOSContextInjector` extrae headers de Kong
- [ ] Middleware `BitMaskAuthorize` verifica bits 20-22
- [ ] Todos los logs incluyen `ctx_id` (vacío en standalone, nunca NULL)

### Datos
- [ ] BDs nombradas `smartrates_db` y `smartrates_db (schema validation)`
- [ ] Columna `ctx_id VARCHAR(50) NOT NULL DEFAULT ''` en `security.audit_log`
- [ ] Patrones bSearch declarados (currencies.yml, exchange_rates.yml)
- [ ] Cajas biedata implementadas (4 cajas de importación)
- [ ] Regla anti-loop: escrituras con `origin='bkernel'` no se re-emiten

### Comunicación
- [ ] `/metrics` expuesto en puerto 28301
- [ ] `/health` y `/ready` en puerto 28302
- [ ] `manifest.yml` creado con todos los campos requeridos

### Despliegue
- [ ] Puertos en rango 28300-28303 registrados en catálogo SBOS
- [ ] Secrets declarados en `vault_paths` del manifest.yml
- [ ] `yaml_engine.yml` con NetworkPolicy restricta (allow from: kong, bkernel)

### Observabilidad
- [ ] Logs JSON con los 10 campos obligatorios (timestamp, level, service, version, request_id, ctx_id, tenant, user_id, endpoint, response_code, response_ms)
- [ ] Dashboard Grafana con SRE Golden Signals en `resources/dashboard.json`

---
_SKULL · SBOS · SmartRates · 014-ACOPLAMIENTO-SBOS · v1.0 · 2026-05-23_
