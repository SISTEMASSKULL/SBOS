# SBOS-MP05
## Banco de Pruebas de Fichas (Testbench)
### Validador Universal, Constructor Inteligente y Pipeline de Certificación

### SKULL · SBOS — Sovereign Business Operating System
### v2.0 · Marzo 2026

---

**Código:** SBOS-MP05
**Propósito:** Herramienta universal del ecosistema SBOS con tres funciones:
1. **Validador** — verifica que una ficha funciona correctamente antes de publicarla
2. **Constructor** — genera y enriquece archivos de la ficha usando conocimiento acumulado
3. **Certificador** — pipeline obligatorio antes de publicar en el SKULL Release Plane

Este motor es el prototipo del Core del daemon bos y del CoreUI. La lógica de resolución recursiva de dependencias que aquí se valida en Podman se reutiliza tal cual en K8s.

---

## 1. Arquitectura

### 1.1 Stack Tecnológico

| Componente | Tecnología | Por qué |
|-----------|-----------|---------|
| Motor de contenedores | **Podman 4.9.3** (rootless) | Pods nativos como K8s, `podman play kube` lee YAML K8s directo, CRI-O es el runtime de K8s, sin daemon root |
| Build de imágenes | **Buildah** | Daemonless, OCI-compliant, mismo resultado que Dockerfile |
| Inspección de imágenes | **Skopeo** | Copiar/verificar imágenes sin daemon |
| Container runtime | **crun** | Más ligero que runc, escrito en C, rootless nativo |
| Estado del motor | **PostgreSQL 18-alpine** | En pod propio, gestiona estado + colas + knowledge base |
| Host | **Ubuntu 24.04 LTS** | Mismo SO que producción SBOS |
| Manifiestos de fichas | **YAML de Kubernetes** | Desde el día 1, no docker-compose. `podman play kube` los ejecuta directamente |

### 1.2 Diagrama

```
┌─────────────────────────────────────────────────────────────┐
│  Pod: sbos-testbench-engine                                  │
│                                                              │
│  ┌──────────────────┐  ┌──────────────────────────────────┐ │
│  │ PostgreSQL 18     │  │ Motor Bash                       │ │
│  │ (estado + colas   │  │                                  │ │
│  │  + knowledge base)│  │  testbench.sh (CLI)              │ │
│  │                   │  │  engine.sh (Kahn + recursión)    │ │
│  │  fichas_state     │  │  scaffolder.sh (constructor)     │ │
│  │  install_queue    │  │  certifier.sh (certificador)     │ │
│  │  install_log      │  │  task_catalog_global.sh          │ │
│  │  relations_log    │  │  logger.sh                       │ │
│  │  knowledge_base   │  │                                  │ │
│  └──────────────────┘  └──────────────────────────────────┘ │
└────────────┬────────────────────────────────────────────────┘
             │ podman network: sbos-testbench-net
             │
     ┌───────┴──────────────────────────────────┐
     │  Fichas instaladas (pods Podman)          │
     │  sbos-postgresql, sbos-redis,             │
     │  sbos-keycloak, sbos-mailserver, ...      │
     └───────────────────────────────────────────┘
```

### 1.3 Ventaja clave de Podman sobre Docker

Las fichas NO usan docker-compose.yml. Usan YAML de Kubernetes desde el día 1:

```bash
# El testbench ejecuta el YAML de K8s directamente con Podman
podman play kube fichas/postgresql/resources/k8s/pod.yml

# Cuando migres a K8s real, el MISMO archivo se aplica:
kubectl apply -f fichas/postgresql/resources/k8s/pod.yml
```

Además, al terminar de validar una ficha:
```bash
# Podman genera YAML de K8s a partir del pod corriendo
podman generate kube sbos-postgresql > postgresql-validated.yml
```

---

## 2. Los Tres Roles del Testbench

### 2.1 VALIDADOR — `testbench.sh install <ficha>`

Verifica que una ficha funciona. Resuelve dependencias recursivamente, instala, configura relaciones, y ejecuta tests de verificación.

