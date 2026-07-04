# SBOS-021 — Guía de Incorporación al Equipo
## Cómo contribuir al SBOS desde el primer día

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-021
**Versión:** 1.0
**Estado:** ACTIVO — Complementos en archivos separados
**Complementos:**
  - SBOS-021-ABF-AntiBusFactor-v1_0.md (Plan Anti-Bus-Factor — complemento disponible)
  - SBOS-MP01-CompletarDocs-v1_0.md PARTE C (Onboarding Funcional — complemento disponible)
**Documento nuevo** — no reemplaza a ningún documento anterior
**Clasificación:** Guía Operativa — Incorporación de Contribuidores

---

## 1. Lo que necesitas saber antes de empezar

### El modelo mental del SBOS en 20 minutos

El SBOS es un sistema operativo de negocio soberano. No es un producto SaaS que se configura — es una plataforma que se instala, se extiende y se opera. Antes de escribir una línea de código, necesitas entender tres conceptos:

**La Ficha es la unidad atómica del sistema.**
Todo lo que el SBOS instala, configura y mantiene está encapsulado en una ficha. Una ficha es un contrato formal entre el sistema y una aplicación. Si no existe una ficha para una aplicación, el sistema no la conoce. Si la ficha tiene un error, el sistema lo detecta. Si la ficha cambia, el sistema reconcilia. Lee SBOS-006 completo antes de escribir tu primera contribución.

**El bKernel es el sistema nervioso.**
El bKernel observa todos los cambios en la base de datos PostgreSQL via WAL (Write-Ahead Log) y propaga esos cambios a los consumidores correctos. No hay polling. No hay webhooks manuales. No hay sincronización por cron. Todo pasa por el bKernel. Lee SBOS-010 para entender cómo funciona.

**Los Tres Principios son inquebrantables.**
1. Gobernanza por Keycloak — toda autenticación y autorización pasa por Keycloak
2. PostgreSQL como base de datos — no se usa ninguna otra base de datos relacional
3. Solo software de licencia libre — MIT, Apache 2.0, GPL, AGPL o equivalente. n8n está vetado (Sustainable Use License viola el Principio 3).

Si una contribución viola alguno de estos tres principios, no puede ser aceptada. No hay excepciones.

### Ruta de lectura recomendada para un nuevo contribuidor

Lee los documentos en este orden. No saltes pasos.

| Orden | Documento | Tiempo estimado | Por qué es necesario |
|---|---|---|---|
| 1 | SBOS-000 — Índice y Glosario | 30 min | El vocabulario compartido del sistema |
| 2 | SBOS-001 — Visión y Alcance | 20 min | Por qué existe el sistema y a quién sirve |
| 3 | SBOS-002 — Arquitectura General | 45 min | El mapa completo del sistema |
| 4 | SBOS-006 — Sistema de Fichas | 60 min | La unidad de contribución más frecuente |
| 5 | SBOS-018 — Estándares de Calidad | 30 min | Las reglas que el validador aplica |
| 6 | SBOS-010 — bKernel | 45 min | El canal de mensajería principal |
| 7 | SBOS-022 — Bounded Contexts | 30 min | Dónde vive cada dominio de negocio |

Con esos siete documentos leídos, puedes hacer tu primera contribución sin preguntar al equipo.

---

## 2. Entorno de desarrollo

### 2.1 Entorno de desarrollo

El desarrollador trabaja en **VS Code en Windows 11** conectado por SSH al VPS de desarrollo (Ubuntu 24.04 LTS). No se desarrolla localmente en Windows — el VPS es el entorno de compilación, ejecución y pruebas.

**Extensiones VS Code recomendadas** (se instalan automáticamente si el repo incluye `.vscode/extensions.json`):

- `ms-vscode-remote.remote-ssh` — conexión SSH al VPS (obligatoria)
- `rust-analyzer` — Rust (bkernel, biedata)
- `golang.go` — Go (bos, bcompass, bsearch, bauth, bnexus)
- `ms-python.python` — Python (api, validators)
- `redhat.vscode-yaml` — YAML (fichas, manifiestos, reglas)
- `timonwong.shellcheck` — Bash (core, task_catalog.sh)
- `Dart-Code.flutter` — Flutter/Dart (core-ui)

