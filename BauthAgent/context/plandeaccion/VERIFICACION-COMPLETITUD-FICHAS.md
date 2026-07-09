# VERIFICACION-COMPLETITUD-FICHAS.md — Sistema de Fichas SBOS

**Fecha:** 2026-05-19  
**Propósito:** Análisis completo del sistema de fichas, taxonomía Host vs Contenedor, servidores lógicos como futuros VPS físicos, y plan de verificación para la terminación del Core SP-01 y Core UI.  
**Fuentes:** SBOS-018, SBOS-019, SBOS-020, SBOS-035, SBOS-036, SBOS-049, SBOS-005, código Go del daemon `bos`, 112 `manifest.yml`.

---

## 1. PRINCIPIO ARQUITECTÓNICO: BOS ES UNA CAPA DEL SISTEMA OPERATIVO

### 1.1 El BOS se instala directamente en el host

El BOS (IAM Installer) **no es un contenedor**. Es una capa del sistema operativo que se instala directamente sobre Ubuntu Server en el host físico/VPS:

```
                        CAPA USUARIO (apps de negocio)
    ┌────────────────────────────────────────────────────┐
    │  KUBERNETES (contenedores)                          │
    │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────────┐ │
    │  │ ERP  │ │ HR   │ │ CRM  │ │ VD   │ │ Email    │ │
    │  │tryton│ │gnu-  │ │saleor│ │next- │ │postfix   │ │
    │  │      │ │health│ │      │ │cloud │ │dovecot   │ │
    │  └──────┘ └──────┘ └──────┘ └──────┘ └──────────┘ │
    ├────────────────────────────────────────────────────┤
    │  CAPA SISTEMA (host, instalado directamente)        │
    │  ┌──────────────────────────────────────────────┐  │
    │  │  BOS daemon (bos) + bosctl                   │  │
    │  │  systemd service, sd_notify, watchdog         │  │
    │  │  K8s (kubelet, containerd, kubeadm)           │  │
    │  │  nginx (reverse proxy TLS)                   │  │
    │  │  linkerd, kyverno, hardening                  │  │
    │  └──────────────────────────────────────────────┘  │
    │  UBUNTU SERVER (host físico / VPS)                 │
    └────────────────────────────────────────────────────┘
```

La **prueba de fuego** del BOS es su funcionamiento sobre Ubuntu Server real en el host. El contenedor `sbos-greenfield` es un entorno de staging para desarrollo, no el destino de producción.

### 1.2 Consecuencia para las fichas

Toda ficha debe declarar explícitamente **dónde se instala**:

| `deployment_target` | Significado | Dónde corre |
|---|---|---|
| `host` | Se instala directamente en el sistema operativo | Ubuntu Server (systemd, binarios, configuración del host) |
| `container` | Se instala como pod dentro de Kubernetes | K8s cluster (Deployment, StatefulSet, DaemonSet) |

**Regla de oro:** La mayoría de las fichas deben ser `container`. Solo son `host` aquellas que constituyen la infraestructura del sistema operativo mismo: bootstrap, K8s, reverse proxy, service mesh, políticas de seguridad, hardening. Todo lo demás — bases de datos, identidad, aplicaciones de negocio — corre en contenedores gestionados por Kubernetes.

---

## 2. CONSTRUCCIÓN Y CERTIFICACIÓN DE UNA FICHA — EL LABORATORIO SKULL

### 2.1 Una imagen de contenedor no es una ficha

El BOS no puede hacer nada con una imagen genérica de contenedor. No sabe cómo instalarla, no conoce sus dependencias, no tiene sus health checks, no puede repararla, no sabe cómo integrarla al ecosistema. Para que una aplicación se convierta en **ficha SBOS**, debe pasar por un proceso de construcción, simulación y certificación en el laboratorio de SKULL.

```
IMAGEN DE CONTENEDOR                  FICHA SBOS CERTIFICADA
─────────────────────                  ────────────────────────
keycloak/keycloak:26.1                keycloak (ficha SBOS)
                                      ├── manifest.yml (completo, verificado)
Es solo software.                      ├── task_catalog.sh (7 funciones probadas)
El BOS no sabe qué hacer              ├── yaml_engine.yml (fases declarativas)
con esto.                              ├── resources/
                                      │   ├── keycloak/ (OIDC clients, roles)
                                      │   ├── kong/ (rutas, plugins)
                                      │   ├── vault/ (políticas de secretos)
                                      │   └── sql/ (migraciones)
                                      ├── keycloak.k8s.yml (adaptado a SBOS)
                                      └── keycloak.network (segmentación SBOS)

                                      El BOS sabe instalarla, repararla,
                                      monitorearla y desinstalarla.
                                      Está integrada al sistema operativo
                                      de negocios.
```

### 2.2 El pipeline de construcción y certificación

Toda ficha SBOS pasa por 5 etapas en el laboratorio SKULL antes de estar disponible para descarga:

```
ETAPA 1 — RECETA           ETAPA 2 — CONSTRUCCIÓN      ETAPA 3 — SIMULACIÓN
─────────────────          ─────────────────────       ─────────────────
Definir qué es la          Construir los archivos      Probar en laboratorio
aplicación y qué necesita  de la ficha                 SIN instalar en producción

┌──────────────────┐       ┌──────────────────┐       ┌──────────────────┐
│  RECETA          │       │  CONSTRUCCIÓN     │       │  SIMULACIÓN       │
│                  │       │                  │       │                  │
│ • Nombre         │       │ • manifest.yml   │       │ • Entorno aislado │
│ • Versión        │  ──▶  │ • task_catalog   │  ──▶  │ • Red efímera     │
│ • Imagen(base)   │       │ • yaml_engine    │       │ • Simula ciclo:   │
│ • Dependencias   │       │ • resources/     │       │   install→health  │
│ • Puertos        │       │ • K8s manifests  │       │   →repair→uninst  │
│ • Volúmenes      │       │ • network policy │       │ • Valida señales  │
│ • Health check   │       │                  │       │   __SBOS__        │
│ • Integraciones  │       │                  │       │ • Verifica R16    │
└──────────────────┘       └──────────────────┘       └──────────────────┘
                                                             │
                                                       ¿Pasó todas
                                                       las pruebas?
                                                       ┌────┴────┐
                                                       │ SÍ      │ NO
                                                       │         │
                                                       ▼         ▼
                                              CONTINÚA    VOLVER A
                                                         CONSTRUCCIÓN
                                                             │
ETAPA 4 — CERTIFICACIÓN     ETAPA 5 — PUBLICACIÓN              │
───────────────────────     ─────────────────────              │
Firma y sello SBOS          Disponible en catálogo             │
                             para descarga                     │
┌──────────────────┐       ┌──────────────────┐
│  CERTIFICACIÓN    │       │  PUBLICACIÓN      │
│                  │       │                  │
│ • Firma SHA-256  │       │ • Catálogo SKULL │
│ • Sello versión  │  ──▶  │ • Disponible para│
│ • Metadatos:     │       │   bosctl fetch   │
│   - fecha certif │       │ • Versión X.Y.Z  │
│   - quién certif │       │ • Changelog      │
│   - resultado    │       │                  │
│     simulación   │       │                  │
│ • Ficha declarada│       │                  │
│   APTA para SBOS │       │                  │
└──────────────────┘       └──────────────────┘
```

### 2.3 Etapa 1 — RECETA: definición de la ficha

Define **qué** es la aplicación, **qué necesita** y **cómo debe comportarse**:

```yaml
# receta.yml — entrada al pipeline de construcción
identity:
  id: keycloak
  name: Keycloak Identity Provider
  category: 1
  server: identityserver
  criticality: true

source:
  image: keycloak/keycloak:26.1
  registry: docker.io
  type: container

requirements:
  ports: [9000, 8443]
  volumes: ["/opt/keycloak/data"]
  cpu_min: "500m"
  memory_min: "512Mi"
  dependencies: [postgresql, vault]

integrations:
  auth: oidc
  gateway: kong
  secrets: vault
  database: postgresql

health:
  endpoint: /health/live
  port: 9000
  expected_status: 200
```

### 2.4 Etapa 2 — CONSTRUCCIÓN: crear los archivos de la ficha

