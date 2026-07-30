# Documentación Técnica — BOS Control Plane Soberano

**Versión:** 2.1.0
**Mantenido por:** bos-developer
**Última actualización:** 2026-07-18

---

## ⭐ Documento rector

| Documento | Archivo | Rol |
|-----------|---------|-----|
| **Directrices de Categoría Control Plane Soberano** | [0.00_MANUAL-DIRECTRICES-BOS-CONTROL-PLANE.md](0.00_MANUAL-DIRECTRICES-BOS-CONTROL-PLANE.md) | **Carta rectora** — define la categoría, los 6 motores, los diferenciadores irrenunciables, el modelo de madurez L0-L4, y las 10 directrices editoriales. **Todo manual se lee bajo esta carta.** |

---

## Organización por motores

lo **define** (qué hace, cómo, por qué). Los manuales siguientes lo **fortalecen** (detalle
específico de cada aspecto). El número `N.MM` refleja esta jerarquía: `N` = motor, `MM` =
orden de lectura.

---

## ① Motor IAM Installer — "Instalar"

> Bootstrap del SO, despliegue del stack de identidad, ciclo de vida de tenants, sagas, hardening de red.

| Rol | N° | Manual | Depende de | Estado |
|-----|:--:|--------|------------|:------:|
| **DEFINE** | 1.01 | [IAM Installer](1.01_MANUAL-IAM-INSTALLER.md) | 0.00 | ✅ 3.0.0 |
| Fortalece | 1.02 | [Sagas de Instalación](1.02_MANUAL-IAM-INSTALLER-SAGAS.md) | 1.01 | ✅ 3.0.0 |
| Fortalece | 1.03 | [Ciclo de Vida de Tenants](1.03_MANUAL-IAM-INSTALLER-TENANTS.md) | 1.02 | ✅ 2.0.0 |
| Fortalece | 1.04 | [Seguridad de Red  ](1.04_MANUAL-IAM-INSTALLER-SEGURIDAD.md) | 1.01 | ✅ 1.0.0 |
| Fortalece | 1.05 | [Estándares y Certificación](1.05_MANUAL-IAM-INSTALLER-ESTANDARES.md) | 1.04 | ✅ 1.0.0 |

---

## ② Motor SO Observable — "Observar"

> Watchdog 3-capas, motores de capacidad, health checks, métricas, reconciliación y drift.

| Rol | N° | Manual | Depende de | Estado |
|-----|:--:|--------|------------|:------:|
| **DEFINE** | 2.01 | [SO Observable](2.01_MANUAL-SO-OBSERVABLE.md) | 1.01 | ✅ 1.0.0 |
| Fortalece | 2.02 | [Motores de Capacidad](2.02_MANUAL-SO-OBSERVABLE-CAPACIDAD.md) | 2.01 | ✅ 1.0.0 |
| Fortalece | 2.03 | [Health Checks y Métricas](2.03_MANUAL-SO-OBSERVABLE-METRICAS.md) | 2.01 | ✅ 1.0.0 |
| Fortalece | 2.04 | [Reconciliación y Drift](2.04_MANUAL-SO-OBSERVABLE-RECONCILIACION.md) | 2.03 | ✅ 1.0.0 |

---

## ③ Motor Server FICHAS — "Administrar fichas"

> Máquina de 18 estados, executor, parser, discovery, health, drift, repair, rollback, versionado, CLI.

| Rol | N° | Manual | Depende de | Estado |
|-----|:--:|--------|------------|:------:|
| **DEFINE** | 3.01 | [Server FICHAS](3.01_MANUAL-SERVER-FICHAS.md) | 1.01 | ✅ 1.0.0 |
| Fortalece | 3.02 | [Executor y Parser](3.02_MANUAL-SERVER-FICHAS-EXECUTOR.md) | 3.01 | ✅ 1.0.0 |
| Fortalece | 3.03 | [Discovery, Health y Drift](3.03_MANUAL-SERVER-FICHAS-DISCOVERY.md) | 3.02 | ✅ 1.0.0 |
| Fortalece | 3.04 | [Repair, Rollback y Cleanup](3.04_MANUAL-SERVER-FICHAS-REPAIR.md) | 3.03 | ✅ 1.0.0 |
| Fortalece | 3.05 | [Versionado y Dashboard](3.05_MANUAL-SERVER-FICHAS-VERSIONADO.md) | 3.01 | ✅ 1.0.0 |
| Fortalece | 3.06 | [CLI bosctl ficha](3.06_MANUAL-SERVER-FICHAS-CLI.md) | 3.02 | ✅ 1.0.0 |
| Fortalece | 3.07 | [Catálogo de Fichas](3.07_MANUAL-SERVER-FICHAS-CATALOGO.md) | 3.01 | ✅ 1.0.0 |
| **DEFINE** | 3.08 | [Port Manager](3.08_MANUAL-PORT-MANAGER.md) | 3.01, 3.02 | ✅ 1.0.0 |

---

## ④ Motor Context Plane — "Resolver contexto"

> ctx_id, dctx_id, device.register, promote, switch, invalidate, seguridad, propagación, integración bAuth.