**VPS de desarrollo:**

- Ubuntu Server 24.04 LTS
- Acceso SSH con clave Ed25519
- Todo el toolchain se instala con `make setup-dev` (idempotente — se puede ejecutar múltiples veces sin efectos secundarios)

**Plataformas soportadas para desarrollo:**

- Ubuntu 22.04 LTS o superior (recomendado: 24.04 LTS)
- Debian 12 (Bookworm) o superior
- Fedora 38 o superior
- Windows 11 con WSL2 Ubuntu 22.04+ (alternativa si no hay VPS)

macOS funciona para desarrollo de fichas y reglas YAML, y para los daemons Go. No funciona para compilar los daemons Rust (bkernel, biedata) en su target de producción (MUSL).

### 2.2 Herramientas necesarias

Todas las herramientas se instalan ejecutando `make setup-dev` en el VPS. El script es idempotente — detecta qué ya está instalado y solo instala lo que falta. A continuación el detalle de lo que instala:

```bash
# 1. Rust (para bkernel y biedata — daemons de latencia determinista)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustup default stable
rustup component add clippy rustfmt
cargo install cargo-audit
cargo install cross
cargo install cargo-flamegraph

# 2. Go 1.22+ (para bos, bcompass, bsearch, bauth, bhnexus, banexus)
wget https://go.dev/dl/go1.22.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.22.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install golang.org/x/tools/cmd/goimports@latest
go install golang.org/x/vuln/cmd/govulncheck@latest

# 3. Python 3.11+ (para api/, validators/)
sudo apt install python3.11 python3.11-venv python3-pip

# 4. Podman 4.9.3 + Buildah + crun (testbench — NO Docker)
sudo apt install podman buildah crun
# Verificar: podman --version → 4.9.3+

# 5. kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 6. Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 7. Ed25519 signing tools
sudo apt install openssh-client

# 8. yamllint + kubeconform
pip install yamllint
# kubeconform para validación de YAML K8s en fichas
wget https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz
tar xzf kubeconform-linux-amd64.tar.gz && sudo mv kubeconform /usr/local/bin/

# 9. bats-core (tests de los 4 archivos maestros Bash)
sudo apt install bats

# 10. Flutter SDK (para core-ui/ — solo si se trabaja en el frontend)
# Ver https://docs.flutter.dev/get-started/install/linux
```

### 2.3 Clonar el repositorio

```bash
git clone git@github.com:SISTEMASSKULL/sbos.git
cd sbos

# Estructura del monorepo
ls -la
# cmd/             → binarios Go (bos, bosctl)
# internal/        → lógica Go del daemon bos (16 módulos)
# core/            → 4 archivos maestros Bash
# api/             → backend FastAPI (SP-04)
# daemons/         → 8 daemons soberanos (Rust + Go)
# servers/         → catálogo de fichas (15 servidores lógicos)
# products/        → manifiestos de producto (SBOS-032)
# core-ui/         → Core UI Flutter + SDK Dart (SP-05/06)
# testbench/       → validador/constructor/certificador (SBOS-MP05)
# release-plane/   → distribución soberana (SBOS-038)
# validators/      → validate_sp01.py + validate_sp02.py
# scripts/         → utilidades de desarrollo
# docs/            → 68+ documentos de especificación
# Makefile         → comandos estándar
```

Ver SBOS-018 §14 para la estructura completa del monorepo con todos los subdirectorios.

### 2.4 Configurar el entorno Python del validador

```bash
# Crear entorno virtual
python3.11 -m venv .venv
source .venv/bin/activate

# Instalar dependencias
pip install -r requirements-dev.txt

# Verificar que el validador funciona
make validate
# Resultado esperado: "✓ All validations passed (0 fichas, 0 rules)"
```

### 2.5 Ejecutar las pruebas

```bash
# Pruebas del validador Python
make test-validator

# Pruebas de los componentes Rust
make test-rust

# Pruebas de integración (requiere Docker)
make test-integration

# Todos los tests
make test-all
```

Todos los tests deben pasar en verde antes de hacer cualquier commit. Un PR con tests en rojo no se revisa.

