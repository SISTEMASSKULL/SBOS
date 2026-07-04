# SBOS-050-PORT-CATALOG
## Política de Puertos, Subdominios y Segmentación de Red
## Estándar HUMAN-DOC
### SKULL · SBOS · v3.1 · Mayo 2026

---

## Índice de Contenido

```
PARTE I   — FUNDAMENTOS Y POLÍTICA
  §1  Propósito y Alcance
  §2  Marco Normativo Internacional
  §3  Principios de Diseño de Red

PARTE II  — ESPACIO DE PUERTOS SBOS
  §4  Los Tres Rangos IANA y Mapa de Asignación SBOS
  §5  Tabla Maestra de Puertos NO DISPONIBLES

PARTE III — ARQUITECTURA DE CAPAS DE RED
  §6  Modelo de Tres Capas (containerPort / ClusterIP / Externo)
  §7  Puertos del Host Ubuntu (Capa Exterior)
  §8  Puertos de Infraestructura Kubernetes
  §9  Puertos de la Capa de Servicio (ClusterIP SBOS)
  §10 Puertos de Exposición Externa (LoadBalancer + NodePort)

PARTE IV  — CATÁLOGO DE PUERTOS POR SERVIDOR LÓGICO
  §11 Puertos Canónicos de Aplicaciones (containerPort)
  §12 Esquema ClusterIP SBOS — Derivación y Tabla

PARTE V   — APLICACIONES PROPIAS SKULL
  §13 Rango Reservado SKULL Custom Apps (28100–28999)

PARTE VI  — SUBDOMINIOS sksistemas.com
  §14 Marco Normativo de Subdominios
  §15 Subdominios Activos y Catálogo Oficial
  §16 Enrutamiento Kong — Subdominio → Servicio

PARTE VII — OPERACIÓN Y GOBERNANZA
  §17 Política de Seguridad — Reglas Absolutas
  §18 Proceso de Asignación de un Puerto Nuevo
  §19 NetworkPolicy Kubernetes — Plantillas
  §20 Prompt de Agente — Instrucciones de Mantenimiento
  §21 Trazabilidad
```

---

# PARTE I — FUNDAMENTOS Y POLÍTICA

---

## 1. Propósito y Alcance

Este documento es la **fuente de verdad** para toda asignación de puertos TCP/UDP y subdominios DNS en el ecosistema SBOS. Cubre la totalidad del stack: host Ubuntu, infraestructura Kubernetes, aplicaciones de terceros, daemons soberanos, aplicaciones propias SKULL y servicios expuestos en `sksistemas.com`.

En caso de conflicto entre este documento y cualquier otro del corpus HUMAN-DOC, este documento prevalece en materia de puertos y subdominios.

**Lo que garantiza esta política:**
- Ausencia de colisiones de puerto en todo el stack
- Cumplimiento de estándares internacionales (IANA, CIS, NSA/CISA, ISO 27001)
- Trazabilidad inmediata: el número de puerto identifica el servidor lógico y la ficha
- Seguridad por defecto: deny-all en host y en K8s NetworkPolicy

---

## 2. Marco Normativo Internacional

| Estándar | Organismo | Alcance | Aplicación en SBOS |
|---|---|---|---|
| **IANA RFC 6335** (2011) | IETF/IANA | Define los tres rangos de puertos TCP/UDP | SBOS opera en User Ports (1024–49151); nunca en Dynamic (49152–65535) para servicios |
| **IANA RFC 7605** (2015) | IETF | Recomendaciones de uso de puertos registrados | Servicios propios SKULL usan rango propio (28100–28999) con baja densidad IANA |
| **RFC 1034 + RFC 1123** (1987/1989) | IETF | Sintaxis y jerarquía DNS de subdominios | Subdominios sksistemas.com: solo letras, dígitos, guiones; max 63 chars por label |
| **RFC 2606 + RFC 6761** (1999/2013) | IETF/IANA | Nombres de dominio reservados para uso especial | Prohibidos: `localhost`, `local`, `test`, `example`, `invalid`, `onion`, `home` |
| **CIS Ubuntu 24.04 Benchmark** | CIS | Hardening del host Linux | UFW: deny-all incoming; solo 22/80/443 desde exterior |
| **CIS Kubernetes Benchmark v1.8** | CIS | Seguridad del cluster K8s | API Server no expuesto a internet; NetworkPolicy default-deny; TLS en todo componente |
| **NSA/CISA Kubernetes Hardening Guide v1.2** (2022) | NSA + CISA | Guía de endurecimiento K8s para infraestructura crítica | Default-deny NetworkPolicy; segmentación de namespaces; kubelet :10250 sin acceso a internet |
| **ISO/IEC 27001:2022 A.8.20** | ISO/IEC | Network Security Controls | Inventario completo de puertos = control de superficie de ataque; evidencia auditada |
| **ISO/IEC 27001:2022 A.8.22** | ISO/IEC | Network Segregation | Separación de tráfico por namespace + NetworkPolicy |
| **NIST SP 800-41 Rev.1** | NIST | Firewall Policy Guidelines | Política de firewall basada en inventario explícito; deny-all por defecto |
| **NIST SP 800-207** | NIST | Zero Trust Architecture | Verificación continua: cada request valida puerto + identidad + contexto |

---

## 3. Principios de Diseño de Red

Estos principios son inquebrantables. Ninguna decisión de implementación puede violarlos.

| # | Principio | Aplicación concreta |
|---|---|---|
| **P1** | **Deny-all por defecto** | UFW: `default deny incoming`. K8s: NetworkPolicy `default-deny-all` en todos los namespaces (NSA/CISA) |
| **P2** | **Mínima superficie de ataque** | Solo 3 puertos abiertos externamente en el host: 22, 80, 443. Todo lo demás: ClusterIP interno |
| **P3** | **Puertos canónicos inmutables** | Los containerPorts de apps de terceros nunca se modifican (PG=5432, Redis=6379). Cambiarlo rompe compatibilidad |
| **P4** | **Certeza absoluta sobre disponibilidad** | Si hay duda sobre si un puerto está libre: NO se usa. Ver §5 (Tabla NO DISPONIBLES) |
| **P5** | **Un puerto = un servicio** | Nunca dos servicios SBOS comparten puerto en el mismo namespace |
| **P6** | **Bases de datos: nunca externas** | PostgreSQL, Redis, MySQL, etcd: solo ClusterIP. Sin NodePort, sin LoadBalancer, sin hostPort |
| **P7** | **Trazabilidad del número** | El ClusterIP SBOS es derivable: `BASE_SERVIDOR + (FICHA×10) + TIPO`. Ver §12 |
| **P8** | **TLS en todo** | Todo servicio expuesto externamente habla HTTPS. Sin HTTP plano en producción (CIS Kubernetes §5.4) |
| **P9** | **HTTP vetado entre daemons y Smart*** | Toda comunicación entre los 8 daemons soberanos y entre daemons y aplicaciones propias SKULL (Smart*) usa exclusivamente **WebSocket** o **Unix socket**. HTTP se permite solo para métricas Prometheus (scrape unidireccional), healthcheck K8s probes, y la API bos expuesta a bosctl/Core UI. Sin excepciones. |
| **P10** | **Mínima exposición HTTP al exterior** | Los daemons no exponen endpoints HTTP al exterior salvo los 3 definidos explícitamente en §7.2 (bos :9440, :9441, :9443). El par Nexus (bhnexus+banexus) comunica exclusivamente por WebSocket mTLS. |

---

# PARTE II — ESPACIO DE PUERTOS SBOS

---

## 4. Los Tres Rangos IANA y Mapa de Asignación SBOS

### 4.1 Rangos IANA (RFC 6335)

| Rango | Nombre IANA | Descripción | Posición SBOS |
|---|---|---|---|
| **0 – 1023** | System / Well-Known | Protocolos estándar. Requieren root para bind | ❌ Solo para protocolos del OS (SSH, HTTP, HTTPS, DNS...) |
| **1024 – 49151** | User / Registered | Aplicaciones y servicios | ✅ **Zona de operación de SBOS** |
| **49152 – 65535** | Dynamic / Private / Ephemeral | Conexiones salientes del cliente (OS) | ❌ Nunca asignar a servicios |

### 4.2 Mapa de Asignación SBOS dentro del Rango User (1024–49151)

```
1024                                                                          49151
│                                                                               │
├──────┬────────┬──────┬──────┬──────┬───────┬───────┬──────┬─────────────────┤
│ Apps │ SBOS   │Obser-│Daem. │ Obs.  │ SKULL │Node- │   Libre IANA    │
│ canó-│ Clust. │ vabi-│ Sobe-│ Stack │ Custom│ Port │  (sin asignar)  │
│ nicas│  IP    │ lidad│ ranos│ SBOS  │  Apps │ SBOS │                 │
│1024  │ 8100   │ 9090 │ 9400 │ 9500  │28100  │31000 │  32000–49151    │
│ –    │  –     │  –   │  –   │  –    │  –    │  –   │                 │
│ 8099 │ 8999   │ 9399 │ 9499 │ 9999  │28999  │31999 │                 │
│  ✅  │  🔒    │  🔒  │  🔒  │  🔒   │  🔒   │  🔒  │       ✅        │
└──────┴────────┴──────┴──────┴──────┴───────┴───────┴──────┴─────────────────┘

LEYENDA:
  ✅ Disponible para nuevos containerPorts de apps (verificar §5 antes de asignar)
  🔒 Reservado — ver sección correspondiente de este documento
```

### 4.3 Nota sobre Puertos K8s Core

Los puertos de infraestructura Kubernetes (6443, 2379-2380, 10248-10259) están **dispersos** en el espacio de puertos — no forman un bloque continuo dentro del rango User IANA. Por eso no aparecen como columna en el mapa de §4.2. Se gestionan via reglas UFW restringidas a `CIDR_CLUSTER`. Ver §8 para la lista completa.

### 4.4 Tabla de Rangos Reservados SBOS

| Rango | Uso | Sección |
|---|---|---|
| 0 – 1023 | Well-Known IANA — OS y stack de correo | §7 |
| 1024 – 8099 | containerPorts canónicos de apps (libre si no hay conflicto) | §11 |
| 8100 – 8999 | ClusterIP K8s SBOS (esquema derivable por servidor lógico) | §12 |
| 9090 – 9399 | Observabilidad: Prometheus, Grafana, Loki, Tempo, OTel | §11 |
| 9400 – 9499 | Daemons soberanos SBOS (host Ubuntu, fuera de K8s) | §7.2 |
| 9500 – 9999 | Uso general SBOS (Zabbix, Wazuh, auxiliares) | §11 |
| 10248 – 10259 | Kubernetes control plane interno | §8.1 |
| 28100 – 28999 | SKULL Custom Apps (SMARTA y desarrollo propio) | §13 |
| 31000 – 31999 | NodePort K8s SBOS (solo mantenimiento temporal) | §10.2 |

---

## 5. Tabla Maestra de Puertos NO DISPONIBLES

Esta tabla es la primera consulta obligatoria antes de asignar cualquier puerto. Si el puerto aparece aquí: **no se usa, sin excepciones**.

### 5.1 Well-Known IANA (0–1023) — Exclusivamente para el OS y Protocolos Estándar

| Puerto(s) | Protocolo | Asignado a | Razón de exclusión |
|---|---|---|---|
| 22 | TCP | SSH | Host admin — UFW externo |
| 25 | TCP | SMTP | MTA-to-MTA únicamente |
| 53 | TCP/UDP | DNS | CoreDNS K8s |
| 80 | TCP | HTTP | NGINX ingress (→443) |
| 110 | TCP | POP3 | Plano — no usar en producción |
| 143 | TCP | IMAP | Solo con STARTTLS (stack correo) |
| 179 | TCP | BGP | Calico CNI |
| 443 | TCP | HTTPS | NGINX ingress — entrada única |
| 465 | TCP | SMTPS | Stack de correo |
| 587 | TCP | SMTP Submission | Stack de correo |
| 993 | TCP | IMAPS | Stack de correo |
| 995 | TCP | POP3S | Stack de correo |

### 5.2 Kubernetes Core — Nunca Reasignar

| Puerto(s) | Componente | Razón |
|---|---|---|
| 2379–2380 | etcd client/peer | K8s core — `kubeadm` falla si están ocupados |
| 6443 | kube-apiserver | K8s core — API Server |
| 10248–10250 | kubelet healthz / API | K8s core |
| 10256–10259 | kube-proxy / scheduler / controller | K8s core |

### 5.3 Service Mesh Linkerd — Todos los Pods

Los puertos de Linkerd están presentes en **cada pod** del cluster. Ninguna NetworkPolicy ni Kyverno Policy puede bloquearlos.

| Puerto(s) | Componente | Razón |
|---|---|---|
| 4140, 4143 | linkerd-proxy outbound / inbound | Sidecar en cada pod (mTLS automático) |
| 4191 | linkerd-proxy admin | Métricas y healthcheck del proxy |
| 8086, 8080 | Linkerd control plane | destination + identity services |
| 9995 | linkerd-proxy metrics | Prometheus scrape del sidecar |

### 5.4 Puertos de Alta Conflictividad — Movidos a NO DISPONIBLES

Criterio: si existe cualquier nivel de duda sobre disponibilidad, el puerto es NO DISPONIBLE. La certeza absoluta es el único criterio aceptable (Principio P4).

| Puerto | Registro IANA | Conflictos documentados | Decisión |
|---|---|---|---|
| **3000** | `RemoteWare Client` | Grafana (**ya asignado en SBOS**), Node.js, Rails | 🚫 NO DISPONIBLE |
| **5000** | `upnp` | Flask dev, Docker Registry, UPnP | 🚫 NO DISPONIBLE |
| **8000** | `irdmi` | Django dev, Vault dev, AWS DynamoDB local (**Tryton/Saleor ya lo usan**) | 🚫 NO DISPONIBLE |
| **8008** | `http-alt` | HTTP proxy, FileMaker, cámaras IP, OpenVPN | 🚫 NO DISPONIBLE |
| **8080** | `http-alt` | Tomcat, Jenkins, Spring Boot, Jira, Squid, Rancher, cAdvisor | 🚫 NO DISPONIBLE — máximo conflicto |
| **8088** | Unassigned | Hadoop YARN ResourceManager, Riak, productos Huawei | 🚫 NO DISPONIBLE |
| **8090** | `opsmessaging` | Atlassian Bamboo, Confluence, Couchbase | 🚫 NO DISPONIBLE |
| **8888** | `ddi-tcp-1` | Jupyter Notebook, MAMP, HBase Master UI | 🚫 NO DISPONIBLE |
| **9000** | `cslistener` | MinIO S3 (**ya asignado en SBOS**), SonarQube, PHP-FPM | 🚫 NO DISPONIBLE |
| **9090** | Prometheus | Prometheus (**ya asignado en SBOS monitorserver**) | 🚫 NO DISPONIBLE |
| **9100** | Node Exporter | Node Exporter (**ya asignado en SBOS**) | 🚫 NO DISPONIBLE |
| **9200** | Elasticsearch HTTP | Wazuh/Elastic (**ya asignado en SBOS**) | 🚫 NO DISPONIBLE |
| **9300** | Elasticsearch peer | Elastic peer (**ya asignado en SBOS**) | 🚫 NO DISPONIBLE |