```
testbench.sh install <ficha>

  → Lee manifest.yml
  → Resuelve dependencias (Kahn recursivo)
  → Para cada dependencia:
      ¿corre? → solo configurar relación
      ¿no corre? → instalarla primero (recursión)
  → pre_install → podman play kube → post_install → verify
  → Registrar estado + relaciones + descubrimientos
```

### 2.2 CONSTRUCTOR — `testbench.sh scaffold <ficha>`

Genera y enriquece los archivos de una ficha usando el conocimiento acumulado en la base de datos. No parte de cero — analiza el tipo de aplicación y propone una ficha pre-llenada.

```
testbench.sh scaffold grafana

  → Consulta knowledge_base: "¿qué sé sobre apps tipo web+dashboard?"
  → Encuentra patrones de: keycloak (web+dashboard), pgadmin (web+dashboard)
  → Genera manifest.yml con:
      - depends_on: postgresql (patrón: toda app con BD)
      - depends_on: keycloak (patrón: toda app web con auth)
      - relation: database "grafana_db" (patrón predecible)
      - relation: keycloak_client "grafana" (patrón predecible)
      - healthcheck: curl http://localhost:3000/api/health (conocido)
  → Genera yaml_engine.yml con:
      - pre_install: create_directories (patrón universal)
      - post_install: wait_ready + configure_databases (patrón BD)
      - verify: check_http + check_db_connection (patrón web+BD)
  → Genera resources/k8s/pod.yml con:
      - imagen: grafana/grafana-oss:11.x
      - puertos: 3000
      - volumeMounts para /var/lib/grafana
  → El desarrollador REVISA, AJUSTA y COMPLETA lo que falta
  → Luego ejecuta: testbench.sh install grafana
```

### 2.3 CERTIFICADOR — `testbench.sh certify <ficha>`

Pipeline obligatorio antes de publicar una ficha en el SKULL Release Plane (SBOS-038). Ninguna ficha llega al catálogo sin pasar esta certificación.

```
testbench.sh certify <ficha>

  NIVEL 1 — ESTRUCTURA (lint)
    □ manifest.yml existe y es YAML válido
    □ yaml_engine.yml existe con fases pre/post/verify
    □ task_catalog.sh existe y las funciones referenciadas existen
    □ resources/k8s/pod.yml existe y es K8s YAML válido
    □ Nombres siguen convención SBOS (sbos-<nombre>)

  NIVEL 2 — ESQUEMA (schema validation)
    □ manifest.yml cumple el schema de SBOS-006
    □ pod.yml es válido contra API de K8s (kubeconform)
    □ Todas las dependencias referenciadas existen como fichas

  NIVEL 3 — INSTALACIÓN (integration test)
    □ testbench.sh install <ficha> ejecuta sin error
    □ El pod arranca y pasa healthcheck
    □ Todas las relaciones se configuran correctamente
    □ La fase verify pasa todos los checks

  NIVEL 4 — SEGURIDAD
    □ Imagen no corre como root (rootless verificado)
    □ No hay passwords en texto plano en los archivos
    □ Variables de entorno secretas usan vault_path
    □ Red restringida (solo puertos declarados)

  NIVEL 5 — IDEMPOTENCIA
    □ Ejecutar install dos veces NO duplica datos
    □ Las BDs no se recrean si ya existen
    □ Los clients KC no se duplican
    □ El estado final es idéntico en ambas ejecuciones

  RESULTADO:
    ✅ CERTIFICADA → firma Ed25519 → publicar en Release Plane
    ❌ RECHAZADA → informe detallado de qué falla
```

---

## 3. Knowledge Base — La Memoria del Testbench

### 3.1 Tablas de conocimiento

