# SBOS-MP05

## Banco de Pruebas de Fichas (Testbench)

### Validador Universal, Constructor Inteligente y Pipeline de Certificación

### SKULL · SBOS — Sovereign Business Operating System

### v2.0 · Marzo 2026

\---

**Código:** SBOS-MP05
**Propósito:** Herramienta universal del ecosistema SBOS con tres funciones:

1. **Validador** — verifica que una ficha funciona correctamente antes de publicarla
2. **Constructor** — genera y enriquece archivos de la ficha usando conocimiento acumulado
3. **Certificador** — pipeline obligatorio antes de publicar en el SKULL Release Plane

Este motor es el prototipo del Core del daemon bos y del CoreUI. La lógica de resolución recursiva de dependencias que aquí se valida en Podman se reutiliza tal cual en K8s.

\---

## 1\. Arquitectura

### 1.1 Stack Tecnológico

|Componente|Tecnología|Por qué|
|-|-|-|
|Motor de contenedores|**Podman 4.9.3** (rootless)|Seguridad: Ejecuta SmartTax y SmartReport sin privilegios de root. K8s Ready: Usa pods reales; podman play kube permite probar los manifiestos de producción en tu Ubuntu local.|
|Build de imágenes|**Buildah**|Daemonless: Crea imágenes OCI de bAPITAX y Jasper de forma aislada. Permite builds más finos y seguros al no requerir un socket expuesto.|
|Inspección de imágenes / Firma|**Skopeo**|Crítico para verificar la integridad de las imágenes antes de moverlas al registro privado de SBOS, asegurando que el motor fiscal no sea alterado.|
|Container runtime|**crun**|Más ligero que runc, escrito en C, rootless nativo. El runtime más rápido y ligero disponible. Ideal para contenedores efímeros que generan PDFs pesados con Jasper.|
|Estado del motor|**PostgreSQL 18-alpine**|En pod propio, gestiona estado + colas + knowledge base. Persistencia de alta disponibilidad para los 21 sectores del SIN. Se despliega como un contenedor hermano dentro del mismo Pod|
|Host|**Ubuntu 24.04 LTS**|Mismo SO que producción SBOS|
|Manifiestos de fichas|**YAML de Kubernetes**|Desde el día 1, `podman play kube` los ejecuta directamente|
|Orquestación Local|**YAML de Kubernetes**|Se eliminan los archivos .docker-compose. Todo se define en deployment.yaml y service.yaml, los cuales Podman ejecuta nativamente.|

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
│  │  fichas\_state     │  │  scaffolder.sh (constructor)     │ │
│  │  install\_queue    │  │  certifier.sh (certificador)     │ │
│  │  install\_log      │  │  task\_catalog\_global.sh          │ │
│  │  relations\_log    │  │  logger.sh                       │ │
│  │  knowledge\_base   │  │                                  │ │
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

\---

## 2\. Los Tres Roles del Testbench

### 2.1 VALIDADOR — `testbench.sh install <ficha>`

Verifica que una ficha funciona. Resuelve dependencias recursivamente, instala, configura relaciones, y ejecuta tests de verificación.

```
testbench.sh install <ficha>

  → Lee manifest.yml
  → Resuelve dependencias (Kahn recursivo)
  → Para cada dependencia:
      ¿corre? → solo configurar relación
      ¿no corre? → instalarla primero (recursión)
  → pre\_install → podman play kube → post\_install → verify
  → Registrar estado + relaciones + descubrimientos
```

### 2.2 CONSTRUCTOR — `testbench.sh scaffold <ficha>`

Genera y enriquece los archivos de una ficha usando el conocimiento acumulado en la base de datos. No parte de cero — analiza el tipo de aplicación y propone una ficha pre-llenada.

