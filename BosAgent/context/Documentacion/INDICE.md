# Documentación Técnica — BOS Control Plane Soberano

**Versión:** 3.0.0
**Mantenido por:** bos-developer
**Última actualización:** 2026-07-31

**Leyenda de estado:**
✅ = completo y actualizado · 🟡 = necesita actualización (gaps identificados) · ⬜ = pendiente de escribir

---

## ⭐ Documento rector

| Documento | Archivo | Rol |
|-----------|---------|-----|
| **Directrices de Categoría Control Plane Soberano** | [0.00_MANUAL-DIRECTRICES-BOS-CONTROL-PLANE.md](0.00_MANUAL-DIRECTRICES-BOS-CONTROL-PLANE.md) | **Carta rectora** — define la categoría, los 6 motores, los diferenciadores irrenunciables, el modelo de madurez L0-L4, y las 10 directrices editoriales. **Todo manual se lee bajo esta carta.** |
| **Plan de Completitud del Desarrollo** | [0.01_PLAN-COMPLETITUD-DESARROLLO.md](0.01_PLAN-COMPLETITUD-DESARROLLO.md) | Mapa de madurez — 8 fases, orden de prioridad, verificación VPS real. Documento vivo. |

---

## Organización por motores

Cada motor tiene un manual que lo **define** (qué hace, cómo, por qué). Los manuales siguientes lo
**fortalecen** (detalle específico de cada aspecto). El número `N.MM` refleja esta jerarquía:
`N` = motor, `MM` = orden de lectura.

---

## ① Motor IAM Installer — "Instalar"

> Bootstrap del SO, despliegue del stack soberano (PG 18.4 · Redis 8.6.2 · Vault 2.0.1 · KC 26.6.2 · Kong 3.9.x LTS),
> ciclo de vida de tenants, sagas con compensación, hardening de red, Zero Trust, certificación IAM Enterprise.

| Rol | N° | Manual | Depende de | Estado | Gaps pendientes |
|-----|:--:|--------|------------|:------:|----------------|
| **DEFINE** | 1.01 | [IAM Installer](1.01_MANUAL-IAM-INSTALLER.md) | 0.00 | ✅ 3.0.0 | — |
| Fortalece | 1.02 | [Sagas de Instalación](1.02_MANUAL-IAM-INSTALLER-SAGAS.md) | 1.01 | ✅ 3.0.0 | — |
| Fortalece | 1.03 | [Ciclo de Vida de Tenants](1.03_MANUAL-IAM-INSTALLER-TENANTS.md) | 1.02 | ✅ 2.0.0 | — |
| Fortalece | 1.04 | [Seguridad de Red — Zero Trust](1.04_MANUAL-IAM-INSTALLER-SEGURIDAD.md) | 1.01 | 🟡 1.3.0 | NRS-03 mTLS entre daemons · NRS-04 Wazuh SIEM · NRS-10 CI pipeline gosec/govulncheck · NIST SP 800-207 7 tenets explícitos |
| Fortalece | 1.05 | [Estándares y Certificación IAM Enterprise](1.05_MANUAL-IAM-INSTALLER-ESTANDARES.md) | 1.04 | 🟡 1.0.0 | Tabla de evidencia por control ISO 27001:2022 (A.8.9-A.8.32) · SLOs k6 con latencias objetivo · pasos FAPI 2.0 Conformance Suite |

---

## ② Motor SO Observable — "Observar"

> Watchdog 3-capas, 4 motores de capacidad (collector/forecaster/policy_engine/action_engine),
> health checks, métricas Prometheus, reconciliación y drift detection, anti-death-spiral HPA+VPA.

| Rol | N° | Manual | Depende de | Estado | Gaps pendientes |
|-----|:--:|--------|------------|:------:|----------------|
| **DEFINE** | 2.01 | [SO Observable](2.01_MANUAL-SO-OBSERVABLE.md) | 1.01 | ✅ 1.0.0 | — |
| Fortalece | 2.02 | [Motores de Capacidad](2.02_MANUAL-SO-OBSERVABLE-CAPACIDAD.md) | 2.01 | 🟡 1.0.0 | Los 4 motores están especificados pero sin implementación real: añadir archivos Go creados · tablas T-406/T-407 en BD · integración watchdog (A.08 flujo ITIL 4) · anti-death-spiral histéresis (A.06 §4) |
| Fortalece | 2.03 | [Health Checks y Métricas](2.03_MANUAL-SO-OBSERVABLE-METRICAS.md) | 2.01 | ✅ 1.0.0 | — |
| Fortalece | 2.04 | [Reconciliación y Drift](2.04_MANUAL-SO-OBSERVABLE-RECONCILIACION.md) | 2.03 | ✅ 1.0.0 | — |