```sql
-- Patrones descubiertos por tipo de aplicación
CREATE TABLE kb_app_patterns (
    id              SERIAL PRIMARY KEY,
    app_type        VARCHAR(30) NOT NULL,    -- 'database', 'web', 'mail', 'cache', 'monitoring'
    pattern_key     VARCHAR(50) NOT NULL,    -- 'healthcheck_command', 'default_port', 'needs_pvc'
    pattern_value   TEXT NOT NULL,           -- 'pg_isready -U postgres', '5432', 'true'
    confidence      FLOAT DEFAULT 1.0,      -- 0.0-1.0 basado en cuántas fichas lo confirman
    learned_from    VARCHAR(50),            -- 'postgresql', 'keycloak', etc.
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Relaciones descubiertas entre fichas
CREATE TABLE kb_relation_patterns (
    id              SERIAL PRIMARY KEY,
    source_type     VARCHAR(30) NOT NULL,    -- 'web' (la app que necesita)
    target_ficha    VARCHAR(50) NOT NULL,    -- 'postgresql' (la dependencia)
    relation_type   VARCHAR(30) NOT NULL,    -- 'database', 'redis_db', 'keycloak_client'
    template        JSONB NOT NULL,          -- template de la relación
    frequency       INT DEFAULT 1,           -- cuántas fichas usan este patrón
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Configuraciones de post_install exitosas
CREATE TABLE kb_post_install_recipes (
    id              SERIAL PRIMARY KEY,
    ficha_id        VARCHAR(50) NOT NULL,
    task_name       VARCHAR(100) NOT NULL,
    task_params     JSONB,
    execution_order INT,
    success_count   INT DEFAULT 1,
    failure_count   INT DEFAULT 0,
    avg_duration_ms INT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Imágenes Docker validadas con metadata
CREATE TABLE kb_validated_images (
    id              SERIAL PRIMARY KEY,
    image_name      VARCHAR(200) NOT NULL,
    image_tag       VARCHAR(50) NOT NULL,
    size_mb         INT,
    arch            VARCHAR(20) DEFAULT 'amd64',
    default_port    INT,
    default_user    VARCHAR(50),
    healthcheck_cmd TEXT,
    start_period_s  INT,
    needs_pvc       BOOLEAN DEFAULT false,
    pvc_path        TEXT,
    validated_at    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(image_name, image_tag)
);
```

### 3.2 Cómo aprende el testbench

Cada vez que se instala una ficha exitosamente, el motor registra los patrones:

```
INSTALACIÓN EXITOSA de postgresql:
  → kb_validated_images: postgres:18-alpine, 82MB, port 5432,
    healthcheck "pg_isready", start_period 30s, needs_pvc true, path /var/lib/postgresql
  → kb_app_patterns: type=database, healthcheck=pg_isready, default_port=5432
  → kb_post_install_recipes: wait_ready(30s) + configure_databases + configure_extensions

INSTALACIÓN EXITOSA de keycloak:
  → kb_validated_images: keycloak:26.1, port 8080,
    healthcheck "curl /health/ready", start_period 60s
  → kb_app_patterns: type=web, needs_keycloak_client=false (ES keycloak)
  → kb_relation_patterns: web→postgresql = database con pgcrypto (confidence 1.0)
  → kb_post_install_recipes: wait_ready(60s) + import_realm + create_admin

INSTALACIÓN EXITOSA de roundcube:
  → kb_relation_patterns: web→postgresql = database (frequency +1, confidence +0.1)
  → kb_relation_patterns: web→keycloak = client (frequency 1, nuevo patrón)
  → kb_relation_patterns: web→redis = redis_db para sessions (nuevo patrón)

... después de 10 fichas instaladas, el motor sabe:
  - 8 de 10 apps web necesitan postgresql → confidence 0.8
  - 6 de 10 apps web necesitan keycloak_client → confidence 0.6
  - 3 de 10 apps web necesitan redis → confidence 0.3
  - Toda app con BD necesita wait_ready + configure_databases en post_install
  - Toda app web tiene healthcheck HTTP en / o /health
```

### 3.3 Cómo el scaffold usa el conocimiento

