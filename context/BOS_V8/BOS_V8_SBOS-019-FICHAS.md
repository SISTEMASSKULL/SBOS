# SBOS-019-FICHAS
## Sistema de Fichas — Estándar HUMAN-DOC
### SKULL · SBOS · V8 · Mayo 2026

---

## 1. Definición Canónica

Una ficha SBOS es la unidad de despliegue atómica del SBOS. Contrato autocontenido que encapsula todo el conocimiento necesario para que el IAM Installer lleve una aplicación desde NO INSTALADA hasta INSTALADA — OK y la mantenga operativa — sin que el Core sepa qué aplicación es.

**Propiedad fundamental:** el Core no sabe que PostgreSQL existe. PostgreSQL no sabe cómo funciona el Core. Agregar la app número 97 es crear una carpeta.

## 2. Posición en el Ecosistema Cloud-Native

| Patrón | Qué resuelve | Qué le falta |
|---|---|---|
| Helm Chart | Packaging K8s | Solo Day 1 |
| K8s Operator | Ciclo vida completo | Requiere controlador Go/Python por app |
| CNAB / Porter | Bundle autocontenido | Sin semántica de estados ni governance |
| Ansible Role | Automatización idempotente | Sin dependencias entre apps |
| Golden Path | Templates self-service | No cubre operación en producción |
| **Ficha SBOS** | **Day 1 + Day 2 + integración + governance + conocimiento producción** | Específico SBOS |

## 3. Los Tres Contratos

**manifest.yml** — Identidad, recursos, dependencias, governance. Lo que lee DEPENDENCY_RESOLVER y HEALTH_CHECKER.

**yaml_engine.yml** — Fases del ciclo de vida (install, update, repair, uninstall). Intención declarativa sin lógica Bash.