---

## ③ Motor Server FICHAS — "Administrar fichas"

> Máquina de 18 estados (naming inglés: PENDING/INSTALLED/DEGRADED/…), executor, parser, discovery,
> health, drift, repair, rollback, versionado, CLI, Port Manager Kardex, Event Bus Redis Streams.

| Rol | N° | Manual | Depende de | Estado | Gaps pendientes |
|-----|:--:|--------|------------|:------:|----------------|
| **DEFINE** | 3.01 | [Server FICHAS](3.01_MANUAL-SERVER-FICHAS.md) | 1.01 | 🟡 1.0.0 | Actualizar nombres de los 18 estados al inglés (A.14 v6.0.0): PENDING/INSTALLED/DEGRADED/REPAIRING/UNINSTALLED/etc. |
| Fortalece | 3.02 | [Executor y Parser](3.02_MANUAL-SERVER-FICHAS-EXECUTOR.md) | 3.01 | ✅ 1.0.0 | — |
| Fortalece | 3.03 | [Discovery, Health y Drift](3.03_MANUAL-SERVER-FICHAS-DISCOVERY.md) | 3.02 | ✅ 1.0.0 | — |
| Fortalece | 3.04 | [Repair, Rollback y Cleanup](3.04_MANUAL-SERVER-FICHAS-REPAIR.md) | 3.03 | ✅ 1.0.0 | — |
| Fortalece | 3.05 | [Versionado y Dashboard](3.05_MANUAL-SERVER-FICHAS-VERSIONADO.md) | 3.01 | ✅ 1.0.0 | — |
| Fortalece | 3.06 | [CLI bosctl ficha](3.06_MANUAL-SERVER-FICHAS-CLI.md) | 3.02 | ✅ 1.0.0 | — |
| Fortalece | 3.07 | [Catálogo de Fichas y Servidores Lógicos](3.07_MANUAL-SERVER-FICHAS-CATALOGO.md) | 3.01 | 🟡 1.0.0 | Añadir S16-webserver (nginx/certbot/modsecurity/website-engine) · corregir bauth → S03-identityserver · añadir fichas daemons hermanos (bkernel/biedata/bsearch/bnexus) |
| **DEFINE** | 3.08 | [Port Manager y Kardex](3.08_MANUAL-PORT-MANAGER.md) | 3.01, 3.02 | 🟡 2.1.0 | Cablear portman.Assign() en lifecycle.go · portman.Release() en UNINSTALLED · ValidateKardex() en reconcile/scheduler.go cada 300s |
| Fortalece | 3.09 | [Event Bus Redis Streams](3.09_MANUAL-SERVER-FICHAS-EVENTBUS.md) | 3.02, 3.08 | ⬜ PENDIENTE | Nuevo subsistema — events ficha.installed/degraded/repaired/uninstalled · ctx.promoted/invalidated · contratos entre daemons vía Redis Streams DB0 |

---

## ④ Motor Context Plane — "Resolver contexto"

> ctx_id, dctx_id, device.register, promote, switch, invalidate, seguridad,
> propagación, integración bAuth 12 dominios, FAPI 2.0, Kong PEP, NIST 800-207 Policy Administrator.

| Rol | N° | Manual | Depende de | Estado | Gaps pendientes |
|-----|:--:|--------|------------|:------:|----------------|
| **DEFINE** | 4.01 | [Context Plane](4.01_MANUAL-CONTEXT-PLANE.md) | 1.01 | ✅ 2.0.0 | — |
| Fortalece | 4.02 | [Ciclo de Vida ctx_id](4.02_MANUAL-CONTEXT-PLANE-CICLO.md) | 4.01 | ✅ 1.0.0 | — |
| Fortalece | 4.03 | [Seguridad del Contexto](4.03_MANUAL-CONTEXT-PLANE-SEGURIDAD.md) | 4.02 | 🟡 1.0.0 | Sección mTLS en endpoints ctx · cert efímero ECDSA P-256 Vault PKI por sesión · NIST 800-207 Tenet 2 (autenticación en cada recurso) |
| Fortalece | 4.04 | [Propagación y Trazabilidad](4.04_MANUAL-CONTEXT-PLANE-PROPAGACION.md) | 4.01 | ✅ 1.0.0 | — |
| Fortalece | 4.05 | [Integración bAuth e IAM Enterprise](4.05_MANUAL-CONTEXT-PLANE-BAUTH.md) | 4.01 | 🟡 1.0.0 | FAPI 2.0 sobre ctx: PAR, DPoP, PKCE, LoA 1-4 (RFC 9470) · Plugin SBOS-Context para Kong (PEP NIST 800-207) · Evaluación 12 dominios bAuth con Redis cache 30s |