```
testbench.sh scaffold paperless-ngx

  Motor: "paperless-ngx es tipo 'web+ocr'. ¿Qué sé?"
  
  Consulta: SELECT * FROM kb_app_patterns WHERE app_type = 'web' AND confidence > 0.5
  Resultado:
    - needs_postgresql: true (confidence 0.8)
    - needs_keycloak: true (confidence 0.6)
    - healthcheck: HTTP (confidence 0.9)
    - needs_pvc: true (confidence 0.7)

  Consulta: SELECT * FROM kb_relation_patterns WHERE source_type = 'web' AND frequency > 2
  Resultado:
    - postgresql: database "{ficha_id}_db" con owner "{ficha_id}_user"
    - keycloak: client "{ficha_id}" con redirect ["http://localhost:{port}/*"]

  Motor genera manifest.yml:
    depends_on:
      - ficha: postgresql
        relations:
          - type: database
            database: "paperless_db"        ← predecible por patrón
            owner: "paperless_user"          ← predecible por patrón
      - ficha: keycloak
        relations:
          - type: keycloak_client
            client_id: "paperless-ngx"       ← predecible por patrón
    healthcheck:
      command: "curl -f http://localhost:8000/"  ← predecible por patrón web

  Motor muestra:
    "Ficha generada con 70% de confianza. Revisa y completa:
     ⚠ Imagen Docker: no encontrada en kb. Especifica manualmente.
     ⚠ Puerto: asumí 8000 (promedio web). Verifica.
     ⚠ Redis: confidence 0.3 — no incluido. ¿Lo necesita?"
```

---

## 4. Algoritmo de Resolución: Kahn + Recursión

```
función INSTALAR(ficha, _visitados=[]):

    SI ficha EN _visitados:
        ERROR "Dependencia circular: {_visitados} → {ficha}"
        ABORTAR
    _visitados.agregar(ficha)

    SI contenedor_corriendo(ficha.container_name):
        RETORNAR OK

    PARA CADA dep EN ficha.depends_on:
        SI contenedor_corriendo(dep.container_name):
            CONFIGURAR_RELACION(ficha, dep)
        SINO:
            INSTALAR(dep, _visitados)
            CONFIGURAR_RELACION(ficha, dep)

    ejecutar_fase("pre_install")
    podman_play_kube(ficha)
    esperar_healthy(ficha)
    ejecutar_fase("post_install")
    ejecutar_fase("verify")
    registrar_estado(ficha, "running")
    aprender_patrones(ficha)          ← NUEVO: alimentar knowledge base
```

---

## 5. Formato del manifest.yml

### Ficha sin dependencias (postgresql)

```yaml
identity:
  id: "postgresql"
  name: "PostgreSQL 18"
  version: "18-alpine"
  container_name: "sbos-postgresql"
  app_type: "database"                # Para el knowledge base
depends_on: []
healthcheck:
  command: "pg_isready -U postgres -h localhost"
  interval: 10
  timeout: 5
  retries: 5
  start_period: 30
```

### Ficha con dependencias y relaciones (roundcube)

```yaml
identity:
  id: "roundcube"
  name: "Roundcube Webmail"
  version: "latest"
  container_name: "sbos-roundcube"
  app_type: "web"
depends_on:
  - ficha: "postgresql"
    container_name: "sbos-postgresql"
    relations:
      - type: "database"
        database: "roundcube_db"
        owner: "roundcube_user"
        password: "${ROUNDCUBE_DB_PASSWORD}"
  - ficha: "redis"
    container_name: "sbos-redis"
    relations:
      - type: "redis_db"
        db: 1
        purpose: "sessions"
  - ficha: "mailserver"
    container_name: "sbos-mailserver"
    relations:
      - type: "service"
        host: "sbos-mailserver"
        imap_port: 993
        smtp_port: 587
  - ficha: "keycloak"
    container_name: "sbos-keycloak"
    relations:
      - type: "keycloak_client"
        client_id: "roundcube"
        redirect_uris: ["http://localhost:8080/*"]
        roles: ["mail-user"]
healthcheck:
  command: "curl -f http://localhost/"
  interval: 30
  timeout: 10
  retries: 15
  start_period: 60
```

---

## 6. Escenarios de Resolución

### `testbench.sh install roundcube` (nada corre)