A partir de la receta, se construyen todos los archivos:

| Archivo generado | A partir de |
|---|---|
| `manifest.yml` completo | Receta + resolución de dependencias |
| `task_catalog.sh` | Plantillas de fase por tipo (host/container) |
| `yaml_engine.yml` | Receta + plantilla de fases |
| `resources/keycloak/` | Plantillas OIDC específicas SBOS |
| `resources/kong/` | Plantillas de rutas y plugins |
| `resources/vault/` | Políticas de secretos |
| `resources/sql/` | Migraciones y seeds |
| `<app>.k8s.yml` | Plantilla Kubernetes adaptada a SBOS |
| `<app>.network` | NetworkPolicy con segmentación SBOS |

### 2.5 Etapa 3 — SIMULACIÓN: laboratorio de pruebas sin producción

El **Core API** del BOS expone un modo de simulación. No instala nada en producción. Crea un entorno aislado y ejecuta el ciclo completo:

```
bosctl simulate <ficha-id> --receta receta.yml

Entorno de simulación:
├── Red aislada (namespace temporal K8s o sandbox)
├── Dependencias mock o reales según disponibilidad
├── Ejecuta ciclo completo:
│   ├── pre_install  → validaciones pre-vuelo
│   ├── install      → despliegue en sandbox
│   ├── post_install → verificación post
│   ├── health       → health check
│   ├── repair       → simular fallo y reparar
│   └── uninstall    → limpiar sandbox
├── Verifica:
│   ├── Señales __SBOS__ correctas en cada fase
│   ├── R16: sin hardcode de paths
│   ├── Recursos OIDC/Kong/Vault cargables
│   ├── Health check responde OK
│   └── Rollback y compensación funcionan
└── Resultado: APTA / NO APTA
```

**Regla fundamental:** La simulación NUNCA instala en producción. Usa un sandbox temporal que se destruye al terminar. Si algo falla, el sandbox se limpia igual. El entorno de producción no se toca.

### 2.6 Etapa 4 — CERTIFICACIÓN: la ficha es declarada APTA

Si la simulación pasa todas las pruebas:

```json
{
  "ficha_id": "keycloak",
  "version": "1.3.0",
  "certificacion": {
    "estado": "APTA",
    "fecha": "2026-05-19T15:30:00Z",
    "certificador": "SKULL Lab",
    "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "resultado_simulacion": {
      "pre_install": "OK",
      "install": "OK",
      "post_install": "OK",
      "health": "OK",
      "repair": "OK",
      "uninstall": "OK",
      "seniales": "OK",
      "r16": "OK",
      "recursos": "OK"
    }
  }
}
```

Solo después de la certificación, el software deja de ser "una imagen de contenedor" y se convierte en **ficha SBOS**.

### 2.7 Etapa 5 — PUBLICACIÓN: disponible en el catálogo SKULL

La ficha certificada se publica en el servidor de releases. A partir de este momento:
- Aparece en el catálogo SKULL con su versión y changelog
- Los clientes BOS la ven disponible (`bosctl catalog list --available`)
- Puede descargarse con `bosctl fetch keycloak`
- El manifiesto reducido + logo + descripción se sincronizan al catálogo local

---

## 3. EL SERVIDOR DE RELEASES DE SKULL — DESCARGA DE LA CAPA DE INTEGRACIÓN

### 3.1 El BOS ya sabe qué fichas existen

Cuando el BOS se instala, **la estructura de servidores y fichas ya está presente** en el filesystem:

```
/etc/bos/blibs/servers/
├── hostserver/
│   ├── sbos-bootstrap-os/
│   │   ├── manifest.reducido.yml    ← identidad mínima
│   │   ├── logo.png                 ← logo de la aplicación
│   │   └── descripcion.md           ← breve explicación
│   ├── sbos-bootstrap-k8s/
│   │   ├── manifest.reducido.yml
│   │   ├── logo.png
│   │   └── descripcion.md
│   └── ...
├── dataserver/
│   ├── postgresql/
│   │   ├── manifest.reducido.yml
│   │   ├── logo.png
│   │   └── descripcion.md
│   ├── keycloak/   ← NOTA: keycloak está en identityserver, esto es solo ejemplo
│   └── ...
└── ...
```

Cada carpeta de ficha contiene **tres archivos locales** que le permiten al BOS conocer su existencia:

| Archivo local (siempre presente) | Contenido |
|---|---|
| `manifest.reducido.yml` | Identidad mínima: id, nombre, categoría, servidor, criticalidad, dependencias, logo_url |
| `logo.png` | Logo de la aplicación (para mostrarlo en el catálogo visual y Core UI) |
| `descripcion.md` | Breve explicación de qué hace la ficha, para qué sirve, qué resuelve |

Con esto, el BOS:
- Sabe que la ficha **existe** y está **disponible** para ser instalada
- Puede mostrarla en el catálogo (Core UI) con su logo y descripción
- Conoce sus dependencias (del manifiesto reducido) para resolver el grafo
- Pero **no puede instalarla todavía** — faltan los archivos pesados

### 3.2 Qué se descarga de SKULL y qué se instala de fuentes habituales

Una ficha SBOS tiene **tres partes** que provienen de orígenes distintos:

| Parte | Origen | Ya está local? | Qué es |
|---|---|---|---|
| **Catálogo ligero** | Viene con el BOS | ✅ Siempre | manifiesto reducido + logo + descripción |
| **Software base** | Fuente habitual (Docker Hub, apt, registry) | ❌ Se descarga al instalar | La aplicación en sí: imagen de Keycloak, binario de nginx, paquete de PostgreSQL |
| **Capa de integración SBOS** | **Servidor SKULL** (descarga) | ❌ Se descarga con `bosctl fetch` | Manifiesto completo, task_catalog, yaml_engine, resources, K8s manifests |

**Lo que se descarga de SKULL** no es el software, sino la **capa que lo convierte en ficha SBOS instalable**:

| Archivo descargado de SKULL | Función |
|---|---|
| `manifest.yml` (completo) | Identidad, dependencias, governance, health check, timeouts |
| `task_catalog.sh` | Funciones de ciclo de vida con señales `__SBOS__` |
| `yaml_engine.yml` | Fases declarativas de instalación |
| `resources/keycloak/` | OIDC clients, roles, mappers preconfigurados para RBAC del BOS |
| `resources/kong/` | Rutas y plugins Kong predefinidos |
| `resources/vault/` | Políticas de secretos específicas |
| `resources/sql/` | Migraciones y seeds de base de datos |
| `resources/config/` | Configuraciones de producción personalizadas |
| `<app>.k8s.yml` | Manifiesto Kubernetes adaptado al ecosistema SBOS |
| `<app>.network` | NetworkPolicy adaptada a la segmentación SBOS |

**Ejemplo concreto — Keycloak:**
1. El BOS ya tiene `servers/identityserver/keycloak/` con `manifest.reducido.yml` + `logo.png` + `descripcion.md` — **sabe que Keycloak existe**
2. La **imagen** `keycloak/keycloak:26.1` se descarga de Docker Hub (al momento de instalar)
3. La **capa de integración** se descarga de SKULL: `manifest.yml` completo, `task_catalog.sh`, `resources/keycloak/` (con clients OIDC, roles sbos-viewer/sbos-operator/sbos-admin, mappers), `yaml_engine.yml`
4. El BOS ejecuta la ficha: despliega la imagen en K8s **aplicándole** todas las configuraciones descargadas
5. Resultado: Keycloak corriendo **ya integrado** al sistema operativo de negocios, con RBAC, rutas Kong, y health check funcionando

Cada capa de integración en el servidor de SKULL ya fue:
- Configurada con todos sus recursos y dependencias
- Probada (ciclo instalar→health→reparar→desinstalar verificado)
- Versionada y hasheada (SHA-256 de todos sus archivos)

### 3.3 El estado HABILITAR — la capa de integración no se ha descargado aún

Una ficha en estado **HABILITAR** ya es visible en el catálogo del BOS (tiene su carpeta, manifiesto reducido, logo, descripción), pero **no se puede instalar** porque los archivos pesados (task_catalog.sh, yaml_engine.yml, resources/) no se han descargado todavía desde SKULL.