---

## ⑤ Motor Dashboard — "Exponer interface"

> JSON-RPC 2.0, WebSocket sobre Unix socket, contratos de eventos, momentos de conexión,
> Domain Manager S16, biaOS agente IA soberano, RBAC dual.

| Rol | N° | Manual | Depende de | Estado | Gaps pendientes |
|-----|:--:|--------|------------|:------:|----------------|
| **DEFINE** | 5.01 | [Dashboard — Interface Dual](5.01_MANUAL-DASHBOARD.md) | 1.01 | 🟡 2.0.0 | Sección RBAC dual (FileRBAC + BauthRBAC) sobre los 55+ métodos JSON-RPC · Domain Manager `bos.web.domain.*` 5 métodos (S16-webserver) |
| Fortalece | 5.02 | [WebSocket sobre Unix Socket](5.02_MANUAL-DASHBOARD-WEBSOCKET.md) | 5.01 | ✅ 1.0.0 | — |
| Fortalece | 5.03 | [Contratos de Eventos](5.03_MANUAL-DASHBOARD-EVENTOS.md) | 5.01 | ✅ 1.0.0 | — |
| Fortalece | 5.04 | [Momentos de Conexión](5.04_MANUAL-DASHBOARD-CONEXION.md) | 5.03 | ✅ 1.0.0 | — |
| Fortalece | 5.05 | [biaOS — Agente IA Soberano](5.05_MANUAL-DASHBOARD-BIAOS.md) | 5.01 | ⬜ PENDIENTE | Nuevo subsistema — ICAP Engine, embedding diagnosis, Ollama local, `bos.ai.*` JSON-RPC, flujo A.08 Etapa 2 |

---

## ⑥ Motor Banco de Pruebas — "Verificar"

> Documento vivo de pruebas verificables. Dos vías obligatorias por prueba: CLI + JSON-RPC. Nunca ✅.

| Rol | N° | Manual | Depende de | Estado |
|-----|:--:|--------|------------|:------:|
| **DEFINE** | 6.01 | [Banco de Pruebas BOS](6.01_MANUAL-BANCO-PRUEBAS.md) | ①–⑤ | 🟡 1.0.0 (vivo, nunca ✅) |

---

## Anexos