**resources/** — Artefactos de integración exactos: OIDC para KC, rutas Kong, políticas Vault, SQL, configs producción.

## 4. Tres Tipos

| Tipo | workload.type | Cuándo corre | Ejemplos |
|---|---|---|---|
| 1 Sistema | bash | Antes de K8s o mantenimiento host | sbos-bootstrap-os, sbos-bootstrap-k8s |
| 2 Aplicación | kubernetes | Con K8s operativo | postgresql, keycloak, redis, kong |
| 3 Opcional Pura | kubernetes | Cualquier momento (criticality: false) | LibreOffice, configuraciones |

## 5. Cinco Estados

| Estado | Condición | Acciones |
|---|---|---|
| BLOQUEADA | Deps no satisfechas | Ver requisitos, instalar cadena |
| NO INSTALADA | Deps satisfechas | Instalar |
| INSTALADA — OK | Pod Running + health OK | Verificar, Reparar, Actualizar, Desinstalar |
| INSTALADA — ALERTA | CrashLoopBackOff o health failing | Reparar, Ver logs, Diagnóstico |
| ACTUALIZACIÓN DISPONIBLE | Drift en resources/ o nueva versión | Actualizar, Omitir, Ver diff |

## 6. Orden de Ejecución

**execution_order:** preferencia global (menor = antes). sbos-bootstrap (0) reservado.

**depends_on:** restricción absoluta, prioridad total sobre execution_order.

Algoritmo DEPENDENCY_RESOLVER: Lee manifest.yml → grafo dirigido → detecta ciclos → Kahn → dentro mismo nivel → execution_order.

hostserver: solo execution_order (K8s no existe para verificar deps).

## 7. Estructura Física

```
servers/<servidor>/<app>/
├── manifest.yml          ← Identidad y gobernanza
├── yaml_engine.yml       ← Fases declarativas
├── task_catalog.sh       ← Funciones Bash específicas
├── <app>.k8s.yml         ← Manifest K8s
├── <app>.network         ← NetworkPolicy
├── <app>.volume          ← PVC
├── <app>.container       ← Quadlet/Podman (emergencia)
└── resources/
    ├── sql/              ← Schema, seed, migrations
    ├── config/           ← Configuraciones producción
    ├── keycloak/         ← Client OIDC + roles + mappers
    ├── kong/             ← Rutas + plugins
    ├── vault/            ← Políticas secretos
    ├── migrations/       ← Scripts migración
    └── data/             ← Datos iniciales negocio
```

## 8. Jerarquía de Conocimiento

```
NIVEL 1 — UNIVERSAL (Core): funciones sin nombre de app
NIVEL 2 — ESPECÍFICO (task_catalog.sh): funciones con nombre de app
NIVEL 3 — DECLARATIVO (yaml_engine.yml): intención, no lógica
NIVEL 4 — ESTADO (resources/): artefactos cristalizados
```

Regla: función que menciona app concreta → task_catalog.sh individual. NUNCA catálogo global.

## 9. manifest.yml Completo

```yaml
identity:
  id: "postgresql"
  name: "PostgreSQL 18"
  version: "18.2"
  server: "dataserver"
  namespace: "sbos-data"
  criticality: true

workload:
  type: "kubernetes"
  state: "prod"

order:
  execution_order: 100

parameters:
  PG_VERSION: "18"
  PG_MAX_CONNECTIONS: "500"

requirements:
  ram_mb: 1024
  cpu_cores: 1
  disk_gb: 500
  depends_on:
    - type: "ficha"
      target: "sbos-bootstrap"
      state: "installed"

deployment:
  namespace: "sbos-data"
  node_selector: "tipo=dataserver"
  k8s_manifest: "postgresql.k8s.yml"
  workload_type: "StatefulSet"
  network_policy: "postgresql.network"

governance:
  category: 3
  backup_required: true
  backup_schedule: "0 2 * * *"

health:
  check_command: "pg_isready -U postgres"
  check_via: "kubectl_exec"
  pod_selector: "app=postgresql"
  interval_seconds: 30
  failure_threshold: 3

integrations:
  provides_to: ["postfixadmin", "roundcube", "keycloak"]

bsearch_config:
  enabled: true
  priority: high
  schema_discoverer: auto
  index_entities:
    - entity: invoice
      table: account_invoice
      primary_field: number
      display_fields: [number, party, amount_total]
      search_fields: [number, party, description]
      url_template: "/accounting/invoice/{id}"
      permission_check: "ficha"

compatibility:
  min_iam_installer_version: "4.0.0"
```

---

## 10. yaml_engine.yml Completo

```yaml
phases:
  pre_install:
    tasks:
      - task: "check_node_resources"
        params: { ram_mb_required: 1024, disk_gb_required: 500 }
      - task: "create_k8s_namespace"
        params: { namespace: "sbos-data" }
      - task: "pg_create_k8s_secrets"
        params: { namespace: "sbos-data", secret_path: "secret/sbos/postgresql" }
  post_install:
    tasks:
      - task: "wait_pod_ready"
        params: { namespace: "sbos-data", pod_selector: "app=postgresql", timeout_seconds: 120 }
      - task: "pg_configure_databases"
        params:
          databases:
            - { name: "postfixadmin_db", owner_secret: "secret/sbos/postfixadmin/db" }
            - { name: "keycloak_db", owner_secret: "secret/sbos/keycloak/db" }
  update:
    tasks:
      - task: "reconcile_file"
        update_strategy: "hot"
        drift_check: true
        params: { source: "resources/config/postgresql.conf" }
  repair:
    diagnosis_first: true
    tasks:
      - task: "pg_diagnose_connections"
        on_failure: "continue"
      - task: "rollout_restart"
        params: { namespace: "sbos-data", resource: "StatefulSet/postgresql" }
        on_failure: "abort"
  uninstall:
    require_confirmation: "DESINSTALAR-POSTGRESQL"
    governance_category: 3
    tasks:
      - task: "take_backup_snapshot"
        params: { backup_name: "pre-uninstall-postgresql" }
```

---

## 11. task_catalog.sh Ejemplo Real

```bash
#!/usr/bin/env bash
_task_pg_create_k8s_secrets() {
    local params="$1"
    local namespace secret_path
    namespace=$(echo "$params" | yq eval '.namespace' -)
    secret_path=$(echo "$params" | yq eval '.secret_path' -)
    echo "__SBOS__STEP_START__ Creando secrets PostgreSQL en: $namespace"
    if kubectl get secret pg-master-credentials -n "$namespace" &>/dev/null; then
        echo "__SBOS__STEP_SKIP__ Secret ya existe"
        return 0
    fi
    local password=$(openssl rand -base64 32)
    vault kv put "${secret_path}/master" password="$password" username="postgres" || {
        echo "__SBOS__STEP_ERROR__ CAUSA: Vault no disponible SOLUCIÓN: sbos verify vault"
        return 1
    }
    kubectl create secret generic pg-master-credentials \
        --from-literal=password="$password" --from-literal=username="postgres" \
        -n "$namespace" --dry-run=client -o yaml | kubectl apply -f -
    echo "__SBOS__STEP_OK__ Secrets creados"
    return 0
}
export -f _task_pg_create_k8s_secrets
```

Validación obligatoria (validate_sp02.py exit 0): SBOS-DOC completo, export -f, señales __SBOS__, sin kubectl apply directo, sin nombres de otras apps.

---

## 12. Conocimiento de Producción Preservado

| Problema | Cómo se cristaliza |
|---|---|
| Redis Roundcube formato 'host:port:db:pass' | resources/config/config.inc.php con comentario |
| Dovecot UID 5000, Postfix UID 105 | _task_fix_vmail_permissions() con SBOS-DOC |
| SSL antes del primer arranque mailserver | Orden en yaml_engine.yml |
| DKIM por dominio, no global | manifest.yml domains[] + loop task_catalog |
| PostfixAdmin solo 127.0.0.1 | oauth2_ready: true en manifest |
| PG crea BDs de otras apps en post_install | resources/sql/seed-<app>-database.sql |

---

## 13. Niveles de Governance

Las fichas SBOS soportan tres niveles de governance que determinan el nivel de
aprobación requerido para operaciones destructivas (desinstalar, repair invasivo):

| Nivel | Nombre | Requisito | Uso típico |
|---|---|---|---|
| 1 | Libre | Sin confirmación adicional | Fichas de sistema internas, bootstrapping |
| 2 | Confirmación | Pantalla de confirmación con diagnóstico | Fichas de aplicación estándar |
| 3 | Dual-Control | Dos administradores sbos-admin, ventana 60min | Fichas críticas (PostgreSQL, Keycloak, Vault) |

El nivel de governance se declara en `manifest.yml` bajo `governance.category` y se
hereda en el `yaml_engine.yml` para la fase `uninstall`.

---

## 14. Versionado Semántico de Fichas

PATCH: fix idempotencia, mensajes, timeouts.
MINOR: nueva tarea, campo opcional, entidad bsearch.
MAJOR: schema roto, nombre renombrado, migración destructiva.

Migración MAJOR: backup obligatorio → ejecutar migration SQL → aplicar manifest → health check → OK o rollback automático.

Compatibilidad: **N-1 MAJOR garantizada**. Una ficha en versión MAJOR X funciona contra
el IAM Installer de versión MAJOR X y X-1. Si se requiere MAJOR X-2, DEPENDENCY_RESOLVER
detecta el conflictode compatibilidad y bloquea la instalación con un error explícito.

Conflictos de dependencias por versión son detectados por DEPENDENCY_RESOLVER y reportados
al administrador vía Core UI.

---

## 15. Extensibilidad

1. Crear carpeta servers/<servidor>/nueva-app/
2. Escribir manifest.yml + yaml_engine.yml + task_catalog.sh + resources/
3. IAM Installer descubre automáticamente
4. Aparece en Core UI
5. DEPENDENCY_RESOLVER integra en grafo

El Core no cambia. Solo existe una carpeta nueva.

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1-3 | SBOS-006 v4.0 | §3 Definición, §2 Ecosistema, §4 Tres Contratos |
| §4-5 | SBOS-006 v4.0 | §5 Tres Tipos, §6 Cinco Estados |
| §6 | SBOS-006 v4.0 | §7 Orden Ejecución (execution_order + depends_on + Kahn) |
| §7-8 | SBOS-006 v4.0 | §8 Estructura Física, §9 Jerarquía Conocimiento |
| §9 | SBOS-006 v4.0 | §11 manifest.yml completo + bsearch_config + governance |
| §10 | SBOS-006 v4.0 | §12 yaml_engine.yml completo (fases, diagnosis_first) |
| §11 | SBOS-006 v4.0 | §13 task_catalog.sh (función real + validate_sp02) |
| §12 | SBOS-006 v4.0 | §14 Resources (tabla conocimiento preservado) |
| §13 Governance | SBOS-006 v4.0 + V5 FICHA v4.0 | Niveles 1-3, Dual-Control |
| §14 | SBOS-006 v4.0 | §17 Versionado (semver, breaking changes, migración MAJOR) + V5 FICHA v4.0 N-1 MAJOR |
| §15 | SBOS-006 v4.0 | §18 Extensibilidad |

---

## Fuentes de Enriquecimiento V8

| Fuente | Ruta | Tipo | Detalle |
|---|---|---|---|
| BOS_V6_SBOS-019-FICHAS.md | Procesar/ | V6 Base | Contenido completo preservado |
| BOS_V5_SBOS-006-FICHA-v4_0.md | Procesar/ | V5 | bsearch_config block, governance levels 1-3, N-1 MAJOR compatibility, knowledge preservation table |
| SBOS-018-DAEMON-BOS §6 | Consolidado | V8 | Principios de arquitectura P1-P15 relevantes a fichas |

---

_SKULL · SBOS · SBOS-019-FICHAS · V8 · Mayo 2026_