```
ANTES DE HABILITAR (local)              DESPUÉS DE HABILITAR (local)
────────────────────────                ──────────────────────────
servers/identityserver/keycloak/        servers/identityserver/keycloak/
├── manifest.reducido.yml  ✅           ├── manifest.reducido.yml  ✅
├── logo.png               ✅           ├── logo.png               ✅
├── descripcion.md         ✅           ├── descripcion.md         ✅
│                                       ├── manifest.yml           🆕 descargado
│                                       ├── task_catalog.sh        🆕 descargado
│                                       ├── yaml_engine.yml        🆕 descargado
│                                       ├── keycloak.k8s.yml       🆕 descargado
│                                       ├── keycloak.network       🆕 descargado
│                                       └── resources/             🆕 descargado
│                                           ├── keycloak/
│                                           ├── kong/
│                                           ├── vault/
│                                           └── sql/

Estado: HABILITAR                        Estado: NO_INSTALADA
"Conozco la ficha, sé qué hace,          "Ficha completa. Lista para
 pero no puedo instalarla aún"            instalar cuando sus deps
                                          estén satisfechas"
```

```
SERVIDOR SKULL (releases)                   HOST CLIENTE (BOS)
─────────────────────────                   ─────────────────────
┌──────────────────────────┐                ┌──────────────────────────┐
│  Capa de integración      │                │  Estructura local         │
│  (task_catalog + yaml     │                │  (manifiesto reducido     │
│   + resources + K8s)      │                │   + logo + descripción)   │
│                           │                │                           │
│  ┌──────────────────────┐ │                │  ┌──────────────────────┐ │
│  │ keycloak/            │ │                │  │ keycloak/            │ │
│  │ ├── manifest.yml     │ │── bosctl fetch─▶│  │ ├── manifest.reducido│ │
│  │ ├── task_catalog.sh  │ │  + SHA-256      │  │ ├── logo.png         │ │
│  │ ├── yaml_engine.yml  │ │                 │  │ ├── descripcion.md   │ │
│  │ ├── keycloak.k8s.yml │ │                 │  │ ├── manifest.yml  🆕 │ │
│  │ └── resources/       │ │                 │  │ ├── task_catalog.🆕 │ │
│  └──────────────────────┘ │                │  │ └── resources/    🆕 │ │
│                           │                │  └──────────────────────┘ │
│  ┌──────────────────────┐ │                │                           │
│  │ postgresql/          │ │                │  ┌──────────────────────┐ │
│  │ ...                  │ │                │  │ postgresql/          │ │
│  └──────────────────────┘ │                │  │ (igual: reducido      │ │
└──────────────────────────┘                │  │  + logo + desc)       │ │
                                            │  └──────────────────────┘ │
                                            └──────────────────────────┘
```

### 3.4 Fases del proceso HABILITAR

```
HABILITAR
  ├── 1. FETCH        → Descargar capa de integración desde SKULL (HTTPS)
  ├── 2. VERIFY       → Verificar SHA-256 de cada archivo descargado
  ├── 3. UNPACK       → Escribir archivos en la carpeta de la ficha (junto al reducido + logo + desc)
  ├── 4. REGISTER     → Plugin Loader detecta el nuevo task_catalog.sh, completa el registro
  └── 5. TRANSITION   → Si deps satisfechas → NO_INSTALADA
                         Si deps insatisfechas → BLOQUEADA
                         Si error en descarga → HABILITAR (reintentar)
```

### 2.5 El catálogo SKULL

### 3.5 El manifiesto reducido local vs el manifiesto completo descargado

| Campo | manifiesto reducido (local, siempre) | manifiesto completo (descargado de SKULL) |
|---|---|---|
| identity.id | ✅ | ✅ |
| identity.name | ✅ | ✅ |
| identity.version | ✅ (mínima) | ✅ (completa, con changelog) |
| identity.category | ✅ | ✅ |
| identity.server | ✅ | ✅ |
| identity.description | ✅ (breve) | ✅ (completa) |
| identity.logo_url | ✅ | ✅ |
| requirements.dependencies | ✅ | ✅ |
| order.execution_order | ✅ | ✅ |
| governance.auto_install | ✅ | ✅ |
| workload.type | ✅ | ✅ |
| deployment.target | ✅ | ✅ |
| health.check_command | ❌ | ✅ |
| health.check_interval | ❌ | ✅ |
| health.threshold | ❌ | ✅ |
| requirements.cpu/memory | ❌ | ✅ |
| deployment.strategy | ❌ | ✅ |
| order.timeout_minutes | ❌ | ✅ |

El BOS construye el **catálogo visual** (Core UI) con los datos del manifiesto reducido. El manifiesto completo llega con la descarga y agrega la información operacional (health checks, recursos, timeouts).

### 3.6 El catálogo SKULL

El BOS sincroniza periódicamente con el servidor SKULL para detectar nuevas versiones de la capa de integración:

```json
{
  "catalog_version": "2026-05-19",
  "server": "releases.sbos.internal",
  "fichas": {
    "keycloak": {
      "installed_version": "1.2.0",
      "available_version": "1.3.0",
      "sha256": "def456...",
      "size_bytes": 2457600,
      "estado": "ACTUALIZACION_DISPONIBLE"
    },
    "postgresql": {
      "installed_version": null,
      "available_version": "1.1.0",
      "sha256": "abc123...",
      "size_bytes": 3200000,
      "estado": "HABILITAR"
    }
  }
}
```

El comando `bosctl fetch <ficha>` descarga la capa de integración de una ficha específica. `bosctl fetch --product bootstrap` descarga todas las fichas del producto bootstrap.

---

## 4. SERVIDORES LÓGICOS = FUTUROS VPS FÍSICOS

### 2.1 Modelo de crecimiento horizontal

Cada **servidor lógico** (carpeta bajo `servers/`) está diseñado para convertirse en un **VPS físico independiente** cuando la carga o los recursos lo requieran:

```
HOY (un solo VPS):                     MAÑANA (crecimiento horizontal):
┌──────────────────────────┐           ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  VPS único                │           │  VPS host    │  │  VPS data    │  │  VPS comms   │
│  hostserver/              │           │  hostserver/ │  │  dataserver/ │  │ commsserver/ │
│  dataserver/              │  ──►      │              │  │  postgresql  │  │  postfix     │
│  commsserver/             │           │  nginx ──────┼──│  redis       │  │  dovecot     │
│  identityserver/          │           │  kong ───────┼──│  minio       │  │  rocketchat  │
│  ...                      │           │              │  │              │  │              │
└──────────────────────────┘           └─────────────┘  └─────────────┘  └─────────────┘
                                              │                │                │
                                        ┌─────────────┐  ┌─────────────┐
                                        │  VPS identity│  │  VPS erp     │
                                        │identityserver│  │  erpserver/  │
                                        │  keycloak    │  │  tryton      │
                                        └─────────────┘  └─────────────┘
```

### 4.2 Reglas de crecimiento

1. El **nombre del servidor lógico** (carpeta `servers/<nombre>/`) es el **mismo nombre** que tendrá el VPS físico cuando migre.
2. Cuando un servidor lógico migra a su propio VPS, **todas las fichas de ese servidor migran con él**.
3. El BOS en el hostserver principal orquesta a los BOS agentes en cada VPS satélite.
4. Cada VPS satélite tiene su propio BOS daemon instalado en el host (capa OS).
5. La comunicación entre VPS es a través de la red, con nginx/kong como gateway central en el hostserver.

### 4.3 Los 16 servidores lógicos

