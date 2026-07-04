# SBOS-020-COREUI
## Core UI — Frontend del IAM Installer — Estándar HUMAN-DOC
### SKULL · SBOS · V8 · Mayo 2026

---

## 1. Identidad

| Campo | Valor |
|---|---|
| Nombre | Core UI |
| Tecnología | Flutter (Dart) — único codebase multi-dispositivo |
| Despliegue | Pod K8s en namespace sbos-installer (es una ficha SBOS) |
| Acceso | Web, Android, iOS, tablet, desktop |
| State management | BLoC (operaciones) + Riverpod (catálogo global) |
| Comunicación | REST API + WebSocket (Centrifugo) |
| Auth | Keycloak OIDC (JWT) — MFA obligatorio |
| API spec | OpenAPI 3.0 (/etc/sbos/openapi.yaml) |

## 2. Función

Frontend del IAM Installer. Cockpit soberano del SBOS. Adicionalmente es el **PAP (Policy Administration Point)** del RolFramework — único lugar donde un admin puede crear/editar RolTemplates y UserTemplates.

**No ejecuta operaciones** — las solicita al Core vía API REST. **No mantiene estado propio** — todo vive en .sbos_state.json. Si Core UI cae, sistema opera vía bosctl.

## 3. El Core UI como PAP del RolFramework

| Punto | Función | Implementación SBOS |
|---|---|---|
| PAP | Administra políticas de identidad | **Core UI** — formularios RolTemplate/UserTemplate |
| PIP | Datos de políticas | PostgreSQL → bos_rol_template |
| PDP | Decide acceso | Keycloak + Tryton |
| PEP | Bloquea/permite | Tryton (5 capas) + OAuth2-Proxy |

Vistas de identidad: RolTemplates (lista, crear, editar, jerarquía, sync status, force-sync, historial). UserTemplates (lista, asignar rol, flujo onboarding, acciones rápidas). Solo sbos-admin puede editar.

## 4. Las 5 Vistas Principales

### Vista 1 — Catálogo de Fichas
- Fichas por servidor lógico y por estado con semaforización
- Info por ficha: estado, versión, recursos, dependencias, health, acciones
- Grafo de dependencias interactivo (DEPENDENCY_RESOLVER + MENU_ENGINE)
- Probe/dry-run: "Verificar antes de instalar"
- Sección Identidad integrada (RolTemplates, UserTemplates)

### Vista 2 — Progreso de Operaciones
- Progreso paso a paso en tiempo real vía WebSocket
- Reconexión + replay desde .jsonl (no pierde pasos si navegador cierra)
- Errores accionables: CAUSA + SOLUCIÓN + comando CLI

### Vista 3 — Dashboard de Salud
- Semaforización global (verde/ámbar/rojo)
- Métricas cluster (CPU/RAM/disco por nodo vía Prometheus)
- Fichas en ALERTA con acceso directo a reparar
- Panel sincronización identidad (SYNCED/DRIFT/ERROR)
- Alertas push a dispositivo móvil

### Vista 4 — Crecimiento Horizontal
- Asistente guiado: 3 parámetros (IP, SSH password, rol del nodo)
- kubeadm join automático + node selector + verificación
- Monitoreo post-expansión

### Vista 5 — Auditoría
- Historial completo: quién, cuándo, qué, resultado, duración
- Filtros: ficha, tipo, admin, fechas, resultado
- Export JSON
- Trazabilidad governance dual-control (ambas aprobaciones)

## 5. Relación Core ↔ Core UI

```
Admin en Core UI → POST /api/fichas/postgresql/install
  → Backend Python: FICHA_LINTER → DEPENDENCY_RESOLVER → INSTALL_RUNNER
  → Core Bash: YAML Engine → sbos_k8s_core() → K8s
  → Señales stdout → PROGRESS_EMITTER → WebSocket → Core UI (tiempo real)
  → STATE_MANAGER → .sbos_state.json → Core UI refleja nuevo estado
```

## 6. Arquitectura Flutter

**BLoC** para operaciones de alto riesgo (install, repair, update, uninstall, RolTemplates, UserTemplates). Flujo Event → BLoC → State. Testeable y auditable.

**Riverpod** para estado global (catálogo, dashboard, sync RolFramework). Providers declarativos sin BuildContext.

**WebSocket + StreamBuilder** para progreso en tiempo real. Reconstruye solo pasos afectados.

**Feature-First** architecture:
```
lib/features/
  catalog/   → vista catálogo + lógica fichas
  progress/  → vista progreso + WebSocket stream
  dashboard/ → vista salud + métricas Prometheus
  growth/    → vista expansión cluster
  audit/     → vista auditoría
  identity/  → vista RolTemplates + UserTemplates
  shared/    → widgets compartidos + tema + routing
    state/   → Providers globales Riverpod
```

## 7. Multi-Dispositivo