### 2.6 Variables de entorno — `.env.example`

El archivo `.env.example` en la raíz del monorepo contiene todas las variables necesarias para el testbench y el desarrollo local. Se copia a `.env` y se ajustan los valores:

```bash
cp .env.example .env
# Editar .env con los valores de tu VPS
```

Contenido de `.env.example`:

```bash
# === TESTBENCH ===
SBOS_TESTBENCH_PG_HOST=127.0.0.1
SBOS_TESTBENCH_PG_PORT=5432
SBOS_TESTBENCH_PG_USER=testbench
SBOS_TESTBENCH_PG_PASSWORD=changeme_testbench
SBOS_TESTBENCH_PG_DB=testbench_db

# === PODMAN ===
SBOS_PODMAN_NETWORK=sbos-dev
SBOS_PODMAN_REGISTRY=localhost

# === FICHAS (se usan durante testbench.sh install) ===
SBOS_PG_ADMIN_PASSWORD=changeme_pg
SBOS_REDIS_PASSWORD=changeme_redis
SBOS_MINIO_ROOT_USER=minioadmin
SBOS_MINIO_ROOT_PASSWORD=changeme_minio
SBOS_VAULT_TOKEN=changeme_vault
SBOS_KC_ADMIN_USER=admin
SBOS_KC_ADMIN_PASSWORD=changeme_kc
SBOS_KONG_DB_PASSWORD=changeme_kong
SBOS_GRAFANA_ADMIN_PASSWORD=changeme_grafana

# === DESARROLLO ===
SBOS_ENV=dev
SBOS_DOMAIN=dev.sbos.local
SBOS_LOG_LEVEL=debug

# === FIRMA Ed25519 (solo para release — no se usa en dev) ===
# SBOS_SIGN_KEY_PATH=/path/to/ed25519_private_key
```

En producción estas variables no existen — los secretos viven en Vault. El `.env` es exclusivamente para desarrollo y testbench.

### 2.7 Setup idempotente

El comando `make setup-dev` instala todo lo necesario en el VPS. Es seguro ejecutarlo múltiples veces — solo instala lo que falta:

```bash
cd sbos
make setup-dev

# Lo que hace:
# 1. Verifica Ubuntu 24.04 LTS
# 2. Instala herramientas faltantes (§2.2)
# 3. Configura Podman rootless si no está configurado
# 4. Crea red sbos-dev si no existe
# 5. Levanta PostgreSQL del testbench si no corre
# 6. Aplica DDL de Knowledge Base si las tablas no existen
# 7. Copia .env.example → .env si .env no existe
# 8. Ejecuta make validate para verificar que todo funciona
```

---

## 3. El ciclo de contribución estándar

### El flujo de una contribución desde el inicio hasta producción

```
DESARROLLO LOCAL
──────────────────────────────────────────────────────────────
1. Crear rama desde main
   git checkout -b feat/ficha-tryton-sueldos

2. Escribir la contribución (ficha, regla, ruta, caja)

3. Ejecutar el validador localmente
   make validate
   → Debe pasar al 100%

4. Ejecutar tests
   make test-all
   → Todos en verde

5. Firmar la contribución con la clave Ed25519 personal
   make sign
   → Genera .sig en el directorio de la contribución

REVISIÓN
──────────────────────────────────────────────────────────────
6. Crear Pull Request en GitHub
   → Descripción: qué hace, por qué, qué fichas/reglas afecta
   → El CI corre el validador automáticamente

7. Revisión por al menos un contribuidor senior
   → Si hay cambios pedidos: iterar en la misma rama

8. Merge a main (solo el revisor hace el merge, nunca el autor)

PUBLICACIÓN
──────────────────────────────────────────────────────────────
9. El Release Server detecta el nuevo commit en main
   → Genera el artefacto firmado con la clave del Release Server
   → Versiona el artefacto según semver

10. Los IAM Installers de los clientes detectan la nueva versión
    → Aplican la actualización en la próxima ventana de mantenimiento
    → Verifican la firma Ed25519 del Release Server antes de aplicar
```

### Convenciones de nombres de rama