| # | Servidor lógico | Namespace K8s | Cuándo migra a VPS propio |
|---|---|---|---|
| S-HOST | hostserver | sbos-installer | **Nunca** — es el VPS raíz, siempre presente |
| S01 | dataserver | sbos-data | Cuando PostgreSQL/Redis/MinIO necesitan recursos dedicados |
| S02 | gatewayserver | sbos-gateway | Cuando el tráfico externo satura el host principal |
| S03 | identityserver | sbos-identity | Cuando Keycloak/Wazuh compiten por CPU con otras cargas |
| S04 | erpserver | sbos-erp | Cuando el ERP consume recursos significativos |
| S05 | devserver | sbos-apps | Bajo demanda — aplicaciones de desarrollo |
| S06 | appsserver | sbos-apps | Bajo demanda — aplicaciones de negocio general |
| S07 | reportserver | sbos-apps | Cuando Superset/Airflow generan carga de BI |
| S08 | docserver | sbos-docs | Cuando Paperless/Solr procesan muchos documentos |
| S09 | searchserver | sbos-search | Cuando Elasticsearch requiere RAM dedicada |
| S10 | commsserver | sbos-comms | Cuando el correo consume recursos de red/CPU |
| S11 | vdiserver | sbos-vdi | Cuando los escritorios virtuales necesitan GPU/recursos |
| S12 | monitorserver | sbos-monitor | Bajo demanda — monitoreo y observabilidad |
| S13 | geoserver | sbos-geo | Bajo demanda — tracking geoespacial |
| S14 | opsserver | sbos-ops | Bajo demanda — GitLab, backups, CI/CD |
| S15 | aiserver | sbos-ai | Cuando Ollama/Qdrant requieren GPU o RAM dedicada |

---

## 5. TAXONOMÍA FUNDAMENTAL: FICHAS HOST vs FICHAS CONTENEDOR

### 5.1 Definición

Toda ficha se clasifica por su **destino de despliegue**, que determina cómo el BOS la instala y gestiona:

| `deployment_target` | Instalada por | Ejecutada como | Health check | Ejemplos |
|---|---|---|---|---|
| `host` | Script Bash ejecutado directamente en el host | systemd service, binario, daemon | Comando shell en el host | bos.service, kubelet, nginx |
| `container` | `kubectl apply` de manifiestos YAML | Pod en K8s (Deployment/StatefulSet/DaemonSet) | HTTP check o comando dentro del pod | postgresql, keycloak, grafana |

### 5.2 Clasificación completa de las 112 fichas

#### FICHAS HOST — Se instalan directamente en Ubuntu Server

| # | Ficha ID | Servidor | Orden | Función en el host |
|---|---|---|---|---|
| H01 | sbos-bootstrap-os | hostserver | 1 | Prepara el SO: dependencias apt, python3, binarios base |
| H02 | sbos-bootstrap-k8s | hostserver | 5 | Instala kubeadm, kubelet, containerd en el host |
| H03 | sbos-bootstrap-platform | hostserver | 10 | Crea namespaces K8s, RBAC, configuraciones iniciales |
| H04 | sbos-lifecycle | hostserver | 15 | Instala bos.service como daemon systemd en el host |
| H05 | network-validator | hostserver | 15 | Valida conectividad de red del host y DNS interno |
| H06 | local-path-provisioner | hostserver | 25 | StorageClass local para volúmenes K8s en el host |
| H07 | nginx | gatewayserver | 50 | Reverse proxy TLS — instalado en el host, no en contenedor. Puerta de entrada de TODO el tráfico externo |
| H08 | linkerd | hostserver | 150 | Service mesh — DaemonSet que inyecta sidecars en todos los pods |
| H09 | kyverno | hostserver | 155 | Policy engine — políticas de admisión y seguridad en el cluster |
| H10 | sbos-bootstrap-hardening | hostserver | 300 | Hardening CIS Benchmark del host (kube-bench, AppArmor, auditd) |
| H11 | k8s-upgrader | hostserver | 310 | Actualización de versión de K8s en el host |
| H12 | cert-rotation | hostserver | 320 | Rotación de certificados TLS del host y del cluster |
| H13 | compliance-check | hostserver | 330 | Verificación de cumplimiento CIS en el host |

**Total fichas host: 13**

#### FICHAS CONTENEDOR — Se instalan como pods en Kubernetes

##### S01 — dataserver (13 fichas, `sbos-data`)

| # | Ficha ID | Orden | Tipo K8s | Dependencias |
|---|---|---|---|---|
| C01 | postgresql | 100 | StatefulSet (Patroni HA) | network-validator |
| C02 | pgbouncer | 105 | Deployment | postgresql |
| C03 | pgbackrest | 108 | Deployment | postgresql |
| C04 | redis | 110 | Deployment | network-validator |
| C05 | timescaledb | 112 | StatefulSet | postgresql |
| C06 | minio | 115 | StatefulSet | network-validator |
| C07 | citus | 118 | StatefulSet | postgresql |
| C08 | mysql | 120 | StatefulSet | (ninguna) |
| C09 | vault | 120 | StatefulSet | postgresql |
| C10 | symmetricds | 125 | Deployment | postgresql, mysql |
| C11 | pgadmin4 | 130 | Deployment | postgresql, oauth2-proxy |
| C12 | pg-partman | — | Deployment | postgresql |
| C13 | pg-stat-monitor | — | Deployment | postgresql |

##### S02 — gatewayserver (3 fichas contenedor en `sbos-gateway`)

| # | Ficha ID | Orden | Tipo K8s | Dependencias |
|---|---|---|---|---|
| C14 | kong | 145 | Deployment | postgresql, keycloak |
| C15 | certbot | — | Deployment | nginx |
| C16 | modsecurity | — | Deployment | nginx |

> **Nota:** nginx (H07) está clasificado como HOST. Es el reverse proxy TLS instalado directamente en el host. Kong (C14) es el API Gateway interno que corre en contenedor.

##### S03 — identityserver (5 fichas, `sbos-identity`)

| # | Ficha ID | Orden | Tipo K8s | Dependencias |
|---|---|---|---|---|
| C17 | keycloak | 130 | StatefulSet | postgresql, vault |
| C18 | oauth2-proxy | 135 | Deployment | keycloak |
| C19 | wazuh-manager | 160 | StatefulSet | elasticsearch |
| C20 | wazuh-indexer | — | StatefulSet | — |
| C21 | openvas | — | Deployment | postgresql |

##### S04 — erpserver (2 fichas, `sbos-erp`)

| # | Ficha ID | Orden | Tipo K8s | Dependencias |
|---|---|---|---|---|
| C22 | tryton | 170 | StatefulSet | postgresql, keycloak |
| C23 | rabbitmq-erp | — | StatefulSet | — |

##### S05 — devserver (7 fichas, `sbos-apps`)

| # | Ficha ID | Orden | Dependencias |
|---|---|---|---|
| C24 | smartpay | — | postgresql |
| C25 | smartorc | — | postgresql |
| C26 | smartreport | — | postgresql |
| C27 | smarttax | 180 | postgresql |
| C28 | smartrates | — | postgresql |
| C29 | smartvaultflow | — | postgresql, vault |
| C30 | smartportfolio | — | postgresql |

##### S06 — appsserver (16 fichas, `sbos-apps`)

| # | Ficha ID | Orden | Dependencias |
|---|---|---|---|
| C31 | gnuhealth | 200 | postgresql, keycloak |
| C32 | saleor | 205 | postgresql, redis, keycloak |
| C33 | directus | 210 | postgresql, keycloak |
| C34 | tastyigniter | — | postgresql |
| C35 | easyappointments | — | postgresql |
| C36 | orangehrm | — | postgresql |
| C37 | wikijs | — | postgresql |
| C38 | trilium | — | (ninguna, SQLite interno) |
| C39 | espocrm | — | postgresql |
| C40 | taiga | — | postgresql |
| C41 | openproject | — | postgresql |
| C42 | calcom | — | postgresql |
| C43 | zammad | — | postgresql |
| C44 | limesurvey | — | postgresql |
| C45 | authelia | — | postgresql |
| C46 | vaultwarden | — | (ninguna, SQLite interno) |

##### S07 — reportserver (6 fichas, `sbos-apps`)

| # | Ficha ID | Orden | Dependencias |
|---|---|---|---|
| C47 | jaspersoft | — | postgresql |
| C48 | jasperstarter | — | postgresql |
| C49 | pdfjs | — | (ninguna) |
| C50 | superset | 286 | postgresql, keycloak |
| C51 | airflow | 288 | postgresql, redis, keycloak |
| C52 | openmetadata | — | postgresql |

##### S08 — docserver (8 fichas, `sbos-docs`)

| # | Ficha ID | Orden | Dependencias |
|---|---|---|---|
| C53 | paperless-ngx | 295 | postgresql, redis, minio, keycloak |
| C54 | tesseract | — | (ninguna) |
| C55 | tabula | — | (ninguna) |
| C56 | camelot | — | (ninguna) |
| C57 | kimios | — | postgresql |
| C58 | solr | — | (ninguna) |
| C59 | docuseal | — | postgresql |