```
→ dep: postgresql → NO corre → INSTALAR(postgresql) → ✅
  → RELACION: crear roundcube_db → ✅
→ dep: redis → NO corre → INSTALAR(redis) → ✅
  → RELACION: verificar Redis DB 1 → ✅
→ dep: mailserver → NO corre → INSTALAR(mailserver)
    → dep interna: redis → SÍ → configurar rspamd → ✅
  → RELACION: verificar IMAP + SMTP → ✅
→ dep: keycloak → NO corre → INSTALAR(keycloak)
    → dep interna: postgresql → SÍ → crear keycloak_db → ✅
  → RELACION: crear client roundcube → ✅
→ instalar roundcube → ✅

Resultado: pediste 1 ficha, se instalaron 5.
Knowledge base: 5 fichas nuevas con patrones registrados.
```

---

## 7. Estructura de Carpetas

```
/opt/sbos-testbench/
├── engine/
│   ├── testbench.sh              ← CLI principal
│   ├── engine.sh                 ← Resolución Kahn + recursión
│   ├── scaffolder.sh             ← Constructor de fichas
│   ├── certifier.sh              ← Pipeline de certificación
│   ├── task_catalog_global.sh    ← Funciones globales
│   ├── logger.sh
│   └── .env
├── fichas/
│   ├── postgresql/
│   │   ├── manifest.yml
│   │   ├── yaml_engine.yml
│   │   ├── task_catalog.sh
│   │   └── resources/
│   │       ├── k8s/pod.yml       ← YAML de K8s (Podman lo ejecuta directo)
│   │       ├── config/
│   │       └── sql/
│   ├── redis/
│   ├── keycloak/
│   └── ...
├── products/
│   ├── bootstrap.yml
│   ├── mail.yml
│   └── erp.yml
├── config/
│   ├── .env.example
│   ├── network.yml
│   └── schema.sql                ← DDL del motor + knowledge base
└── tests/
```

---

## 8. Estado Persistente + Knowledge Base (PostgreSQL del motor)

```sql
-- ESTADO: fichas instaladas
CREATE TABLE fichas_state (
    ficha_id        VARCHAR(50) PRIMARY KEY,
    container_name  VARCHAR(100) NOT NULL,
    status          VARCHAR(20) DEFAULT 'not_installed',
    healthcheck     VARCHAR(20),
    installed_at    TIMESTAMPTZ,
    last_check      TIMESTAMPTZ
);

-- ESTADO: cola de instalaciones
CREATE TABLE install_queue (
    id              SERIAL PRIMARY KEY,
    ficha_id        VARCHAR(50) NOT NULL,
    requested_by    VARCHAR(50),
    priority        INT DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'pending',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ESTADO: log de operaciones
CREATE TABLE install_log (
    id              SERIAL PRIMARY KEY,
    ficha_id        VARCHAR(50) NOT NULL,
    phase           VARCHAR(20) NOT NULL,
    status          VARCHAR(20) NOT NULL,
    duration_ms     INT,
    error_detail    TEXT,
    executed_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ESTADO: relaciones configuradas
CREATE TABLE relations_log (
    id              SERIAL PRIMARY KEY,
    source_ficha    VARCHAR(50) NOT NULL,
    target_ficha    VARCHAR(50) NOT NULL,
    relation_type   VARCHAR(30) NOT NULL,
    relation_detail JSONB,
    status          VARCHAR(20) DEFAULT 'ok',
    configured_at   TIMESTAMPTZ DEFAULT NOW()
);

-- KNOWLEDGE BASE: patrones por tipo de app
CREATE TABLE kb_app_patterns (
    id              SERIAL PRIMARY KEY,
    app_type        VARCHAR(30) NOT NULL,
    pattern_key     VARCHAR(50) NOT NULL,
    pattern_value   TEXT NOT NULL,
    confidence      FLOAT DEFAULT 1.0,
    learned_from    VARCHAR(50),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- KNOWLEDGE BASE: relaciones entre tipos de fichas
CREATE TABLE kb_relation_patterns (
    id              SERIAL PRIMARY KEY,
    source_type     VARCHAR(30) NOT NULL,
    target_ficha    VARCHAR(50) NOT NULL,
    relation_type   VARCHAR(30) NOT NULL,
    template        JSONB NOT NULL,
    frequency       INT DEFAULT 1,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- KNOWLEDGE BASE: recetas de post_install exitosas
CREATE TABLE kb_post_install_recipes (
    id              SERIAL PRIMARY KEY,
    ficha_id        VARCHAR(50) NOT NULL,
    task_name       VARCHAR(100) NOT NULL,
    task_params     JSONB,
    execution_order INT,
    success_count   INT DEFAULT 1,
    failure_count   INT DEFAULT 0,
    avg_duration_ms INT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- KNOWLEDGE BASE: imágenes validadas con metadata
CREATE TABLE kb_validated_images (
    id              SERIAL PRIMARY KEY,
    image_name      VARCHAR(200) NOT NULL,
    image_tag       VARCHAR(50) NOT NULL,
    size_mb         INT,
    default_port    INT,
    healthcheck_cmd TEXT,
    start_period_s  INT,
    needs_pvc       BOOLEAN DEFAULT false,
    pvc_path        TEXT,
    validated_at    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(image_name, image_tag)
);
```

