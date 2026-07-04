# SBOS-009-REPOS
## Repositorios — Estandar HUMAN-DOC (Enriquecido V8)
### SKULL · SBOS v1.2-V8 · Mayo 2026

---

## 1. Mapa de Repositorios

| Repo | Organizacion | Lenguajes | Componente |
|---|---|---|---|
| sbos | github.com/SISTEMASSKULL/sbos | Bash, Python, Go, Rust, Dart, YAML | Monorepo principal |

Decision: monorepo unico. Independencia de build via GitHub Actions path filters por directorio, no repos separados.

---

## 2. Estructura del Monorepo

```
/opt/bos/
+-- bos                    <- binario Go estatico (CGO_ENABLED=0)
+-- bosctl                 <- CLI Go para administracion local

/etc/bos/
+-- bos.toml               <- configuracion del daemon
+-- .sbos_state.json       <- estado persistente (solo STATE_MANAGER escribe)
+-- *.jsonl                <- eventos para replay WebSocket
+-- blibs/
    +-- core/              <- 4 archivos maestros Bash
    ¦   +-- 00_MASTER_INSTALL_SBOS.sh
    ¦   +-- 00_TASK_CATALOG_SBOS.sh
    ¦   +-- 00_YAML_ENGINE_SBOS.sh
    ¦   +-- 00_ARCHITECTURE_SBOS.yml
    +-- servers/           <- fichas del catalogo (por servidor logico)
        +-- hostserver/
        ¦   +-- sbos-bootstrap-os/
        +-- dataserver/
        ¦   +-- postgresql/
        ¦       +-- manifest.yml
        ¦       +-- yaml_engine.yml
        ¦       +-- task_catalog.sh
        ¦       +-- resources/k8s/pod.yml
        +-- identityserver/
        +-- gatewayserver/
        +-- ... (15 servidores logicos)
```

Desarrollo local en: /opt/sbos-dev/ (staging/testbench)

---

## 3. Estrategia de Ramas — Trunk-Based Development (TBD)

**Decision formal:** Trunk-Based Development con Pull Requests cortos. GitFlow vetado. Decision tomada en SBOS-COMPLETITUD-v2 §2 B2.1, formalizada en ADR-010 (ver SBOS-006-ADR y SBOS-048-ADR-CATALOG).

**Fundamento:** El DORA State of DevOps Report 2024 y trunkbaseddevelopment.com documentan que equipos elite que implementan CI/CD continuo usan TBD como practica estandar. Para un monorepo polyglot (Rust + Go + Python + Bash + Dart) con un solo desarrollador, GitFlow genera merge hell y overhead sin beneficio de coordinacion. El Release Plane de SKULL (canary → early → stable) ya gestiona la cadencia de releases, haciendo redundantes las release branches de GitFlow.

### Ramas

```
RAMA PRINCIPAL:
  main  →  siempre deployable, siempre verde, fuente de verdad
           Todo lo que llega a main pasa CI completo

RAMAS CORTAS (max. 1-2 dias de vida):
  feature/<descripcion-corta>  →  funcionalidad nueva
  fix/<descripcion-corta>      →  correccion de bug
  docs/<descripcion-corta>     →  documentacion

RAMA ABOLIDA:
  develop      → no existe (GitFlow vetado)
  release/*    → no existe (Release Plane lo gestiona)
  hotfix/*     → no existe (usar fix/<descripcion-corta>)
```

### Politica de merge

- Todo merge a `main` requiere que **todos los CI gates de 013-TESTING pasen** — sin excepciones
- Las ramas se eliminan **inmediatamente** tras el merge (sin ramas long-lived)
- Commits directos a `main` permitidos **solo para**: typos en documentacion, hotfixes criticos de una linea, cambios triviales de configuracion. Todo lo demas va por rama + PR
- Feature flags para codigo incompleto que llega a `main` antes de estar listo para activarse

### Politica de PR segun tamano del equipo

**Con 1 integrante (estado actual — Super Usuario):**
- El Super Usuario puede hacer merge directo a `main` para cambios de baja complejidad sin PR formal, siempre que el CI pase
- Los cambios que afecten principios arquitectonicos (SBOS-004-RULES §1) o modifiquen el comportamiento de un daemon soberano requieren PR aunque sea auto-merge — para mantener registro en GitHub con descripcion del cambio
- Los cambios en fichas o reglas YAML del stack se consideran baja complejidad y pueden mergearse directamente si pasan el FICHA_LINTER