##### S09 — searchserver (2 fichas, `sbos-search`)

| # | Ficha ID | Orden | Dependencias |
|---|---|---|---|
| C60 | elasticsearch | 315 | (ninguna) |
| C61 | rabbitmq-search | — | — |

##### S10 — commsserver (12 fichas, `sbos-comms`)

| # | Ficha ID | Orden | Dependencias |
|---|---|---|---|
| C62 | postfix | 320 | (ninguna) |
| C63 | dovecot | 322 | postfix |
| C64 | roundcube | — | postfix, dovecot |
| C65 | cypht | — | — |
| C66 | postfixadmin | — | postfix, postgresql |
| C67 | spamassassin | — | postfix |
| C68 | clamav | — | postfix |
| C69 | freepbx | — | postgresql |
| C70 | rocketchat | 340 | mongodb, keycloak |
| C71 | mattermost | 345 | postgresql, keycloak |
| C72 | centrifugo | 350 | redis, keycloak |

##### S11 — vdiserver (3 fichas, `sbos-vdi`)

| # | Ficha ID | Orden | Dependencias |
|---|---|---|---|
| C73 | nextcloud | 358 | postgresql, redis, keycloak |
| C74 | fedora-kde | — | — |
| C75 | onlyoffice | — | postgresql |

##### S12 — monitorserver (4 fichas, `sbos-monitor`)

| # | Ficha ID | Orden | Dependencias |
|---|---|---|---|
| C76 | prometheus | 200 | network-validator |
| C77 | grafana | 210 | postgresql, prometheus |
| C78 | alertmanager | — | prometheus |
| C79 | alloy | — | prometheus |

##### S13 — geoserver (5 fichas, `sbos-geo`)

| # | Ficha ID | Orden | Dependencias |
|---|---|---|---|
| C80 | traccar | 365 | postgresql, keycloak |
| C81 | fleetbase | — | postgresql |
| C82 | xibo | — | postgresql |
| C83 | novosga | — | postgresql |
| C84 | cardmesh | — | — |

##### S14 — opsserver (8 fichas, `sbos-ops`)

| # | Ficha ID | Orden | Dependencias |
|---|---|---|---|
| C85 | gitlab | 380 | postgresql, redis, keycloak, minio |
| C86 | k6 | — | — |
| C87 | trivy | — | — |
| C88 | bareos | — | postgresql |
| C89 | velero | — | minio |
| C90 | goss | — | — |
| C91 | pgbackrest-svc | — | postgresql |
| C92 | searxng | — | — |

##### S15 — aiserver (7 fichas, `sbos-ai`)

| # | Ficha ID | Orden | Dependencias |
|---|---|---|---|
| C93 | ollama | 410 | (ninguna, usa GPU del host) |
| C94 | open-webui | — | ollama |
| C95 | qdrant | 418 | (ninguna) |
| C96 | embedding-worker | — | ollama |
| C97 | langfuse | — | postgresql |
| C98 | flowise | — | postgresql |
| C99 | bcompass-svc | 430 | postgresql, qdrant |

**Total fichas contenedor: 99**

### 5.3 Verificación de la clasificación

| Métrica | Valor |
|---|---|
| Fichas host | 13 |
| Fichas contenedor | 99 |
| Total general | 112 |
| % en contenedor | 88.4% |
| % en host | 11.6% |

**Check de coherencia:** Solo las fichas en hostserver y gatewayserver (nginx) son host. Todas las fichas en servidores S01-S15 son contenedor. Esto es correcto: los servidores lógicos de aplicación (dataserver, erpserver, commsserver, etc.) están diseñados para correr en K8s y migrar a VPS propios.

---

## 6. CICLO DE VIDA DE UNA FICHA

### 6.1 Seis estados canónicos

| # | Estado | Condición | Acciones posibles |
|---|---|---|---|
| 0 | `HABILITAR` | Ficha visible en catálogo local (manifiesto reducido + logo + descripción) pero capa de integración NO descargada aún | `bosctl fetch <ficha>`, descargar + verificar SHA-256 |
| 1 | `BLOQUEADA` | Ficha descargada pero dependencias no satisfechas | Ver requisitos, instalar cadena de dependencias |
| 2 | `NO_INSTALADA` | Ficha descargada + dependencias satisfechas | Instalar |
| 3 | `INSTALADA -- OK` | Service/Deployment running + health OK | Verificar, Reparar, Actualizar, Desinstalar |
| 4 | `INSTALADA -- ALERTA` | Health check fallando | Reparar, Ver logs, Diagnóstico |
| 5 | `ACTUALIZACION_DISPONIBLE` | Drift en archivos o nueva versión en servidor SKULL | `bosctl fetch --update`, Actualizar, Omitir |

**HABILITAR es el estado cero.** La ficha ya tiene carpeta local con `manifest.reducido.yml` + `logo.png` + `descripcion.md`. El BOS la conoce y la muestra en el catálogo. Pero **no se puede instalar** porque la capa de integración (`task_catalog.sh`, `yaml_engine.yml`, `manifest.yml` completo, `resources/`) no se ha descargado de SKULL. Solo después de `bosctl fetch` y la verificación SHA-256, la ficha está completa y puede transicionar a BLOQUEADA o NO_INSTALADA.

**Diferencia por deployment_target:**
- Ficha `host`: "running" = systemd service active o binario en ejecución. Health check es un comando shell en el host.
- Ficha `container`: "running" = pod en estado Ready. Health check es HTTP o kubectl exec.

### 6.2 Estados transicionales internos

`INSTALANDO`, `ACTUALIZANDO`, `REPARANDO`, `DESINSTALANDO`, `ERROR`, `DESCARGANDO`

### 6.3 Transiciones válidas

```
HABILITAR → DESCARGANDO           (bosctl fetch <ficha>)
DESCARGANDO → BLOQUEADA           (descarga OK, dependencias insatisfechas)
DESCARGANDO → NO_INSTALADA        (descarga OK, dependencias satisfechas)
DESCARGANDO → HABILITAR           (descarga fallida, reintentar)
BLOQUEADA → NO_INSTALADA
NO_INSTALADA → INSTALANDO
INSTALANDO → INSTALADA_OK | INSTALADA_ALERTA | NO_INSTALADA
INSTALADA_OK → INSTALADA_ALERTA | ACTUALIZACION_DISPONIBLE | ACTUALIZANDO | DESINSTALANDO
INSTALADA_ALERTA → REPARANDO | INSTALADA_OK
ACTUALIZACION_DISPONIBLE → ACTUALIZANDO
ACTUALIZANDO → INSTALADA_OK | INSTALADA_ALERTA | ERROR
REPARANDO → INSTALADA_OK | INSTALADA_ALERTA | ERROR
DESINSTALANDO → NO_INSTALADA | ERROR
ERROR → REPARANDO | NO_INSTALADA
```

### 6.4 Particularidades de HABILITAR

- Una ficha en HABILITAR **ya tiene carpeta en el filesystem** con tres archivos: `manifest.reducido.yml`, `logo.png`, `descripcion.md`. El BOS la conoce, la muestra en el catálogo, y sabe sus dependencias.
- Lo que **falta** son los archivos pesados: `task_catalog.sh`, `yaml_engine.yml`, `manifest.yml` completo, `resources/`, y los manifiestos K8s. Sin ellos, la ficha no se puede instalar.
- El estado HABILITAR **no requiere dependencias satisfechas** — eso se evalúa después de la descarga, cuando el manifiesto completo está disponible.
- Si la descarga falla (red, SHA-256 mismatch, servidor no disponible), la ficha vuelve a HABILITAR para reintento. Los archivos del intento fallido se eliminan.
- Si la descarga es exitosa, el Plugin Loader detecta el nuevo `task_catalog.sh`, carga el manifiesto completo, y transiciona a BLOQUEADA o NO_INSTALADA.
- El catálogo SKULL se sincroniza periódicamente para detectar nuevas versiones disponibles de la capa de integración.

### 6.5 Seis fases del ciclo de vida (task_catalog.sh)