| N° | Título | Motor | Estado | Gaps pendientes |
|:--:|--------|:-----:|:------:|----------------|
| A.01 | [Estado del Arte — Planos de Control 2026](Anexos/A.01_ANEXO-INDUSTRIA-CONTROL-PLANES.md) | ① | ✅ 1.0.0 | — |
| A.02 | [Estructura del Servidor de Producción](Anexos/A.02_ANEXO-ESTRUCTURA-SERVIDOR-PRODUCCION.md) | ① | ✅ 2.2.0 | — |
| A.03 | [Plataforma Web Multi-Tenant con Nginx](Anexos/A.03_ANEXO-PLATAFORMA-WEB-MULTI-TENANT-NGINX.md) | ①⑤ | ✅ 3.0.0 | — |
| A.04 | [Stack Canónico y Puertos (SBOS-050)](Anexos/A.04_ANEXO-STACK-CANONICO-PUERTOS.md) | ① | ✅ 1.0.0 | — |
| A.05 | [Anatomía Canónica de Ficha](Anexos/A.05_ANEXO-ANATOMIA-FICHA.md) | ③ | ✅ 1.0.0 | — |
| A.06 | [Kubernetes Operator Pattern y el BOS](Anexos/A.06_ANEXO-KUBERNETES-OPERATOR-PATTERN.md) | ③ | ✅ 1.0.0 | — |
| A.07 | [Vault PKI, AppRole y Secretos](Anexos/A.07_ANEXO-VAULT-PKI-SECRETS.md) | ① | ✅ 1.0.0 | — |
| A.08 | [Flujo End-to-End de Operación](Anexos/A.08_ANEXO-FLUJO-END-TO-END.md) | ② | ✅ 1.0.0 | — |
| A.09 | [Normas y Estándares Internacionales](Anexos/A.09_ANEXO-NORMAS-ESTANDARES-INTERNACIONALES.md) | TODOS | ✅ 1.0.0 | — |
| A.10 | [Observabilidad del BOS](Anexos/A.10_ANEXO-OBSERVABILIDAD-BOS.md) | ②⑤ | ✅ 1.0.0 | — |
| A.11 | [Cadena Completa de Instalación](Anexos/A.11_ANEXO-CADENA-INSTALACION.md) | ① | ✅ 4.0.0 | — |
| A.12 | [Motor de Asignación de Puertos y Kardex](Anexos/A.12_ANEXO-PORT-MANAGER-KARDEX.md) | ③ | ✅ 4.0.0 | — |
| A.13 | [Arquitectura K8s de la VPS de Prueba](Anexos/A.13_ANEXO-VPS-PRUEBA-KUBERNETES-ARQUITECTURA.md) | ①⑥ | ✅ 1.0.0 | — |
| A.14 | [DDL BOS — Tablas del Control Plane (v6.0.0)](Anexos/A.14_PROPUESTA-DDL-BOS-TABLAS-FALTANTES.md) | ③④ | 🟡 6.0.0 | Nomenclatura en inglés (18 estados) ya en DDL — falta tabla `bos.net_web_domain` (T-415 S16) · verificar sync con schema real en VPS |
| A.15 | [Network Security Manager](Anexos/A.15_ANEXO-NETWORK-SECURITY-MANAGER.md) | ①③ | ✅ 1.0.0 | — |
| A.16 | [Implementación Zero Trust NIST SP 800-207](Anexos/A.16_ANEXO-ZERO-TRUST-IMPLEMENTACION.md) | ① | ⬜ PENDIENTE | Nuevo — guía NIST SP 800-207 aplicada a SBOS: Kong=PEP, BOS=PA, bAuth=PE, mTLS entre daemons, NetworkPolicy deny-all, Wazuh SIEM |
| A.17 | [Certificación FAPI 2.0](Anexos/A.17_ANEXO-FAPI2-CERTIFICACION.md) | ①④⑥ | ⬜ PENDIENTE | Nuevo — procedimiento FAPI 2.0 Conformance Suite, PAR, DPoP, PKCE, PS256/ES256 |

---

## Estado del corpus

| Motor | Manuales | ✅ Completo | 🟡 Actualizar | ⬜ Pendiente |
|-------|:--------:|:-----------:|:-------------:|:-----------:|
| ① IAM Installer | 5 | 3 | 2 (1.04 · 1.05) | — |
| ② SO Observable | 4 | 3 | 1 (2.02) | — |
| ③ Server FICHAS | 9 | 5 | 3 (3.01 · 3.07 · 3.08) | 1 (3.09) |
| ④ Context Plane | 5 | 3 | 2 (4.03 · 4.05) | — |
| ⑤ Dashboard | 5 | 4 | 1 (5.01) | 1 (5.05) |
| ⑥ Banco de Pruebas | 1 | — | 1 (6.01 vivo) | — |
| **TOTAL manuales** | **29** | **18** | **9** | **2** |

| Anexos | Total | ✅ Completo | 🟡 Actualizar | ⬜ Pendiente |
|--------|:-----:|:-----------:|:-------------:|:-----------:|
| A.01–A.17 | **17** | 14 | 1 (A.14) | 2 (A.16 · A.17) |

**Prioridad de actualización (orden del plan 0.01):**
1. `3.01` → nombres 18 estados en inglés (Fase I.0, bloqueante de consistencia)
2. `3.07` → S16-webserver + daemons hermanos (Fase I.5)
3. `1.04` → NRS-03/04/10 + NIST SP 800-207 (Fase II)
4. `4.03` → mTLS + Vault PKI ephemeral cert (Fase III)
5. `4.05` → FAPI 2.0 + Kong PEP (Fase III)
6. `2.02` → implementación real 4 motores (Fase V)
7. `5.01` → RBAC dual + Domain Manager (Fase VI)
8. `1.05` → evidencia ISO 27001 + SLOs k6 (Fase VII)

**Nuevos a escribir (orden de activación):**
1. `3.09` — Event Bus Redis Streams (Fase IV)
2. `A.16` — Zero Trust NIST 800-207 (Fase II)
3. `5.05` — biaOS Agente IA Soberano (Fase VI)
4. `A.17` — Certificación FAPI 2.0 (Fase VII)

---

*SKULL · SBOS · BosAgent · Julio 2026 · v3.0.0*