| Tipo de cambio | Prefijo | Ejemplo |
|---|---|---|
| Nueva ficha | `feat/ficha-` | `feat/ficha-tryton-sueldos` |
| Actualización de ficha | `update/ficha-` | `update/ficha-rocketchat-v2` |
| Nueva regla bKernel | `feat/rule-` | `feat/rule-empleado-sync` |
| Nueva ruta SBOS AI Tools | `feat/route-` | `feat/route-approval-compras` |
| Nueva caja SBOS Data Integration | `feat/box-` | `feat/box-facturacion-sat` |
| Corrección de bug | `fix/` | `fix/ficha-tryton-puerto` |
| Documentación | `docs/` | `docs/ficha-tryton-guia` |

---

## 4. Tutorial: agregar una ficha nueva

Este es el tutorial más importante. La mayoría de contribuciones son fichas nuevas o actualizaciones de fichas existentes.

### 4.1 Entender qué es una ficha

Una ficha es un directorio con cuatro archivos obligatorios y varios opcionales. La estructura mínima:

```
fichas/
└── sp-tryton-sueldos/
    ├── metadata.yml        ← identidad y versión de la ficha
    ├── deployment.yml      ← cómo se despliega en K8s
    ├── config.yml          ← configuración de la aplicación
    └── health.yml          ← cómo se valida que funciona
```

Para el detalle completo de cada contrato, consultar SBOS-006 §3 (contratos de fichas).

### 4.2 Crear la estructura de la ficha

```bash
# Usar el generador del Makefile
make new-ficha NOMBRE=sp-tryton-sueldos

# El generador crea la estructura con templates
ls fichas/sp-tryton-sueldos/
# metadata.yml      ← template con campos obligatorios marcados
# deployment.yml    ← template K8s básico
# config.yml        ← template vacío
# health.yml        ← template con health check HTTP básico
```

### 4.3 Completar metadata.yml

```yaml
# fichas/sp-tryton-sueldos/metadata.yml
apiVersion: sbos.skull.io/v1
kind: Ficha
metadata:
  name: sp-tryton-sueldos
  version: "1.0.0"
  description: "Módulo de liquidación de sueldos para Tryton ERP"
  category: "erp-financiero"
  license: "GPL-3.0"          # OBLIGATORIO — licencia de la aplicación
  upstream: "https://github.com/tryton/account_payroll"

spec:
  server: "appserver"          # servidor lógico donde se despliega (ver SBOS-016)
  namespace: "tryton"
  requires:
    - sp-tryton-base            # fichas de las que depende esta ficha
    - sp-postgresql             # la base de datos siempre es una dependencia explícita
  provides:
    - service: "tryton-sueldos"
      port: 8000
  keycloak:
    realm: "bos-main"
    client_id: "tryton-sueldos"
    roles:
      - name: "bos-rrhh-sueldos"
        description: "Acceso al módulo de liquidación de sueldos"
```

### 4.4 Completar deployment.yml

```yaml
# fichas/sp-tryton-sueldos/deployment.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tryton-sueldos
  namespace: tryton
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tryton-sueldos
  template:
    metadata:
      labels:
        app: tryton-sueldos
    spec:
      securityContext:
        runAsNonRoot: true         # OBLIGATORIO — CIS K8s Level 1
        runAsUser: 1000
      containers:
        - name: tryton-sueldos
          image: "tryton/tryton:7.0"
          resources:
            requests:
              cpu: "100m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"      # OBLIGATORIO — todos los pods tienen límites
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: tryton-sueldos-db
                  key: password    # secretos desde Vault, nunca en texto plano
```

### 4.5 Completar health.yml

```yaml
# fichas/sp-tryton-sueldos/health.yml
apiVersion: sbos.skull.io/v1
kind: HealthCheck
spec:
  http:
    path: "/health"
    port: 8000
    expectedStatus: 200
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
  # El IAM Installer verifica este endpoint después del despliegue
  # Si falla 3 veces consecutivas → rollback automático
```

### 4.6 Validar la ficha localmente