| Función | Fase | En host | En contenedor |
|---|---|---|---|
| `ficha_pre_install()` | Validaciones pre-vuelo | Verificar systemd, dependencias apt | Verificar K8s API, namespace, RBAC |
| `ficha_install()` | Despliegue | `cp` + `systemctl enable` + `systemctl start` | `kubectl apply` de manifiestos |
| `ficha_post_install()` | Verificación post | `systemctl is-active`, verificar archivos | `kubectl wait --for=condition=Ready` |
| `ficha_repair()` | Reparación | `systemctl restart`, reinstalar binario | `kubectl rollout restart`, `kubectl delete pod` |
| `ficha_uninstall()` | Desinstalación | `systemctl disable --now`, `rm` | `kubectl delete` de recursos |
| `ficha_health()` | Health check | Comando shell directo | HTTP request o `kubectl exec` comando |
| `ficha_diagnosis()` | Diagnóstico | `systemctl status`, `journalctl` | `kubectl describe pod`, `kubectl logs` |

### 4.3 Transiciones válidas

```
BLOQUEADA → NO_INSTALADA
NO_INSTALADA → INSTALANDO
INSTALANDO → INSTALADA_OK | INSTALADA_ALERTA | NO_INSTALADA
INSTALADA_OK → INSTALADA_ALERTA | ACTUALIZACION_DISPONIBLE | ACTUALIZANDO | DESINSTALANDO
INSTALADA_ALERTA → REPARANDO | INSTALADA_OK
ACTUALIZACION_DISPONIBLE → ACTUALIZANDO
ACTUALIZANDO → INSTALADA_OK | INSTALADA_ALERTA | ERROR
REPARANDO → INSTALADA_OK | INSTALADA_ALERTA | ERROR
DESINSTALANDO → NO_INSTALADA | ERROR
ERROR → REPARANDO | NO_INSTALADA
```

---

## 7. ORDEN DE BOOTSTRAP (CON DISTINCIÓN HOST/CONTENEDOR)

```
orden  ficha                       target     depends_on                  criticalidad
─────  ──────────────────────────  ────────   ──────────────────────────  ───────────
 01    sbos-bootstrap-os           HOST       (nada)                      FUNDACIONAL
 05    sbos-bootstrap-k8s          HOST       01                          FUNDACIONAL
 10    sbos-bootstrap-platform     HOST       05                          FUNDACIONAL
 15    sbos-lifecycle              HOST       01                          FUNDACIONAL
 15    network-validator           HOST       10                          FUNDACIONAL
 25    local-path-provisioner      HOST       10                          FUNDACIONAL
─── PUERTA DE ENTRADA A CONTENEDORES ─────────────────────────────────────────────
 50    nginx                       HOST       15 (net-val)                CRÍTICO ★
─── PRIMERAS FICHAS EN CONTENEDOR ─────────────────────────────────────────────────
100    postgresql                  CONTAINER  15 (net-val)                CRÍTICO
105    pgbouncer                   CONTAINER  100                         ALTO
108    pgbackrest                  CONTAINER  100                         ALTO
110    redis                       CONTAINER  15                          ALTO
115    minio                       CONTAINER  15                          ALTO
120    vault                       CONTAINER  100                         CRÍTICO
120    mysql                       CONTAINER  (nada)                      MEDIO
130    keycloak                    CONTAINER  100 + 120                   CRÍTICO
135    oauth2-proxy                CONTAINER  130                         ALTO
145    kong                        CONTAINER  100 + 130                   ALTO
150    linkerd                     HOST       15                          CRÍTICO
155    kyverno                     HOST       15                          ALTO
200    prometheus                  CONTAINER  15                          ALTO
210    grafana                     CONTAINER  100 + 200                   MEDIO
300    sbos-bootstrap-hardening    HOST       130 + 145 + 200 + 150       CRÍTICO
─── RESTO DE FICHAS (99 contenedor + 0 host) ──────────────────────────────────────
```

> ★ **nginx** es la puerta de entrada: primera ficha que expone tráfico externo. Está en el host, no en contenedor, porque es el reverse proxy TLS que recibe TODO el tráfico antes de enrutarlo a Kong o a los pods.

---

## 8. PROTOCOLO DE SEÑALES `__SBOS__`

Parseadas por `installer/saga.go:parseOutput()`. El `StepObserver` emite en tiempo real a Core UI vía WebSocket.

### Señales de progreso
```
__SBOS__STEP_START__    <descripción>
__SBOS__STEP_OK__       <descripción>
__SBOS__STEP_FAIL__     <descripción>
__SBOS__STEP_SKIP__     <razón>
__SBOS__STEP_PROGRESS__ <N>/<TOTAL> <descripción>
```

### Señales de finalización
```
__SBOS__DONE__OK__
__SBOS__DONE__ERROR__
__SBOS__DONE__ERROR__COMPENSABLE__
__SBOS__DONE__ERROR__FATAL__
```

### Señales de compensación
```
__SBOS__ROLLBACK_START__
__SBOS__CLEANUP_DONE__
```

---

## 9. RELACIÓN FICHA ↔ BOS (ARQUITECTURA DEL DAEMON)

### 9.1 Seis loops internos

| Loop | Tick | Función |
|---|---|---|
| OBSERVER_LOOP | 5s | Desbloquear, auto-instalar (solo auto_install), auto-reparar |
| HEALTH_CHECKER | 30s | Clasificar fichas en 5 estados canónicos |
| RECONCILE_SCHEDULER | 300s | Detectar drift vía SHA-256 |
| PLUGIN_LOADER | Continuo | Descubrir fichas nuevas en `servers/` |
| API REST + WebSocket | — | Responder a bosctl y Core UI |
| GROWTH_DETECTOR | — | Decidir cuándo un servidor lógico debe migrar a VPS propio |

### 9.2 Flujo completo: desde carpeta nueva hasta INSTALADA_OK

```
1. Operador crea carpeta servers/<servidor>/<nueva-ficha>/
2. PLUGIN_LOADER detecta task_catalog.sh → registra ficha
3. Lee manifest.yml → extrae deployment_target (host|container)
4. STATE_MANAGER crea estado inicial: NO_INSTALADA o BLOQUEADA
5. OBSERVER_LOOP (5s) evalúa:
   - Si auto_install=true + deps OK → INSTALANDO
   - Si auto_install=false → espera bosctl install o Core UI
6. ORCHESTRATOR ejecuta saga según deployment_target:
   - HOST: ejecuta task_catalog.sh directamente en el host
   - CONTAINER: ejecuta task_catalog.sh que a su vez llama kubectl apply
7. STATE_MANAGER registra INSTALADA_OK + hashes SHA-256
8. HEALTH_CHECKER monitorea cada 30s
9. RECONCILE_SCHEDULER detecta drift cada 300s
```

### 9.3 Diferencia crítica: instalación host vs contenedor

```
FICHA HOST:
  bos → exec task_catalog.sh → systemctl enable/start → binary runs on host
  Health check: systemctl is-active, test -f, grep en archivo de config

FICHA CONTAINER:
  bos → exec task_catalog.sh → kubectl apply -f <app>.k8s.yml → pod runs in K8s
  Health check: curl http://localhost:port/health, kubectl exec <pod> -- <comando>
```

---

## 10. PRODUCTOS (NIVEL 2)

| Producto | Categoría | Fichas | Tiempo est. | auto_install |
|---|---|---|---|---|
| bootstrap | platform | 16 (13 host + 3 contenedor) | ~48 min | **true** (único) |
| mail | communication | 4 | ~12 min | false |
| erp | business | 2 | ~8 min | false |
| documents | business | 5 | ~10 min | false |
| monitoring | operations | 4 | ~8 min | false |
| vdi | platform | 4 | ~15 min | false |
| ai | intelligence | 6 | ~12 min | false |
| devops | operations | 3 | ~15 min | false |

El comando `bosctl product install <producto>` no está implementado en el código Go actual (PGE-2.2 pendiente).

---

## 11. CORE SP-01 — ESTADO DE COMPLETITUD

### 11.1 Módulos implementados en Go