| Factor | Uso | Experiencia |
|---|---|---|
| Móvil | Emergencias nocturnas, alertas | Vista compacta ALERTA. Acciones rápidas. Push notifications. Biometría 2am |
| Tablet | Gestión operativa reuniones | Dos paneles (catálogo + detalle). Landscape optimizado |
| Desktop/Web | Administración completa | Dashboard extendido, logs realtime, grafo pantalla completa, RolTemplates |

## 8. Estrategia Offline

Pérdida durante operación: PROGRESS_EMITTER replay desde .jsonl al reconectar. Sin conexión al Core: último estado en caché (modo lectura). No permite ejecutar operaciones.

## 9. Seguridad por Capas

**Capa 1 — Auth:** Keycloak OIDC + MFA obligatorio. Biometría en móvil (post-MFA, no reemplaza).

**Capa 2 — RBAC:**

| Rol | Ver | Ejecutar | Governance 3 | Editar RolTemplates |
|---|---|---|---|---|
| sbos-viewer | Todo | Nada | No | No |
| sbos-operator | Todo + sync identity | Install, repair, update | No | No |
| sbos-admin | Todo | Todo incl. uninstall | Sí | Sí |

**Capa 3 — Confirmaciones:** governance ≥2 muestra pantalla con recursos afectados + string confirmación. Cat.3 requiere segundo sbos-admin (ventana 60min).

**Capa 4 — Auditoría:** toda acción en Vault audit log (identidad, timestamp, IP, acción, ficha, resultado).

## 10. Contrato de API — Endpoints REST

### Fichas
```
GET  /api/fichas                     → lista con estado
GET  /api/fichas/{id}                → detalle + logs
POST /api/fichas/{id}/probe          → dry-run (200)
POST /api/fichas/{id}/install        → 202 + operation_id + ws_url
POST /api/fichas/{id}/repair         → 202 + operation_id + ws_url
POST /api/fichas/{id}/update         → 202 + operation_id + ws_url
POST /api/fichas/{id}/uninstall      → 202 (requiere confirmation_string)
```

### Dashboard y Cluster
```
GET  /api/dashboard                  → salud global + nodos + fichas alerta + rolframework
POST /api/cluster/nodes              → agregar nodo (IP + SSH + role)
```

### Identidad (RolFramework PAP)
```
GET  /api/identity/roltemplates      → lista con sync_status
GET  /api/identity/roltemplates/{id} → detalle + historial
POST /api/identity/roltemplates      → crear (sbos-admin)
PUT  /api/identity/roltemplates/{id} → editar + re-sync
POST /api/identity/roltemplates/{id}/force-sync → forzar sync DRIFT
GET  /api/identity/usertemplates     → lista activos
POST /api/identity/usertemplates     → asignar rol a usuario
```

### Governance y Auditoría
```
GET  /api/audit                      → historial con filtros
GET  /api/operations/{id}            → estado operación (para reconexión)
POST /api/governance/approve/{id}    → segunda aprobación cat.3
```

## 11. Eventos WebSocket

```json
{"event": "step_progress",  "step": 8, "total_steps": 12, "status": "running"}
{"event": "step_done",      "step": 8, "duration_ms": 28400}
{"event": "step_error",     "step": 8, "error": {"code": "POD_TIMEOUT", "cause": "...", "solution": "...", "cli_command": "..."}}
{"event": "operation_done", "result": "success", "total_duration_ms": 240000}
{"event": "ficha_state_changed", "old_status": "INSTALANDO", "new_status": "INSTALADA_OK"}
{"event": "system_alert",  "severity": "critical", "type": "pod_crash_loop", "message": "..."}
{"event": "roltemplate_sync_status", "old_status": "SYNCED", "new_status": "DRIFT"}
```

## 12. Códigos de Error

| HTTP | Código | Significado | Acción |
|---|---|---|---|
| 400 | validation_error | Manifest/parámetros inválidos | Revisar campos |
| 401 | unauthorized | JWT ausente/expirado | Re-autenticarse KC |
| 403 | forbidden | Rol insuficiente | Contactar sbos-admin |
| 404 | ficha_not_found | Ficha no existe | Verificar ID |
| 409 | operation_in_progress | Operación activa | Esperar |
| 409 | dependency_not_satisfied | Dep no instalada | Instalar dep primero |
| 409 | governance_pending | Esperando 2da aprobación | Segundo admin aprueba |
| 422 | confirmation_mismatch | String no coincide | Escribir exacto |
| 500 | core_error | Error interno Core | journalctl -u sbos-core |
| 503 | kubernetes_unavailable | Cluster no responde | Verificar cluster |

## 13. Stack Técnico

| Componente | Tecnología | Justificación |
|---|---|---|
| Framework | Flutter (Dart) | Único codebase web+móvil+desktop. Motor renderizado propio |
| Estado ops | BLoC | Event→BLoC→State para ops alto riesgo |
| Estado global | Riverpod | Providers sin BuildContext |
| REST | HTTP + FastAPI | Operaciones síncronas |
| Realtime | WebSocket | StreamBuilder para reconstrucción reactiva |
| Auth | Keycloak OIDC JWT | SSO + MFA + RBAC |
| API spec | OpenAPI 3.0 | Contrato formal frontend/backend |
| Push | FCM (móvil) / sistema (desktop) | Alertas sin Core UI abierto |
| Métricas | Prometheus (vía backend) | Dashboard salud |
| Deploy | Ficha SBOS en sbos-installer | Gestionada por IAM Installer |