**Con 2+ integrantes (al incorporar el segundo integrante):**
- Todo merge a `main` requiere revision aprobada de al menos 1 persona distinta al autor — sin excepciones
- El propietario del daemon afectado debe ser siempre uno de los revisores (ver SBOS-046-ONBOARDING §2.2 — tabla de propiedad por daemon)
- PRs de documentacion no requieren revision del propietario tecnico del daemon — cualquier integrante puede revisar
- PRs que modifican mas de 1 daemon simultaneamente requieren revision de ambos propietarios

**GitHub Branch Protection Rules a activar en el momento de incorporar el segundo integrante:**

```yaml
# Configuracion en GitHub → Settings → Branches → Branch protection rules → main
required_pull_request_reviews:
  required_approving_review_count: 1
  dismiss_stale_reviews: true              # invalidar aprobaciones si hay nuevos commits
  require_code_owner_review: false         # activar cuando se configure CODEOWNERS
required_status_checks:
  strict: true                             # rama debe estar actualizada antes de merge
  contexts:
    - CI pipeline completo                 # nombre del workflow de GitHub Actions
required_conversation_resolution: true     # todos los comentarios deben resolverse
delete_branch_on_merge: true              # elimina la rama automaticamente
allow_force_pushes: false
allow_deletions: false
```

**Archivo CODEOWNERS (crear cuando haya 2+ integrantes):**

```
# /CODEOWNERS — propietarios tecnicos por directorio/daemon
# Formato: <patron> <@usuario-github>

/daemons/bkernel/      @super-usuario    # propietario: bKernel
/daemons/biedata/      @super-usuario    # propietario: biedata
/daemons/bauth/        @super-usuario    # propietario: bAuth
# Actualizar con @segundo-integrante cuando se incorpore y complete el ejercicio de validacion
# Ver SBOS-046-ONBOARDING §2.3 para criterios de co-propiedad
```

### Tags de version

```
vX.Y.Z  →  tag aplicado sobre main por el Release Plane
           firmado con Ed25519 (ver SBOS-041-RELEASE-PLANE)
           El tag ES la release — no se crean release branches
```

### Convenciones de commit