```bash
# Validar solo esta ficha
make validate FICHA=sp-tryton-sueldos

# Resultado esperado:
# ✓ metadata.yml — schema válido
# ✓ deployment.yml — schema válido, limits presentes, runAsNonRoot = true
# ✓ health.yml — schema válido
# ✓ license: GPL-3.0 — licencia libre aprobada
# ✓ sp-tryton-base — dependencia existe en el catálogo
# ✓ sp-postgresql — dependencia existe en el catálogo
# ✓ All validations passed (1 ficha)
```

Si el validador reporta errores, corregirlos antes de continuar. El validador es el árbitro final — si falla, el PR no se puede aprobar.

### 4.7 Firmar y hacer el PR

```bash
# Firmar la ficha con la clave Ed25519 personal
make sign FICHA=sp-tryton-sueldos
# Genera: fichas/sp-tryton-sueldos/metadata.yml.sig

# Commit y push
git add fichas/sp-tryton-sueldos/
git commit -m "feat(ficha): agrega sp-tryton-sueldos v1.0.0

Agrega módulo de liquidación de sueldos para Tryton 7.0.
Depende de sp-tryton-base y sp-postgresql.
Crea rol bos-rrhh-sueldos en Keycloak."

git push origin feat/ficha-tryton-sueldos
# Crear PR en GitHub desde la rama
```

---

## 5. Tutorial: agregar una regla al bKernel

Las reglas del bKernel definen qué pasa cuando un dato cambia en PostgreSQL. Si un empleado nuevo se registra en OrangeHRM, la regla del bKernel decide qué otros sistemas necesitan saber.

### 5.1 Estructura de una regla YAML

```yaml
# rules/empleado-sync.yml
apiVersion: sbos.skull.io/v1
kind: Rule
metadata:
  name: empleado-sync
  version: "1.0.0"
  description: "Sincroniza empleados nuevos de OrangeHRM a Keycloak"

spec:
  trigger:
    table: "ohrm_employee"           # tabla de PostgreSQL a observar
    operations: [INSERT, UPDATE]      # qué operaciones disparan la regla
    schema: "orangehrm"              # schema donde vive la tabla

  filter:
    condition: "NEW.termination_id IS NULL"   # solo empleados activos

  transform:
    # Mapeo de campos: campo_origen → campo_destino
    fields:
      emp_firstname:   first_name
      emp_lastname:    last_name
      work_email:      email
      employee_id:     external_id

  destination:
    type: redis_stream
    stream: "bkernel:keycloak_sync"
    consumer_group: "keycloak_worker"

  on_error:
    strategy: dead_letter_queue
    dlq_stream: "bkernel:dlq"
    max_retries: 3
    retry_delay_seconds: 30
```

### 5.2 Campos obligatorios

| Campo | Descripción |
|---|---|
| `trigger.table` | La tabla PostgreSQL exacta a observar (con schema) |
| `trigger.operations` | Al menos uno de: INSERT, UPDATE, DELETE |
| `destination.type` | El canal de destino (ver tabla de decisión en SBOS-022) |
| `on_error.strategy` | Qué hacer si falla: `dead_letter_queue`, `discard`, `halt` |

### 5.3 Probar la regla localmente

```bash
# Levantar PostgreSQL + bKernel en Docker para pruebas locales
make dev-up

# Ejecutar las pruebas de la regla
make test-rule RULE=empleado-sync

# El test inserta una fila en ohrm_employee y verifica
# que el evento correcto llegó al redis stream
# Resultado esperado:
# ✓ INSERT trigger — evento emitido al stream bkernel:keycloak_sync
# ✓ UPDATE trigger — evento emitido al stream bkernel:keycloak_sync
# ✓ DELETE trigger — ignorado correctamente (no está en operations)
# ✓ empleado con termination_id — ignorado correctamente (filter OK)
# ✓ All rule tests passed

make dev-down
```

### 5.4 Validar y hacer el PR

```bash
make validate RULE=empleado-sync
make sign RULE=empleado-sync
git add rules/empleado-sync.yml rules/empleado-sync.yml.sig
git commit -m "feat(rule): sincroniza empleados OrangeHRM → Keycloak"
git push origin feat/rule-empleado-sync
```

---

## 6. Tutorial: agregar una ruta a SBOS AI Tools

Las rutas de SBOS AI Tools son los workflows de negocio del sistema. Si el proceso de aprobación de compras requiere tres niveles de autorización, eso es una ruta de SBOS AI Tools.