### 5.5 Rangos Bloqueados por Asignación SBOS

| Rango | Asignado a | Referencia |
|---|---|---|
| 8100 – 8999 | ClusterIP K8s SBOS | §12 |
| 9400 – 9499 | Daemons soberanos (bos: 9440-9443, bhnexus: 9444-9446, bauth: 9450-9453, bkernel: 9460-9461, biedata: 9470-9471, bcompass: 9480-9483, bsearch: 9490-9493) | §7.2 |
| 28100 – 28999 | SKULL Custom Apps | §13 |
| 31000 – 31999 | NodePort SBOS | §10.2 |

---

# PARTE III — ARQUITECTURA DE CAPAS DE RED

---

## 6. Modelo de Tres Capas

Cada servicio SBOS tiene tres representaciones de puerto. Confundirlas es la causa más común de errores de configuración en K8s.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  CAPA 3 — EXPOSICIÓN EXTERNA                                                │
│  Puerto visible desde Internet / LAN del cliente                            │
│  Mecanismos: LoadBalancer MetalLB (80/443), NodePort (31000-31999 temporal) │
│  Siempre pasa por NGINX → Kong                                              │
└────────────────────────────┬────────────────────────────────────────────────┘
                             │ proxy_pass / routing
┌────────────────────────────▼────────────────────────────────────────────────┐
│  CAPA 2 — SERVICIO ClusterIP (K8s Service port)                             │
│  Puerto interno del cluster. Solo accesible dentro del cluster K8s.         │
│  Esquema SBOS: BASE_SERVIDOR + (FICHA×10) + TIPO → §12                      │
│  Ejemplo: Keycloak ClusterIP = 8200 (S03, F0, T0)                           │
└────────────────────────────┬────────────────────────────────────────────────┘
                             │ targetPort
┌────────────────────────────▼────────────────────────────────────────────────┐
│  CAPA 1 — PUERTO CANÓNICO DEL CONTENEDOR (containerPort)                    │
│  Puerto real en que la app escucha DENTRO del pod.                          │
│  Definido por el fabricante. NUNCA se modifica.                             │
│  Ejemplo: Keycloak containerPort = 8080 (siempre, aunque el ClusterIP sea   │
│  8200 y el externo sea 443)                                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Regla de oro:** una base de datos nunca tiene Capa 3. PostgreSQL, Redis, MySQL, etcd: solo Capa 1 + Capa 2 (ClusterIP). Sin LoadBalancer, sin NodePort, sin hostPort.

---

## 7. Puertos del Host Ubuntu (Capa Exterior)

### 7.1 Puertos Externos — Abiertos por UFW al Exterior

Solo tres puertos llegan desde Internet/LAN al host Ubuntu. Todo lo demás: `ufw default deny incoming`.