```
testbench.sh scaffold grafana

  → Consulta knowledge\_base: "¿qué sé sobre apps tipo web+dashboard?"
  → Encuentra patrones de: keycloak (web+dashboard), pgadmin (web+dashboard)
  → Genera manifest.yml con:
      - depends\_on: postgresql (patrón: toda app con BD)
      - depends\_on: keycloak (patrón: toda app web con auth)
      - relation: database "grafana\_db" (patrón predecible)
      - relation: keycloak\_client "grafana" (patrón predecible)
      - healthcheck: curl http://localhost:3000/api/health (conocido)
  → Genera yaml\_engine.yml con:
      - pre\_install: create\_directories (patrón universal)
      - post\_install: wait\_ready + configure\_databases (patrón BD)
      - verify: check\_http + check\_db\_connection (patrón web+BD)
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
    □ yaml\_engine.yml existe con fases pre/post/verify
    □ task\_catalog.sh existe y las funciones referenciadas existen
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
    □ Variables de entorno secretas usan vault\_path
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

\---

## 3\. Knowledge Base — La Memoria del Testbench

### 3.1 Tablas de conocimiento

```sql
-- Patrones descubiertos por tipo de aplicación
CREATE TABLE kb\_app\_patterns (
    id              SERIAL PRIMARY KEY,
    app\_type        VARCHAR(30) NOT NULL,    -- 'database', 'web', 'mail', 'cache', 'monitoring'
    pattern\_key     VARCHAR(50) NOT NULL,    -- 'healthcheck\_command', 'default\_port', 'needs\_pvc'
    pattern\_value   TEXT NOT NULL,           -- 'pg\_isready -U postgres', '5432', 'true'
    confidence      FLOAT DEFAULT 1.0,      -- 0.0-1.0 basado en cuántas fichas lo confirman
    learned\_from    VARCHAR(50),            -- 'postgresql', 'keycloak', etc.
    created\_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Relaciones descubiertas entre fichas
CREATE TABLE kb\_relation\_patterns (
    id              SERIAL PRIMARY KEY,
    source\_type     VARCHAR(30) NOT NULL,    -- 'web' (la app que necesita)
    target\_ficha    VARCHAR(50) NOT NULL,    -- 'postgresql' (la dependencia)
    relation\_type   VARCHAR(30) NOT NULL,    -- 'database', 'redis\_db', 'keycloak\_client'
    template        JSONB NOT NULL,          -- template de la relación
    frequency       INT DEFAULT 1,           -- cuántas fichas usan este patrón
    created\_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Configuraciones de post\_install exitosas
CREATE TABLE kb\_post\_install\_recipes (
    id              SERIAL PRIMARY KEY,
    ficha\_id        VARCHAR(50) NOT NULL,
    task\_name       VARCHAR(100) NOT NULL,
    task\_params     JSONB,
    execution\_order INT,
    success\_count   INT DEFAULT 1,
    failure\_count   INT DEFAULT 0,
    avg\_duration\_ms INT,
    created\_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Imágenes Podman validadas con metadata
CREATE TABLE kb\_validated\_images (
    id              SERIAL PRIMARY KEY,
    image\_name      VARCHAR(200) NOT NULL,
    image\_tag       VARCHAR(50) NOT NULL,
    size\_mb         INT,
    arch            VARCHAR(20) DEFAULT 'amd64',
    default\_port    INT,
    default\_user    VARCHAR(50),
    healthcheck\_cmd TEXT,
    start\_period\_s  INT,
    needs\_pvc       BOOLEAN DEFAULT false,
    pvc\_path        TEXT,
    validated\_at    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(image\_name, image\_tag)
);
```

### 3.2 Cómo aprende el testbench

Cada vez que se instala una ficha exitosamente, el motor registra los patrones:

```
INSTALACIÓN EXITOSA de postgresql:
  → kb\_validated\_images: postgres:18-alpine, 82MB, port 5432,
    healthcheck "pg\_isready", start\_period 30s, needs\_pvc true, path /var/lib/postgresql
  → kb\_app\_patterns: type=database, healthcheck=pg\_isready, default\_port=5432
  → kb\_post\_install\_recipes: wait\_ready(30s) + configure\_databases + configure\_extensions

INSTALACIÓN EXITOSA de keycloak:
  → kb\_validated\_images: keycloak:26.1, port 8080,
    healthcheck "curl /health/ready", start\_period 60s
  → kb\_app\_patterns: type=web, needs\_keycloak\_client=false (ES keycloak)
  → kb\_relation\_patterns: web→postgresql = database con pgcrypto (confidence 1.0)
  → kb\_post\_install\_recipes: wait\_ready(60s) + import\_realm + create\_admin

INSTALACIÓN EXITOSA de roundcube:
  → kb\_relation\_patterns: web→postgresql = database (frequency +1, confidence +0.1)
  → kb\_relation\_patterns: web→keycloak = client (frequency 1, nuevo patrón)
  → kb\_relation\_patterns: web→redis = redis\_db para sessions (nuevo patrón)

... después de 10 fichas instaladas, el motor sabe:
  - 8 de 10 apps web necesitan postgresql → confidence 0.8
  - 6 de 10 apps web necesitan keycloak\_client → confidence 0.6
  - 3 de 10 apps web necesitan redis → confidence 0.3
  - Toda app con BD necesita wait\_ready + configure\_databases en post\_install
  - Toda app web tiene healthcheck HTTP en / o /health
```

### 3.3 Cómo el scaffold usa el conocimiento

```
testbench.sh scaffold paperless-ngx

  Motor: "paperless-ngx es tipo 'web+ocr'. ¿Qué sé?"
  
  Consulta: SELECT \* FROM kb\_app\_patterns WHERE app\_type = 'web' AND confidence > 0.5
  Resultado:
    - needs\_postgresql: true (confidence 0.8)
    - needs\_keycloak: true (confidence 0.6)
    - healthcheck: HTTP (confidence 0.9)
    - needs\_pvc: true (confidence 0.7)

  Consulta: SELECT \* FROM kb\_relation\_patterns WHERE source\_type = 'web' AND frequency > 2
  Resultado:
    - postgresql: database "{ficha\_id}\_db" con owner "{ficha\_id}\_user"
    - keycloak: client "{ficha\_id}" con redirect \["http://localhost:{port}/\*"]

  Motor genera manifest.yml (Kubernetes Pod/Deployment):
    depends\_on:
      - ficha: postgresql
        relations:
          - type: database
            database: "paperless\_db"        ← predecible por patrón
            owner: "paperless\_user"          ← predecible por patrón
      - ficha: keycloak
        relations:
          - type: keycloak\_client
            client\_id: "paperless-ngx"       ← predecible por patrón
    healthcheck:
      command: "curl -f http://localhost:8000/"  ← predecible por patrón web

  Motor muestra:
    "Ficha generada con 70% de confianza. Revisa y completa:
	⚠ Imagen OCI/Podman: no encontrada en kb. Especifica manualmente para buildah o registro.



&#x09;⚠ Puerto: asumí 8000 (promedio web). Verifica para el mapeo del Pod.



&#x09;⚠ Redis: confidence 0.3 — no incluido en el manifiesto actual. ¿Lo necesita el Pod?"```

\---

## 4\. Algoritmo de Resolución: Kahn + Recursión

```
función INSTALAR(ficha, \_visitados=\[]):

    SI ficha EN \_visitados:
        ERROR "Dependencia circular: {\_visitados} → {ficha}"
        ABORTAR
    \_visitados.agregar(ficha)

    SI contenedor\_corriendo(ficha.container\_name):
        RETORNAR OK

    PARA CADA dep EN ficha.depends\_on:
        SI contenedor\_corriendo(dep.container\_name):
            CONFIGURAR\_RELACION(ficha, dep)
        SINO:
            INSTALAR(dep, \_visitados)
            CONFIGURAR\_RELACION(ficha, dep)

    ejecutar\_fase("pre\_install")
    podman\_play\_kube(ficha)
    esperar\_healthy(ficha)
    ejecutar\_fase("post\_install")
    ejecutar\_fase("verify")
    registrar\_estado(ficha, "running")
    aprender\_patrones(ficha)          ← NUEVO: alimentar knowledge base
```

\---

## 5\. Formato del manifest.yml

### Ficha sin dependencias (postgresql)

```yaml
identity:
  id: "postgresql"
  name: "PostgreSQL 18"
  version: "18-alpine"
  container\_name: "sbos-postgresql"
  app\_type: "database"                # Para el knowledge base
depends\_on: \[]
healthcheck:
  command: "pg\_isready -U postgres -h localhost"
  interval: 10
  timeout: 5
  retries: 5
  start\_period: 30
```

### Ficha con dependencias y relaciones (roundcube)

```yaml
identity:
  id: "roundcube"
  name: "Roundcube Webmail"
  version: "latest"
  container\_name: "sbos-roundcube"
  app\_type: "web"
depends\_on:
  - ficha: "postgresql"
    container\_name: "sbos-postgresql"
    relations:
      - type: "database"
        database: "roundcube\_db"
        owner: "roundcube\_user"
        password: "${ROUNDCUBE\_DB\_PASSWORD}"
  - ficha: "redis"
    container\_name: "sbos-redis"
    relations:
      - type: "redis\_db"
        db: 1
        purpose: "sessions"
  - ficha: "mailserver"
    container\_name: "sbos-mailserver"
    relations:
      - type: "service"
        host: "sbos-mailserver"
        imap\_port: 993
        smtp\_port: 587
  - ficha: "keycloak"
    container\_name: "sbos-keycloak"
    relations:
      - type: "keycloak\_client"
        client\_id: "roundcube"
        redirect\_uris: \["http://localhost:8080/\*"]
        roles: \["mail-user"]
healthcheck:
  command: "curl -f http://localhost/"
  interval: 30
  timeout: 10
  retries: 15
  start\_period: 60
```

\---

## 6\. Escenarios de Resolución

### `testbench.sh install roundcube` (nada corre)

```
→ dep: postgresql → NO corre → INSTALAR(postgresql) → ✅
  → RELACION: crear roundcube\_db → ✅
→ dep: redis → NO corre → INSTALAR(redis) → ✅
  → RELACION: verificar Redis DB 1 → ✅
→ dep: mailserver → NO corre → INSTALAR(mailserver)
    → dep interna: redis → SÍ → configurar rspamd → ✅
  → RELACION: verificar IMAP + SMTP → ✅
→ dep: keycloak → NO corre → INSTALAR(keycloak)
    → dep interna: postgresql → SÍ → crear keycloak\_db → ✅
  → RELACION: crear client roundcube → ✅
→ instalar roundcube → ✅

Resultado: pediste 1 ficha, se instalaron 5.
Knowledge base: 5 fichas nuevas con patrones registrados.
```

\---

## 7\. Estructura de Carpetas

```
/opt/sbos-testbench/
├── engine/
│   ├── testbench.sh              ← CLI principal
│   ├── engine.sh                 ← Resolución Kahn + recursión
│   ├── scaffolder.sh             ← Constructor de fichas
│   ├── certifier.sh              ← Pipeline de certificación
│   ├── task\_catalog\_global.sh    ← Funciones globales
│   ├── logger.sh
│   └── .env
├── fichas/
│   ├── postgresql/
│   │   ├── manifest.yml
│   │   ├── yaml\_engine.yml
│   │   ├── task\_catalog.sh
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

\---

## 8\. Estado Persistente + Knowledge Base (PostgreSQL del motor)

```sql
-- ESTADO: fichas instaladas
CREATE TABLE fichas\_state (
    ficha\_id        VARCHAR(50) PRIMARY KEY,
    container\_name  VARCHAR(100) NOT NULL,
    status          VARCHAR(20) DEFAULT 'not\_installed',
    healthcheck     VARCHAR(20),
    installed\_at    TIMESTAMPTZ,
    last\_check      TIMESTAMPTZ
);

-- ESTADO: cola de instalaciones
CREATE TABLE install\_queue (
    id              SERIAL PRIMARY KEY,
    ficha\_id        VARCHAR(50) NOT NULL,
    requested\_by    VARCHAR(50),
    priority        INT DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'pending',
    created\_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ESTADO: log de operaciones
CREATE TABLE install\_log (
    id              SERIAL PRIMARY KEY,
    ficha\_id        VARCHAR(50) NOT NULL,
    phase           VARCHAR(20) NOT NULL,
    status          VARCHAR(20) NOT NULL,
    duration\_ms     INT,
    error\_detail    TEXT,
    executed\_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ESTADO: relaciones configuradas
CREATE TABLE relations\_log (
    id              SERIAL PRIMARY KEY,
    source\_ficha    VARCHAR(50) NOT NULL,
    target\_ficha    VARCHAR(50) NOT NULL,
    relation\_type   VARCHAR(30) NOT NULL,
    relation\_detail JSONB,
    status          VARCHAR(20) DEFAULT 'ok',
    configured\_at   TIMESTAMPTZ DEFAULT NOW()
);

-- KNOWLEDGE BASE: patrones por tipo de app
CREATE TABLE kb\_app\_patterns (
    id              SERIAL PRIMARY KEY,
    app\_type        VARCHAR(30) NOT NULL,
    pattern\_key     VARCHAR(50) NOT NULL,
    pattern\_value   TEXT NOT NULL,
    confidence      FLOAT DEFAULT 1.0,
    learned\_from    VARCHAR(50),
    created\_at      TIMESTAMPTZ DEFAULT NOW()
);

-- KNOWLEDGE BASE: relaciones entre tipos de fichas
CREATE TABLE kb\_relation\_patterns (
    id              SERIAL PRIMARY KEY,
    source\_type     VARCHAR(30) NOT NULL,
    target\_ficha    VARCHAR(50) NOT NULL,
    relation\_type   VARCHAR(30) NOT NULL,
    template        JSONB NOT NULL,
    frequency       INT DEFAULT 1,
    created\_at      TIMESTAMPTZ DEFAULT NOW()
);

-- KNOWLEDGE BASE: recetas de post\_install exitosas
CREATE TABLE kb\_post\_install\_recipes (
    id              SERIAL PRIMARY KEY,
    ficha\_id        VARCHAR(50) NOT NULL,
    task\_name       VARCHAR(100) NOT NULL,
    task\_params     JSONB,
    execution\_order INT,
    success\_count   INT DEFAULT 1,
    failure\_count   INT DEFAULT 0,
    avg\_duration\_ms INT,
    created\_at      TIMESTAMPTZ DEFAULT NOW()
);

-- KNOWLEDGE BASE: imágenes validadas con metadata
CREATE TABLE kb\_validated\_images (
    id              SERIAL PRIMARY KEY,
    image\_name      VARCHAR(200) NOT NULL,
    image\_tag       VARCHAR(50) NOT NULL,
    size\_mb         INT,
    default\_port    INT,
    healthcheck\_cmd TEXT,
    start\_period\_s  INT,
    needs\_pvc       BOOLEAN DEFAULT false,
    pvc\_path        TEXT,
    validated\_at    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(image\_name, image\_tag)
);
```

\---

## 9\. Comandos del CLI

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

\---

## 10\. De Testbench a bos Real

```
TESTBENCH (Podman)                  →  BOS (K8s)
─────────────────────               ─────────────────────
testbench.sh (Bash)                 →  bos (binario Go)
podman play kube                    →  kubectl apply -f
podman exec                         →  kubectl exec -n
.env passwords                      →  Vault secrets
Podman network                      →  Calico CNI
Volúmenes Podman                    →  PVC + StorageClass
PostgreSQL del motor                →  bos\_db (mismas tablas)
Knowledge base                      →  bos\_db (mismas tablas)
certify → firma manual              →  certify → firma Ed25519 automática
scaffold → genera archivos          →  Core UI → wizard de creación de fichas

LO QUE NO CAMBIA (95%):
  manifest.yml, yaml\_engine.yml, task\_catalog.sh, resources/
  Algoritmo de Kahn, lógica de relaciones, knowledge base
  YAML de K8s en resources/k8s/ → EL MISMO ARCHIVO
```

\---

## 11\. Evolución del Testbench

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

\---

*SKULL · SBOS · SBOS-MP05 · Banco de Pruebas de Fichas · v2.0 · Marzo 2026*