### 6.1 Estructura de una ruta

```yaml
# routes/approval-compras.yml
apiVersion: sbos.skull.io/v1
kind: Route
metadata:
  name: approval-compras
  version: "1.0.0"
  description: "Workflow de aprobación de órdenes de compra"
  category: "governance"      # governance | automation | integration | ai-assisted

spec:
  trigger:
    type: event
    source: redis_stream
    stream: "bkernel:compras_nuevas"

  steps:
    - id: validar_presupuesto
      type: rule_check
      rule: "compra.monto <= departamento.presupuesto_disponible"
      on_fail: reject

    - id: aprobacion_jefe
      type: approval_gate
      approver_role: "bos-jefe-compras"
      timeout_hours: 24
      on_timeout: escalate_to_gerencia

    - id: aprobacion_gerencia
      type: approval_gate
      condition: "steps.validar_presupuesto.monto > 10000"   # solo si monto > 10k
      approver_role: "bos-gerente-financiero"
      timeout_hours: 48

    - id: emitir_orden
      type: action
      action: "tryton.purchase.confirm"
      payload:
        purchase_id: "{{ trigger.purchase_id }}"

  compensation:
    # Si cualquier paso falla después de emitir_orden
    - step: emitir_orden
      compensate: "tryton.purchase.cancel"

  notifications:
    channel: redis_stream
    stream: "sbos:vdi:notifications"
```

### 6.2 Probar la ruta en Flowise

SBOS AI Tools usa Flowise como motor de ejecución. Para probar una ruta antes del PR:

```bash
# Levantar Flowise local
make dev-flowise

# Importar la ruta al entorno local de Flowise
make import-route ROUTE=approval-compras
# Flowise disponible en: http://localhost:3000

# Ejecutar la prueba de la ruta con un evento simulado
make test-route ROUTE=approval-compras
# El test verifica todos los caminos del workflow:
# ✓ Camino normal: validación OK → aprobación jefe → emitir orden
# ✓ Camino rechazo: monto > presupuesto → reject
# ✓ Camino escalamiento: timeout jefe → escalate_to_gerencia
# ✓ Compensación: orden emitida → fallo posterior → cancel ejecutado

make dev-down
```

### 6.3 Validar y hacer el PR

```bash
make validate ROUTE=approval-compras
make sign ROUTE=approval-compras
git add routes/approval-compras.yml routes/approval-compras.yml.sig
git commit -m "feat(route): workflow de aprobación de órdenes de compra"
git push origin feat/route-approval-compras
```

---

## 7. Tutorial: agregar una caja a SBOS Data Integration

Las cajas de SBOS Data Integration son conectores de integración exterior. Si el cliente necesita recibir facturas del SAT de México o sincronizar datos con un ERP legacy, eso es una caja.

### 7.1 Estructura de una caja

Cada caja vive en su directorio con tres archivos:

```
boxes/
└── mx-sat-cfdi/
    ├── mapping.yml           ← cómo transformar el dato externo al esquema SBOS
    ├── validation_rules.yml  ← qué validar antes de aceptar el dato
    └── connector.rs          ← el código del conector (Rust)
```

### 7.2 El mapping.yml

```yaml
# boxes/mx-sat-cfdi/mapping.yml
apiVersion: sbos.skull.io/v1
kind: BoxMapping
metadata:
  name: mx-sat-cfdi
  version: "1.0.0"
  description: "Conector para CFDI 4.0 del SAT de México"
  license: "Apache-2.0"

spec:
  source:
    format: xml
    schema: "http://www.sat.gob.mx/cfd/4"
    encoding: UTF-8

  destination:
    table: "account_move"
    schema: "tryton"

  text_template: |
    Factura {{ source.Folio }} de {{ source.Emisor.Nombre }}
    Fecha: {{ source.Fecha }}
    Total: {{ source.Total }} {{ source.Moneda }}

  fields:
    - source: "Folio"
      destination: "reference"
      type: string
      required: true

    - source: "Fecha"
      destination: "date"
      type: date
      format: "YYYY-MM-DDTHH:MM:SS"

    - source: "Total"
      destination: "amount"
      type: decimal
      precision: 2

    - source: "Emisor.RFC"
      destination: "party_tax_id"
      type: string

  metadata:
    realm_field: "receptor_rfc"     # qué campo del dato externo identifica el realm
    operation_field: "tipo_comprobante"
```