| Módulo | Archivo | Estado |
|---|---|---|
| STATE_MANAGER | `state/manager.go` | ⚠️ Tiene 5 estados canónicos — falta agregar HABILITAR como estado 0 |
| DEPENDENCY_RESOLVER | `main.go:topologicalSort()` | ✅ Completo (Kahn, detección ciclos, execution_order) |
| HEALTH_CHECKER | `health/checker.go` | ✅ Completo (clasificación HEALTHY/DEGRADED/DOWN) |
| ORCHESTRATOR | `installer/saga.go` | ✅ Completo (install/update/repair/remove, parseo señales) |
| COMPENSATOR | `installer/compensator.go` | ✅ Completo (rollback chains, best-effort) |
| PLUGIN_LOADER | `plugin/loader.go` | ✅ Completo (descubrimiento, parseo manifest, SHA-256) |
| RECONCILE_SCHEDULER | `reconcile/scheduler.go` | ✅ Completo (drift detection 300s) |
| BOSCTL CLI | `cmd/bosctl/main.go` | ✅ Completo (daemon control + OS-layer commands) |
| API REST | `internal/server/api.go` | ✅ Completo (/status, /health, /fichas/.../install, /shutdown) |
| WebSocket | `internal/server/ws.go` | ✅ Completo (streaming progreso en tiempo real) |
| Watchdog | `main.go:startWatchdog()` | ✅ Completo (sd_notify WATCHDOG=1 cada 15s) |
| Startup Reconcile | `main.go:runNormal()` | ✅ Completo (jitter 0-30s, reparación bootstrap) |
| Shutdown Saga | `main.go:shutdown()` | ✅ Completo (drain kubelet → stop kubelet → stop containerd) |

### 11.2 Gaps del Core SP-01

| Gap | Prioridad | Impacto |
|---|---|---|
| Repair saga k8s debe reiniciar containerd antes que kubelet | **CRÍTICA** | Tras restart del BOS, kubelet queda sin socket de containerd |
| Modo simulación no implementado — `bosctl simulate <ficha>` | **CRÍTICA** | Sin simulación no hay forma de certificar una ficha sin instalarla en producción |
| Pipeline de construcción (RECETA→CONSTRUIR→SIMULAR) no existe | **CRÍTICA** | Las fichas se crean manualmente sin un proceso estandarizado ni certificación |
| Estado HABILITAR no implementado en `state/manager.go` | **CRÍTICA** | El daemon no tiene el estado 0 — asume que las fichas ya existen localmente |
| `bosctl fetch <ficha>` no existe como comando | **CRÍTICA** | Sin fetch no hay mecanismo para descargar la capa de integración desde SKULL |
| Catálogo SKULL no implementado (sincronización, versionado) | **ALTA** | El BOS no sabe qué fichas están disponibles en el servidor de releases |
| `deployment_target` no está implementado como campo en manifest.yml | **ALTA** | El daemon no distingue host vs container — debe agregarse al parser de manifest |
| `bosctl product install` no implementado | MEDIA | Azúcar sobre `bosctl install`, no bloquea funcionalidad |
| 4 scripts Bash maestros no verificados en staging | BAJA | El daemon Go implementa toda la lógica, los scripts Bash son respaldo |

### 11.3 Acción inmediata #1: fix repair saga k8s

En `staging/core/servers/hostserver/sbos-bootstrap-k8s/task_catalog.sh`:

```bash
# CORRECTO: containerd primero, luego kubelet
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    systemctl restart containerd
    sleep 5
    systemctl restart kubelet
    echo "${__SBOS__STEP_OK__} repair"
}
```

### 11.4 Acción inmediata #2: agregar deployment_target al manifest.yml

Campo nuevo requerido en todo `manifest.yml`:

```yaml
deployment:
  target: host          # host | container
  strategy: Recreate    # existente
```

El `loader.go` debe parsear este campo y el state manager debe almacenarlo. El orchestrator debe decidir el método de instalación basado en este campo:

- `host` → ejecutar task_catalog.sh directamente (systemd, cp, etc.)
- `container` → task_catalog.sh wrappea `kubectl apply`

---

## 12. CORE UI — ESTADO Y ROADMAP

### 12.1 Backend vs Frontend

| Componente | Estado |
|---|---|
| Backend API REST (daemon bos, puerto 9443) | ✅ Completo |
| Backend WebSocket (streaming de progreso) | ✅ Completo |
| Frontend Flutter (5 vistas) | ❌ 0% implementado |

### 12.2 Dependencias para iniciar construcción

| Dependencia | Estado |
|---|---|
| Keycloak OIDC | ⚠️ Ficha existe, no instalada en entorno de prueba |
| Centrifugo (broker WebSocket) | ⚠️ Ficha existe, no instalada |
| VDI Server | ❌ Bloquea despliegue de escritorio virtual |
| SBOS IAM Style (bstyle) | ❌ Bloquea sistema de diseño visual |

### 12.3 Roadmap — qué se puede hacer YA

**Fase A — Backend de UI (1-2 semanas):**
- Instalar keycloak y centrifugo en sbos-greenfield
- Verificar WebSocket streaming desde el daemon
- Verificar autenticación JWT contra Keycloak

**Fase B — Flutter mínimo funcional (2-3 semanas):**
- Login OIDC + Catálogo de Fichas (consulta GET /status)
- Consola de operaciones (POST install + WebSocket progreso)

**Fase C — Vistas completas (3-4 semanas):**
- Dashboard de Salud, Crecimiento Horizontal, Auditoría

---

## 13. PLAN DE VERIFICACIÓN DE COMPLETITUD

### 13.1 Niveles de verificación

```
NIVEL 0 — BUILD:      ¿Compila? ¿go build sin errores?
NIVEL 1 — CATALOGO:   ¿Carpeta de ficha existe? ¿manifest.reducido.yml + logo.png + descripcion.md presentes?
NIVEL 2 — MANIFEST:   ¿manifest.yml completo válido? ¿Campos obligatorios? ¿deployment_target declarado?
NIVEL 3 — HABILITAR:  ¿bosctl fetch funciona? ¿SHA-256 verifica? ¿Transición HABILITAR→BLOQUEADA/NO_INSTALADA?
NIVEL 4 — CATALOG:    ¿task_catalog.sh con 7 funciones? ¿yaml_engine.yml con fases?
NIVEL 5 — CLASIFIC:   ¿deployment_target correcto? ¿host solo en hostserver/gatewayserver?
NIVEL 6 — SAGA:       ¿Ciclo install → health → repair → uninstall funciona?
NIVEL 7 — DEPS:       ¿Grafo sin ciclos? ¿Dependencias forward-only?
NIVEL 8 — INTEG:      ¿No colisión de puertos? ¿NetworkPolicy correcta?
```

### 13.2 Verificaciones por dimensión

#### A — Catálogo ligero local (112)

| Check | Meta | Herramienta |
|---|---|---|
| Carpeta `servers/<server>/<ficha>/` existe | 112/112 | `find staging/core/servers -type d` |
| `manifest.reducido.yml` presente | 112/112 | `test -f` |
| `logo.png` presente | 112/112 | `test -f` |
| `descripcion.md` presente | 112/112 | `test -f` |
| identity.id único en los 112 reducidos | 0 duplicados | script `verify_catalogo.sh` |

#### B — Manifests completos (112, descargados de SKULL)

| Check | Meta | Herramienta |
|---|---|---|
| `manifest.yml` completo existe y es YAML válido | 112/112 | `yq eval . manifest.yml` |
| `deployment.target` declarado (host|container) | 112/112 | grep + validación |
| identity.id único | 0 duplicados | script `verify_manifests.sh` |
| Coherencia: host solo en hostserver, gatewayserver | 13 host, resto container | script |
| order.execution_order sin conflicto mismo nivel | 112 únicos | script |

#### C — Task Catalogs (112)

| Check | Meta | Herramienta |
|---|---|---|
| task_catalog.sh existe y es ejecutable | 112/112 | `test -x` |
| 7 funciones requeridas definidas | 112 × 7 = 784 | `declare -f ficha_<fase>` |
| Marcadores `__SBOS__STEP_*` en cada función | 784 funciones | grep |
| Sin hardcode de paths (R16) | 112 | grep por `/opt/`, `/etc/` fijos sin variable |

#### D — YAML Engines (112)

