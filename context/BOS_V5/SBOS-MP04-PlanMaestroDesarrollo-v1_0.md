# SBOS-MP04
## Plan Maestro de Desarrollo: Estado del Proyecto y Ruta de Implementación
### Evaluación de Daemons + Inventario de Fichas + Capital Técnico TODOIAM + Plan de Sprints

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-MP04
**Sintetiza:** Evaluación de 8 daemons, inventario de 38 fichas con porcentajes, análisis del código legacy TODOIAM (4,495 líneas validadas), y plan de sprints para puesta en marcha.

---

## 1. Estado Actual

Fase A del Roadmap (SBOS-017). 68 documentos, ~43,000 líneas de especificación. Sin código ejecutable. Meta OKR: 1 cliente piloto Q3 2026. El desarrollo debe empezar ya.

---

## 2. Evaluación de Madurez de los 8 Daemons

| # | Daemon | Nivel | Líneas | Listo | Lo que falta |
|:-:|--------|:-----:|:------:|:-----:|-------------|
| 1 | **bos** (Installer) | N5 | 3,450 | ✅ | Ficha de referencia real |
| 2 | **bkernel** (Data Kernel) | N5 | 2,382 | ✅ | — |
| 3 | **biedata** (Integration) | N4.5 | 2,122 | ✅ | XML de ejemplo AFIP/SAT |
| 4 | **bcompass** (AI Tools) | N4.5 | 2,646 | ✅ | Protocolo fed. learning |
| 5 | **bsearch** (Data RAG) | N5 | 1,727 | ✅ | — |
| 6 | **bauth** (Auth Enforce) | N5 | 2,467 | ✅ | ⚠ Sin SP en Roadmap |
| 7 | **bhnexus** (Nexus Host) | N4 | 259 | ⚠ | Estructura binario Go |
| 8 | **banexus** (Nexus Agent) | N4 | 215 | ⚠ | Spec PAM + Go |

**6 de 8 listos para código.** Los 2 restantes se necesitan en Fase 5.

---

## 3. Capital Técnico — TODOIAM (código validado)

### 3.1 Servicios Docker funcionales (10)

| Servicio | Imagen Docker | % ficha |
|---------|---------------|:-------:|
| PostgreSQL 18 | `postgres:18-alpine` | 75% |
| PostgreSQL 17 | `postgres:17-alpine` | 70% |
| PostgreSQL 16 | `postgres:16-alpine` | 70% |
| MySQL 8.0 | `mysql:8.0` | 65% |
| Redis 7 | `redis:7-alpine` | 70% |
| PgAdmin 4 | `dpage/pgadmin4:latest` | 70% |
| Mailserver | `docker-mailserver:latest` | 80% |
| PostfixAdmin | `postfixadmin:latest` | 80% |
| Roundcube | `roundcubemail:latest` | 80% |
| Cypht | `php:8.3-apache` | 75% |

### 3.2 Motor reutilizable del TODOIAM

- **YAML Engine:** motor de fases (pre_install → install → post_install → verify) — reutilización 100%
- **Task Catalog:** ~70 funciones Bash validadas (crear BDs, verificar salud, crear cuentas mail, generar SSL, tests) — redistribuir por ficha
- **Podman Core:** punto único de ejecución de contenedores — reutilización 100% (migrado de Docker a Podman 4.9.3)

### 3.3 Qué cambia al migrar a SBOS

- Stacks monolíticos (3) → fichas individuales (10+)
- IPs fijas → DNS K8s (cuando tengamos K8s)
- Passwords .env → Vault
- Sin Keycloak → agregarlo como ficha nueva

---

## 4. Inventario de 38 Fichas por Prioridad

### P1 — Sin estas no arranca (12 fichas)

| Ficha | % | TODOIAM |
|-------|:-:|:------:|
| sbos-bootstrap-os | 40% | ✗ |
| sbos-bootstrap-k8s | 40% | ✗ |
| sbos-bootstrap-platform | 40% | ✗ |
| postgresql | 75% | ✅ |
| redis | 70% | ✅ |
| vault | 30% | ✗ |
| keycloak | 30% | ✗ |
| nginx | 25% | ✗ |
| kong | 25% | ✗ |
| prometheus | 30% | ✗ |
| grafana | 30% | ✗ |
| sbos-bootstrap-hardening | 30% | ✗ |

### P2 — Funciona como SO (8 fichas)

| Ficha | % | TODOIAM |
|-------|:-:|:------:|
| mailserver | 80% | ✅ |
| postfixadmin | 80% | ✅ |
| roundcube | 80% | ✅ |
| cypht | 75% | ✅ |
| tryton | 25% | ✗ |
| pgadmin | 70% | ✅ |
| alertmanager | 25% | ✗ |
| oauth2-proxy | 20% | ✗ |

### P3 — Valor agregado (10 fichas)

mysql 65%, orangehrm 15%, loki 25%, tempo 20%, gitlab 20%, bareos 15%, velero 20%, paperless 20%, docuseal 15%, tryton-workers 20%

### P4 — Avanzado post-v0.9 (8 fichas)

linkerd, kyverno, network-validator, wazuh, certbot, symmetricds, sbos-nginx-web, minio

**Promedio global: ~35%.** Correo al 79% (TODOIAM). Bootstrap al 35%.

---

## 5. Plan de Sprints (4 semanas con Testbench Podman)

| Sprint | Fichas | Entregable |
|--------|--------|-----------|
| 1 | postgresql, redis, vault, pgadmin | Datos + secrets |
| 2 | keycloak, kong, nginx, oauth2-proxy | SSO + gateway |
| 3 | mailserver, postfixadmin, roundcube, cypht | Correo con SSO |
| 4 | prometheus, grafana, tryton | Observabilidad + ERP |

Las fichas se validan en Podman 4.9.3 usando el Testbench (SBOS-MP05) antes de migrar a K8s.

---

## 6. Dependencias Críticas

```
bos (SP-01) → TODO depende de esto
  ├── bootstrap → todas las fichas
  ├── bkernel → PostgreSQL + Tryton
  │     └── biedata, bsearch, bcompass
  ├── bauth → Keycloak + Tryton
  │     └── bhnexus → banexus
  └── Core UI → Backend + SDK
```

---

*SKULL · SBOS · SBOS-MP04 · Marzo 2026*