### 7.3 El validation_rules.yml

```yaml
# boxes/mx-sat-cfdi/validation_rules.yml
rules:
  - field: "Folio"
    required: true
    max_length: 40

  - field: "Total"
    required: true
    type: decimal
    min: 0.01

  - field: "Emisor.RFC"
    required: true
    pattern: "^[A-Z&Ñ]{3,4}[0-9]{6}[A-Z0-9]{3}$"   # RFC mexicano

  - field: "NoCertificado"
    required: true
    description: "Número de certificado del SAT — valida que el CFDI es auténtico"
```

### 7.4 Compilar y firmar el conector

```bash
# Compilar la caja como shared library
make build-box BOX=mx-sat-cfdi
# Genera: boxes/mx-sat-cfdi/target/mx-sat-cfdi.so

# Ejecutar las pruebas del conector
make test-box BOX=mx-sat-cfdi
# El test procesa CFDIs de ejemplo y verifica el mapping
# ✓ CFDI válido → mapeado correctamente a account_move
# ✓ CFDI con RFC inválido → rechazado por validation_rules
# ✓ CFDI sin Total → rechazado por required

# Firmar el .so con la clave Ed25519 personal
make sign-box BOX=mx-sat-cfdi
# Genera: boxes/mx-sat-cfdi/target/mx-sat-cfdi.so.sig
```

### 7.5 Validar y hacer el PR

```bash
make validate BOX=mx-sat-cfdi
git add boxes/mx-sat-cfdi/
git commit -m "feat(box): conector CFDI 4.0 SAT México"
git push origin feat/box-facturacion-sat
```

---

## 8. Qué hacer ante una duda arquitectónica

Antes de preguntar al equipo, consultar los documentos en este orden:

**¿No entiendo qué hace un término o componente?**
→ SBOS-000 §2 (Glosario). Si no está ahí, es un término nuevo que debería agregarse.

**¿No sé en qué servidor lógico va mi componente?**
→ SBOS-016 (Mapa de Servidores). Cada servidor tiene una responsabilidad clara.

**¿No sé qué canal de mensajería usar?**
→ SBOS-022 §4 (Tabla de decisión de canal). Es exactamente para eso.

**¿No sé a qué bounded context pertenece mi contribución?**
→ SBOS-022 §2 (Los bounded contexts del sistema).

**¿No sé si mi ficha cumple los estándares?**
→ Ejecutar `make validate`. Si pasa, cumple. Si falla, el validador dice exactamente qué falla.

**¿No sé si la licencia de una dependencia es aceptable?**
→ SBOS-018 §2 (Política de licencias). MIT, Apache 2.0, GPL, AGPL son aceptables. Cualquier licencia con restricción de uso comercial no lo es.

**¿La duda no está resuelta por ningún documento?**
→ Crear un issue en GitHub con la etiqueta `architecture-question` antes de escribir código. Las decisiones de arquitectura se toman en equipo y se documentan en el issue antes de implementarse. Nunca implementar primero y documentar después.

### Jerarquía de documentos para consultar

```
SBOS-000  → El glosario y las rutas de lectura
SBOS-002  → La arquitectura general (el mapa grande)
SBOS-022  → Los bounded contexts y el modelo de mensajería
SBOS-018  → Los estándares de calidad
SBOS-006  → El sistema de fichas (la contribución más común)
SBOS-010  → El bKernel (el canal de mensajería principal)
SBOS-014  → SBOS AI Tools (los workflows de negocio)
SBOS-011  → SBOS Data Integration (las cajas de integración exterior)
```

---

## 9. Registro de cambios

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| 1.0 | Marzo 2026 | SKULL Team | Documento inicial |

---

*SKULL · SBOS · SBOS-021-ONBOARDING · v1.0 · Marzo 2026*
-e 
---

## Onboarding para Roles No Técnicos

> **Integrado desde SBOS-MP01 PARTE C en v2.0.**