## 14. Posicionamiento vs Industria

| Herramienta | Lo que adopta Core UI | Lo que no |
|---|---|---|
| Backstage | Catálogo como fuente de verdad, single pane of glass | No multi-tenant, no plugins externos |
| Rancher | App catalog con estados, gestión cluster, RBAC | No múltiples clusters, no recursos K8s crudos |
| ArgoCD | Grafo dependencias, drift detection | No GitOps — catálogo en servers/ |
| Lens/K8s Dashboard | Logs realtime, terminal shell | Abstrae al nivel fichas, no pods |

Contribución original: catálogo fichas + grafo interactivo + progreso realtime con replay + dual-control governance + PAP RolFramework + multi-dispositivo Flutter + OpenAPI 3.0 formal.

## 15. Integración con Smart* Subproyectos

El Core UI proporciona la plataforma de interfaz para los subproyectos Smart* del
ecosistema SBOS, siguiendo el patrón de integración establecido en SBOS Smart Report:

| Subproyecto | Integración Core UI | Tipo de UI | Referencia |
|---|---|---|---|
| SBOS Smart Report | Viewer dual (invocado/directo) vía WebView | Flutter Desktop + WebView | SBOS-REPORT-012 |
| SBOS-IAM-Style | Tema visual, generador de logo, theming | Flutter con providers de tema | brand-system |
| SBOS CMS | Panel de pedidos, ctx_id tracing | Flutter Web | BOSCMS |
| SBOS Tryton | Panel contable, planes de cuentas | Flutter Desktop | SBOSTRY |

### Patrón de Integración Dual-UI (de SBOS Smart Report)

El Core UI puede alojar viewers de subproyectos Smart* mediante un patrón dual:

- **Modo Invocado:** La app Smart* abre el viewer de Core UI con parámetros concretos
- **Modo Directo:** El usuario abre el viewer desde el catálogo de Core UI

Este patrón permite que el Core UI actúe como plataforma central de lanzamiento para
todas las herramientas Smart* manteniendo la autonomía de cada subproyecto.

### Compilación Multiplataforma (de SBOS-IAM-Style)

El Core UI se compila para múltiples plataformas desde el servidor Ubuntu de desarrollo:

| Target | Comando | Resultado |
|---|---|---|
| Linux x86_64 | `flutter build linux --release` | AppImage |
| Windows x64 | `flutter build windows --release` (MinGW cross) | Instalador NSIS .exe |
| macOS | `flutter build macos --release` (GitHub Actions) | .dmg |

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1-2 Identidad | SBOS-007 v4.0 | §1 Posición, §4 Definición |
| §3 PAP | SBOS-007 v4.0 | §2 PAP RolFramework completo |
| §4 5 Vistas | SBOS-007 v4.0 | §6 Las 5 Vistas (completas con detalle) |
| §5 Core↔UI | SBOS-007 v4.0 | §5 Relación (diagrama flujo completo) |
| §6 Flutter | SBOS-007 v4.0 | §7 BLoC+Riverpod+WebSocket+Feature-First |
| §7 Multi-device | SBOS-007 v4.0 | §8 (tabla 3 factores forma) |
| §8 Offline | SBOS-007 v4.0 | §9 (2 escenarios) |
| §9 Seguridad | SBOS-007 v4.0 | §10 (4 capas + tabla RBAC) |
| §10-11 API | SBOS-007 v4.0 | §11 completo (endpoints REST + WebSocket + códigos error) |
| §12 Códigos | SBOS-007 v4.0 | §11.7 tabla completa |
| §13 Stack | SBOS-007 v4.0 | §12 tabla técnica |
| §14 Posición | SBOS-007 v4.0 | §13 tabla comparativa |
| §15 Smart* | SBOS-REPORT-012 + SBOS-IAM-Style 09 | Integración dual-UI, compilación multiplataforma |

---

## Fuentes de Enriquecimiento V8

| Fuente | Ruta | Tipo | Detalle |
|---|---|---|---|
| BOS_V6_SBOS-020-COREUI.md | Procesar/ | V6 Base | Contenido completo preservado |
| BOS_V5_SBOS-007-COREUI-v4_0.md | Procesar/ | V5 | PAP RolFramework, OpenAPI 3.0, RBAC tabla, 4 capas seguridad |
| SBOS-REPORT-012-INTERFACES-USUARIO.md | sbos/subproyectos/ | Smart* | Viewer dual (invocado/directo), toolbar de 6 acciones, catálogo global/local |
| SBOS-IAM-Style 09 dev-environment-setup.md | sbos/subproyectos/ | Smart* | Flutter cross-compile, targets multiplataforma, AppImage, NSIS |

---

_SKULL · SBOS · SBOS-020-COREUI · V8 · Mayo 2026_