| Check | Meta |
|---|---|
| yaml_engine.yml existe | 112/112 |
| Fases: install, repair, uninstall mínimo | 112 × 3 = 336 fases |
| update presente para fichas con auto_update | Verificar |

#### E — Dependencias

| Check | Meta |
|---|---|
| Grafo sin ciclos | 0 ciclos (Kahn en main.go) |
| Dependencias forward-only | execution_order(dep) < execution_order(ficha) |
| Todas las dependencias resuelven a IDs reales | 100% |

#### F — Clasificación Host vs Contenedor

| Check | Meta |
|---|---|
| Fichas host: solo en servidores hostserver y gatewayserver/nginx | 13 exactamente |
| Fichas host: deployment.target = host | 13 |
| Fichas contenedor: deployment.target = container | 99 |
| Fichas host sin dependencias de fichas contenedor | Verificar |

#### G — HABILITAR y descarga desde SKULL

| Check | Meta |
|---|---|
| `bosctl fetch <ficha>` implementado | Comando funcional con HTTPS + SHA-256 |
| Catálogo local completo (112 reducidos + logo + desc) | Cada ficha tiene sus 3 archivos base |
| Catálogo SKULL sincronizable | `bosctl catalog update` trae versiones disponibles |
| Estado HABILITAR en state manager | Sexto estado canónico con transiciones DESCARGANDO |
| Fichas en HABILITAR visibles en catálogo | Carpeta + reducido + logo + desc presentes, pero sin task_catalog |
| Descarga fallida → reintento | Vuelve a HABILITAR, no pierde la referencia |
| SHA-256 mismatch → abortar | Ficha no se registra si hash no coincide |

### 13.3 Priorización de verificación en entorno real (host Ubuntu)

**Fase 0 — HABILITAR (descarga desde SKULL, PREVIA a todo):**
- [ ] Verificar que `bosctl catalog update` sincroniza el catálogo desde SKULL
- [ ] Verificar que `bosctl fetch sbos-bootstrap-os` descarga la capa de integración
- [ ] Verificar que la ficha descargada pasa verificación SHA-256
- [ ] Verificar que la ficha transiciona HABILITAR → NO_INSTALADA o BLOQUEADA
- [ ] Verificar que una ficha en HABILITAR no aparece en el filesystem hasta ser descargada

**Fase 1 — Bootstrap en el host (entorno de fuego real):**
- [x] sbos-bootstrap-os → INSTALADA_OK (verificado en contenedor staging)
- [x] sbos-bootstrap-k8s → INSTALADA_OK (verificado en contenedor staging)
- [x] sbos-lifecycle → INSTALADA_OK (verificado en contenedor staging)
- [ ] **PENDIENTE: Probar bootstrap completo en Ubuntu Server real (VPS/host físico)**

**Fase 2 — Infraestructura host crítica:**
- [ ] network-validator (H05, host)
- [ ] sbos-bootstrap-platform (H03, host)
- [ ] local-path-provisioner (H06, host)
- [ ] nginx (H07, host, categoría 3, PRIMERA ficha que expone tráfico)
- [ ] linkerd (H08, host)
- [ ] kyverno (H09, host)

**Fase 3 — Primeras fichas contenedor (infraestructura de datos e identidad):**
- [ ] postgresql (C01, container, orden 100)
- [ ] vault (C09, container, orden 120)
- [ ] keycloak (C17, container, orden 130)
- [ ] kong (C14, container, orden 145)
- [ ] prometheus (C76, container, orden 200)
- [ ] grafana (C77, container, orden 210)

**Fase 4 — Fichas de aplicación por servidor lógico:**
- [ ] erpserver: tryton (C22)
- [ ] appsserver: gnuhealth (C31), saleor (C32), directus (C33)
- [ ] commsserver: postfix (C62), dovecot (C63), rocketchat (C70)

**Fase 5 — Hardening y seguridad:**
- [ ] sbos-bootstrap-hardening (H10, host, requiere keycloak+kong+prometheus+linkerd)
- [ ] cert-rotation (H12, host)
- [ ] compliance-check (H13, host)

---

## 14. MÉTRICAS AGREGADAS DE COMPLETITUD

```json
{
  "total_fichas": 112,
  "servidores_logicos": 16,
  "fichas_host": 13,
  "fichas_contenedor": 99,
  "porcentaje_contenedor": 88.4,
  "estados_canonicos": 6,
  "estado_cero": "HABILITAR — ficha visible en catálogo local (reducido+logo+desc), capa de integración no descargada",
  "pipeline_certificacion": {
    "etapas": ["RECETA", "CONSTRUCCION", "SIMULACION", "CERTIFICACION", "PUBLICACION"],
    "estado": "PENDIENTE — no implementado",
    "bosctl_simulate": "no existe",
    "laboratorio_pruebas": "no implementado"
  },
  "manifests_reducidos_locales": "112/112 (estimado — falta verificar)",
  "logos_locales": "112/112 (estimado — falta verificar)",
  "descripciones_locales": "112/112 (estimado — falta verificar)",
  "manifests_completos_skull": "112/112 (100%)",
  "task_catalogs_creados": "112/112 (100%)",
  "yaml_engines_creados": "112/112 (100%)",
  "fichas_certificadas_por_simulacion": 0,
  "fichas_verificadas_en_host_real": 0,
  "fichas_verificadas_en_contenedor_staging": 3,
  "deployment_target_en_manifests": "PENDIENTE — campo no implementado",
  "estado_habilitar_en_state_manager": "PENDIENTE — no implementado",
  "bosctl_fetch": "PENDIENTE — comando no existe",
  "bosctl_simulate": "PENDIENTE — comando no existe",
  "catalogo_skull": "PENDIENTE — sincronización no implementada",
  "productos_definidos": 8,
  "productos_implementados_en_bosctl": 0,
  "core_sp01_completado": "~60% — falta simulación, certificación, HABILITAR, fetch, catálogo SKULL, deployment_target",
  "core_ui_completado": "~10% — backend API completo, frontend 0%",
  "gaps_criticos": [
    "bosctl simulate — sin modo simulación no se puede certificar fichas",
    "pipeline RECETA→CONSTRUIR→SIMULAR→CERTIFICAR→PUBLICAR no implementado",
    "repair saga k8s — containerd antes que kubelet",
    "estado HABILITAR no implementado en state/manager.go",
    "bosctl fetch no existe — sin descarga desde SKULL",
    "catálogo SKULL no implementado"
  ],
  "prueba_de_fuego": "Instalar BOS + bootstrap en Ubuntu Server real (host físico/VPS)"
}
```

---

## 15. FUENTES

| Documento | Ruta |
|---|---|
| SBOS-005-STACK | `v6/SBOS-005-STACK.md` — 16 servidores lógicos, stack |
| SBOS-018-DAEMON-BOS | `v6/SBOS-018-DAEMON-BOS.md` — Daemon BOS, sagas, señales |
| SBOS-019-FICHAS | `v6/SBOS-019-FICHAS.md` — Sistema de fichas, ciclo de vida |
| SBOS-020-COREUI | `v6/SBOS-020-COREUI.md` — Core UI, 5 vistas, RBAC |
| SBOS-035-INSTALL-ROUTINE | `humano/SBOS-035-INSTALL-ROUTINE.md` — Rutina bootstrap |
| SBOS-036-PRODUCTS | `humano/SBOS-036-PRODUCTS.md` — 8 productos Nivel 2 |
| SBOS-049-FICHAS-BOS | `humano/SBOS-049-FICHAS-BOS.md` — Especificación de fichas |
| INVENTARIO-FICHAS | `staging/core/servers/INVENTARIO-FICHAS.md` |
| PLAN-DESARROLLO-LIFECYCLE | `context/PLAN-DESARROLLO-LIFECYCLE.md` |
| BOS-LIFECYCLE-PLAN-v2 | `context/BOS-LIFECYCLE-PLAN-v2.md` |
| main.go | `src/cmd/bos/main.go` — Observer loop, topological sort |
| saga.go | `src/internal/installer/saga.go` — Orchestrator, parseo señales |
| manager.go | `src/internal/state/manager.go` — State machine |
| loader.go | `src/internal/plugin/loader.go` — Plugin discovery |