| Rol | N° | Manual | Depende de | Estado |
|-----|:--:|--------|------------|:------:|
| **DEFINE** | 4.01 | [Context Plane](4.01_MANUAL-CONTEXT-PLANE.md) | 1.01 | ✅ 2.0.0 |
| Fortalece | 4.02 | [Ciclo de Vida ctx_id](4.02_MANUAL-CONTEXT-PLANE-CICLO.md) | 4.01 | ✅ 1.0.0 |
| Fortalece | 4.03 | [Seguridad del Contexto](4.03_MANUAL-CONTEXT-PLANE-SEGURIDAD.md) | 4.02 | ✅ 1.0.0 |
| Fortalece | 4.04 | [Propagación y Trazabilidad](4.04_MANUAL-CONTEXT-PLANE-PROPAGACION.md) | 4.01 | ✅ 1.0.0 |
| Fortalece | 4.05 | [Integración bAuth](4.05_MANUAL-CONTEXT-PLANE-BAUTH.md) | 4.01 | ✅ 1.0.0 |

---

## ⑤ Motor Dashboard — "Exponer interface"

> JSON-RPC 2.0, WebSocket sobre Unix socket, contratos de eventos, momentos de conexión.

| Rol | N° | Manual | Depende de | Estado |
|-----|:--:|--------|------------|:------:|
| **DEFINE** | 5.01 | [Dashboard](5.01_MANUAL-DASHBOARD.md) | 1.01 | ✅ 1.0.0 |
| Fortalece | 5.02 | [WebSocket sobre Unix Socket](5.02_MANUAL-DASHBOARD-WEBSOCKET.md) | 5.01 | ✅ 1.0.0 |
| Fortalece | 5.03 | [Contratos de Eventos](5.03_MANUAL-DASHBOARD-EVENTOS.md) | 5.01 | ✅ 1.0.0 |
| Fortalece | 5.04 | [Momentos de Conexión](5.04_MANUAL-DASHBOARD-CONEXION.md) | 5.03 | ✅ 1.0.0 |

---

## ⑥ Motor Banco de Pruebas — "Verificar"

> Documento vivo de pruebas verificables. Dos vías obligatorias por prueba: CLI + JSON-RPC.

| Rol | N° | Manual | Depende de | Estado |
|-----|:--:|--------|------------|:------:|
| **DEFINE** | 6.01 | [Banco de Pruebas BOS](6.01_MANUAL-BANCO-PRUEBAS.md) | ①–⑤ | 🟡 1.0.0 (vivo, nunca ✅) |

---

## Anexos

| N° | Anexo | Fortalece al motor | Estado |
|:--:|-------|:------------------:|:------:|
| A.01 | [Estado del Arte — Planos de Control 2026](Anexos/A.01_ANEXO-INDUSTRIA-CONTROL-PLANES.md) | ① | ✅ |
| A.02 | [Estructura del Servidor de Producción](Anexos/A.02_ANEXO-ESTRUCTURA-SERVIDOR-PRODUCCION.md) | ① | ✅ 2.2.0 |
| A.03 | [Plataforma Web Multi-Tenant con Nginx](Anexos/A.03_ANEXO-PLATAFORMA-WEB-MULTI-TENANT-NGINX.md) | ① | ✅ |
| A.04 | [Stack Canónico y Puertos (SBOS-050)](Anexos/A.04_ANEXO-STACK-CANONICO-PUERTOS.md) | ① | ✅ 1.0.0 |
| A.05 | [Anatomía Canónica de Ficha](Anexos/A.05_ANEXO-ANATOMIA-FICHA.md) | ③ | ✅ 1.0.0 |
| A.06 | [Kubernetes Operator Pattern y el BOS](Anexos/A.06_ANEXO-KUBERNETES-OPERATOR-PATTERN.md) | ③ | ✅ 1.0.0 |
| A.07 | [Vault PKI, AppRole y Secretos](Anexos/A.07_ANEXO-VAULT-PKI-SECRETS.md) | ① | ✅ 1.0.0 |
| A.08 | [Flujo End-to-End de Operación](Anexos/A.08_ANEXO-FLUJO-END-TO-END.md) | ② | ✅ 1.0.0 |
| A.09 | [Normas y Estándares Internacionales](Anexos/A.09_ANEXO-NORMAS-ESTANDARES-INTERNACIONALES.md) | TODOS | ✅ 1.0.0 |
| A.10 | [Observabilidad del BOS](Anexos/A.10_ANEXO-OBSERVABILIDAD-BOS.md) | ②⑤ | ✅ 1.0.0 |
| A.11 | [Cadena Completa de Instalación](Anexos/A.11_ANEXO-CADENA-INSTALACION.md) | ① | ✅ 4.0.0 |
| A.12 | [Motor de Asignación de Puertos y Kardex](Anexos/A.12_ANEXO-PORT-MANAGER-KARDEX.md) | ③ | ✅ 4.0.0 |
| A.13 | [Arquitectura K8s de la VPS de Prueba](Anexos/A.13_ANEXO-VPS-PRUEBA-KUBERNETES-ARQUITECTURA.md) | ①⑥ | ✅ 1.0.0 |

---

## Estado del corpus

| Motor | Manuales | Anexos | ✅ Completado | 🟡 Vivo | ⬜ Pendiente |
|-------|:--------:|:------:|:------------:|:------:|:----------:|
| ① IAM Installer | 5 | 7 | 12 | 0 | 0 |
| ② SO Observable | 4 | 1 | 5 | 0 | 0 |
| ③ Server FICHAS | 8 | 3 | 11 | 0 | 0 |
| ④ Context Plane | 5 | 0 | 5 | 0 | 0 |
| ⑤ Dashboard | 4 | 1 | 5 | 0 | 0 |
| ⑥ Banco de Pruebas | 1 | 0 | 0 | 1 | 0 |
| **TOTAL** | **27** | **13** | **38** | **1** | **0** |

**Nota:** A.09 aplica a TODOS los motores. A.10 aplica a ② y ⑤. A.12 aplica a ③.

---

*SKULL · SBOS · BosAgent · Julio 2026*