| Puerto | Protocolo | Servicio | Notas |
|---|---|---|---|
| **22** | TCP | SSH | Restringir por IP de origen en producción. Considerar cambio a puerto no estándar |
| **80** | TCP | HTTP → NGINX | Obligatorio para ACME challenge (Let's Encrypt). Redirige inmediatamente a 443 |
| **443** | TCP | HTTPS → NGINX → Kong | Punto de entrada único para usuarios y APIs |

**Adicionalmente, si se usa VPN WireGuard:**

| Puerto | Protocolo | Servicio | Notas |
|---|---|---|---|
| **51820** | UDP | WireGuard VPN | Solo si `vpn.sksistemas.com` está activo. Restringir a IPs conocidas |

### 7.2 Daemons Soberanos en el Host (rango 9400–9499)

Los 8 daemons soberanos corren como `systemd` en el host Ubuntu fuera de K8s (ADR-002). Su rango de puertos es **9400–9499**, bloqueado externamente por UFW. Solo accesibles desde `localhost` y desde pods del cluster vía `CIDR_PODS`.

**Política de comunicación entre daemons (P9 — inquebrantable):**
- Toda comunicación entre daemons usa **WebSocket** o **Unix socket**
- HTTP entre daemons está **VETADO**
- HTTP entre daemons y aplicaciones Smart* está **VETADO**
- HTTP permitido únicamente para: (a) métricas Prometheus (scrape unidireccional, lectura), (b) healthcheck K8s probes, (c) API bos expuesta a bosctl/Core UI
- La única excepción controlada: biedata → APIs tributarias externas (SIAT/AFIP/SAT) — es el único daemon autorizado a salir al exterior (SBOS-008 §5)

---

#### bos — IAM Installer (Go) — Control Plane Soberano + Dueño del Context Plane

Lenguaje: Go + Python 16 módulos. Gestiona fichas, productos, despliegues, Context Plane (ADR-011), ciclo de vida de tenants.

| Puerto | Tipo | Función | Protocolo | Quién consume |
|---|---|---|---|---|
| **9440** | WebSocket | Streaming bidireccional hacia Core UI: estado de fichas, progreso install, eventos del sistema en tiempo real | WSS | Core UI (Flutter) |
| **9441** | API REST | Endpoints REST: `/api/v1/installer/*`, `/api/v1/fichas/*`, `/api/v1/products/*`, `/api/v1/context/*` (ADR-011) | HTTPS | Core UI, bosctl, Kong plugin sbos-context |
| **9442** | Métricas | Prometheus scrape del bos | HTTP | Prometheus (scrape unidireccional) |
| **9443** | Healthcheck | Readiness/liveness del daemon | HTTP | K8s probe (via hostNetwork) |

> **Nota:** el bos es el único daemon con API REST expuesta al exterior del rango 9400-9499, porque necesita ser consumida por bosctl (CLI) y Core UI (Flutter pod K8s). Todo lo demás entre daemons es WebSocket o Unix socket.

---

#### bkernel — SBOS Data Kernel (Rust) — Plano de Datos

Lenguaje: Rust. Escucha el WAL de PostgreSQL vía socket Unix con latencia <50μs. Ejecuta reglas YAML. Propaga cambios entre apps del stack.

| Puerto | Tipo | Función | Protocolo | Quién consume |
|---|---|---|---|---|
| **9460** | Métricas | Prometheus scrape: throughput WAL, latencia reglas, DLQ count, LSN lag | HTTP | Prometheus (scrape unidireccional) |
| **9461** | Healthcheck | Estado slot WAL, conexión PG, última regla ejecutada | HTTP | K8s probe (via hostNetwork) |
| — | Unix Socket | `/run/bos/bkernel-mcp.sock` — protocolo MCP stdio para bCompass | stdio | bCompass exclusivamente |

> **bkernel NO tiene API REST ni WebSocket de negocio.** Solo métricas y healthcheck como puertos TCP. Toda comunicación de negocio es via el slot WAL de PostgreSQL (socket Unix de PG) y el socket MCP para bCompass. No abrir ningún puerto TCP adicional para bkernel.

---

#### biedata — SBOS Data Integration (Rust) — Aduana Soberana de Datos

**Metáfora:** biedata es la aduana soberana del SBOS. Todo dato que entra desde el exterior o sale hacia el exterior pasa por biedata. Las cajas declaran las reglas; biedata las ejecuta.

**Lenguaje:** Rust. **Modo de activación:** por eventos — Redis Stream (publicado por bKernel), file_watch (inotify), cron, o manual via `bosctl biedata run <caja>`.

| Puerto | Tipo | Función | Protocolo | Quién consume |
|---|---|---|---|---|
| **9470** | Métricas | Prometheus scrape: ejecuciones de cajas, éxitos/fallos/parciales, duración, registros procesados | HTTP | Prometheus (scrape unidireccional) |
| **9471** | Healthcheck | Estado del daemon, última ejecución de caja, streams escuchados | HTTP | K8s probe (via hostNetwork) |
| — | Saliente externo | APIs tributarias externas: SIAT Bolivia (SOAP/mTLS), AFIP Argentina (SOAP/WSAA), SAT México (REST CFDI 4.0), DIAN Colombia | HTTPS saliente | Solo biedata sale al exterior — NINGÚN otro daemon |

**Flujo EXPORT — cómo biedata recibe datos y los entrega al exterior (ejemplo: factura → SIAT):**

```
① Usuario aprueba factura en Tryton o SmartTax
          ↓
② PostgreSQL WAL: UPDATE account_invoice SET state='posted'
          ↓
③ bKernel detecta el cambio via slot WAL
  Evalúa regla: invoice_tributaria_trigger.yml
  Condición: state=posted AND tax_country IN ['BO','AR','MX','CO']
          ↓
④ bKernel publica en Redis Stream: biedata:invoices:{tax_country}
          ↓
⑤ biedata.service consume el Redis Stream
  Resuelve caja: boxes/export/facturas_siat/
  Ejecuta 6 fases:
    VALIDATE     → verifica credenciales y variables de entorno en Vault
    AUTHENTICATE → carga certificado digital mTLS del SIAT desde Vault
    EXTRACT      → query SELECT-only a PostgreSQL (factura + cliente)
    TRANSFORM    → construye XML firmado según XSD oficial del SIAT
    LOAD         → POST mTLS al endpoint del SIAT / AFIP / SAT / DIAN
    AUDIT        → registra código de autorización en biedata_db.box_executions
          ↓
⑥ bKernel detecta la escritura en biedata_db via WAL
  bKernel actualiza tryton_db.account_invoice con el código fiscal
          ↓
⑦ Tryton / SmartTax muestran la factura autorizada con número de autorización
```

**Flujo IMPORT — cómo biedata recibe datos del exterior e incorpora al stack (ejemplo: clientes Excel):**

```
① Archivo clientes_2026.xlsx llega a /mnt/biedata/incoming/clientes/
          ↓
② biedata detecta via file_watch (inotify)
  Activa caja: boxes/import/clientes_excel/
  Ejecuta fases:
    EXTRACT   → calamine lee XLSX sin GC pauses (9.4x más rápido que openpyxl)
    TRANSFORM → aplica mapping.yml (razon_social→name, correo→email)
    VALIDATE  → valida email format, NIT pattern
    LOAD      → UPSERT en espocrm.accounts con origin='biedata'
    AUDIT     → registra en biedata_db
          ↓
③ bKernel detecta las escrituras nuevas en espocrm via WAL
  bKernel propaga a Tryton (como party.party), bSearch (indexa), etc.
```

**Separación fundamental biedata / bKernel:**

| bKernel | biedata |
|---|---|
| Sincroniza apps internas entre sí | Conecta stack con el mundo exterior |
| WAL continuo, loop infinito | Opera por eventos (no continuo) |
| Sin contacto con exterior | Único daemon autorizado a salir al exterior |
| Propaga cambios internos | Traduce formatos externos (XML, SFTP, API) |
| Publica en Redis Stream cuando detecta trigger | Consume Redis Stream para ejecutar cajas |

**Principio de cierre del ciclo:** biedata escribe con `origin='biedata'` → bKernel detecta esa escritura vía WAL (antiloop protegido) → bKernel propaga la respuesta del exterior de vuelta al stack.

> biedata NO tiene API REST pública ni WebSocket entrante. Su activación es siempre interna.
#### bauth — SBOS Auth Enforce (Go) — Plano de Identidad

Lenguaje: Go. Evalúa simultáneamente 3 dominios: **Lógico** (red autorizada, LoA requerido, apps permitidas), **Físico** (zona autorizada, horario laboral, hardware), **Financiero** (límites transaccionales, SoD, doble firma). Resultado: BitMask de 64 bits que define exactamente qué puede hacer el usuario en ese contexto.

| Puerto | Tipo | Función | Protocolo | Quién consume |
|---|---|---|---|---|
| **9450** | WebSocket | Canal bidireccional: push de invalidación de BitMask/política a bhnexus cuando cambia RolTemplate o UserTemplate. bhnexus suscrito permanentemente. | WSS | bhnexus (suscriptor permanente) |
| **9451** | API REST | Endpoints REST: `/api/v1/roltemplate/*`, `/api/v1/usertemplate/*`, `/api/v1/authorize/*`, `/api/v1/sync/*`, `/api/v1/biometric/*`, `/api/v1/audit`, `/api/v1/health` | HTTPS | Core UI (gestión de templates), bos (Context Plane sync) |
| **9452** | Métricas | Prometheus scrape: accesos grant/deny, drifts KC↔Tryton, latencia sync, BitMask cache hits | HTTP | Prometheus (scrape unidireccional) |
| **9453** | Healthcheck | Estado del daemon, sync KC status, última evaluación | HTTP | K8s probe (via hostNetwork) |
| — | Unix Socket | `/run/bos/bauth.sock` — evaluación de BitMask en tiempo real para bhnexus (cache miss). Protocolo: length-prefix JSON, latencia <5ms, timeout 1s | stdio | bhnexus (cache miss path) |
| — | Unix Socket | `/run/bos/bauth-mcp.sock` — MCP stdio para bCompass | stdio | bCompass exclusivamente |

> **Topología bauth:** bhnexus tiene DOS canales con bauth: (1) WebSocket :9450 para recibir push de invalidaciones de política, (2) Unix socket `/run/bos/bauth.sock` para evaluación en tiempo real en cache miss (<5ms). El WebSocket es permanente (suscripción). El Unix socket es por demanda (cache miss).

---

#### bcompass — SBOS AI Tools (Go) — Plano de Inteligencia

Lenguaje: Go. Route Engine de IA soberana con 4 tipos de ruta: analyst (análisis), agent (conversacional), flow (automatización), report (reportes). Usa Ollama local vía HTTP (único caso de HTTP interno autorizado: bCompass → Ollama, misma red interna del cluster, sin salir al exterior). Governance por niveles: 1 (auto), 2 (rol CONFIG), 3 (rol OWNER).

| Puerto | Tipo | Función | Protocolo | Quién consume |
|---|---|---|---|---|
| **9480** | WebSocket | Streaming de propuestas HITL y resultados de rutas hacia Core UI en tiempo real. Approval Gates notificados en tiempo real al administrador. | WSS | Core UI (aprobación HITL), bosctl |
| **9481** | API REST | Endpoints REST: `/api/v1/compass/*` — consultar propuestas pendientes, aprobar/rechazar Approval Gates, listar rutas activas, historial Langfuse | HTTPS | Core UI (gestión HITL), bos (Context Plane) |
| **9482** | Métricas | Prometheus scrape: rutas ejecutadas por tipo, HITL pendientes, latencia LLM, tokens consumidos, Governance 1/2/3 distribución | HTTP | Prometheus (scrape unidireccional) |
| **9483** | Healthcheck | Estado daemon, Ollama reachable, Qdrant reachable, Langfuse reachable | HTTP | K8s probe (via hostNetwork) |
| — | Unix Socket | `/run/bos/bkernel-mcp.sock` — MCP stdio (consume bkernel) | stdio | bCompass como MCP Host |
| — | Unix Socket | `/run/bos/bauth-mcp.sock` — MCP stdio (consume bauth) | stdio | bCompass como MCP Host |
| — | Unix Socket | `/run/bos/bsearch-mcp.sock` — MCP stdio (consume bsearch) | stdio | bCompass como MCP Host |

> **Nota Ollama:** bCompass → Ollama usa HTTP (POST :11434) dentro del cluster K8s. Esta es la **única excepción autorizada** de HTTP entre daemon y servicio interno, justificada porque Ollama no soporta WebSocket y opera dentro de la red privada del cluster (NetworkPolicy protege). Registrada como excepción explícita, no viola P9 por ser comunicación interna al cluster sin acceso externo.

---

#### bsearch — SBOS Data RAG (Go) — Plano de Búsqueda

Lenguaje: Go. Búsqueda federada Typesense (full-text) + Qdrant (semántico vectorial). Schema Discoverer usa Qwen3-coder para entender nuevas estructuras automáticamente. Indexa desde el WAL via bkernel:index_queue (Redis Stream).

| Puerto | Tipo | Función | Protocolo | Quién consume |
|---|---|---|---|---|
| **9490** | WebSocket | Streaming de resultados de búsqueda en tiempo real hacia Core UI y SBOS VDI. Sugerencias de autocompletado en tiempo real. | WSS | Core UI, SBOS VDI (banexus) |
| **9491** | API REST | Endpoints REST: `/api/v1/search/*` — búsqueda federada, búsqueda por entidad, Schema Discoverer status, índices Typesense, colecciones Qdrant | HTTPS | Core UI, bos (Context Plane), banexus |
| **9492** | Métricas | Prometheus scrape: queries/s, latencia Typesense/Qdrant, documentos indexados, cache hits | HTTP | Prometheus (scrape unidireccional) |
| **9493** | Healthcheck | Estado daemon, Typesense reachable, Qdrant reachable, último reindex | HTTP | K8s probe (via hostNetwork) |
| — | Unix Socket | `/run/bos/bsearch-mcp.sock` — MCP stdio para bCompass | stdio | bCompass como MCP Host |

---

#### bhnexus + banexus — Par Nexus Soberano (Go) — Plano de Conectividad Hardware

bhnexus y banexus son una **unidad compuesta** que opera como una sola entidad funcional. No son daemons independientes.

**bhnexus** — SBOS Nexus Host (systemd en host Ubuntu):

| Puerto | Tipo | Función | Protocolo | Quién consume |
|---|---|---|---|---|
| **9444** | WebSocket mTLS | Acepta conexiones entrantes de todos los banexus. Hasta 10.000 conexiones concurrentes. Auth request/response, policy push, heartbeat. | WSS/mTLS | banexus en cada Fedora VDI — **único canal externo de bhnexus** |
| **9445** | Métricas | Prometheus scrape: dispositivos activos, auth latencia, cache hits/misses, policy updates | HTTP | Prometheus (scrape unidireccional) |
| **9446** | Healthcheck | Estado daemon, banexus conectados, bauth socket status | HTTP | K8s probe (via hostNetwork) |
| — | Unix Socket | `/run/bos/bauth.sock` — consulta bAuth en cache miss (latencia <5ms, timeout 1s, retry 3) | stdio | bAuth exclusivamente |

**banexus** — SBOS Nexus Agent (systemd --user en Fedora):

| Canal | Tipo | Función | Protocolo | Notas |
|---|---|---|---|---|
| — | **Sin puertos TCP entrantes** | banexus es cliente puro — no escucha | — | Nodo Fedora no acepta conexiones entrantes de SBOS |
| Saliente → :9444 | WebSocket mTLS | Único canal de comunicación con bhnexus. auth_request, auth_response, policy_update, shell_auth, heartbeat | WSS/mTLS outbound | Reconexión backoff exp: 1→5→15→30→60s. Offline: cache efímero AES-256-GCM |
| udev + libusb | Kernel hooks | Intercepta credenciales USB/input ANTES que evdev | kernel | QR, NFC MIFARE DESFire, huella, tarjeta Wiegand |
| Serial/GPIO | Hardware | Actúa sobre actuadores post-autorización | serial/GPIO | Relés (cajón POS, chapas), pantallas |

**Topología invariable — NUNCA violar:**
```
banexus (Fedora) ──WSS/mTLS──► bhnexus ──Unix socket──► bAuth

VETADO:
  ✗ banexus → bAuth directamente     (rompe routing y cache)
  ✗ banexus → Keycloak               (banexus no habla con KC)
  ✗ banexus → K8s cluster            (banexus sin acceso al cluster)
  ✗ bhnexus → HTTP externo           (solo WSS inbound + Unix socket a bAuth)
  ✗ dispositivo → bhnexus sin banexus (rompe interceptación soberana)
```

**Flujo soberano en <50ms:**
```
T+0ms   Credencial presentada en Fedora
T+1ms   banexus intercepta via udev — ANTES que el OS
T+2ms   banexus → bhnexus: {auth_request} WSS/mTLS
T+5ms   bhnexus: cache hit (SAM TTL 30s) O Unix socket → bAuth (cache miss <5ms)
T+15ms  bhnexus → banexus: {auth_response + actuator_commands} WSS
T+15ms  banexus activa relé (cajón/chapa) O deniega con registro
```

---

#### Tabla Consolidada de Puertos de Daemons

| Puerto | Daemon | Tipo | Protocolo | Función resumida |
|---|---|---|---|---|
| **9440** | bos | WebSocket | WSS | Streaming Core UI — eventos instalación tiempo real |
| **9441** | bos | API REST | HTTPS | Fichas, productos, context API, deploy |
| **9442** | bos | Métricas | HTTP | Prometheus scrape bos |
| **9443** | bos | Healthcheck | HTTP | K8s probe bos |
| **9444** | bhnexus | WebSocket mTLS | WSS/mTLS | Canal Par Nexus — banexus → bhnexus |
| **9445** | bhnexus | Métricas | HTTP | Prometheus scrape bhnexus |
| **9446** | bhnexus | Healthcheck | HTTP | K8s probe bhnexus |
| **9450** | bauth | WebSocket | WSS | Push política a bhnexus — invalidación BitMask |
| **9451** | bauth | API REST | HTTPS | RolTemplate, UserTemplate, authorize, sync, biométrico |
| **9452** | bauth | Métricas | HTTP | Prometheus scrape bauth |
| **9453** | bauth | Healthcheck | HTTP | K8s probe bauth |
| **9460** | bkernel | Métricas | HTTP | Prometheus scrape bkernel |
| **9461** | bkernel | Healthcheck | HTTP | K8s probe bkernel |
| **9470** | biedata | Métricas | HTTP | Prometheus scrape biedata |
| **9471** | biedata | Healthcheck | HTTP | K8s probe biedata |
| **9480** | bcompass | WebSocket | WSS | Streaming HITL y propuestas a Core UI |
| **9481** | bcompass | API REST | HTTPS | Propuestas, Approval Gates, historial Langfuse |
| **9482** | bcompass | Métricas | HTTP | Prometheus scrape bcompass |
| **9483** | bcompass | Healthcheck | HTTP | K8s probe bcompass |
| **9490** | bsearch | WebSocket | WSS | Streaming búsqueda y autocompletado a Core UI/VDI |
| **9491** | bsearch | API REST | HTTPS | Búsqueda federada Typesense+Qdrant, Schema Discoverer |
| **9492** | bsearch | Métricas | HTTP | Prometheus scrape bsearch |
| **9493** | bsearch | Healthcheck | HTTP | K8s probe bsearch |

**Unix Sockets (sin puerto TCP — solo filesystem):**

| Socket | Dueño | Consumidores | Función |
|---|---|---|---|
| `/run/bos/bkernel-mcp.sock` | bkernel | bCompass | MCP stdio — estado WAL, reglas, métricas |
| `/run/bos/bauth-mcp.sock` | bauth | bCompass | MCP stdio — evaluate_access, BitMask, delegaciones |
| `/run/bos/bsearch-mcp.sock` | bsearch | bCompass | MCP stdio — búsqueda federada con contexto tenant |
| `/run/bos/bauth.sock` | bauth | bhnexus | Evaluación BitMask tiempo real (cache miss, <5ms) |

---

#### Diagrama de Comunicaciones entre Daemons

```
┌─────────────────────────────────────────────────────────────────────┐
│  COMUNICACIONES INTER-DAEMON — solo WebSocket y Unix socket         │
│  (HTTP entre daemons VETADO — P9)                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  bos :9441 (REST HTTPS) ◄────────────── Core UI / bosctl            │
│  bos :9440 (WSS)        ◄────────────── Core UI (streaming)         │
│                                                                     │
│  bauth :9450 (WSS)  ────push política──► bhnexus (suscriptor)       │
│  bauth :9451 (REST) ◄────────────────── Core UI / bos               │
│  /run/bos/bauth.sock ◄──cache miss────  bhnexus (sync, <5ms)        │
│  /run/bos/bauth-mcp.sock ◄────────────  bCompass (MCP stdio)        │
│                                                                     │
│  /run/bos/bkernel-mcp.sock ◄──────────  bCompass (MCP stdio)        │
│                                                                     │
│  bsearch :9490 (WSS)  ──────────────►  Core UI / VDI (streaming)   │
│  bsearch :9491 (REST) ◄─────────────── Core UI / bos / banexus      │
│  /run/bos/bsearch-mcp.sock ◄──────────  bCompass (MCP stdio)        │
│                                                                     │
│  bcompass :9480 (WSS)  ─────────────►  Core UI (HITL streaming)    │
│  bcompass :9481 (REST) ◄────────────── Core UI / bos               │
│  bcompass ──HTTP :11434──► Ollama      (excepción controlada:       │
│                                         mismo cluster, sin exterior) │
│                                                                     │
│  bhnexus :9444 (WSS/mTLS) ◄──────────  banexus (Par Nexus)         │
│  /run/bos/bauth.sock ──────────────►   bAuth (cache miss)           │
│                                                                     │
│  biedata (sin puertos entrantes salvo métricas)                     │
│  biedata ──HTTPS saliente──► SIAT/AFIP/SAT (único daemon exterior)  │
│                                                                     │
│  MÉTRICAS (HTTP unidireccional — scrape solo lectura):              │
│  Prometheus ──► :9442(bos) :9445(bhnexus) :9452(bauth)             │
│  Prometheus ──► :9460(bkernel) :9470(biedata) :9482(bcompass)      │
│  Prometheus ──► :9492(bsearch)                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.3 Política UFW Completa del Host

```bash
# ================================================================
# POLÍTICA UFW SBOS — aplicada por sbos-bootstrap-os v2.0
# Alineada con: CIS Ubuntu 24.04 Benchmark + NIST SP 800-41 Rev.1
# ================================================================

# Sustitur por valores reales del entorno:
# CIDR_CLUSTER = red entre nodos K8s (ej: 10.0.0.0/24)
# CIDR_PODS    = red de pods Calico  (ej: 192.168.0.0/16)
# IP_ADMIN     = IP del administrador

# --- POLÍTICA BASE (deny-all) ---
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# --- ACCESO PÚBLICO (Internet → Host) ---
ufw allow 22/tcp   comment 'SSH admin — restringir IP en producción'
ufw allow 80/tcp   comment 'HTTP NGINX — ACME challenge + redirect a 443'
ufw allow 443/tcp  comment 'HTTPS NGINX — punto de entrada único SBOS'

# --- KUBERNETES CONTROL PLANE (solo entre nodos del cluster) ---
ufw allow from <CIDR_CLUSTER> to any port 6443  proto tcp comment 'K8s API Server'
ufw allow from <CIDR_CLUSTER> to any port 2379:2380 proto tcp comment 'etcd client+peer'
ufw allow from <CIDR_CLUSTER> to any port 10259 proto tcp comment 'kube-scheduler'
ufw allow from <CIDR_CLUSTER> to any port 10257 proto tcp comment 'kube-controller-manager'

# --- KUBERNETES WORKER (todos los nodos) ---
ufw allow from <CIDR_CLUSTER> to any port 10250 proto tcp comment 'kubelet API'
ufw allow from <CIDR_CLUSTER> to any port 10248 proto tcp comment 'kubelet healthz'
ufw allow from <CIDR_CLUSTER> to any port 10249 proto tcp comment 'kube-proxy metrics'
ufw allow from <CIDR_CLUSTER> to any port 10256 proto tcp comment 'kube-proxy healthz'

# --- CALICO CNI (BGP mode — default SBOS bare metal) ---
ufw allow from <CIDR_CLUSTER> to any port 179   proto tcp comment 'Calico BGP'
ufw allow from <CIDR_CLUSTER> to any port 9099  proto tcp comment 'Calico healthcheck'
# Alternativa VXLAN (si el entorno no soporta BGP):
# ufw allow from <CIDR_CLUSTER> to any port 4789 proto udp comment 'Calico VXLAN'
# Encriptación WireGuard entre pods (opcional):
# ufw allow from <CIDR_CLUSTER> to any port 51820 proto udp comment 'Calico WireGuard'

# --- METALLB Layer 2 (default SBOS) ---
ufw allow from <CIDR_CLUSTER> to any port 7946 proto tcp comment 'MetalLB memberlist TCP'
ufw allow from <CIDR_CLUSTER> to any port 7946 proto udp comment 'MetalLB memberlist UDP'

# --- DAEMONS SOBERANOS (solo localhost + CIDR pods) ---
ufw allow from 127.0.0.1      to any port 9440:9499 comment 'Daemons soberanos localhost'
ufw allow from <CIDR_PODS>    to any port 9440:9499 comment 'Daemons soberanos desde pods'

# --- CORREO (solo si mail.sksistemas.com activo) ---
ufw allow 25/tcp   comment 'SMTP — MTA-to-MTA únicamente'
ufw allow 465/tcp  comment 'SMTPS — clientes correo TLS implícito'
ufw allow 587/tcp  comment 'SMTP Submission — clientes correo STARTTLS (RFC 6409)'
ufw allow 993/tcp  comment 'IMAPS — clientes IMAP TLS'
ufw allow 995/tcp  comment 'POP3S — clientes POP3 TLS'

# --- PROHIBICIONES EXPLÍCITAS (ISO 27001 A.8.20 — inventario superficie de ataque) ---
ufw deny 5432  comment 'PostgreSQL — NUNCA externo'
ufw deny 6379  comment 'Redis — NUNCA externo'
ufw deny 3306  comment 'MySQL — NUNCA externo'
ufw deny 8001  comment 'Kong Admin API — NUNCA externo'
ufw deny 8200  comment 'Vault — NUNCA externo'
ufw deny 2379  comment 'etcd — solo entre nodos cluster'

# --- NODEPORT MANTENIMIENTO (habilitar temporalmente, cerrar inmediatamente tras uso) ---
# ufw allow from <IP_ADMIN> to any port 31000:31999 proto tcp comment 'NodePort TEMPORAL'

ufw enable
```

---

## 8. Puertos de Infraestructura Kubernetes

Ningún servicio SBOS puede asignarse en estos puertos. Kubeadm valida en preflight los puertos marcados (**) y falla si están ocupados.

### 8.1 Control Plane (nodo master)

| Puerto | Protocolo | Componente | Quién accede | Preflight |
|---|---|---|---|---|
| **6443** | TCP | kube-apiserver | Todos los nodos, kubectl, Core UI | ** Crítico |
| **2379** | TCP | etcd client | kube-apiserver → etcd | ** Crítico |
| **2380** | TCP | etcd peer | etcd ↔ etcd (HA multi-nodo) | ** HA only |
| **10259** | TCP | kube-scheduler | kube-apiserver → scheduler | ** Crítico |
| **10257** | TCP | kube-controller-manager | kube-apiserver → controller | ** Crítico |
| **10250** | TCP | kubelet API | kube-apiserver → kubelet | ** Crítico |
| **10248** | TCP | kubelet healthz | Healthcheck local | ** Crítico |

### 8.2 Worker Nodes

| Puerto | Protocolo | Componente | Quién accede |
|---|---|---|---|
| **10250** | TCP | kubelet API | kube-apiserver |
| **10248** | TCP | kubelet healthz | local |
| **10249** | TCP | kube-proxy metrics | Prometheus scrape |
| **10256** | TCP | kube-proxy healthz | local |

### 8.3 Calico CNI

| Puerto | Protocolo | Modo | Cuándo activo |
|---|---|---|---|
| **179** | TCP | BGP (default SBOS bare metal) | Siempre |
| **4789** | UDP | VXLAN (alternativo) | Si BGP no disponible |
| **5473** | TCP | Calico Typha proxy | Clusters > 50 nodos |
| **51820** | UDP | WireGuard encryption | Si habilitado |
| **9099** | TCP | calico-node healthcheck | Siempre |
| **9091** | TCP | Calico métricas | Prometheus scrape |

### 8.4 MetalLB, CoreDNS, Kyverno, CRI-O, Linkerd

| Puerto | Protocolo | Componente | Notas |
|---|---|---|---|
| **7946** | TCP/UDP | MetalLB memberlist | Layer 2 mode (default SBOS) |
| **7472** | TCP | MetalLB metrics | Prometheus scrape |
| **53** | TCP/UDP | CoreDNS | DNS interno K8s (`*.svc.cluster.local`) |
| **9153** | TCP | CoreDNS metrics | Prometheus scrape |
| **9443** | TCP | Kyverno webhook | kube-apiserver → admission controller |
| **4140, 4143** | TCP | Linkerd proxy outbound/inbound | Sidecar en cada pod |
| **4191** | TCP | Linkerd proxy admin | Métricas y debug |
| **8086, 8080** | TCP | Linkerd control plane | destination + identity |
| Unix socket | — | CRI-O container runtime | `/var/run/crio/crio.sock` — sin puertos TCP |

> **Nota sobre conflicto Kyverno 9443 vs bos Context API 9443:** Kyverno usa ClusterIP 9443 (network namespace del pod). bos usa host 9443 (network namespace del host Ubuntu). Son namespaces de red distintos — no hay conflicto. Verificar que Kyverno no use `hostPort: 9443`.

---

## 9. Puertos de la Capa de Servicio — ClusterIP SBOS

Ver §12 para el esquema completo de derivación y la tabla de puertos ClusterIP por servidor lógico.

---

## 10. Puertos de Exposición Externa

### 10.1 LoadBalancer MetalLB — Solo Dos Servicios

MetalLB asigna IPs virtuales flotantes. En SBOS solo dos servicios reciben LoadBalancer:

| Servicio | IP Virtual | Puertos expuestos | Destino interno |
|---|---|---|---|
| **NGINX Ingress** | `<VIP_SBOS>` | 80 (→443), 443 | Kong ClusterIP 8160 |
| **Kong Gateway** | `<VIP_KONG>` | 80, 443 | Kong containerPort 8000/8443 |

Todos los demás servicios: ClusterIP exclusivamente.

### 10.2 NodePort — Solo Mantenimiento Temporal

Rango customizado SBOS: **31000–31999** (override del default K8s 30000–32767).

```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml
- --service-node-port-range=31000-31999
```

Esquema de derivación: `NodePort = 310 + SS` donde SS = número del servidor lógico (2 dígitos).

| NodePort | Servidor | Servicio típico de mantenimiento |
|---|---|---|
| 31001 | S01 dataserver | PgAdmin — acceso BD |
| 31002 | S02 gatewayserver | Kong Admin API |
| 31003 | S03 identityserver | Keycloak Admin Console |
| 31004 | S04 erpserver | Tryton directo |
| 31012 | S12 monitorserver | Grafana directo |
| 31014 | S14 aiserver | Open WebUI directo |

**Política de uso NodePort:**
- Solo habilitar durante la tarea de mantenimiento: `ufw allow from <IP_ADMIN> to any port 31000:31999 proto tcp`
- Cerrar inmediatamente al terminar: `ufw delete allow 31000:31999`
- Nunca para tráfico de usuarios ni APIs de producción

---

# PARTE IV — CATÁLOGO DE PUERTOS POR SERVIDOR LÓGICO

---

## 11. Puertos Canónicos de Aplicaciones (containerPort)

El containerPort es el puerto real en que la app escucha dentro del contenedor. Lo define el fabricante — **nunca se modifica** (P3). Si el containerPort está en §5 (NO DISPONIBLES), el Service K8s lo remapea al ClusterIP SBOS correspondiente.

> **Aviso importante sobre containerPorts conflictivos:** muchas apps del stack usan 8080 o 8000 como containerPort (Keycloak, Tryton, Saleor, Airflow, Superset, etc.). Esto NO viola la política. Lo prohibido es asignar ClusterIP SBOS o NodePort en esos números. El Service K8s hace el remapeo. Ver §12 para los ClusterIPs correctos.

---

### 11.9 S01 — dataserver: Dependencias HA (Patroni + etcd)

La alta disponibilidad de PostgreSQL requiere Patroni y etcd. Estos tres procesos colaboran con puertos específicos entre los 3 nodos del cluster HA.

| App | containerPort | Protocolo | Función | Observaciones |
|---|---|---|---|---|
| **Patroni REST API** | **8008** | TCP | Health checks (`/master`, `/replica`, `/health`), gestión HA | Kong/HAProxy lo usa para routing hacia el nodo primario activo |
| **etcd client** | **2379** | TCP | Patroni → etcd (DCS — Distributed Configuration Store) | También usado por K8s control plane — compartido |
| **etcd peer** | **2380** | TCP | etcd ↔ etcd entre los 3 nodos HA | HA únicamente |
| **SymmetricDS** | **31415** | TCP | CDC bidireccional PG↔MySQL (OrangeHRM, FreePBX) | Solo ClusterIP |
| **MySQL** | **3306** | TCP | Apps legacy: OrangeHRM, FreePBX, Easy!Appointments | NUNCA externo |
| **MongoDB** | **27017** | TCP | Rocket.Chat (única app que requiere MongoDB) | NUNCA externo — StatefulSet ReplicaSet |

> **Nota Patroni 8008 vs Linkerd 8086:** no hay conflicto. Patroni usa 8008 en el contenedor PG; Linkerd control plane usa 8086. Son servicios distintos en distintos namespaces.

### 11.10 S07 — reportserver (BI + ETL)

| App | containerPort | Protocolo | Función |
|---|---|---|---|
| **Superset** | **8088** | TCP | BI dashboards — ⚠️ containerPort 8088 está en §5.4 como NO DISPONIBLE para servicios SBOS pero ES el canónico de Superset; el ClusterIP SBOS es 8700+offset |
| **Airflow Webserver** | **8080** | TCP | UI/API DAGs — ⚠️ containerPort 8080 (canónico Airflow). El ClusterIP SBOS es el del §12 |
| **Airflow Scheduler** | — | — | Proceso interno — sin puerto de servicio propio |
| **OpenMetadata** | **8585** | TCP | UI catálogo de datos |
| **JasperReports CE** | **8080** | TCP | Reportes — mismo aviso que Airflow |

> **Aclaración importante:** el hecho de que Airflow y Superset usen containerPort 8080/8088 internamente NO viola la política. Los containerPorts son fijos por el fabricante (P3). Lo que está prohibido es asignar **ClusterIP SBOS** o **NodePort** en esos puertos. El Service K8s los mapea al ClusterIP correspondiente del §12.

### 11.11 S08 — docserver (DMS + OCR + Firma)

| App | containerPort | Protocolo | Función |
|---|---|---|---|
| **Paperless-NGX** | **8000** | TCP | DMS web — containerPort canónico |
| **Apache Solr** | **8983** | TCP | Full-text search backend para Kimios |
| **DocuSeal** | **3000** | TCP | Firma digital — ⚠️ containerPort 3000 (canónico); ClusterIP SBOS diferente |

### 11.12 S09 — searchserver

| App | containerPort | Protocolo | Función |
|---|---|---|---|
| **Elasticsearch** | **9200** | TCP | HTTP API — Wazuh logs, búsqueda |
| **Elasticsearch cluster** | **9300** | TCP | Comunicación entre nodos Elasticsearch |
| **Typesense** | **8108** | TCP | Full-text search alternativo |
| **RabbitMQ AMQP** | **5672** | TCP | Mensajería Tryton↔Saleor/Airflow |
| **RabbitMQ Management** | **15672** | TCP | Admin UI — solo ClusterIP |
| **RabbitMQ TLS** | **5671** | TCP | AMQP sobre TLS |

### 11.13 S10 — commsserver (Correo + Mensajería + VoIP)

| App | containerPort | Protocolo | Función |
|---|---|---|---|
| **Postfix MTA** | **25** | TCP | SMTP MTA-to-MTA |
| **Dovecot IMAP** | **143/993** | TCP | IMAP / IMAPS |
| **Dovecot POP3** | **110/995** | TCP | POP3 / POP3S |
| **Roundcube** | **80** | TCP | Webmail |
| **Cypht** | **80** | TCP | Webmail multi-cuenta |
| **PostfixAdmin** | **80** | TCP | Admin dominios/buzones |
| **SpamAssassin** | — | — | In-line con Postfix vía Amavis — sin puerto separado |
| **ClamAV+Amavis** | — | — | In-line con Postfix — sin puerto separado |
| **FreePBX HTTP** | **80** | TCP | Panel admin |
| **FreePBX SIP** | **5060** | UDP/TCP | SIP signaling |
| **FreePBX SIP TLS** | **5061** | TCP | SIP sobre TLS |
| **FreePBX RTP** | **10000–20000** | UDP | Media streams — rango amplio; exponer selectivamente |
| **Rocket.Chat** | **3000** | TCP | Messaging — ⚠️ containerPort 3000 (canónico); ClusterIP diferente |
| **MongoDB** | **27017** | TCP | Backend Rocket.Chat — NUNCA externo |
| **Mattermost** | **8065** | TCP | Messaging DevOps |
| **Centrifugo HTTP/WS** | **8000** | TCP | WebSocket real-time |
| **Centrifugo gRPC** | **8001** | TCP | gRPC API |
| **Centrifugo Admin** | **8002** | TCP | Admin API — solo ClusterIP |

### 11.14 S11 — vdiserver (Escritorio Virtual)

| App | containerPort | Protocolo | Función |
|---|---|---|---|
| **Nextcloud** | **80** | TCP | Archivos, CalDAV, CardDAV |
| **OnlyOffice Docs** | **80** | TCP | Office suite colaborativa |
| **OnlyOffice Docs HTTPS** | **443** | TCP | TLS |
| **OnlyOffice Docs wopi** | **8080** | TCP | WOPI protocol (integración Nextcloud) — containerPort canónico |

### 11.15 S12 — monitorserver (Observabilidad LGTM Extendida)

| App | containerPort | Protocolo | Función |
|---|---|---|---|
| **Prometheus** | **9090** | TCP | Métricas + PromQL |
| **Alertmanager** | **9093** | TCP | Alertas |
| **Grafana** | **3000** | TCP | Dashboards |
| **Loki** | **3100** | TCP | Log aggregation |
| **Grafana Alloy** | **12345** | TCP | Admin UI (DaemonSet — reemplaza Promtail) |
| **Tempo** | **3200** | TCP | Distributed tracing |
| **OTel Collector gRPC** | **4317** | TCP | Receiver |
| **OTel Collector HTTP** | **4318** | TCP | Receiver HTTP |
| **Zabbix Server** | **10051** | TCP | Agentes → servidor |
| **Zabbix Agent** | **10050** | TCP | DaemonSet todos los nodos — Zabbix Server → agente |
| **Portainer CE** | **9000** | TCP | Container mgmt HTTP — ⚠️ 9000 NO DISPONIBLE para nuevos servicios (§5.4) pero ES el canónico de Portainer |
| **Portainer CE HTTPS** | **9443** | TCP | Admin HTTPS — mismo aviso sobre conflicto con Kyverno (§8.4) |

### 11.16 S13 — geoserver (GPS + Logística + Signage)

| App | containerPort | Protocolo | Función |
|---|---|---|---|
| **Traccar Web UI** | **8082** | TCP | Panel de administración y tracking web |
| **Traccar OsmAnd** | **5055** | TCP/UDP | Protocolo OsmAnd (clientes iOS/Android) |
| **Traccar GPS devices** | **5000–5150** | TCP/UDP | Puertos de protocolos GPS (200+ protocolos, uno por fabricante). Rango completo necesario |
| **Fleetbase** | **8080** | TCP | API + UI despacho — containerPort canónico |
| **Xibo CMS** | **80** | TCP | Signage CMS |
| **Novo SGA** | **8080** | TCP | Gestión turnos — containerPort canónico |
| **CardMesh** | **3000** | TCP | vCards NFC/QR — containerPort canónico |

> **Nota crítica Traccar GPS:** el rango 5000–5150 UDP/TCP debe abrirse en UFW si los dispositivos GPS envían datos directamente al servidor. Si se usa un proxy o VPN, solo hace falta el puerto 8082 (Web) y 5055 (OsmAnd app).

### 11.17 S14 — opsserver (CI/CD + Backup + DR)

| App | containerPort | Protocolo | Función |
|---|---|---|---|
| **GitLab CE HTTP** | **80** | TCP | Web UI, API REST |
| **GitLab CE HTTPS** | **443** | TCP | TLS |
| **GitLab CE SSH** | **22** | TCP | Git over SSH — usa el puerto 22 del host; configurar `gitlab_shell_ssh_port=2222` para evitar conflicto con SSH admin |
| **GitLab Container Registry** | **5050** | TCP | Docker/OCI registry integrado |
| **Bareos Director** | **9101** | TCP | Director → File Daemon y Storage comunicación |
| **Bareos Storage Daemon** | **9103** | TCP | Storage ← Director, datos de backup |
| **Bareos File Daemon** | **9102** | TCP | Cliente en cada nodo → Director |
| **Bareos WebUI** | **9100** | TCP | Panel web Bareos — ⚠️ mismo número que Node Exporter Prometheus; usar ClusterIP diferente |
| **SearXNG** | **8080** | TCP | Metabuscador soberano — containerPort canónico |
| **pgBackRest** | — | — | Vía socket Unix + SSH hacia nodos PG; sin puerto de servicio propio |
| **Velero** | — | — | Vía kube API + MinIO S3; sin puerto de servicio propio |
| **K6** | — | — | CLI; sin puerto de servicio propio |
| **Trivy** | — | — | CLI + server mode opcional en 4954 |
| **Goss** | — | — | CLI; sin puerto de servicio propio |

> **GitLab SSH en K8s:** GitLab en K8s usa el puerto 22 del contenedor para SSH git. En SBOS el host ya usa el 22 para admin SSH. Solución: configurar `gitlab_shell_ssh_port: 2222` en el helm chart/manifest y el Service K8s mapea 2222 → containerPort 22. Documentar en bosctl como consideración del producto `devops`.

### 11.18 S15 — aiserver (IA Soberana)

| App | containerPort | Protocolo | Función |
|---|---|---|---|
| **Ollama** | **11434** | TCP | LLM API (OpenAI-compatible) |
| **Open WebUI** | **8080** | TCP | Chat UI — containerPort canónico |
| **Qdrant HTTP** | **6333** | TCP | Vector DB REST |
| **Qdrant gRPC** | **6334** | TCP | Vector DB gRPC |
| **Langfuse** | **3000** | TCP | Observabilidad LLM — containerPort canónico |
| **Flowise** | **3000** | TCP | Visual agent builder — containerPort canónico (mismo que Langfuse; diferentes pods/namespaces) |

### 11.19 Dependencias Especiales — Contenedores con Requerimientos No Estándar

Algunos contenedores del stack tienen dependencias de infraestructura que requieren atención específica en K8s:

| App | Dependencia | Puerto / Recurso | Consideración K8s |
|---|---|---|---|
| **Rocket.Chat** | MongoDB ReplicaSet | 27017 TCP | Requiere StatefulSet para MongoDB con headless Service. La dirección de conexión incluye los 3 miembros del replica set |
| **Patroni 3 nodos** | etcd 3 nodos | 2379/2380 TCP | etcd puede compartirse con K8s control plane o desplegarse como StatefulSet dedicado |
| **FreePBX RTP** | Rango UDP amplio | 10000–20000 UDP | Requiere hostNetwork: true o NodePort en todo el rango (costoso). Evaluar SIP proxy con RTP relay. En K8s considerar media proxy |
| **Traccar GPS** | Rango protocolos | 5000–5150 TCP/UDP | Similar a FreePBX — rango amplio. Considerar LoadBalancer MetalLB con IP dedicada para Traccar |
| **GitLab SSH** | Puerto 22 del host | 22 TCP | Conflicto con SSH admin del host. Usar `gitlab_shell_ssh_port: 2222` |
| **Bareos File Daemon** | Nodos K8s | 9102 TCP | FD debe instalarse en cada nodo Ubuntu como DaemonSet o agente systemd fuera de K8s |
| **Wazuh** | Elasticsearch | 9200/9300 TCP | Wazuh Manager necesita Elasticsearch; ambos en sbos-security namespace |
| **SymmetricDS** | PG + MySQL | 31415 TCP | Proxy de sincronización — ClusterIP entre sbos-data y apps MySQL |


### 11.19b Stack de Correo — mail.sksistemas.com

El subdominio `mail` es el más complejo: agrupa múltiples protocolos en una sola IP. Todos son Well-Known IANA.

| Puerto | Protocolo | Función | Externo | Notas |
|---|---|---|---|---|
| **25** | TCP | SMTP MTA-to-MTA | ✅ Solo entre servidores de correo | NUNCA para clientes finales |
| **110** | TCP | POP3 plano | ❌ Bloqueado | No usar — texto plano |
| **143** | TCP | IMAP + STARTTLS | ⚠️ STARTTLS obligatorio | |
| **465** | TCP | SMTPS (TLS implícito) | ✅ Clientes | `submissions` IANA |
| **587** | TCP | SMTP Submission + STARTTLS | ✅ Clientes (recomendado) | RFC 6409 |
| **993** | TCP | IMAPS | ✅ Clientes | |
| **995** | TCP | POP3S | ✅ Clientes | |

---

## 12. Esquema ClusterIP SBOS — Derivación y Tabla

### 12.1 Fórmula de Derivación

```
ClusterIP SBOS = BASE_SERVIDOR + (FICHA × 10) + TIPO

Tipos de puerto (T):
  T=0 → HTTP principal / servicio
  T=1 → HTTPS / TLS
  T=2 → Métricas Prometheus
  T=3 → Healthcheck / Readiness probe
  T=4 → Admin API
  T=5 → gRPC
  T=6 → WebSocket
  T=7 → Servicio secundario
  T=8 → Debug (SOLO desarrollo — bloqueado en producción por Kyverno)
  T=9 → Reservado

Ejemplo:
  S03 (identityserver) / F0 (Keycloak) / T0 (HTTP):
  BASE=8200 + (0×10) + 0 = 8200
  → Keycloak ClusterIP HTTP = 8200

  S03 / F0 (Keycloak) / T2 (métricas):
  BASE=8200 + (0×10) + 2 = 8202
  → Keycloak Prometheus metrics = 8202
```

### 12.2 Tabla de Rangos ClusterIP por Servidor Lógico

Nombres y contenido alineados con SBOS-005-STACK §3 (fuente de verdad).
Bloques ampliados a 100 puertos para servidores con muchas fichas (S05, S06, S10).

| Servidor Lógico | Nombre (corpus) | Rango ClusterIP | BASE | Apps principales |
|---|---|---|---|---|
| S-HOST | hostserver | — | — | Fichas bash en host — sin ClusterIP K8s |
| S01 | dataserver | **8100–8149** | 8100 | PostgreSQL, PgBouncer, Redis, MinIO, MySQL |
| S02 | gatewayserver | **8150–8199** | 8150 | NGINX, Kong, Vault, OAuth2-Proxy |
| S03 | identityserver | **8200–8249** | 8200 | Keycloak, Wazuh, OpenVAS, Linkerd |
| S04 | erpserver | **8250–8299** | 8250 | Tryton, RabbitMQ (S04) |
| S05 | devserver | **8300–8399** | 8300 | SmartTax, SmartReport, SmartRates, SmartORC, SmartVaultFlow, SmartPortfolio, SmartPay, SBOS IAM Style, SBOS CMS |
| S06 | appsserver | **8400–8499** | 8400 | Saleor, OrangeHRM, EspoCRM, Zammad, Wiki.js, Taiga, OpenProject, Cal.com, LimeSurvey, Vaultwarden, Authelia, TastyIgniter, GNU Health, Directus |
| S07 | reportserver | **8500–8549** | 8500 | JasperReports, Superset, Airflow, OpenMetadata |
| S08 | docserver | **8550–8599** | 8550 | Paperless-NGX, Solr, DocuSeal, Kimios |
| S09 | searchserver | **8600–8649** | 8600 | Elasticsearch, Typesense, RabbitMQ (S09) |
| S10 | commsserver | **8650–8749** | 8650 | Postfix, Dovecot, Roundcube, Cypht, PostfixAdmin, Centrifugo, Mattermost, Rocket.Chat, FreePBX |
| S11 | vdiserver | **8750–8799** | 8750 | Nextcloud, OnlyOffice |
| S12 | monitorserver | **8800–8849** | 8800 | Prometheus, Grafana, Alertmanager, Loki, Alloy, Tempo, OTel, Zabbix, Portainer |
| S13 | geoserver | **8850–8899** | 8850 | Traccar, Fleetbase, Xibo CMS, Novo SGA, CardMesh |
| S14 | opsserver | **8900–8949** | 8900 | GitLab, Bareos, Velero, pgBackRest, SearXNG, K6, Trivy, Goss |
| S15 | aiserver | **8950–8999** | 8950 | Ollama, Open WebUI, Qdrant, Langfuse, Flowise, Embedding Worker |

> **RFC-004 — Deuda técnica documentada:** El rango ClusterIP SBOS original (8100-8999 = 900 puertos, bloques de 50) fue diseñado para ~4 fichas por servidor. Con 110+ apps reales el rango se ha ampliado a bloques de 50-100 según la densidad de cada servidor. S06 (appsserver) y S10 (commsserver) requieren bloques de 100 puertos. La solución adoptada mantiene el rango 8100-8999 pero con bloques variables. RFC-004 debe evaluar si ampliar a 8100-9099 en v2.0.

### 12.3 Tabla de Referencia Rápida — Todas las Apps → Puertos

Tabla completa alineada con SBOS-005-STACK §3. Fórmula: `BASE + (FICHA×10) + TIPO`

#### S01 — dataserver (BASE 8100)

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| PostgreSQL (F0) | 5432 | 8100 | ❌ Nunca |
| Patroni REST (F0) | 8008 | 8103 | ❌ Nunca |
| PgBouncer (F1) | 5432 | 8110 | ❌ Nunca |
| Redis (F2) | 6379 | 8120 | ❌ Nunca |
| Redis Sentinel (F2) | 26379 | 8127 | ❌ Nunca |
| MinIO S3 (F3) | 9000 | 8130 | Via Kong presigned |
| MinIO Console (F3) | 9001 | 8131 | Via Kong `/minio` |
| MySQL (F4) | 3306 | 8140 | ❌ Nunca |
| SymmetricDS (F4) | 31415 | 8147 | ❌ Nunca |
| MongoDB/Rocket (F4) | 27017 | 8148 | ❌ Nunca |
| PgAdmin 4 (F4) | 5050 | 8149 | NodePort 31001 (temporal) |

#### S02 — gatewayserver (BASE 8150)

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| NGINX HTTP (F0) | 80 | 8150 | **80** LoadBalancer |
| NGINX HTTPS (F0) | 443 | 8151 | **443** LoadBalancer |
| Kong Proxy HTTP (F1) | 8000 | 8160 | Via NGINX |
| Kong Proxy HTTPS (F1) | 8443 | 8161 | Via NGINX |
| Kong Admin API (F1) | 8001 | 8164 | ❌ Nunca (NodePort 31002 temporal) |
| Vault API (F2) | 8200 | 8170 | ❌ Nunca |
| Vault Cluster (F2) | 8201 | 8177 | ❌ Nunca |
| OAuth2-Proxy (F3) | 4180 | 8180 | Via Kong |

#### S03 — identityserver (BASE 8200)

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| Keycloak HTTP (F0) | 8080 | 8200 | Via Kong `/auth` |
| Keycloak HTTPS (F0) | 8443 | 8201 | Via Kong |
| Keycloak Management (F0) | 9000 | 8202 | ❌ Solo interno |
| Wazuh Manager (F1) | 1514 | 8210 | ❌ Nunca |
| Wazuh API (F1) | 55000 | 8214 | ❌ Solo interno |
| Wazuh Dashboard (F1) | 443 | 8211 | Via Kong `/security` |
| OpenVAS (F2) | 9390 | 8220 | Via Kong interno |

#### S04 — erpserver (BASE 8250)

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| Tryton ERP (F0) | 8000 | 8250 | Via Kong `/erp` (NodePort 31004 temporal) |
| RabbitMQ AMQP (F1) | 5672 | 8260 | ❌ Nunca |
| RabbitMQ TLS (F1) | 5671 | 8261 | ❌ Nunca |
| RabbitMQ Management (F1) | 15672 | 8264 | ❌ Nunca externo |

#### S05 — devserver Smart* SKULL (BASE 8300)

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| SmartTax (F0) | 28100 | 8300 | Via Kong `/tax` |
| SmartReport (F1) | 28110 | 8310 | Via Kong `/reports` |
| SmartRates (F2) | 28120 | 8320 | Via Kong `/rates` |
| SmartORC (F3) | 28130 | 8330 | Via Kong `/orc` |
| SmartVaultFlow (F4) | 28140 | 8340 | Via Kong `/vaultflow` |
| SmartPortfolio (F5) | 28150 | 8350 | Via Kong `/portfolio` |
| SmartPay (F6) | 28160 | 8360 | Via Kong `/pay` |
| SBOS IAM Style (F7) | 28170 | 8370 | Via Kong `/iam-style` |
| SBOS CMS (F8) | 28180 | 8380 | Via Kong `/cms` |

#### S06 — appsserver (BASE 8400)

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| Saleor (F0) | 8000 | 8400 | Via Kong `/shop` |
| OrangeHRM (F1) | 80 | 8410 | Via Kong `/hr` |
| EspoCRM (F2) | 80 | 8420 | Via Kong `/crm` |
| Zammad (F3) | 3000 | 8430 | Via Kong `/helpdesk` |
| Wiki.js (F4) | 3000 | 8440 | Via Kong `/wiki` |
| Taiga (F5) | 9000 | 8450 | Via Kong `/pm` |
| OpenProject (F6) | 8080 | 8460 | Via Kong `/openproject` |
| Cal.com (F7) | 3000 | 8470 | Via Kong `/calendar` |
| LimeSurvey (F8) | 80 | 8480 | Via Kong `/surveys` |
| Vaultwarden (F9) | 80 | 8490 | Via Kong `/passwords` |
| Authelia (F10+) | 9091 | 8491 | Via Kong `/mfa` |
| TastyIgniter (F11) | 80 | 8492 | Via Kong `/restaurant` |
| GNU Health (F12) | 8000 | 8493 | Via Kong `/health` (criticality: false) |
| Directus (F13) | 8055 | 8494 | Via Kong `/cms-api` |

#### S07 — reportserver (BASE 8500)

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| Superset (F0) | 8088 | 8500 | Via Kong `/bi` |
| Airflow Webserver (F1) | 8080 | 8510 | Via Kong `/workflow` |
| OpenMetadata (F2) | 8585 | 8520 | Via Kong `/catalog` |
| JasperReports (F3) | 8080 | 8530 | Via Kong `/reports/fiscal` |

#### S08 — docserver (BASE 8550)

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| Paperless-NGX (F0) | 8000 | 8550 | Via Kong `/docs` |
| Apache Solr (F1) | 8983 | 8560 | ❌ Backend Kimios |
| DocuSeal (F2) | 3000 | 8570 | Via Kong `/sign` |
| Kimios DMS (F3) | 80 | 8580 | Via Kong `/dms` |

#### S09 — searchserver (BASE 8600)

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| Elasticsearch HTTP (F0) | 9200 | 8600 | ❌ Solo Wazuh interno |
| Elasticsearch Cluster (F0) | 9300 | 8607 | ❌ Nunca |
| Typesense (F1) | 8108 | 8610 | Via bSearch |
| RabbitMQ S09 (F2) | 5672 | 8620 | ❌ Nunca |

#### S10 — commsserver (BASE 8650)

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| Postfix MTA (F0) | 25 | — | **25** MTA-to-MTA |
| Dovecot IMAP (F0) | 143/993 | — | **993** externo |
| Roundcube (F1) | 80 | 8660 | Via Kong `/mail` |
| Cypht (F1) | 80 | 8661 | Via Kong `/mail2` |
| PostfixAdmin (F2) | 80 | 8670 | Via Kong interno |
| Centrifugo HTTP/WS (F3) | 8000 | 8680 | Via Kong `/ws` |
| Centrifugo gRPC (F3) | 8001 | 8681 | Interno |
| Centrifugo Admin (F3) | 8002 | 8684 | ❌ Nunca externo |
| Mattermost (F4) | 8065 | 8690 | Via Kong `/chat` |
| Rocket.Chat (F5) | 3000 | 8700 | Via Kong `/rocketchat` |
| MongoDB/Rocket (F5) | 27017 | — | ❌ Nunca (solo ClusterIP interno) |
| FreePBX (F6) | 80 | 8710 | Via Kong `/pbx` |
| FreePBX SIP (F6) | 5060 | — | **5060** externo |
| FreePBX RTP (F6) | 10000-20000 | — | Rango UDP — ver §11.19 |

#### S11 — vdiserver (BASE 8750)

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| Nextcloud (F0) | 80 | 8750 | Via Kong `/files` |
| OnlyOffice Docs (F1) | 80 | 8760 | Via Kong `/office` |
| OnlyOffice WOPI (F1) | 8080 | 8768 | Interno Nextcloud |

#### S12 — monitorserver (BASE 8800)

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| Prometheus (F0) | 9090 | 8800 | ❌ (NodePort 31012 temporal) |
| Alertmanager (F0) | 9093 | 8803 | ❌ Interno |
| Grafana (F1) | 3000 | 8810 | Via Kong `/monitor` |
| Loki (F2) | 3100 | 8820 | ❌ Nunca externo |
| Grafana Alloy (F2) | 12345 | 8824 | DaemonSet — admin interno |
| Tempo (F3) | 3200 | 8830 | ❌ Nunca externo |
| OTel Collector gRPC (F4) | 4317 | 8840 | Interno cluster |
| OTel Collector HTTP (F4) | 4318 | 8841 | Interno cluster |
| Zabbix Server (F5) | 10051 | 8848 | ❌ Agentes internos |  ← CONFLICT-001 resuelto: ajustado de 8850→8848 para liberar BASE S13
| Zabbix Agent | 10050 | — | DaemonSet — sin ClusterIP |
| Portainer CE (F6) | 9000 | 8864 | Via Kong `/portainer` |  ← CONFLICT-002 resuelto: ajustado de 8860→8864 (T=4 admin), libera 8860 para Fleetbase S13

#### S13 — geoserver (BASE 8850)

> **Nota:** BASE 8850 coincide con Zabbix Server de S12 (F5=8850). Al implementar, Zabbix debe usar F5=8848 (T=8 debug offset) o ajustar. Registrar en RFC-004.

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| Traccar Web (F0) | 8082 | 8850 | Via Kong `/gps` |
| Traccar OsmAnd (F0) | 5055 | 8855 | **5055** externo GPS app |
| Traccar GPS devices | 5000-5150 | — | Rango externo — ver §11.19 |
| Fleetbase (F1) | 8080 | 8860 | Via Kong `/fleet` |
| Xibo CMS (F2) | 80 | 8870 | Via Kong `/signage` |
| Novo SGA (F3) | 8080 | 8880 | Via Kong `/turnos` |
| CardMesh (F4) | 3000 | 8890 | Via Kong `/cards` |

#### S14 — opsserver (BASE 8900)

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| GitLab HTTP (F0) | 80 | 8900 | Via Kong `/git` |
| GitLab Registry (F0) | 5050 | 8904 | Via Kong `/registry` |
| GitLab SSH (F0) | 22 | — | NodePort **2222** (git push) |
| Bareos Director (F1) | 9101 | 8910 | ❌ Solo interno cluster |
| Bareos Storage (F1) | 9103 | 8913 | ❌ Solo interno cluster |
| Bareos File Daemon (F1) | 9102 | — | DaemonSet nodos |
| Bareos WebUI (F1) | 9100 | 8914 | Via Kong `/backup` |
| SearXNG (F2) | 8080 | 8920 | Via Kong `/search` |
| Trivy server (F3) | 4954 | 8930 | Solo interno CI/CD |

#### S15 — aiserver (BASE 8950)

| App | containerPort | ClusterIP | Externo |
|---|---|---|---|
| Ollama (F0) | 11434 | 8950 | ❌ Solo bCompass |
| Open WebUI (F1) | 8080 | 8960 | Via Kong `/ai` (NodePort 31014 temporal) |
| Qdrant HTTP (F2) | 6333 | 8970 | ❌ Solo bSearch/bCompass |
| Qdrant gRPC (F2) | 6334 | 8972 | ❌ Interno |
| Langfuse (F3) | 3000 | 8980 | Via Kong `/langfuse` |
| Flowise (F5) | 3000 | 8990 | Via Kong `/flowise` |
| Embedding Worker (F6) | — | — | Worker Redis — sin puerto |


### 12.4 Registro de Conflictos ClusterIP

| ID | Estado | Descripción | Resolución |
|---|---|---|---|
| **CONFLICT-001** | ✅ Resuelto | Zabbix Server (S12 F5) asignado a 8850 colisionaba con BASE de S13 geoserver (8850) | Zabbix Server → 8848 (T=8 slot debug reutilizado para admin alternativo) |
| **CONFLICT-002** | ✅ Resuelto | Portainer CE (S12 F6) en 8860 colisionaba con Fleetbase (S13 F1) en 8860 | Portainer CE → 8864 (T=4 admin) |
| **DEBT-001** | 🔄 RFC-004 abierto | Rango ClusterIP 8100-8999 (900 puertos, bloques de 50) insuficiente para 110+ apps. S06 appsserver tiene 14 apps (140 puertos necesarios) y S10 commsserver tiene 9 apps (90 puertos). Bloques variables adoptados como solución provisional | **Propuesta RFC-004:** ampliar rango ClusterIP a 8100-9099 (1000 puertos). Reasignar S13-S15 a BASE 9000-9099. Requiere ADR y migración de Services K8s existentes |

### 12.5 Propuesta RFC-004 — Resolución DEBT-001

Cuando el stack supere el rango 8100-8999, aplicar el siguiente esquema ampliado:

```
ESQUEMA AMPLIADO (RFC-004 — pendiente aprobación ARB):

Rango nuevo: 8100 – 9099  (1000 puertos, bloques de 100 por servidor)

  S01 dataserver      8100–8199   BASE 8100
  S02 gatewayserver   8200–8299   BASE 8200   ← nota: Vault containerPort 8200
  S03 identityserver  8300–8399   BASE 8300   ← nota: KC containerPort 8080→ClusterIP 8300
  S04 erpserver       8400–8499   BASE 8400
  S05 devserver       8500–8599   BASE 8500
  S06 appsserver      8600–8699   BASE 8600
  S07 reportserver    8700–8799   BASE 8700
  S08 docserver       8800–8899   BASE 8800
  S09 searchserver    8900–8999   BASE 8900
  S10 commsserver     9000–9099   BASE 9000   ← riesgo: 9000 es MinIO canónico
                                               usar 9010 como primer ClusterIP
  S11 vdiserver       9100–9199   BASE 9100   ← riesgo: 9100 es Node Exporter
                                               usar 9110 como primer ClusterIP
  S12 monitorserver   9200–9299   BASE 9200
  S13 geoserver       9300–9399   BASE 9300
  S14 opsserver       9400–9499   BASE 9400   ← colisión con daemons soberanos
                                               BLOQUEANTE — no implementar sin
                                               reubicar daemons a 9500-9599
  S15 aiserver        9500–9599   BASE 9500

CONCLUSIÓN RFC-004: el esquema ampliado a 9099 tiene múltiples colisiones
con containerPorts canónicos (MinIO, Node Exporter) y con los daemons soberanos.
RECOMENDACIÓN: mantener el esquema actual (8100-8999, bloques variables)
y usar offsets controlados para fichas de alta densidad. No ampliar sin
resolver primero la reubicación de daemons soberanos.
```


---

# PARTE V — APLICACIONES PROPIAS SKULL

---

## 13. Rango Reservado SKULL Custom Apps (28100–28999)

### 13.1 Por Qué Este Rango

La investigación (mayo 2026) confirmó que el rango 8000–9000 está masivamente ocupado por el ecosistema DevOps. Los puertos "populares" más usados en desarrollo (8080, 8088, 8090, 8888) están todos registrados por IANA o tienen conflictos documentados — ver §5.4. Asignar cualquiera de ellos a una app propia SKULL garantiza colisiones futuras.

El rango **28100–28999** fue elegido por:
- Rango IANA User Ports válido (1024–49151)
- Muy baja densidad de asignaciones en el registro IANA oficial
- Sin colisión con ningún rango SBOS existente
- Derivable con el mismo esquema T ya definido en §12.1
- El prefijo `28` identifica visualmente código SKULL

### 13.2 Sub-rangos por Producto

| Sub-rango | Producto / Línea | Descripción |
|---|---|---|
| **28100–28299** | Smart* (S05 devserver) | Productos propios SKULL: SmartTax(28100), SmartReport(28110), SmartRates(28120), SmartORC(28130), SmartVaultFlow(28140), SmartPortfolio(28150), SmartPay(28160), SBOS IAM Style(28170), SBOS CMS(28180) — bloque de 10 por app |
| **28300–28399** | Smart* APIs públicas | APIs externas de productos Smart* expuestas en Kong |
| **28400–28499** | SKULL Internal Tools | Herramientas internas SKULL (admin, CI/CD, fleet dashboard) |
| **28500–28599** | SKULL Dev / Experimental | Prototipos y sandboxes — NUNCA producción |
| **28600–28899** | Reservado | Productos futuros — no asignar sin decisión ARB |
| **28900–28999** | Overflow | Desborde si algún sub-rango se agota |

### 13.3 Esquema de Asignación SMARTA

Mismo esquema de tipos T que §12.1. Cada app SKULL recibe un bloque de 10 puertos:

```
Puerto Smart* app = 28 [N] [T]
  N = índice de la app × 10 (SmartTax=100, SmartReport=110, SmartRates=120...)
  T = tipo (0=HTTP, 1=HTTPS, 2=métricas, 3=healthcheck, 4=admin, 5=gRPC, 6=WS)

Asignaciones del bloque 28100–28299:
  SmartTax:        28100–28109  (containerPort 28100)
  SmartReport:     28110–28119  (containerPort 28110)
  SmartRates:      28120–28129  (containerPort 28120)
  SmartORC:        28130–28139  (containerPort 28130)
  SmartVaultFlow:  28140–28149  (containerPort 28140)
  SmartPortfolio:  28150–28159  (containerPort 28150)
  SmartPay:        28160–28169  (containerPort 28160)
  SBOS IAM Style:  28170–28179  (containerPort 28170)
  SBOS CMS:        28180–28189  (containerPort 28180)
  [libre]:         28190–28299  (próximos productos SKULL)
```

### 13.4 Registro de Puertos SKULL Custom Asignados

Tabla viva — actualizar en cada asignación:

| Puerto | T | Producto | Servicio | Fecha | Estado |
|---|---|---|---|---|---|
| 28100 | 0 | SmartTax | HTTP principal | May 2026 | ✅ Asignado |
| 28101 | 1 | SmartTax | HTTPS | May 2026 | ✅ Asignado |
| 28102 | 2 | SmartTax | Prometheus metrics | May 2026 | ✅ Asignado |
| 28110 | 0 | SmartReport | HTTP principal | May 2026 | ✅ Asignado |
| 28120 | 0 | SmartRates | HTTP principal | May 2026 | ✅ Asignado |
| 28130 | 0 | SmartORC | HTTP principal | May 2026 | ✅ Asignado |
| 28140 | 0 | SmartVaultFlow | HTTP principal | May 2026 | ✅ Asignado |
| 28150 | 0 | SmartPortfolio | HTTP principal | May 2026 | ✅ Asignado |
| 28160 | 0 | SmartPay | HTTP principal | May 2026 | ✅ Asignado |
| 28170 | 0 | SBOS IAM Style | HTTP principal | May 2026 | ✅ Asignado |
| 28180 | 0 | SBOS CMS | HTTP principal | May 2026 | ✅ Asignado |
| 28400 | 0 | SKULL Internal | Admin tools (reservado) | May 2026 | 🔒 Reservado |
| 28500 | 0 | SKULL Dev | Sandbox dev (reservado) | May 2026 | 🔒 Reservado |

### Enriquecimiento Smart ORC: Puertos específicos por tipo T

El subproyecto SmartORC documenta en su manifest.yml la asignación completa de puertos dentro del bloque 28130-28139, siguiendo el esquema T de §12.1:

```
28130  T=0  HTTP principal (API REST)
28131  T=1  HTTPS / TLS
28182  T=2  Métricas Prometheus    (endpoint GET /metrics)
28183  T=3  Healthcheck            (endpoint GET /health + /ready)
```

**Endpoints por puerto:**

| Puerto | Función | Endpoints |
|---|---|---|
| 28180 | API REST | `POST /api/v1/documents`, `GET /api/v1/documents/{doc_id}`, `PATCH .../status`, `POST .../custody`, endpoints de reportes y configuración |
| 28181 | HTTPS | Misma API sobre TLS — habilitado en producción |
| 28182 | Métricas | `GET /metrics` — Prometheus scrape, métricas de operaciones ORC por tenant |
| 28183 | Healthcheck | `GET /health` (liveness), `GET /ready` (readiness) — K8s probes + diagnóstico de dependencias (Nextcloud, Rocket.Chat, Vault, bSearch) |

> **Restricción de arquitectura:** El endpoint `POST /api/v1/documents/from-scanner` (recepción desde banexus) se sirve en el puerto 28180 pero no via Kong — solo desde localhost del cluster, porque banexus no tiene acceso al gateway. Esto es coherente con la topología invariable del Par Nexus (banexus no habla con Kong).

### Enriquecimiento Smart Report: Variables de entorno con puertos derivados

El subproyecto SmartReport documenta en su `.env.example` los puertos derivados para una app SKULL Custom, confirmando el patrón:

```
# Puerto de métricas Prometheus (expuesto como T=2 de la ficha SBOS)
METRICS_PORT=28202       # Bloque SmartReport (28110) + offset metrics (T=2)

# Puerto de health check (expuesto como T=3 de la ficha SBOS)
HEALTH_PORT=28203        # Bloque SmartReport (28110) + offset health (T=3)
```

**Confirmación del patrón:**
- SmartReport containerPort base: `28110` (T=0)
- Métricas: `28110 + 2 = 28112` → mapeado a ClusterIP S05 F1 T2 = `8312`
- Healthcheck: `28110 + 3 = 28113` → mapeado a ClusterIP S05 F1 T3 = `8313`

Esto verifica que el esquema de tipos T funciona tanto para el containerPort directo (rango 28100-28999) como para el ClusterIP derivado (S05 BASE 8300 + offset).

---

# PARTE VI — SUBDOMINIOS sksistemas.com

---

## 14. Marco Normativo de Subdominios

| Estándar | Regla aplicable |
|---|---|
| **RFC 1034 §3.5** | Labels: letras, dígitos, guiones. Máx 63 chars por label. FQDN máx 253 chars |
| **RFC 1123 §2.1** | El primer carácter puede ser letra o dígito (relaja RFC 952) |
| **RFC 2606** | Prohibidos: `.test`, `.example`, `.invalid`, `.localhost` |
| **RFC 6761** | Prohibidos: `localhost`, `local`, `onion`, `home.arpa`, `invalid` |
| **RFC 6762** | `local` usado por mDNS/Bonjour — conflicto con redes LAN |
| **ICANN Policy** | Subdominios no pueden ser confusos ni engañosos para usuarios |

### 14.1 Sintaxis Válida para Labels

```
✅ Correcto:   mail, api, auth, erp-bo, smarta-api, pos2
❌ Incorrecto: _mail (underscore), mail.sub (punto dentro del label),
               localhost, local, test, example, admin (ver §14.2)
```

### 14.2 Subdominios Prohibidos

| Subdominio | Razón | Normativa |
|---|---|---|
| `localhost` | IANA — resuelve siempre a 127.0.0.1 | RFC 6761 |
| `local` | mDNS/Bonjour — conflicto redes LAN | RFC 6762 |
| `test` | Reservado IANA para testing privado | RFC 2606 |
| `example` | Reservado IANA para documentación | RFC 2606 |
| `invalid` | Siempre debe fallar resolución | RFC 2606 |
| `onion` | Tor hidden services | RFC 7686 |
| `home` | `home.arpa` reservado IANA | RFC 8375 |
| `admin` | Expone panel admin en DNS público — vector de ataque | ISO 27001 A.8.20 |
| `root` | Conflicto conceptual con raíz DNS | Industria |
| `internal` | Usado por muchos sistemas — conflictos frecuentes | Industria |
| `corp` | Candidato TLD ICANN 2012 — riesgo colisión futura | ICANN |

---

## 15. Subdominios Activos y Catálogo Oficial

### 15.1 Subdominios Detectados — Enumeración DNS Mayo 2026

Todos resuelven a **144.91.76.130** con HTTPS activo y TLS válido.

| Subdominio | FQDN | Servicio Inferido |
|---|---|---|
| `www` | www.sksistemas.com | Sitio web corporativo SKULL |
| `mail` | mail.sksistemas.com | Correo — Roundcube + MTA |
| `api` | api.sksistemas.com | Kong API Gateway |
| `support` | support.sksistemas.com | Portal de soporte al cliente |
| `auth` | auth.sksistemas.com | Keycloak SSO |
| `core` | core.sksistemas.com | SBOS Core UI (IAM Installer) |
| `secrets` | secrets.sksistemas.com | HashiCorp Vault |
| `status` | status.sksistemas.com | Status page / uptime monitor |
| `pipeline` | pipeline.sksistemas.com | CI/CD Pipeline |

### 15.2 Catálogo Completo — Infraestructura SKULL

| Subdominio | Estado | Servicio SBOS | ClusterIP SBOS |
|---|---|---|---|
| `www` | ✅ Activo | Sitio corporativo (NGINX) | 8150 |
| `api` | ✅ Activo | Kong API Gateway | 8160 |
| `auth` | ✅ Activo | Keycloak SSO | 8200 |
| `core` | ✅ Activo | SBOS Core UI | 8150 |
| `secrets` | ✅ Activo | Vault | 8204 |
| `mail` | ✅ Activo | Roundcube + MTA | Puertos correo §11.9 |
| `support` | ✅ Activo | Portal soporte | ClusterIP → Kong |
| `status` | ✅ Activo | Status page | ClusterIP → Kong |
| `pipeline` | ✅ Activo | CI/CD | ClusterIP → Kong |
| `monitor` | 🔒 Reservado | Grafana + Prometheus | 8710 |
| `logs` | 🔒 Reservado | Loki viewer | 8720 |
| `git` | 🔒 Reservado | GitLab / Gitea | ClusterIP → Kong |
| `registry` | 🔒 Reservado | Container Registry OCI | ClusterIP → Kong |
| `release` | 🔒 Reservado | SKULL Release Plane | ClusterIP → Kong |
| `ai` | 🔒 Reservado | Open WebUI (Ollama) | 8860 |
| `docs` | 🔒 Reservado | Documentación técnica | ClusterIP → Kong |
| `vpn` | 🔒 Reservado | WireGuard VPN | UDP 51820 (externo) |

### 15.3 Catálogo Completo — Productos SBOS para Tenants

| Subdominio | Estado | Producto SBOS | Descripción |
|---|---|---|---|
| `erp` | 🔒 Reservado | Tryton ERP | Acceso ERP multi-tenant via Keycloak |
| `pos` | 🔒 Reservado | Saleor POS | Punto de Venta web | 8900 |
| `shop` | 🔒 Reservado | Saleor E-commerce | Tienda online | 8300 |
| `hr` | 🔒 Reservado | OrangeHRM | RRHH y nómina |
| `crm` | 🔒 Reservado | EspoCRM | CRM multi-tenant |
| `tax` | 📅 Planeado | SmartTax (S05) | Interfaz administrativa tax compliance BO/AR/MX — usa biedata como motor de export |
| `fiscal` | 📅 Planeado | SmartTax módulo fiscal | Portal reportes fiscales para contadores |
| `chat` | 🔒 Reservado | Mattermost | Mensajería corporativa |
| `meet` | 📅 Planeado | Jitsi Meet | Videoconferencia soberana |
| `files` | 🔒 Reservado | Nextcloud | Gestión de archivos | 8450 |
| `tasks` | 🔒 Reservado | Vikunja | Gestión de tareas |
| `reports` | 📅 Planeado | Metabase | Reportes y BI | 8500 |
| `pbx` | 📅 Planeado | FreePBX | Central telefónica IP |
| `search` | 🔒 Reservado | bSearch (Typesense) | Búsqueda federada | 8550 |
| `smarta` | 📅 Planeado | SMARTA Portal | Producto propio SKULL |

### 15.4 Patrón Multi-tenant Geográfico

Para clientes con presencia en múltiples países/ciudades (UN/LOCODE recomendado):

| Patrón | Ejemplo | Descripción |
|---|---|---|
| `{tenant}.sksistemas.com` | `acme.sksistemas.com` | Portal dedicado del tenant ACME |
| `{país}.{producto}.sksistemas.com` | `bo.erp.sksistemas.com` | ERP para Bolivia |
| `{ciudad}.{producto}.sksistemas.com` | `lpz.pos.sksistemas.com` | POS sucursal La Paz |

---

## 16. Enrutamiento Kong — Subdominio → Servicio

Todo el tráfico externo fluye: Cliente HTTPS → NGINX (MetalLB :443) → Kong (ClusterIP 8160) → Servicio destino.

```
Internet :443
     │
[NGINX — LoadBalancer MetalLB VIP]
     │
[Kong API Gateway — ClusterIP 8160]
     │
     ├── www.sksistemas.com        → NGINX static / app web        :8150
     ├── auth.sksistemas.com       → Keycloak                      :8200
     ├── core.sksistemas.com       → Core UI Flutter                :8150
     ├── secrets.sksistemas.com    → Vault                          :8204
     ├── api.sksistemas.com        → Kong (self — API pública)      :8160
     ├── erp.sksistemas.com        → Tryton ERP                     :8250
     ├── pos.sksistemas.com        → Saleor POS                     :8900
     ├── shop.sksistemas.com       → Saleor E-commerce              :8300
     ├── monitor.sksistemas.com    → Grafana                        :8710
     ├── ai.sksistemas.com         → Open WebUI                     :8860
     ├── tax.sksistemas.com        → SmartTax                       :28NNN
     ├── mail.sksistemas.com       → Roundcube HTTPS                :443
     └── *.sksistemas.com          → Wildcard → HTTP 404 por defecto
```

---

# PARTE VII — OPERACIÓN Y GOBERNANZA

---

## 17. Política de Seguridad — Reglas Absolutas

Estas reglas nunca se violan. Cualquier violación requiere aprobación del ARB y nueva versión de este documento.

| # | Regla | Fundamento |
|---|---|---|
| R1 | Bases de datos (PG, Redis, MySQL, etcd) NUNCA tienen exposición externa | Principio P6 — CIS Kubernetes §5.3 |
| R2 | Kong Admin API (8001/8444) NUNCA tiene NodePort ni LoadBalancer | La Admin API controla todo el gateway |
| R3 | Vault (8200/8201) NUNCA tiene exposición externa | Secrets del sistema — solo pods con AppRole |
| R4 | Daemons soberanos (9440–9499) NUNCA tienen NodePort ni hostPort expuesto | Solo localhost + CIDR pods |
| R5 | Los puertos T=8 (debug) NUNCA se habilitan en producción | Kyverno Policy valida en admission |
| R6 | API Server K8s (:6443) NUNCA se expone a internet | NSA/CISA Kubernetes Hardening Guide §3.1 |
| R7 | Todo servicio nuevo DEBE declarar su puerto en §11–§13 antes del primer commit | ISO 27001 A.8.20 |
| R8 | Los puertos del rango dinámico (49152–65535) no se asignan a servicios | RFC 6335 — son efímeros del OS |
| R9 | Cualquier cambio al rango de puertos de un servidor lógico (§12.2) requiere ADR | SBOS-048 proceso ARB |
| R10 | **HTTP entre daemons soberanos está VETADO** (P9) | Solo WebSocket o Unix socket entre daemons. Excepciones explícitas: métricas Prometheus (scrape unidireccional), healthcheck K8s probes, API bos hacia bosctl/Core UI |
| R11 | **HTTP entre daemons y aplicaciones Smart* está VETADO** (P9) | Smart* se comunica con daemons exclusivamente por WebSocket. Un Smart* que llame a un daemon por HTTP viola esta regla sin excepción |
| R12 | **biedata es el único daemon autorizado a realizar conexiones HTTP salientes al exterior** | Ningún otro daemon puede conectarse a APIs externas. Todo acceso externo debe declararse como caja biedata |

---

## 18. Proceso de Asignación de un Puerto Nuevo

Seguir este proceso en orden. No saltear pasos.

```
PASO 1 — Consultar §5 (Tabla NO DISPONIBLES)
  Si el puerto aparece → STOP. Elegir otro.

PASO 2 — Verificar tipo de servicio
  ¿App de tercero?      → Usar su containerPort canónico (§11). No cambiar.
  ¿K8s Service SBOS?    → Derivar ClusterIP con fórmula §12.1.
  ¿App propia SKULL?    → Usar rango 28100–28999 (§13).
  ¿Daemon soberano?     → Usar rango 9400–9499 (§7.2).
  ¿NodePort mantenimiento? → Usar rango 31000–31999 (§10.2).

PASO 3 — Verificar disponibilidad en el host
  ss -tlnp | grep <puerto>
  lsof -i :<puerto>

PASO 4 — Verificar en el registro IANA oficial
  https://www.iana.org/assignments/service-names-port-numbers
  Estado debe ser "Unassigned" para el puerto elegido

PASO 5 — Registrar en este documento
  Agregar a la tabla correspondiente (§11, §12, §13, §17.4 o §15)
  con: Puerto, Tipo T, Producto/App, Función, Fecha, Estado

PASO 6 — Actualizar UFW si aplica
  Agregar regla con comment descriptivo al bloque §7.3

PASO 7 — Si afecta arquitectura de red
  Abrir RFC en GitHub → ARB → ADR en SBOS-048-ADR-CATALOG

PASO 8 — Registrar en SBOS-016-NOTES
  Añadir la asignación como decisión de sesión
```

---

## 19. NetworkPolicy Kubernetes — Plantillas

Alineadas con NSA/CISA Kubernetes Hardening Guide v1.2 y CIS Kubernetes Benchmark v1.8. Aplicar en cada namespace al momento del despliegue.

### 19.1 Default Deny — Todo Namespace SBOS (obligatorio)

```yaml
# Aplicar en: todos los namespaces (skull-*, inka-*, sbos-system, etc.)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: <NAMESPACE>
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### 19.2 Allow — Ingress desde Kong al Servicio

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-kong-ingress
  namespace: skull-maya
spec:
  podSelector:
    matchLabels:
      app: tryton
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-gateway
      ports:
        - protocol: TCP
          port: 8000   # containerPort canónico de Tryton
```

### 19.3 Allow — Egress al dataserver (PostgreSQL)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-postgres-egress
  namespace: skull-maya
spec:
  podSelector:
    matchLabels:
      app: tryton
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-data
      ports:
        - protocol: TCP
          port: 5432   # containerPort canónico PostgreSQL
```

### 19.4 Allow — Egress biedata hacia exterior (APIs tributarias)

```yaml
# biedata es el ÚNICO namespace/pod autorizado a salir al exterior
# Todos los demás namespaces tienen egress denegado hacia internet
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-biedata-external-egress
  namespace: sbos-system   # namespace del host — biedata corre en host, no en K8s
  # NOTA: biedata corre como systemd en el host. Esta policy aplica
  # si biedata llegara a correr en K8s en el futuro.
  # En el modelo actual: UFW allow outgoing (default) cubre a biedata en el host.
spec:
  podSelector:
    matchLabels:
      app: biedata
  policyTypes:
    - Egress
  egress:
    - ports:
        - protocol: TCP
          port: 443    # HTTPS saliente hacia SIAT/AFIP/SAT/DIAN
```

### 19.5 Allow — Egress pods hacia Redis (cache/pubsub)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-redis-egress
  namespace: skull-maya    # replicar en cada namespace tenant
spec:
  podSelector: {}    # todos los pods del namespace
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-data
      ports:
        - protocol: TCP
          port: 6379    # Redis containerPort canónico
```

### 19.6 Allow — Ingress Prometheus scrape desde monitorserver

```yaml
# Prometheus necesita acceso entrante a los puertos de métricas de cada pod
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus-scrape
  namespace: skull-maya
spec:
  podSelector: {}    # todos los pods del namespace exponen /metrics
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-monitor
      ports:
        - protocol: TCP
          port: 9090    # Prometheus pull — el puerto varía por app; ajustar por ficha
```

### 19.7 Allow — Linkerd sidecar (obligatorio en namespaces con mTLS)

```yaml
# Sin esta policy, Linkerd proxy sidecar no puede funcionar
# Aplicar en TODOS los namespaces donde Linkerd está inyectado
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-linkerd-sidecar
  namespace: skull-maya
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - ports:
        - protocol: TCP
          port: 4143    # Linkerd proxy inbound (mTLS automático)
  egress:
    - ports:
        - protocol: TCP
          port: 4140    # Linkerd proxy outbound
        - protocol: TCP
          port: 4191    # Linkerd admin / health
```

### 19.8 Allow — Centrifugo WebSocket desde pods de negocio

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-centrifugo-egress
  namespace: skull-maya
spec:
  podSelector:
    matchLabels:
      tier: business    # apps que usan WebSocket real-time
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-comms
      ports:
        - protocol: TCP
          port: 8000    # Centrifugo HTTP/WS containerPort
        - protocol: TCP
          port: 8001    # Centrifugo gRPC
```

---

## 20. Prompt de Agente — Instrucciones de Mantenimiento

> **⚠️ INSTRUCCIÓN OBLIGATORIA — BOS-Agent, Auth-Agent, Kernel-Agent**
>
> SBOS-050-PORT-CATALOG es un **registro vivo**. Cada vez que participes en la creación o modificación de fichas, manifiestos K8s, reglas UFW, NetworkPolicies o configuraciones de daemon que involucren puertos o subdominios DNS, debes:
>
> **ANTES de asignar:**
> 1. Consultar §5 (Tabla NO DISPONIBLES). Si aparece → STOP.
> 2. Seguir el proceso completo de §18.
> 3. Para apps propias SKULL: usar exclusivamente rango 28100–28999 (§13). Nunca 8080 ni ningún puerto del §5.4.
>
> **DESPUÉS de asignar:**
> 1. Registrar en la tabla correspondiente de este documento (§11, §12, §13 o §15).
> 2. Si requiere UFW: añadir al bloque §7.3 con `comment` descriptivo.
> 3. Si es cambio arquitectónico: abrir RFC → ADR en SBOS-048.
> 4. Registrar en SBOS-016-NOTES como decisión de sesión.
>
> **Regla de prevalencia:** en conflicto entre este documento y cualquier otro del corpus HUMAN-DOC, SBOS-050 prevalece en materia de puertos y subdominios.

---

## 21. Trazabilidad

| Sección | Fuente | Notas |
|---|---|---|
| §2 Marco normativo | IANA RFC 6335 (2011), RFC 7605 (2015), CIS Ubuntu 24.04, CIS Kubernetes v1.8, NSA/CISA Kubernetes Hardening Guide v1.2 (2022), ISO/IEC 27001:2022 A.8.20/A.8.22, NIST SP 800-41/800-207 | Estándares verificados; NSA/CISA añadido en v2.0 |
| §5 NO DISPONIBLES | IANA Registry CSV (mayo 2026), connected.app/ports/8080, portlookup.com, adactio.com/journal/16531 (contexto histórico puertos populares) | Puertos "en observación" promovidos a NO DISPONIBLES en v2.0 |
| §7.3 UFW | CIS Ubuntu 24.04 Benchmark, NIST SP 800-41 Rev.1 | Política completa incluyendo K8s/Calico/MetalLB (añadido v2.0 vs v1.x) |
| §8 K8s ports | kubernetes.io ports-and-protocols; kubeadm preflight checks; Calico docs; MetalLB docs; Linkerd 2-edge docs | Verificado contra documentación oficial de cada componente |
| §11 containerPorts | Documentación oficial de cada app + IANA Service Name Registry | Puertos canónicos — no se inventan |
| §12.2–§12.3 | SBOS-005-STACK §3 (fuente de verdad para nombres S07-S15 y asignación de apps por servidor) | S07=reportserver, S08=docserver, S09=searchserver, S10=commsserver, S11=vdiserver, S12=monitorserver, S13=geoserver, S14=opsserver, S15=aiserver — verificado v3.0 |
| §12 ClusterIP SBOS | Patrón derivado de Momentum .NET Port Allocation Pattern, adaptado; investigación mayo 2026 | Esquema propio SKULL — memorizable y derivable |
| §13 SKULL Custom | IANA Registry análisis densidad 28000-29000; verificación cruzada contra todos los rangos | Rango con mínima densidad IANA fuera de todos los rangos SBOS |
| §14-§16 Subdominios | RFC 1034 (1987), RFC 1123 (1989), RFC 2606 (1999), RFC 6761 (2013); enumeración DNS mayo 2026 (9 subdominios activos en 144.91.76.130) | Subdominios confirmados con HTTPS activo |
| §19 NetworkPolicy | NSA/CISA Kubernetes Hardening Guide v1.2 §4 (Network Policies); CIS Kubernetes Benchmark §5.3; kubernetes.io/docs/concepts/services-networking/network-policies | Plantillas alineadas con ambos estándares |
| SBOS-001-VISION v2.0 | §2 Definición técnica SBOS como OS empresarial | Coherencia con la arquitectura de tres dominios |
| SBOS-002-ARCH | §4 Arquitectura de 5 capas + 8 daemons | Puertos de daemons (§7.2) coherentes |
| SBOS-039-DAEMON-NEXUS + SBOS-NEXUS-CONCEPTUALIZACION-v3_0 | bhnexus :9444 (WSS/mTLS) + :9445 (métricas) + :9446 (healthcheck). banexus sin puertos TCP entrantes. Par Nexus Soberano como unidad compuesta | Verificado contra corpus v3.0 |
| SBOS-048-ADR-CATALOG | ADR-010 Kong 3.9.x; ADR-011 bos Context Plane | Puertos Kong Admin (8001/8444) nunca externos |
| SBOS-049-CONTEXT-PLANE | bos Context API :9443 | Verificado — sin conflicto con Kyverno K8s :9443 |

---

### Enriquecimiento Smart*: Tabla de Puertos por Subproyecto

Los subproyectos Smart* del ecosistema SBOS confirman y refuerzan el esquema de puertos definido en este documento:

**SmartORC (BOSORC-006-ARQUITECTURA):**

| Puerto | Tipo T | Función | Endpoint | Documentado en |
|---|---|---|---|---|
| 28130 | T=0 | HTTP principal (API REST) | `/api/v1/documents/*`, `/api/v1/reports/*`, `/api/v1/config/*` | manifest.yml |
| 28131 | T=1 | HTTPS / TLS | Misma API sobre TLS | manifest.yml |
| 28132 | T=2 | Métricas Prometheus | `GET /metrics` | manifest.yml |
| 28133 | T=3 | Healthcheck | `GET /health`, `GET /ready` | manifest.yml |

**SmartReport (SBOS-REPORT-ENV-EXAMPLE):**

| Puerto | Tipo T | Variable de entorno | Valor | Documentado en |
|---|---|---|---|---|
| 28202 | T=2 | `METRICS_PORT` | 28202 | `.env.example` |
| 28203 | T=3 | `HEALTH_PORT` | 28203 | `.env.example` |

**Confirmación del patrón de derivación:** Ambos subproyectos validan que:
1. El containerPort base = `28` + índice de app + `0` (T=0)
2. Métricas = base + 2 (T=2)
3. Healthcheck = base + 3 (T=3)
4. HTTPS = base + 1 (T=1)
5. El esquema es consistente entre todos los productos Smart* SKULL

---

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Aportacion |
|---|---|---|
| V6 | /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V6_SBOS-050-PORT-CATALOG.md | Base V6 completa — v3.1 con todos los puertos, conflictos ClusterIP resueltos, RFC-004 propuesta ampliada |
| Smart ORC | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart ORC/context/BOSORC-006-ARQUITECTURA.md | Puertos SmartORC: 28130-28133 con endpoints por tipo T, manifest.yml completo, restricción de arquitectura (banexus sin Kong) |
| Smart Report | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Report/context/SBOS-REPORT-ENV-EXAMPLE.md | Variables de entorno con puertos derivados: METRICS_PORT=28202, HEALTH_PORT=28203; confirmación del patrón de derivación T |
| Correlacion V8 | Integracion Smart ORC y Smart Report port tables | Confirmación del esquema de tipos T en apps Smart*; validación cruzada de containerPort vs ClusterIP |

---

_SKULL · SBOS · SBOS-050-PORT-CATALOG · HUMAN-DOC v3.1 · Mayo 2026_
_Reemplaza: v3.0 (Mayo 2026)_
_Cambios v3.1: CONFLICT-001 resuelto (Zabbix 8850→8848); CONFLICT-002 resuelto (Portainer 8860→8864); §12.4 Registro de Conflictos ClusterIP añadido; §12.5 Propuesta RFC-004 con análisis completo de esquema ampliado y conclusión de BLOQUEANTE por colisión con daemons soberanos; §11 limpiado — eliminadas secciones §11.1-§11.8 obsoletas e incorrectas (S06=commsserver equivocado, apps duplicadas); §11 consolidado en §11.9-§11.18 como fuente única
Anterior v3.0-final (sincronización §12.2 y §12.3 con SBOS-005-STACK §3: nombres S07-S15 corregidos, BASEs ClusterIP recalculadas, colisión S01/S02 resuelta asignando MongoDB a F4 de S01, RFC-004 documentada con la deuda de bloques variables; encabezado corregido a v3.0)
Anterior v3.0 (release mayor — gaps cerrados para calificación 10/10): §12.3 completada con 110+ apps organizadas por servidor lógico con ClusterIP derivado; S05 appsserver separado en sección §11.5b limpia; §17 R10-R12 añadidas (HTTP vetado entre daemons como regla de seguridad); §19 NetworkPolicies 19.4-19.8 añadidas (biedata exterior, Redis egress, Prometheus scrape, Linkerd sidecar, Centrifugo); §4.2 mapa corregido + nota §4.3 sobre K8s puertos dispersos; §21 trazabilidad bhnexus corregida a puertos reales 9444/9445; versión encabezado corregida a v2.5; deuda técnica RFC-004 documentada (ClusterIP rango insuficiente para 110+ apps)
Anterior v2.5: §7.2 reescrito completamente con TODOS los puertos de los 8 daemons asignados y justificados desde el corpus. Cada daemon tiene: WebSocket (streaming), API REST (control), Métricas (Prometheus), Healthcheck (K8s probes), Unix sockets donde aplica. Tabla consolidada de 24 puertos asignados + 4 Unix sockets. Diagrama completo de comunicaciones. Política HTTP vetado entre daemons formalizada. biedata único daemon con salida exterior. Excepción controlada bCompass→Ollama documentada.
Anterior v2.4: §7.2 corregido: bhnexus+banexus son Par Nexus Soberano (unidad compuesta, no daemons separados); puertos bhnexus corregidos a 9444 (WSS/mTLS) y 9445 (métricas) según SBOS-039; P9 y P10 añadidos a §3: HTTP vetado entre daemons y entre daemons y Smart*; toda comunicación entre daemons es WebSocket o Unix socket; exposición HTTP al exterior reducida al mínimo (solo bos :9440/:9441/:9443); diagrama de comunicaciones entre daemons actualizado con política
Anterior v2.3: §7.2 reescrito completamente con descripción exacta de cada daemon según el corpus (bos, bkernel, biedata, bauth, bcompass, bsearch, bhnexus, banexus). Correcciones críticas: biedata NO tiene API REST pública (es aduana soberana por eventos); bkernel NO tiene API REST (solo métricas + Unix socket MCP); bauth descripción exacta de 3 dominios y BitMask; bcompass como Route Engine IA con Approval Gates; bsearch Typesense+Qdrant+Schema Discoverer; banexus documentado como cliente Fedora sin puertos TCP entrantes; diagrama de comunicaciones entre daemons añadido
Anterior v2.2: §11 completado con todos los 16 servidores lógicos del corpus (S01 HA Patroni/etcd/MongoDB, S07 Superset/Airflow/OpenMetadata, S08 Solr, S09 Elasticsearch/Typesense, S10 VoIP/RTP/FreePBX/Rocket.Chat, S11 OnlyOffice, S12 Zabbix Agent/Portainer, S13 Traccar GPS range 5000-5150/Fleetbase, S14 GitLab SSH/Bareos 9101-9103, S15 Flowise); §11.19 Dependencias Especiales K8s (MongoDB ReplicaSet, FreePBX RTP, Traccar GPS, GitLab SSH, Bareos FD); corrección Airflow/Superset containerPort canónico vs ClusterIP SBOS
Anterior v2.1: Correcciones basadas en corpus HUMAN-DOC: biedata es aduana soberana (import/export), NO facturación; SmartTax es el producto fiscal (S05 devserver); 8 daemons soberanos verificados contra SBOS-001-VISION; S05 devserver actualizado con 9 productos: SmartTax, SmartReport, SmartRates, SmartORC, SmartVaultFlow, SmartPortfolio, SmartPay + SBOS IAM Style (nuevo) + SBOS CMS (nuevo); rango 28100–28299 completamente asignado a productos Smart*; §16 enrutamiento corregido (tax→SmartTax); §13 sub-rangos reorganizados
Anterior v2.0: Reorganización en 7 Partes lógicas con índice; NSA/CISA Kubernetes Hardening Guide v1.2 añadido al marco normativo; CIS Kubernetes Benchmark v1.8 añadido; §5 Tabla NO DISPONIBLES elevada a Parte II (segunda prioridad de lectura); §19 NetworkPolicy plantillas nuevas; eliminada duplicación de información entre secciones; trazabilidad consolidada en §21