---

## 9. Comandos del CLI

```bash
# VALIDADOR
testbench.sh install <ficha>         # Instalar (resolución recursiva)
testbench.sh install-product <prod>  # Instalar todas las fichas de un producto
testbench.sh uninstall <ficha>       # Parar pod (datos se conservan)
testbench.sh verify <ficha>          # Re-ejecutar verificaciones
testbench.sh status                  # Estado de todas las fichas
testbench.sh logs <ficha>            # podman logs del pod
testbench.sh shell <ficha>           # podman exec -it bash
testbench.sh tree <ficha>            # Árbol de dependencias
testbench.sh reset                   # Parar TODO, reiniciar estado

# CONSTRUCTOR
testbench.sh scaffold <ficha>        # Generar ficha desde knowledge base
testbench.sh enrich <ficha>          # Completar campos faltantes de una ficha existente
testbench.sh suggest <ficha>         # Sugerir mejoras sin modificar archivos

# CERTIFICADOR
testbench.sh certify <ficha>         # Pipeline completo de certificación (5 niveles)
testbench.sh lint <ficha>            # Solo validación de estructura
testbench.sh schema <ficha>          # Solo validación de schema K8s

# KNOWLEDGE BASE
testbench.sh kb stats                # Estadísticas de patrones acumulados
testbench.sh kb patterns <tipo>      # Patrones conocidos para un tipo de app
testbench.sh kb images               # Imágenes validadas
```

---

## 10. De Testbench a bos Real

```
TESTBENCH (Podman)                  →  BOS (K8s)
─────────────────────               ─────────────────────
testbench.sh (Bash)                 →  bos (binario Go)
podman play kube                    →  kubectl apply -f
podman exec                         →  kubectl exec -n
.env passwords                      →  Vault secrets
Podman network                      →  Calico CNI
Volúmenes Podman                    →  PVC + StorageClass
PostgreSQL del motor                →  bos_db (mismas tablas)
Knowledge base                      →  bos_db (mismas tablas)
certify → firma manual              →  certify → firma Ed25519 automática
scaffold → genera archivos          →  Core UI → wizard de creación de fichas

LO QUE NO CAMBIA (95%):
  manifest.yml, yaml_engine.yml, task_catalog.sh, resources/
  Algoritmo de Kahn, lógica de relaciones, knowledge base
  YAML de K8s en resources/k8s/ → EL MISMO ARCHIVO
```

---

## 11. Evolución del Testbench

```
FASE ACTUAL: Herramienta de desarrollo
  → Validar fichas mientras las construimos
  → Descubrir configuraciones reales
  → Acumular conocimiento en la KB

FASE 2: Pipeline de certificación
  → Toda ficha nueva pasa por testbench.sh certify
  → Solo fichas certificadas se publican en Release Plane
  → Integración con GitLab CI del SBOS

FASE 3: Constructor inteligente
  → scaffold genera 70%+ de una ficha nueva
  → enrich completa fichas parciales
  → La KB crece con cada ficha nueva

FASE 4: Migración a Go (se convierte en bos)
  → El motor Bash se reescribe en Go
  → Podman → K8s real
  → testbench.sh → bosctl
  → La KB se convierte en el cerebro del Installer
```

---

*SKULL · SBOS · SBOS-MP05 · Banco de Pruebas de Fichas · v2.0 · Marzo 2026*