## PARTE C — Para insertar en SBOS-021: Onboarding para Roles No Técnicos

### C.1 Perfil del administrador funcional del cliente

El administrador funcional es la persona responsable de operar SBOS en la empresa cliente. No es necesariamente un técnico de TI. Puede ser el contador, el jefe de operaciones, o una persona designada específicamente para la gestión del sistema.

**Lo que puede hacer sin soporte técnico:**
- Crear, modificar y desactivar usuarios del realm de su empresa
- Asignar y quitar roles a usuarios (usando el catálogo de roles de SBOS-009)
- Revisar el estado del stack (qué fichas están activas) en el Core UI
- Interpretar los paneles básicos de Grafana (disponibilidad del sistema, estado del bKernel)
- Solicitar actualizaciones de fichas desde el Core UI
- Exportar reportes del SBOS AI Tools

**Lo que requiere asistencia de SKULL:**
- Cambiar el plan (agregar/quitar módulos)
- Modificar configuraciones de autenticación (flujos MFA, SPIs)
- Actualizar versiones del IAM Installer o daemons soberanos
- Resolver incidentes de nivel 2 o superior

### C.2 Plan de 5 sesiones de onboarding para el administrador funcional

| Sesión | Duración | Temas | Ejercicio práctico |
|--------|---------|-------|-------------------|
| **Sesión 1 — El sistema** | 2 h | Qué es SBOS, los tres planos (Release/IAM/K8s), cómo acceder al Core UI, el concepto de ficha | Acceder al Core UI y navegar a "Estado del Stack" — identificar qué fichas están activas |
| **Sesión 2 — Identidad** | 2 h | Qué es un realm, qué es un usuario, qué es un rol, cómo funciona Keycloak, los 3 niveles de admin | Crear un usuario de prueba, asignarle el rol "Vendedor" del sector retail, verificar que puede iniciar sesión |
| **Sesión 3 — Operación diaria** | 2 h | Cómo interpretar el panel de disponibilidad en Grafana, qué es el bKernel y por qué importa, las alertas que puede recibir | Simular una alerta de prueba y documentar los pasos para reportarla a SKULL |
| **Sesión 4 — Backup y continuidad** | 2 h | Qué es el backup, cuándo se ejecuta, cómo verificar que es exitoso, qué es un RTO y por qué le importa al cliente | Verificar el estado del último backup desde el Core UI + revisar el panel FinOps de Grafana |
| **Sesión 5 — Casos de uso reales** | 2 h | Alta de empleado nuevo (proceso cross-sistema: OrangeHRM → Keycloak → Tryton), baja de empleado, cambio de rol | Ejecutar el alta completa de un empleado de prueba y verificar que aparece en Tryton y tiene acceso correcto |

### C.3 Operaciones diarias del administrador funcional

**Lunes (inicio de semana):**
- Verificar en Core UI que todas las fichas están activas (semáforo verde)
- Revisar las alertas de la semana pasada en el canal Slack de alertas
- Procesar solicitudes de nuevos usuarios pendientes

**Mensual:**
- Revisar el panel FinOps: ¿el uso de recursos está dentro de lo esperado?
- Revisar usuarios inactivos (más de 30 días sin login): desactivar si corresponde
- Confirmar que el backup del último domingo completó exitosamente

### C.4 Cuándo escalar a SKULL

El administrador funcional debe contactar a SKULL cuando:

| Señal | Urgencia | Canal |
|-------|---------|-------|
| El Core UI muestra una ficha en rojo ("error") que no se recupera sola en 15 minutos | Alta | Email + teléfono |
| Un usuario no puede autenticarse y el problema no es la contraseña | Media | Email |
| El panel de Grafana muestra "bKernel DOWN" por más de 5 minutos | Crítica | Teléfono directo |
| Una factura no recibió autorización del ente tributario | Alta | Email |
| La empresa quiere agregar un nuevo módulo o cambiar de plan | Normal | Email con asunto "Cambio de plan" |

---

*SKULL · SBOS · SBOS-MP01 · v1.0 · Marzo 2026*
*Distribuir: Parte A → SBOS-008, Parte B → SBOS-009, Parte C → SBOS-021*