Formato Conventional Commits (https://www.conventionalcommits.org/):
```
<tipo>(<alcance>): <descripcion corta>

Tipos: feat, fix, docs, refactor, test, chore, build, ci
Alcance: bkernel, biedata, bcompass, bsearch, bauth, bos, coreui, fichas, docs

Ejemplos:
  feat(bkernel): add forward-chaining rule engine
  fix(bos): correct saga compensation order in uninstall
  docs(fichas): add postgresql manifest reference example
  chore(ci): update golangci-lint to v2
```

---

## 4. CI/CD

| Herramienta | Proposito | Gate bloqueante |
|---|---|---|
| GitHub Actions | CI — path filters por directorio | Si |
| GitLab CE 17.8+ (S14) | SCM + pipelines en produccion | Si |
| SonarQube | Analisis estatico + cobertura | Si |
| cargo-audit | Auditoria deps Rust | Si |
| golangci-lint | Lint Go | Si |
| clippy --deny warnings | Lint Rust | Si |
| cargo fmt --check | Formato Rust | Si |
| Trivy | Escaneo vulnerabilidades imagenes | Si (zero critical) |
| FICHA_LINTER | Validacion contratos de fichas | Si (cobertura ≥90%) |
| validate_sp01.py | Validacion 14 principios Core | Si |
| K6 | Pruebas de carga | Pre-release |
| Goss | Validacion infraestructura | Pre-release |
| Skopeo | Verificacion integridad imagenes | Si |

---

## 5. Convenciones

### Nombres de archivos
SBOS-XXX-NOMBRE-vN_M.md (documentos). Nombres de fichas: minuscula con guion (postgresql, sbos-bootstrap-os).

### Contenedores
Prefijo sbos-: sbos-postgresql, sbos-keycloak. Containerfile (nunca Dockerfile).

### Versionado
Semantico (semver) para SBOS como producto. Fichas: versionado independiente. Release Plane: canary → early → stable.

---

## 6. Smart* Enriquecimiento — Estructura de Subproyectos

Cada subproyecto Smart* se aloja en su propio directorio dentro del monorepo, siguiendo la estructura de fichas SBOS:

```
/opt/bos/blibs/servers/devserver/
+-- smarttax/                  -> SBOS Smart Tax
¦   +-- manifest.yml
¦   +-- yaml_engine.yml
¦   +-- task_catalog.sh
¦   +-- resources/
¦       +-- php/               -> Codigo fuente PHP 8.2
¦       +-- sql/               -> Migraciones btax_db
¦       +-- templates/         -> Plantillas XML facturacion
+-- smartorc/                  -> SBOS Smart ORC
¦   +-- manifest.yml
¦   +-- resources/
¦       +-- python/            -> Codigo fuente Python 3.12 + FastAPI
¦       +-- sql/               -> Migraciones borc_db
+-- smartvault/                -> SBOS Smart Vault Flow
¦   +-- manifest.yml
¦   +-- resources/
¦       +-- python/            -> Codigo fuente Python 3.12 + FastAPI
¦       +-- sql/               -> Migraciones bvault_db
+-- smartpay/                  -> SBOS Smart Pay
¦   +-- manifest.yml
¦   +-- resources/
¦       +-- node/              -> Codigo fuente Node.js 22 LTS (Medusa)
¦       +-- sql/               -> Migraciones bpay_db
+-- smartrates/                -> SBOS Smart Rates
¦   +-- manifest.yml
¦   +-- resources/
¦       +-- go/                -> Codigo fuente Go 1.22
+-- smartreport/               -> SBOS Smart Report
¦   +-- manifest.yml
¦   +-- resources/
+-- smartportfolio/            -> SBOS Smart Portfolio
¦   +-- manifest.yml
+-- sbos-cms/                  -> SBOS CMS
    +-- manifest.yml
    +-- resources/
        +-- php/               -> Codigo fuente PHP 8.2 (CodeIgniter)
```

Cada subproyecto sigue el mismo ciclo de vida de ficha SBOS: manifest.yml define dependencias, task_catalog.sh ejecuta la instalacion, yaml_engine.yml define el flujo declarativo. La independencia del build se gestiona via GitHub Actions path filters por subdirectorio.

---

## ENRIQUECIMIENTO SBOS (Primera Versión)

### SBOS-018-009-1: Convencion de versionado en Kong

Todas las APIs externas accesibles por los clientes y sus integraciones pasan por Kong. El formato de URL es uniforme en todo el stack:

```
/api/v{MAJOR}/{bounded-context}/{recurso}
```

**Ejemplos:**

| Endpoint | Bounded Context | Recurso | Version |
|----------|----------------|---------|---------|
| `/api/v1/identity/users` | identity | users | v1 |
| `/api/v1/erp/invoices` | erp | invoices | v1 |
| `/api/v1/hrm/employees` | hrm | employees | v1 |
| `/api/v2/erp/invoices` | erp | invoices | v2 (breaking change) |

**Regla de incremento MAJOR:** cualquier cambio que requiera modificar codigo del cliente consumidor es breaking:
- Eliminar un campo de la respuesta JSON
- Cambiar tipo de dato de un campo existente
- Cambiar semantica de un campo (mismo nombre, diferente significado)
- Cambiar URL o metodo HTTP de un endpoint
- Hacer obligatorio un campo que era opcional

**NO requiere incremento MAJOR:** agregar campos opcionales, agregar nuevos endpoints, mejorar performance sin cambiar el contrato.

Quien define la version: el equipo del bounded context propietario del recurso. El cambio de version MAJOR requiere un RFC segun SBOS-025 (proceso ARB).

### SBOS-018-009-2: Versionado de API interna IAM Installer <-> Core UI

Esta API no pasa por Kong, es interna al host entre el IAM Installer (SP-04 FastAPI) y el Core UI (SP-06 Flutter).

**Header de version:** `X-IAM-API-Version: {semver}`

```
GET /internal/fichas/status
X-IAM-API-Version: 1.3.0
Authorization: Bearer <token interno>
```

**Reglas de compatibilidad interna:**
1. El IAM Installer declara su version de API en `GET /internal/version`
2. El Core UI verifica compatibilidad al iniciar sesion
3. Si hay incompatibilidad, el Core UI muestra banner de advertencia al administrador
4. Se despliegan coordinadamente en el mismo release
5. Politica N y N-1: el IAM Installer soporta la version actual del Core UI y la anterior

### SBOS-018-009-3: Politica de sunset para APIs externas

Cuando un endpoint es deprecado:

1. **Headers en todas las respuestas del endpoint deprecado:**
   ```
   Sunset: Sat, 31 Dec 2026 23:59:59 GMT
   Deprecation: true
   Link: <https://bos.cliente.com/api/v2/erp/invoices>; rel="successor-version"
   ```

2. **Periodo minimo de soporte:** 6 meses desde la deprecacion

3. **Notificacion en Core UI:** banner amarillo cuando el admin usa funcionalidad que depende de un endpoint en sunset

4. **Eliminacion:** tras el periodo de sunset, el endpoint retorna `HTTP 410 Gone` con mensaje explicativo

### SBOS-018-009-4: Contratos OpenAPI 3.1 por bounded context

Ubicacion en el repositorio: `servers/{server}/api/openapi.yaml`

```yaml
openapi: "3.1.0"
info:
  title: SBOS ERP API
  version: "1.0.0"
servers:
  - url: https://bos.{tenant}.com/api/v1/erp
paths:
  /invoices:
    get:
      operationId: listInvoices
      security:
        - keycloakOAuth: [erp:read]
      parameters:
        - name: state
          in: query
          schema:
            type: string
            enum: [draft, confirmed, posted, paid, cancelled]
      responses:
        "200":
          description: Lista de facturas
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/InvoiceList'
        "401":
          description: Token JWT invalido o expirado
        "403":
          description: Sin permiso erp:read
components:
  securitySchemes:
    keycloakOAuth:
      type: oauth2
      flows:
        authorizationCode:
          authorizationUrl: https://bos.{tenant}.com/realms/{tenant}/protocol/openid-connect/auth
          tokenUrl: https://bos.{tenant}.com/realms/{tenant}/protocol/openid-connect/token
          scopes:
            erp:read: Lectura de datos ERP
            erp:write: Escritura de datos ERP
```

**Generacion:** FastAPI genera `openapi.json` automaticamente desde anotaciones. Para apps del stack que no son FastAPI (Tryton, OrangeHRM, etc.), el contrato es declarativo manual.

**Cambio breaking:** cualquier cambio al contrato OpenAPI que sea breaking requiere RFC en SBOS-025 antes de implementarse.

### SBOS-018-009-5: Contratos entre Bounded Contexts (WAL, no REST)

Los bounded contexts no se llaman entre si via API REST. La comunicacion entre BCs es via el WAL de PostgreSQL con bKernel como propagador:

```
BC-02 RRHH (OrangeHRM)
  -> INSERT en orangehrm.employee (WAL event)
  -> bKernel detecta el evento
  -> bKernel aplica regla YAML
  -> bKernel escribe en BC-04 Identity (crea usuario en Keycloak via API)
  -> bKernel escribe en BC-01 ERP (crea party en Tryton)
```

**Tabla de contratos de API externos por bounded context:**

| Bounded Context | API externa | Version | Consumers externos |
|----------------|-------------|---------|-------------------|
| BC-01 ERP | `/api/v1/erp/` | v1 | Integraciones de clientes via Kong |
| BC-02 RRHH | `/api/v1/hrm/` | v1 | Portal self-service de empleados |
| BC-03 Ecommerce | `/api/v1/ecommerce/` | v1 | Tienda web externa |
| BC-04 Identity | `/api/v1/identity/` | v1 | Solo admin |
| BC-05 Tributario | `/api/v1/tax/` | v1 | Sistemas contables externos |

**Eventos WAL como contratos implicitos:** aunque los BCs no se llaman via API REST, los eventos WAL son contratos implicitos. Si BC-02 cambia la estructura de `orangehrm.employee`, bKernel puede dejar de detectar eventos correctamente. Los cambios de esquema en tablas monitoreadas por bKernel requieren:
1. RFC en SBOS-025 (como cambio breaking)
2. Actualizacion de reglas YAML de bKernel
3. Prueba en staging antes de produccion

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1 Mapa | SBOS-AYUDA-MEMORIA | §repositorio |
| §3 Estrategia TBD | SBOS-COMPLETITUD-v2 §2 B2.1 | Decision adoptada + especificacion completa + Conventional Commits |
| §3 Politica PR multi-integrante | SBOS-COMPLETITUD-v3 T-A5 + SBOS-046-ONBOARDING §2.2 | Politica de merge con 1 y 2+ integrantes, GitHub Branch Protection Rules, CODEOWNERS template |
| §4 CI/CD | SBOS-018 v1.0 | §9 Validadores Automaticos |
| §6 Smart* | Estructura observada en subproyectos/ | Directorios smarttax, smartorc, smartvault, smartpay, smartrates, smartreport, smartportfolio, sbos-cms |
| §7 ENRIQUECIMIENTO SBOS | SBOS-018-API-Versioning-v1_0.md | Kong URL convention, API versioning, sunset policy, OpenAPI 3.1 contracts, WAL inter-BC communication |

---

## Fuentas de Enriquecimiento V8

| Fuente | Tipo | Contenido aportado |
|---|---|---|
| BOS_V6_SBOS-009-REPOS.md | V6 (canonico) | Contenido base completo preservado |
| Estructura de subproyectos Smart* en /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/ | Smart* | Estructura de directorios de subproyectos, patron de ficha SBOS, independencia de build via path filters |
| SBOS-018-API-Versioning-v1_0.md | SBOS (V8) | API versioning conventions, sunset policy, OpenAPI 3.1 contracts, WAL-based inter-BC communication |

---

_SKULL · SBOS · SBOS-009-REPOS · HUMAN-DOC v1.2-V8 · Mayo 2026_
_Enriquecimiento V8: Smart* estructura de subproyectos en el monorepo + patron de ficha para subproyectos_
