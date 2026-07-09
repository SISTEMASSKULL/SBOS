# DATOS-TUI-INSTALACION.md — Requisitos Completos para la TUI de Instalación del BOS

**Documento vivo de referencia para el desarrollo del TUI de instalación.**
**Actualizar en cada cambio de ficha, saga, o pantalla del wizard.**

**Versión:** 1.1.0 · **Fecha:** 2026-06-17 · **Autor:** sbos-coordinador + bos-developer
**Alineado con:** SBOS-051-TENANT-SPEC v2.0 · SBOS-049-CONTEXT-PLANE · SBOS-050-PORT-CATALOG ·
SBOS-053-DAEMON-TUI-DECOUPLING v1.2 · Dev_Control_Certification_Method v1.0
**Estándares:** ISO/IEC 17788 (multi-tenancy) · ISO 17442 (LEI) · NSA/CISA K8s Hardening ·
NIST SP 800-207 (Zero Trust) · CIS Kubernetes Benchmark v8 · WCAG 2.4.11 (Focus Visible) ·
Go contracts package 2025 · CQRS · Event Sourcing Snapshot

---

## Tabla de Contenidos

1. [Arquitectura del Wizard de Instalación](#1-arquitectura-del-wizard-de-instalación)
2. [Flujo de Pantallas](#2-flujo-de-pantallas)
3. [Datos por Pantalla](#3-datos-por-pantalla)
4. [Catálogo de Fichas: Datos, Pruebas y Comandos](#4-catálogo-de-fichas-datos-pruebas-y-comandos)
5. [Validaciones Pre-instalación (Preflight)](#5-validaciones-pre-instalación-preflight)
6. [Validaciones Post-instalación (Health Gates)](#6-validaciones-post-instalación-health-gates)
7. [Comandos de Instalación](#7-comandos-de-instalación)
8. [Navegación por Teclado](#8-navegación-por-teclado)
9. [Indicadores de Progreso](#9-indicadores-de-progreso)
10. [Manejo de Errores](#10-manejo-de-errores)
11. [Estándares de Industria](#11-estándares-de-industria)
12. [Checklist de Implementación](#12-checklist-de-implementación)

---

## 1. Arquitectura del Wizard de Instalación

### 1.1 Principios de Diseño

| Principio | Estándar | Implementación |
|-----------|----------|---------------|
| **Keyboard-first** | OSInstaller 2025 · WCAG 2.1.1 | Tab/Shift+Tab navega campos; Enter confirma; Escape retrocede |
| **Foco visible** | WCAG 2.4.11 | Focused = underline + texto cyan; Blurred = sin decoración (§5.11.1) |
| **Defaults inteligentes** | InstallAware 2025 · Advanced Installer 23.1 | Cada campo tiene valor por defecto seguro; "Advanced" colapsa complejidad |
| **Progreso honesto** | Linguistics of Package Managers 2025 | Determinístico cuando es posible; indeterminado cuando no; nunca falsas promesas de tiempo |
| **Errores blameless** | Userpilot 2025 | 3 partes: qué falló → por qué → cómo resolverlo |
| **Summary before execution** | OSInstaller · Industry standard | Pantalla de confirmación con todos los valores (secretos ocultos) antes de ejecutar |
| **Console fallback** | InstallAware 2025 | El TUI funciona en modo texto puro (sin GUI); sin dependencias de mouse |
| **Centered constrained layout** | OSInstaller · DaisyUI | max-width, jerarquía visual clara, estética calmada |

### 1.2 Modos de Instalación

```
┌──────────────────────────────────────────────────────────────────┐
│  MODO ASISTIDO (Wizard)                                          │
│  bosctl setup          → wizard paso a paso (7 pantallas)        │
│  Pantallas: P1(Id) → P2(Infra) → P3(Datos) → P3B(Capacidad)     │
│           → P4(Confirmar) → P5(Instalando) → P6(Listo)           │
├──────────────────────────────────────────────────────────────────┤
│  MODO DECLARATIVO (seed.yml)                                     │
│  bosctl deploy seed.yml  → instalación desatendida completa      │
│  Sin interacción. Ideal para CI/CD y automatización.             │
├──────────────────────────────────────────────────────────────────┤
│  MODO HÍBRIDO                                                    │
│  bosctl setup --seed seed.yml  → wizard pre-rellenado            │
│  El wizard muestra valores del seed; permite editar antes de     │
│  confirmar. Útil para revisión humana de despliegues.            │
└──────────────────────────────────────────────────────────────────┘
```

### 1.3 Estados de Pantalla durante Instalación

```
ScreenWelcome        → bienvenida + preflight automático
ScreenWizardP1       → identidad (tenant empresarial + realm)
ScreenWizardP2       → infraestructura (namespace, red, trust)
ScreenWizardP3       → datos (PG, Redis, Vault versiones)
ScreenWizardCapacity → dimensionamiento (tenant/empresa/sucursal/usuario)
ScreenWizardP4       → confirmación (resumen + secretos ocultos)
ScreenInstalling     → progreso en 3 columnas (eventos reales del daemon)
ScreenDone           → resumen final con health check
ScreenError          → error con diagnóstico y opciones (reintentar, reparar, abortar)
```

---

## 2. Flujo de Pantallas

### 2.1 Diagrama de Transiciones

```
ScreenWelcome ──(preflight OK)──→ ScreenWizardP1
     │                                    │
     │ (ya instalado)                     │ (Enter / Next)
     ▼                                    ▼
ScreenBoot                          ScreenWizardP2
     │                                    │
     │                                    │ (Enter / Next)
     ▼                                    ▼
ScreenDashboard                     ScreenWizardP3
                                           │
                                           │ (Enter / Next)
                                           ▼
                                    ScreenWizardCapacity
                                           │
                                           │ (Enter / Next)
                                           ▼
                                    ScreenWizardP4 ──(Confirmar)──→ ScreenInstalling
                                           │                              │
                                           │ (Back)                       │ (7 pasos saga)
                                           └──→ P3                       ▼
                                                                   ScreenDone
                                                                   ScreenError (si falla)
```

### 2.2 Navegación entre Pantallas

| Tecla | Acción | Contexto |
|-------|--------|---------|
| `Tab` | Siguiente campo | En cualquier formulario |
| `Shift+Tab` | Campo anterior | En cualquier formulario |
| `Enter` | Confirmar / Siguiente paso | En campo o botón |
| `Esc` | Retroceder / Cancelar | En wizard (vuelve a pantalla anterior) |
| `Ctrl+C` | Abortar (con confirmación) | Global |
| `↑/↓` | Navegar opciones | En selects y radios |
| `Space` | Toggle checkbox | En checkboxes |

### 2.3 Reglas de Transición

1. **No se puede avanzar sin validar:** el botón "Siguiente" está disabled hasta que todos los campos requeridos son válidos.
2. **No se puede retroceder durante instalación:** una vez en ScreenInstalling, los botones de retroceso se deshabilitan.
3. **Compensación automática:** si un paso falla, los pasos anteriores se compensan en orden inverso (saga pattern).
4. **HITL requerido para eliminar:** `bosctl tenant remove` requiere confirmación humana explícita (gate §F10.C.12).

---

## 3. Datos por Pantalla

### 3.1 P1 — Identidad (ScreenWizardP1)

**Propósito:** Capturar los datos del Tenant Empresarial (Modelo A, SBOS-051 §4) y la identidad del realm (Modelo B, SBOS-051 §5.6).

| Campo | Tipo | Requerido | Default | Validación | Fuente Spec |
|-------|------|-----------|---------|------------|------------|
| `legal_name` | text | ✅ | — | 2-200 chars, no vacío | ISO 17442 / §4.2 |
| `trading_name` | text | ❌ | = legal_name | 1-200 chars | KYB / §4.2 |
| `tax_identifier` | text | ✅ (Bolivia) | — | NIT: 7-15 dígitos | SIN / §4.7 |
| `registration_number` | text | ✅ (Bolivia) | — | Matrícula FUNDEMPRESA | §4.7 |
| `entity_legal_form_code` | select | ✅ | SRL | Enum: UNIPERSONAL\|SRL\|SA\|SOC_COLECTIVA\|... | ISO 20275 / §4.7 |
| `jurisdiction_of_registration` | text | ✅ | "La Paz, Bolivia" | Depto, País | ISO 17442 / §4.7 |
| `entity_status` | select | ✅ | ACTIVA | Enum: ACTIVA\|INACTIVA\|EN_DISOLUCION | ISO 17442 / §4.7 |
| `realm` | text | ✅ | = trading_name slug | 1-64 chars, [a-z0-9-] | Keycloak / §5.6 |
| `display_name` | text | ❌ | = legal_name | 1-200 chars | Keycloak / §5.6 |

**Validaciones cruzadas:**
- `realm` debe ser único en el cluster Keycloak (verificar contra KC Admin API si disponible)
- `tax_identifier` debe tener formato NIT boliviano (validación regex)
- `entity_legal_form_code` determina qué campos adicionales se muestran (ej. Unipersonal → sin separation legal/operating address)

### 3.2 P2 — Infraestructura (ScreenWizardP2)

**Propósito:** Capturar los datos del Dominio Técnico (Modelo B, SBOS-051 §5).

| Campo | Tipo | Requerido | Default | Validación | Fuente Spec |
|-------|------|-----------|---------|------------|------------|
| `domain_id` | text | ✅ | "{realm}-prod" | slug: [a-z0-9-] 1-63 chars | §5.2 |
| `domain_type` | select | ✅ | production | Enum: production\|staging\|development\|sandbox\|dr | §5.2 |
| `tenancy_trust_model` | select | ✅ | hard | Enum: soft\|hard | §5.8 |
| `isolation_mechanism` | select | ✅ | namespace_rbac | Enum: namespace_rbac\|runtime_sandbox\|virtual_cluster | §5.8 |
| `network_policy` | select | ✅ | default-deny | Enum: default-deny\|custom | NSA/CISA §5.4 |

**Validaciones cruzadas:**
- Si `tenancy_trust_model = hard` y `domain_type = production`, recomendar `isolation_mechanism >= runtime_sandbox`
- `domain_id` debe ser único (no debe existir otro namespace con ese domain-id label)

### 3.3 P3 — Datos (ScreenWizardP3)

**Propósito:** Versiones y configuración de los servicios de datos (SBOS-051 §5.5).

| Campo | Tipo | Requerido | Default | Validación | Fuente |
|-------|------|-----------|---------|------------|--------|
| `postgresql_version` | select | ✅ | 18.4 | Enum: 18.4 | ADR-017 |
| `redis_version` | select | ✅ | 8.6.2 | Enum: 8.6.2 | ADR-017 |
| `vault_version` | select | ✅ | 2.0.1 | Enum: 2.0.1 | ADR-017 |
| `redis_persistence` | select | ✅ | AOF | Enum: AOF\|RDB\|AOF+RDB | SBOS docs |
| `vault_engine` | select | ✅ | kv-v2 | Enum: kv-v2 | Vault docs |
| `vault_shamir_keys` | number | ✅ | 3 | 1-10 | Vault docs |
| `vault_shamir_threshold` | number | ✅ | 5 | ≥ keys | Vault docs |
| `context_auto_migrate` | toggle | ✅ | true | — | SBOS-049 §9 |

### 3.4 P3B — Capacidad (ScreenWizardCapacity)

**Propósito:** Dimensionar los recursos según el modelo de capacidad dinámico.

| Campo | Tipo | Requerido | Default | Validación |
|-------|------|-----------|---------|------------|
| `tenants` | number | ✅ | 1 | 1-500 |
| `companies_per_tenant` | number | ✅ | 3 | 1-1000 |
| `branches_per_company` | number | ✅ | 5 | 1-500 |
| `users_per_branch` | number | ✅ | 10 | 1-1000 |
| `concurrent_ctx_id` | number (calc) | — | T×E×S×U | read-only |
| `estimated_ram_gb` | number (calc) | — | fórmula | read-only |
| `estimated_cpu_cores` | number (calc) | — | fórmula | read-only |
| `estimated_disk_gb` | number (calc) | — | fórmula | read-only |

**Fórmula de capacidad (SBOS-PERF-001):**
```
concurrent_ctx_id = tenants × companies × branches × users
RAM  = (concurrent_ctx_id × 2KB) + (tenants × 256MB) + 2GB_base
CPU  = max(4, tenants / 10 + concurrent_ctx_id / 50000)
DISK = concurrent_ctx_id × 5KB + tenants × 10GB + 50GB_base
```

### 3.5 P4 — Confirmación (ScreenWizardP4)

**Propósito:** Mostrar resumen completo antes de ejecutar. Secretos ocultos con `***`.

**Columnas del resumen:**
1. **Identidad:** legal_name, tax_identifier, realm, entity_status
2. **Infraestructura:** domain_id, domain_type, trust_model, isolation
3. **Datos:** PG version, Redis version + persistence, Vault version + engine
4. **Capacidad:** tenants, empresas, sucursales, usuarios, RAM/CPU/DISK estimados
5. **Fichas a instalar:** lista completa en orden (12 fichas)
6. **Usuarios iniciales:** username, email (roles visibles, temp_pwd indicado)

**Botones:** `[Confirmar y Desplegar]` `[Volver a editar]` `[Abortar]`

### 3.6 P5 — Instalando (ScreenInstalling)

**Propósito:** Mostrar el progreso real de la saga de 7 pasos con eventos del daemon.

**3 columnas:**
| Columna | Contenido | Fuente |
|---------|-----------|--------|
| **Paso actual** | Ficha en instalación + spinner + __SBOS__STEP_START__ | WebSocket eventos del daemon |
| **Log** | Últimas 5 líneas de FICHA_LOG | tail -f del archivo de log |
| **Progreso global** | 1/7 → 7/7 con checkmarks ✅/❌ | Estado de cada paso |

### 3.7 P6 — Listo (ScreenDone)

**Propósito:** Mostrar resultado final con health check.

| Elemento | Contenido |
|----------|-----------|
| **Título** | ✅ Tenant desplegado / ❌ Fallo en paso X |
| **Resumen** | Tenant ID, Realm, Namespace, BDs creadas, SPIs instaladas |
| **Health Gates** | C-01 a C-08 verificados con íconos ✅/❌ |
| **Próximos pasos** | Acceder a Core UI, configurar MFA, crear usuarios |
| **Botones** | `[Dashboard]` `[Ver Log Completo]` `[Salir]` |

---

## 4. Catálogo de Fichas: Datos, Pruebas y Comandos

### 4.1 Ficha: sbos-namespace (PASO 1)

| Atributo | Valor |
|----------|-------|
| **Servidor** | S-HOST |
| **Dependencias** | K8s API disponible (C-01: k3s running) |
| **Tiempo estimado** | < 5s |
| **Timeout** | 30s |

**Variables de entorno requeridas:**

| Variable | Default | Descripción |
|----------|---------|-------------|
| `TENANT_ID` | skull | ID fiscal o slug del tenant |
| `TENANT_NAME` | SKULL Tenant | Nombre visible |
| `DOMAIN_ID` | {TENANT_ID}-prod | Identificador del dominio técnico (§5.2) |
| `DOMAIN_TYPE` | production | Tipo de dominio (§5.2) |

**Pruebas de éxito (TUI debe evaluar):**

| # | Prueba | Comando | Criterio |
|---|-------|---------|----------|
| NS-01 | Namespace existe | `kubectl get namespace sbos-{TENANT_ID}` | Phase = Active |
| NS-02 | Labels correctas | `kubectl get ns sbos-{TENANT_ID} -o jsonpath='{.metadata.labels}'` | tenant, name, domain-id, domain-type, managed-by=sbos presentes |
| NS-03 | NetworkPolicy default-deny | `kubectl get networkpolicy default-deny-all -n sbos-{TENANT_ID}` | Existe, policyTypes=[Ingress,Egress] |
| NS-04 | ResourceQuota aplicada | `kubectl get resourcequota tenant-quota -n sbos-{TENANT_ID}` | Existe con hard limits |
| NS-05 | LimitRange aplicada | `kubectl get limitrange tenant-limits -n sbos-{TENANT_ID}` | Existe con default limits |

**Comando de instalación:**
```bash
TENANT_ID=skull TENANT_NAME="SKULL" DOMAIN_ID=skull-prod DOMAIN_TYPE=production \
  bosctl ficha install sbos-namespace
```

### 4.2 Ficha: postgresql (PASO 2)

| Atributo | Valor |
|----------|-------|
| **Servidor** | S01 |
| **Dependencias** | sbos-namespace, K8s PV disponible |
| **Tiempo estimado** | < 60s |
| **Timeout** | 180s |
| **Image** | postgres:18.4-alpine |

**Variables de entorno requeridas:**

| Variable | Default | Descripción |
|----------|---------|-------------|
| `TENANT_ID` | skull | ID del tenant |
| `ENGINE` | postgresql | Motor de BD |
| `VERSION` | 18.4 | Versión canónica (ADR-017) |

**Bases de datos creadas (9 por tenant):**

| BD | Owner | Propósito |
|----|-------|-----------|
| `keycloak_db` | keycloak | Identidad (KC 26.6.2) |
| `bkernel_db` | bkernel | Context Plane + CDC metadata |
| `bauth_db` | bauth | BitMask + políticas de identidad |
| `tryton_db` | tryton | ERP (opcional por tenant) |
| `minio_meta` | minio | Metadatos de objetos |
| `bsearch_catalog` | bsearch | Catálogo de índices de búsqueda |
| `bcompass_db` | bcompass | IA tools (futuro) |
| `bnotify_db` | bnotify | Plantillas y registro de notificaciones |
| `audit_db` | audit | Auditoría ISO 27001 |

**Pruebas de éxito:**

| # | Prueba | Comando | Criterio |
|---|-------|---------|----------|
| PG-01 | Pod Running | `kubectl get pod postgresql-0 -n sbos-data` | STATUS=Running, READY=1/1 |
| PG-02 | BD keycloak_db existe | `psql -h ... -c "SELECT 1 FROM pg_database WHERE datname='keycloak_db'"` | Retorna 1 |
| PG-03 | 9 BDs creadas | `psql -h ... -c "SELECT count(*) FROM pg_database WHERE datname LIKE '%_db'"` | count ≥ 9 |
| PG-04 | wal_level=logical | `psql -h ... -c "SHOW wal_level"` | logical |
| PG-05 | bkernel_slot existe | `psql -h ... -c "SELECT slot_name FROM pg_replication_slots"` | bkernel_slot presente |

### 4.3 Ficha: redis (PASO 3)

| Atributo | Valor |
|----------|-------|
| **Servidor** | S01 |
| **Dependencias** | postgresql |
| **Tiempo estimado** | < 30s |
| **Timeout** | 120s |
| **Image** | redis:8.6.2-alpine |

**Variables de entorno requeridas:**

| Variable | Default | Descripción |
|----------|---------|-------------|
| `TENANT_ID` | skull | ID del tenant |
| `VERSION` | 8.6.2 | Versión canónica |
| `PERSISTENCE` | AOF | Modo de persistencia |

**3 DBs lógicas:**

| DB | Nombre | Propósito |
|----|--------|-----------|
| DB0 | streams_cache | Redis Streams + cache general |
| DB1 | context_registry | Context Registry (TTL sincronizado con KC) |
| DB2 | rate_limiting | Rate Limiting (Kong + API) |

**Pruebas de éxito:**

| # | Prueba | Comando | Criterio |
|---|-------|---------|----------|
| RD-01 | Pod Running | `kubectl get pod redis-0 -n sbos-data` | STATUS=Running, READY=1/1 |
| RD-02 | PING | `redis-cli -h ... PING` | PONG |
| RD-03 | DB1 Context Registry | `redis-cli -h ... -n 1 DBSIZE` | Retorna número (aunque sea 0) |
| RD-04 | ACL bos_context | `redis-cli -h ... ACL LIST \| grep bos_context` | Existe con +@all |
| RD-05 | ACL kong_context | `redis-cli -h ... ACL LIST \| grep kong_context` | Existe con +@read |
| RD-06 | Persistencia activa | `redis-cli -h ... CONFIG GET appendonly` | yes |

### 4.4 Ficha: vault (PASO 4)

| Atributo | Valor |
|----------|-------|
| **Servidor** | S02 |
| **Dependencias** | postgresql, redis |
| **Tiempo estimado** | < 45s |
| **Timeout** | 180s |
| **Image** | hashicorp/vault:2.0.1 |

**Variables de entorno requeridas:**

| Variable | Default | Descripción |
|----------|---------|-------------|
| `TENANT_ID` | skull | ID del tenant |
| `ENGINE` | kv-v2 | Motor de secretos |
| `BASE_PATH` | secret/tenants/{TENANT_ID} | Path base en Vault |
| `APPROLE_TTL` | 24h | TTL del AppRole |

**Pruebas de éxito:**

| # | Prueba | Comando | Criterio |
|---|-------|---------|----------|
| VT-01 | Pod Running | `kubectl get pod vault-0 -n sbos-security` | STATUS=Running |
| VT-02 | Vault unsealed | `vault status -tls-skip-verify` | Sealed=false |
| VT-03 | Engine kv-v2 montado | `vault secrets list -tls-skip-verify` | secret/ presente |
| VT-04 | Path tenant existe | `vault kv list -tls-skip-verify secret/tenants/{TENANT_ID}` | Sin error |
| VT-05 | PKI configurada | `vault read -tls-skip-verify pki/ca` | Certificate presente |

### 4.5 Ficha: keycloak (PASO 5)

| Atributo | Valor |
|----------|-------|
| **Servidor** | S03 |
| **Dependencias** | postgresql (keycloak_db), vault |
| **Tiempo estimado** | < 120s |
| **Timeout** | 300s |
| **Image** | quay.io/keycloak/keycloak:26.6.2 |

**Variables de entorno requeridas:**

| Variable | Default | Descripción |
|----------|---------|-------------|
| `TENANT_ID` | skull | ID del tenant (= realm ID) |
| `TENANT_NAME` | SKULL | Nombre visible del realm |
| `REALM` | skull | ID del realm en Keycloak |
| `SSO_SESSION_MAX` | 43200 | SSO Session Max (segundos, default 12h) |
| `ACCESS_TOKEN_LIFESPAN` | 900 | Access Token Lifespan (segundos, default 15min) |

**5 SPIs (Service Provider Interfaces) instalados:**

| SPI | Clase | Propósito |
|-----|-------|-----------|
| BosRolTemplate | org.keycloak.theme.BosRolTemplateSPI | Plantillas de roles H-RBAC |
| FinancialDomain | org.keycloak.authentication.FinancialDomainSPI | Dominio financiero |
| PhysicalDomain | org.keycloak.authentication.PhysicalDomainSPI | Dominio físico |
| LogicalDomain | org.keycloak.authentication.LogicalDomainSPI | Dominio lógico |
| TemporalContext | org.keycloak.authentication.TemporalContextSPI | Contexto temporal |

**Pruebas de éxito:**

| # | Prueba | Comando | Criterio |
|---|-------|---------|----------|
| KC-01 | Pod Running | `kubectl get pod deploy/keycloak -n sbos-security` | STATUS=Running |
| KC-02 | Admin token | `curl -X POST .../realms/master/protocol/openid-connect/token` | access_token recibido |
| KC-03 | Realm existe | `curl .../admin/realms/{REALM}` | 200 OK, realm.enabled=true |
| KC-04 | 5 SPIs instalados | `curl .../admin/realms/{REALM}/components?type=org.keycloak...` | 5 componentes |
| KC-05 | SSO session config | `curl .../admin/realms/{REALM}` | ssoSessionMaxLifespan={SSO_SESSION_MAX} |
| KC-06 | Token lifespan config | `curl .../admin/realms/{REALM}` | accessTokenLifespan={ACCESS_TOKEN_LIFESPAN} |

### 4.6 Ficha: kong (PASO 7 — parte del grupo de fichas)

| Atributo | Valor |
|----------|-------|
| **Servidor** | S02 |
| **Dependencias** | postgresql, keycloak, vault |
| **Tiempo estimado** | < 45s |
| **Timeout** | 180s |
| **Image** | kong:3.9.0 |

**Pruebas de éxito:**

| # | Prueba | Comando | Criterio |
|---|-------|---------|----------|
| KG-01 | Kong admin reachable | `curl http://localhost:8001/status` | 200 OK |
| KG-02 | Kong proxy HTTPS | `curl -k https://localhost:8443/` | Respuesta (aunque sea 404) |
| KG-03 | Context API plugin | `curl http://localhost:8001/plugins \| grep sbos-context` | Plugin instalado |

### 4.7 Fichas de Daemons (PASO 7 — bkernel, biedata, bauth, bsearch, bhnexus, bnotify)

| Ficha | Servidor | Puerto (SBOS-050) | Dependencias |
|-------|----------|-------------------|-------------|
| bkernel | S04 | 9460-9461 (solo métricas) | PG WAL slot, Redis Streams |
| biedata | S05 | 9470-9472 | PG, Redis, Vault, bkernel |
| bauth | S06 | 9450-9453 | Keycloak, PG bauth_db |
| bsearch | S07 | 9493 (wss://) | PG, Redis, bkernel |
| bhnexus | S08 | 9444 (wss:// mTLS) | bauth Unix socket |
| bnotify | S06 | 28200-28205 | PG, Redis, Keycloak, Kong, Vault, bkernel, biedata |

**⚠️ NOTA:** Las fichas de daemons están en desarrollo (Fase A, ADR-015). Sus task_catalog.sh aún no existen. Este catálogo se actualizará cuando se implementen.

---

## 5. Validaciones Pre-instalación (Preflight)

### 5.1 Criterios C-01 a C-08

El preflight verifica automáticamente al iniciar el wizard (ScreenWelcome). Si hay advertencias, se muestran pero permiten continuar. Si hay errores críticos, el wizard no avanza.

| Criterio | Verificación | Comando | Crítico |
|----------|-------------|---------|---------|
| **C-01** | k3s cluster operativo | `kubectl get nodes` | ✅ SÍ |
| **C-02** | Calico CNI running | `kubectl get pods -n calico-system` | ✅ SÍ |
| **C-03** | PostgreSQL 18.4 instalado | `kubectl get pod postgresql-0 -n sbos-data` | ⚠️ ADVERTENCIA |
| **C-04** | Redis 8.6.2 instalado | `kubectl get pod redis-0 -n sbos-data` | ⚠️ ADVERTENCIA |
| **C-05** | Vault 2.0.1 instalado | `kubectl get pod vault-0 -n sbos-security` | ⚠️ ADVERTENCIA |
| **C-06** | Keycloak 26.6.2 instalado | `kubectl get pod deploy/keycloak -n sbos-security` | ⚠️ ADVERTENCIA |
| **C-07** | Kong 3.9.x instalado | `kubectl get pod deploy/kong -n sbos-gateway` | ⚠️ ADVERTENCIA |
| **C-08** | bos-preflight: system_packages | `dpkg -l \| grep -E 'kubectl\|helm\|jq\|curl'` | ✅ SÍ |
| **C-09** | Espacio en disco ≥ 20GB | `df -h /var/lib/rancher/k3s` | ✅ SÍ |
| **C-10** | RAM disponible ≥ 4GB | `free -m \| grep Mem` | ✅ SÍ |
| **C-11** | CPU cores ≥ 2 | `nproc` | ⚠️ ADVERTENCIA |
| **C-12** | Sistema de archivos no FAT/NTFS | `df -T / \| grep -v fat\|ntfs` | ✅ SÍ |
| **C-13** | Puerto 9443 libre (Context API) | `ss -tln \| grep 9443` | ⚠️ ADVERTENCIA |

### 5.2 Salida del Preflight en TUI

```
╔══════════════════════════════════════════════════════════╗
║  🔍 PREFLIGHT — Verificando sistema...                  ║
╠══════════════════════════════════════════════════════════╣
║  ✅ C-01  k3s cluster              v1.32.0              ║
║  ✅ C-02  Calico CNI               running              ║
║  ❌ C-03  PostgreSQL 18.4          no instalado         ║
║  ❌ C-04  Redis 8.6.2              no instalado         ║
║  ✅ C-08  bos-preflight            paquetes OK          ║
║  ✅ C-09  Disco                    45 GB disponibles    ║
║  ✅ C-10  RAM                      7.8 GB disponibles   ║
║  ⚠️  C-11  CPU                      1 core (mín 2)      ║
║  ✅ C-12  FS Linux                 ext4                 ║
║  ✅ C-13  Puerto 9443              libre                ║
╠══════════════════════════════════════════════════════════╣
║  ⚠️  3 advertencia(s) — presiona Enter para continuar   ║
╚══════════════════════════════════════════════════════════╝
```

---

## 6. Validaciones Post-instalación (Health Gates)

### 6.1 Health Gates por Paso de Saga

Después de cada paso, el TUI debe verificar las pruebas de éxito correspondientes (ver §4). Si una prueba falla, se intenta `ficha_repair()` automáticamente. Si el repair también falla, se activa la compensación (rollback).

### 6.2 Health Check Final (ScreenDone)

```bash
# El TUI ejecuta este health check al finalizar
bosctl health check --full --tenant={TENANT_ID}
```

**Output esperado:**

| Gate | Descripción | Estado |
|------|------------|--------|
| H-01 | Namespace K8s activo | ✅ |
| H-02 | PostgreSQL 9 BDs creadas | ✅ |
| H-03 | Redis DB1 Context Registry accesible | ✅ |
| H-04 | Vault unsealed + engine montado | ✅ |
| H-05 | Keycloak realm + 5 SPIs | ✅ |
| H-06 | Context Plane DDL aplicado | ✅ |
| H-07 | 12 fichas instaladas (todas READY) | ✅ |
| H-08 | Context API :9443 responde | ✅ |
| H-09 | Kong proxy HTTPS responde | ✅ |
| H-10 | audit_events escribiendo en audit_db | ✅ |

---

## 7. Comandos de Instalación

### 7.1 Comandos del Wizard (Modo Asistido)

```bash
# Iniciar wizard completo
bosctl setup

# Wizard pre-rellenado desde seed
bosctl setup --seed servers/seed-skull.yml

# Saltar preflight (solo si ya verificado manualmente)
bosctl setup --skip-preflight

# Modo verbose (muestra logs detallados en el TUI)
bosctl setup --verbose
```

### 7.2 Comandos Declarativos (Modo Automatizado)

```bash
# Desplegar tenant completo desde seed
bosctl deploy servers/seed-skull.yml

# Desplegar con timeout personalizado (default: 30min)
bosctl deploy servers/seed-skull.yml --timeout 45m

# Validar seed sin instalar (dry-run)
bosctl deploy servers/seed-skull.yml --dry-run
```

### 7.3 Comandos de Verificación

```bash
# Health check completo post-deploy
bosctl health check --full --tenant=skull

# Verificar estado de todas las fichas
bosctl ficha status --all

# Verificar estado de un tenant
bosctl tenant status skull

# Listar tenants instalados
bosctl tenant list --json
```

### 7.4 Comandos de Reparación

```bash
# Reparar ficha específica
bosctl ficha repair postgresql --tenant=skull

# Reparar tenant completo (re-ejecuta saga con pasos idempotentes)
bosctl tenant repair skull

# Verificar drift y mostrar diff
bosctl ficha diff sbos-namespace --tenant=skull
```

---

## 8. Navegación por Teclado

### 8.1 Mapa Completo de Teclas

```
┌─────────────────────────────────────────────────────────────┐
│  NAVEGACIÓN GLOBAL                                          │
│  ─────────────                                              │
│  Tab / Shift+Tab     →  siguiente / anterior campo          │
│  Enter               →  confirmar campo / siguiente paso    │
│  Esc                 →  retroceder pantalla / cancelar      │
│  Ctrl+C              →  abortar (con diálogo confirmación)  │
│  Ctrl+L              →  limpiar/redibujar pantalla          │
│                                                             │
│  FORMULARIOS huh                                            │
│  ─────────────                                              │
│  ↑ / ↓               →  navegar opciones (select, multi)    │
│  Space               →  toggle (checkbox, multi-select)     │
│  /                    →  filtrar/buscar en listas largas     │
│  Ctrl+A / Ctrl+E     →  inicio/fin de línea (inputs)        │
│                                                             │
│  PANTALLA DE INSTALACIÓN (ScreenInstalling)                 │
│  ─────────────────────────────────────                      │
│  ↑ / ↓ / PgUp / PgDn →  scroll en panel de log             │
│  Ctrl+F              →  seguir log (auto-scroll al final)    │
│  s                   →  toggle pausa/continuar log           │
│                                                             │
│  PANTALLA DE RESULTADO (ScreenDone / ScreenError)           │
│  ───────────────────────────────────────                    │
│  l                   →  abrir log completo (less)            │
│  r                   →  reintentar paso fallido              │
│  d                   →  ir al dashboard                     │
│  q                   →  salir                               │
└─────────────────────────────────────────────────────────────┘
```

### 8.2 Estados de Foco (WCAG 2.4.11)

| Estado | Visual | Cuándo |
|--------|--------|--------|
| **Focused** | underline + texto cyan + borde sutil | Campo activo para input |
| **Blurred** | sin decoración, texto normal | Campo inactivo |
| **Disabled** | texto gris tenue, sin interacción | Campo bloqueado (deps no cumplidas) |
| **Error** | borde rojo + texto de error abajo | Validación fallida |
| **Success** | checkmark verde a la derecha | Campo validado OK |

---

## 9. Indicadores de Progreso

### 9.1 Tipos de Spinner/Barra

| Contexto | Tipo | Implementación |
|----------|------|---------------|
| **Preflight** | Barra determinística | 0% → 100% (13 criterios, ~7.7% cada uno) |
| **Instalación de ficha** | Spinner animado | Bubble Tea spinner (⣾⣽⣻⢿⡿⣟⣯⣷) |
| **Progreso global** | Barra determinística | 0/7 → 7/7 pasos |
| **Operación indeterminada** | Spinner + texto | "Inicializando..." sin porcentaje |

### 9.2 Mensajes de Progreso por Paso

| Paso | Mensaje | Tiempo Estimado |
|------|---------|----------------|
| 1 | "Creando namespace K8s + NetworkPolicy..." | ~5s |
| 2 | "Desplegando PostgreSQL 18.4 + 9 bases de datos..." | ~60s |
| 3 | "Configurando Redis 8.6.2 + Context Registry DB1..." | ~30s |
| 4 | "Inicializando Vault 2.0.1 + PKI + AppRole..." | ~45s |
| 5 | "Desplegando Keycloak 26.6.2 + Realm + 5 SPIs..." | ~120s |
| 6 | "Aplicando DDL Context Plane..." | ~5s |
| 7 | "Instalando fichas del tenant (12 en orden DAG)..." | ~180s |

**Tiempo total estimado:** ~7 minutos (modo asistido) · ~48 minutos (bootstrap completo)

---

## 10. Manejo de Errores

### 10.1 Estructura de Mensaje de Error (3 partes)

```
┌──────────────────────────────────────────────────────────┐
│  ❌ PASO 3: Redis                                        │
│                                                          │
│  QUÉ FALLÓ: No se pudo conectar a Redis en el pod       │
│  redis-0.sbos-data.svc.cluster.local:6379               │
│                                                          │
│  POR QUÉ: El StatefulSet redis no está Ready.           │
│  El readiness probe falló 3 veces consecutivas.          │
│                                                          │
│  CÓMO RESOLVER:                                          │
│  1. Revisar logs: bosctl ficha logs redis                │
│  2. Verificar PV: kubectl get pv redis-data             │
│  3. Repair: bosctl ficha repair redis                   │
│                                                          │
│  [Reintentar]  [Saltar (riesgoso)]  [Abortar]           │
└──────────────────────────────────────────────────────────┘
```

### 10.2 Códigos de Error del TUI

| Código | Significado | Acción Automática |
|--------|------------|-------------------|
| `E-01` | Timeout de ficha | Reintentar 1 vez → compensar |
| `E-02` | Error de red K8s | Esperar 10s → reintentar |
| `E-03` | PVC no disponible | Alertar → esperar HITL |
| `E-04` | Credenciales inválidas | No reintentar → pedir corrección |
| `E-05` | Versión incompatible | Detener → sugerir upgrade/downgrade |
| `E-06` | Dependencia faltante | Instalar dependencia → reintentar |
| `E-07` | Disco lleno | Alertar → esperar HITL |
| `E-08` | Conflicto de nombres | Sugerir nombre alternativo |
| `E-09` | Permisos insuficientes | Verificar RBAC → alertar |

### 10.3 Política de Reintentos

| Operación | Reintentos | Backoff | Acción al agotar |
|-----------|-----------|---------|-----------------|
| `ficha_install` | 1 | inmediato | Compensar (rollback) |
| `ficha_repair` | 2 | 10s, 30s | Escalar HITL |
| `health_check` | 3 | 5s, 15s, 45s | Marcar DEGRADADA |
| `kubectl apply` | 3 | 1s, 5s, 25s | Error de red |
| `preflight` | 0 | — | Mostrar advertencia |

---

## 11. Estándares de Industria

### 11.1 Patrones Adoptados

| Estándar | Qué adopta SBOS | Referencia |
|----------|----------------|------------|
| **ISO/IEC 17788** | Definición formal de multi-tenancy: cardinalidad 1:N tenant empresarial ↔ dominios técnicos | §6 SBOS-051 |
| **ISO 17442 (LEI)** | Identificador único de entidad legal (20 chars), datos Nivel 1 (identidad) y Nivel 2 (relaciones) | §4.2-4.3 SBOS-051 |
| **ISO 20275 (ELF)** | Catálogo normalizado de formas jurídicas (SRL, SA, etc.) | §4.2 SBOS-051 |
| **NIST SP 800-207** | Zero Trust Architecture: BOS como Policy Administrator (PAP/PDP/PEP) | CONCEPCION-BOS |
| **NSA/CISA K8s Hardening** | 3 fronteras de aislamiento: Control Plane/API, Nodo/Host, Red. NetworkPolicy default-deny. | §7 SBOS-051 |
| **CIS Kubernetes Benchmark v8** | Controles técnicos verificables: RBAC, Pod Security Admission, LimitRange | §5.3 SBOS-051 |
| **WCAG 2.4.11** | Focus Visible: todo elemento interactivo DEBE tener indicador de foco visible | §5.11.1 tokens_component.go |
| **OSInstaller 2025** | Keyboard-first navigation, summary before execution, feature-gated pages | Patterns §1.1 |
| **InstallAware 2025** | Console fallback mode, no runtime dependencies, human-readable scripts | Patterns §1.1 |
| **Stakater MTO** | CRD + Operator pattern: Tenant CR → Operator reconcilia → Namespace+RBC+Quota+NetPol | §6.4 SBOS-051 |
| **AWS Control Plane** | Tenant Management Service centralizado; el Control Plane es dueño del tenant | §4.6 SBOS-051 |
| **FAPI 2.0** | Financial-grade API: PAR, DPoP, PKCE. BOS debe certificarse para clientes financieros | SBOS-CERT-001 |
| **OpenTelemetry** | Propagación ctx_id via W3C Trace Context + Baggage | SBOS-049 §9 |

### 11.2 Patrones de UX de Instaladores (2025)

| Patrón | Ejemplo | SBOS lo implementa como |
|--------|---------|------------------------|
| **Summary before execution** | OSInstaller, Advanced Installer | ScreenWizardP4 (confirmación) |
| **Feature-gated pages** | OSInstaller | Campos opcionales con toggle Yes/No |
| **Keyboard-only nav** | OSInstaller, InstallAware | Tab/Shift+Tab/Enter/Esc completo |
| **Honest progress** | Linguistics of Package Managers | Determinístico cuando es posible; indeterminado cuando no |
| **Blameless errors** | Userpilot 2025 | 3 partes: qué → por qué → cómo |
| **Smart defaults** | Advanced Installer 23.1 | Cada campo con default seguro; complejidad en "Advanced" |
| **Console fallback** | InstallAware 2025 | Bubble Tea TUI renderiza en puro texto |

---

## 12. Checklist de Implementación

### 12.1 Pantallas del Wizard

- [ ] ScreenWelcome — preflight automático con barra de progreso (C-01 a C-13)
- [ ] ScreenWizardP1 — formulario identidad (9 campos, huh form)
- [ ] ScreenWizardP2 — formulario infraestructura (5 campos)
- [ ] ScreenWizardP3 — formulario datos (8 campos)
- [ ] ScreenWizardCapacity — dimensionamiento con cálculos dinámicos
- [ ] ScreenWizardP4 — confirmación (resumen 5 secciones, secretos ocultos)
- [ ] ScreenInstalling — 3 columnas con eventos reales del daemon (WebSocket)
- [ ] ScreenDone — health check final con H-01 a H-10
- [ ] ScreenError — diagnóstico con 3 partes + botones acción

### 12.2 Navegación

- [ ] Tab/Shift+Tab entre campos en TODAS las pantallas de formulario
- [ ] Enter confirma campo + avanza al siguiente (comportamiento huh)
- [ ] Esc retrocede pantalla (excepto en Installing)
- [ ] Ctrl+C aborta con diálogo de confirmación
- [ ] Estados de foco visibles en todos los componentes (WCAG 2.4.11)
- [ ] Validación inline por campo (no esperar al submit)
- [ ] Botón "Siguiente" disabled hasta que todos los required OK

### 12.3 Progreso y Eventos

- [ ] Barra determinística en preflight (13 criterios)
- [ ] Spinner animado durante instalación de cada ficha
- [ ] Eventos reales del daemon vía WebSocket (__SBOS__STEP_START__/OK/FAIL)
- [ ] Log en vivo con auto-scroll (Ctrl+F para seguir)
- [ ] Contador de paso actual (1/7 → 7/7) con checkmarks
- [ ] Tiempo transcurrido por paso y total

### 12.4 Manejo de Errores

- [ ] Mensajes de error en 3 partes (qué, por qué, cómo)
- [ ] Reintentos automáticos con backoff (según política §10.3)
- [ ] Compensación automática si un paso falla (rollback inverso)
- [ ] Diálogo de confirmación para operaciones destructivas
- [ ] Gate HITL para `tenant remove`

### 12.5 Validaciones

- [ ] Preflight C-01 a C-13 antes de iniciar wizard
- [ ] Pruebas de éxito por ficha (NS-01..05, PG-01..05, RD-01..06, VT-01..05, KC-01..06)
- [ ] Health check H-01 a H-10 al finalizar
- [ ] Validación de seed.yml contra schema antes de deploy
- [ ] Dry-run mode (`bosctl deploy --dry-run`)

### 12.6 Cumplimiento Normativo

- [ ] ctx_id en cada operación de instalación (SBOS-049)
- [ ] Sin HTTP entre daemons — solo Unix socket o WebSocket (SBOS-050 P9)
- [ ] Todos los secretos en Vault — nunca en logs ni env vars visibles
- [ ] audit_events para cada paso de instalación (ISO 27001 A.8.15)
- [ ] Versiones canónicas verificadas (ADR-017)
- [ ] seed.yml cumple esquema SBOS-051 §14.1-14.2

---

## 13. Modo Híbrido — Wizard Pre-rellenado desde seed.yml

**Definición (SBOS-053 §3.3):** El wizard de la TUI puede recibir un `seed.yml` parcial o completo y usarlo como defaults en los formularios. El usuario revisa, modifica si es necesario, y confirma.

### 13.1 Comando

```bash
bosctl setup --seed /root/seed-skull.yml
```

### 13.2 Comportamiento

| Estado del seed.yml | Comportamiento del wizard |
|---------------------|--------------------------|
| **Completo** (todos los campos) | Wizard muestra todos los valores como defaults. Usuario solo confirma (un Enter). |
| **Parcial** (algunos campos) | Campos con valor → pre-rellenados. Campos sin valor → vacíos (editables). Solo los requeridos sin valor se piden. |
| **Vacío / no existe** | Wizard normal: todos los campos vacíos. |

### 13.3 Equivalencia de los 3 modos (SBOS-053 §3.3)

```
Mismo daemon, mismo resultado:

Modo asistido          Modo híbrido              Modo declarativo
(interactivo)          (seed.yml + wizard)        (CLI pura)
───────────            ─────────────────          ─────────────
bosctl setup           bosctl setup               bosctl deploy
  └─ formularios         └─ --seed seed.yml         seed-skull.yml
     vacíos                 valores pre-rellenos      (sin TUI)
        │                    │                          │
        └────────────────────┴──────────────────────────┘
                             │
                  daemon recibe seed_params
                  persiste en bkernel_db
                  lanza la saga idéntica
```

### 13.4 Validaciones del modo híbrido

- [ ] El wizard carga el seed.yml y muestra los valores como defaults
- [ ] Los campos con valor del seed son editables (no bloqueados)
- [ ] Los campos sin valor en el seed se comportan como en modo asistido
- [ ] Al confirmar, el wizard envía TODOS los valores (los del seed + los completados)
- [ ] `bosctl deploy seed.yml` con el mismo archivo produce resultado idéntico

---

## 14. Casos de Prueba de Desacoplamiento (DC-01 a DC-10)

**Fuente:** SBOS-053-DAEMON-TUI-DECOUPLING §9. Estos casos deben pasar antes de certificar M2.

| Caso | Descripción | Pasos | Resultado esperado |
|------|------------|-------|-------------------|
| **DC-01** | Instalación sin TUI | `bosctl deploy seed-skull.yml` por SSH, sin abrir TUI | Saga 7/7, health gates H-01 a H-10 verdes |
| **DC-02** | Cierre a mitad de saga | Wizard en paso 3/7 → `kill -9` al proceso TUI | Daemon continúa y completa los 7 pasos |
| **DC-03** | Reconexión tardía | Repetir DC-02, 5 min después abrir nueva TUI | Muestra snapshot correcto (completado o paso real) |
| **DC-04** | Múltiples observadores | 2 TUIs simultáneas mismo `saga_id` | Ambas muestran mismo progreso, ninguna afecta a la otra |
| **DC-05** | Comando inválido fuera de orden | TUI reconectada tarde (7/7), enviar "reintentar paso 3" | Daemon rechaza con error explícito |
| **DC-06** | Secreto no transita por TUI | Inspeccionar payload WS durante instalación con Vault | Ningún token/contraseña en claro en el canal |
| **DC-07** | Parámetros persisten tras cierre TUI | Completar wizard, confirmar, cerrar TUI antes del paso 1 | Daemon lanza saga con params correctos, guardados en bkernel_db |
| **DC-08** | Equivalencia wizard / seed.yml | Instalar mismo tenant 2×: wizard y CLI | Configuraciones idénticas (mismos health checks, CRs, estructura) |
| **DC-09** | Modo híbrido (seed parcial + wizard) | `bosctl setup --seed seed.yml` con seed parcial | Wizard presenta defaults del archivo, campos vacíos editables |
| **DC-10** | Conexión post-instalación (24h) | Conectar TUI a daemon cuya instalación terminó hace 24h | Muestra estado final + logs históricos. No pantalla vacía. |

---

## 15. SAGA_SNAPSHOT — Mecanismo de Reconexión

**Definición:** Mensaje de resync que el daemon envía a cualquier TUI que se conecta. Contiene el estado completo actual de la saga, permitiendo que la TUI se sincronice sin haber estado presente desde el inicio.

### 15.1 Formato del mensaje

```json
{
  "type": "__SBOS__SAGA_SNAPSHOT__",
  "ctx_id": "00dbfc97e2f14e5a8b3c1f9a6d5e7b2c",
  "saga_id": "deploy-skull-prod-20260617",
  "tenant_id": "1234567890",
  "current_step": 5,
  "total_steps": 7,
  "steps_completed": [1, 2, 3, 4],
  "steps_failed": [],
  "active_compensations": [],
  "started_at": "2026-06-17T14:32:01Z",
  "ficha_current": "keycloak",
  "timestamp": "2026-06-17T14:34:15Z"
}
```

### 15.2 Flujo de reconexión

```
TUI se conecta al socket /run/bos/bos.sock
    │
    ▼
1. TUI envía: {"method":"bos.saga.snapshot","params":{"saga_id":"..."}}
    │
    ▼
2. Daemon consulta bkernel_db.saga_state
    │
    ▼
3. Daemon retorna SAGA_SNAPSHOT con estado completo
    │
    ▼
4. TUI renderiza: paso actual, checkmarks, logs existentes
    │
    ▼
5. TUI se suscribe a eventos incrementales desde el paso actual
```

### 15.3 Propiedades del SAGA_SNAPSHOT

- **Inmutable:** generado desde `bkernel_db` (fuente de verdad), no desde memoria del daemon
- **Completo:** incluye todos los pasos completados, fallidos, y compensaciones activas
- **Trazable:** incluye `ctx_id` W3C Trace Context para correlación OpenTelemetry
- **Idempotente:** recibir el mismo snapshot múltiples veces no altera el estado de la TUI

---

## Referencias

- **SBOS-051-TENANT-SPEC.md** — Modelo A/B de Tenant (v2.0, 2026-06-17)
- **SBOS-049-CONTEXT-PLANE.md** — Plano de Contexto Distribuido
- **SBOS-050-PORT-CATALOG.md** — Catálogo de Puertos y Subdominios
- **SBOS-053-DAEMON-TUI-DECOUPLING.md** v1.2 — 13 reglas DTC + 10 casos DC + headless-first
- **Dev_Control_Certification_Method.md** v1.0 — 4 reglas Beck + SOLID + 5 Gates
- **BOS-CONTRATOS-SBOS.md** — 7 contratos que el BOS debe cumplir
- **CONCEPCION-BOS-Y-FASES-M.md** — Concepto real del BOS y escalera M1→M6
- **REGISTRO-ESTADO.md** — Progreso de átomos (251 total, FASE 20 incluida)
- **GAPS-HITL.md** v2.0 (RESUELTO) — Decisiones técnicas de arquitectura
- **BOS-REPAIR-PLAN-MAESTRO-v3.md** — Plan completo de reparación
- **deploy.go** — Saga de 7 pasos con compensación
- **seed-skull.yml** — Seed de referencia para el tenant skull
- `servers/*/task_catalog.sh` — Fichas autocontenidas con install/repair/test/status

---

*DATOS-TUI-INSTALACION.md v1.1 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
*v1.1: Agregados §13 (Modo Híbrido), §14 (DC-01 a DC-10), §15 (SAGA_SNAPSHOT).*
*Alineado con SBOS-053 v1.2 y Dev_Control_Certification_Method v1.0.*
*Este documento debe actualizarse cada vez que se agregue, modifique o elimine una ficha,*
*un paso de saga, una pantalla del wizard, un criterio de validación, o un caso DC.*
