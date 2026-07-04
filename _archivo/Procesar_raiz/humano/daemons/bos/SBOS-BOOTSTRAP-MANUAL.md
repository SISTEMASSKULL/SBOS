# Especificación de Desarrollo — IAM Installer + 19 Fichas Iniciales
## Garantía de Instalación Completa hasta BOS Totalmente Operativo · v3.2 · Junio 2026
### SKULL · SBOS · Documento de Desarrollo para el Agente bos (pane 1)

---

## Prefacio

### ⚠️ ESTA ESPECIFICACIÓN ES SOLO LA RUTINA DE BOOTSTRAP

Este documento define **únicamente** la rutina para romper el ciclo del huevo y la gallina
durante la instalación inicial de las 19 fichas. **No define qué es BOS.** BOS es el
**Plano de Control Soberano del SBOS** y su alcance completo está definido en:

| Documento | Define |
|-----------|--------|
| **SBOS-018-DAEMON-BOS.md** (BOS_V8) | Qué es BOS, 3 planos, 15 principios, Release Plane, Sagas, Multi-tenant, 25 secciones |
| **CLAUDE.md del agente bos** | Responsabilidades completas: Day 0/1/2, 23 comandos bosctl, Context Plane, 112+ fichas |
| **BOS_V8** (51 docs) | Arquitectura completa del ecosistema SBOS |
| **SBOS-049-CONTEXT-PLANE.md** | BOS como dueño del Context Plane, ctx_id, API de contexto |

### ADRs vinculados (obligatorio cumplimiento)

| ADR | Aplica a esta especificación |
|-----|------------------------------|
| **ADR-019** | BOS Interface Dual: CLI + JSON-RPC 2.0 sobre `/run/bos/bos.sock` |
| **ADR-020** | Interface Dual obligatoria para todos los daemons (WebSocket + JSON-RPC 2.0) |
| **ADR-021** | Máquina de 18 estados de ficha (PENDIENTE → LISTA → INSTALANDO → ... → DESINSTALADA) |
| **ADR-017** | Versiones canónicas verificadas (Ubuntu 26.04, PG 18.4, Redis 8.6.2, KC 26.6.2, Vault 2.0.1) |

### Código desarrollado por bos (Iteración 1 — Junio 2026)

| Archivo | Líneas | Función |
|---------|--------|---------|
| `scripts/install.sh` | 522 | Script principal de instalación del IAM Installer |
| `scripts/host-setup.sh` | 84 | Preparación del host Ubuntu 26.04 |
| `scripts/verify-independiente.sh` | 150+ | Verificación independiente del entorno |
| `internal/domain/ficha_service.go` | 98 | Lógica de dominio para operaciones sobre fichas |
| `internal/domain/types.go` | 121 | Tipos: SagaOutcome, FichaInfo, BootstrapStatus, CtxID, PgAuxiliar |
| `internal/domain/bootstrap_service.go` | 100+ | Servicio de bootstrap con 18 estados |
| `internal/domain/ctx_service.go` | 80+ | Servicio de Context Plane (SBOS-049) |
| `internal/domain/pg_auxiliar_service.go` | 250+ | PostgreSQL auxiliar anti-pérdida |
| `internal/server/jsonrpc.go` | 483 | Servidor JSON-RPC 2.0 completo |
| `internal/server/api.go` | 140+ | API HTTP + registro `/rpc` |
| `internal/server/bootstrap.go` | 200+ | Handlers de bootstrap |
| `internal/installer/saga.go` | 280+ | Motor de sagas con compensación |
| `internal/installer/pg_auxiliar.go` | 150+ | Implementación PG auxiliar |

**El agente bos NO debe limitarse a esta especificación.** Después de certificar el
bootstrap, debe continuar con Day 1, Day 2, Context Plane, Release Plane y 112+ fichas.

### Qué cubre esta especificación

El **contrato de aceptación** para la rutina de bootstrap: garantizar que al final del
proceso existe un **cluster Kubernetes real (kubeadm) con Calico 100% configurado,
19 fichas iniciales instaladas y verificadas, y el VDI (Virtual Desktop Infrastructure)
operativo para que el usuario acceda a la Core UI y administre sus fichas de negocio**.

### Objetivo final verificable

```
USUARIO FINAL (cliente)
    │
    ▼
VDI — Fedora KDE Plasma (S11 vdiserver)
    │  Nextcloud + OnlyOffice + navegador
    │  ▸ Prueba de conectividad: CLI → bos (ctx_id, health, estado)
    │
    ▼
Core UI (Flutter) — https://<tenant>.sksistemas.com
    │  Administración de fichas, dashboards, monitoreo
    │
    ▼
20 FICHAS OPERATIVAS — PostgreSQL, Redis, Vault, Keycloak, Kong, bSearch, etc.
```

**Sin VDI operativo, el cliente no puede usar el SBOS.** El bootstrap no termina cuando
los pods están corriendo — termina cuando el usuario puede sentarse frente a su escritorio
virtual, abrir una terminal y verificar conectividad con el ecosistema SBOS.

### Prueba de conectividad VDI → SBOS (línea de comandos, solo verificaciones básicas)

Estas pruebas NO requieren bauth, bSearch ni aplicaciones de negocio. Solo verifican
que el VDI tiene conectividad de red y puede alcanzar los componentes fundamentales
del SBOS ya instalados.

```bash
# 1. Conectividad de red básica — ¿llega al cluster K8s?
ping -c 3 <IP_DEL_HOST_SBOS>
# Esperado: 0% packet loss

# 2. Health check de bos vía Unix socket local (si bosctl está en el VDI)
curl --unix-socket /run/bos/bos.sock http://localhost/health 2>/dev/null || echo "bosctl no instalado aún en VDI"
# Esperado: {"status":"ok"} — o mensaje de "no instalado aún" (válido en fase temprana)

# 3. Resolución DNS — ¿resuelve el dominio del tenant?
nslookup <tenant>.sksistemas.com
# Esperado: IP del balanceador de carga del cluster K8s

# 4. Puerto HTTPS abierto en Kong — ¿NGINX responde?
curl -sk -o /dev/null -w "%{http_code}" https://<tenant>.sksistemas.com
# Esperado: 200 o 301 (redirección a login — aún sin auth)

# 5. Latencia al cluster
curl -sk -o /dev/null -w "time_total: %{time_total}s\n" https://<tenant>.sksistemas.com
# Esperado: < 100ms (red local)
```

**Si estos 5 comandos pasan, el VDI tiene conectividad verificable con el ecosistema
SBOS.** Las pruebas de autenticación (bauth), búsqueda (bSearch) y aplicaciones
(Tryton, OrangeHRM) se agregan cuando esos daemons estén desarrollados.

El problema central es el **huevo y la gallina**: Vault necesita PostgreSQL, PostgreSQL
necesita K8s, K8s necesita Calico, Calico necesita NetworkPolicies, NetworkPolicies
necesitan Vault para secretos... y así infinitamente. La solución es el **patrón de
mínimo viable progresivo**: cada ficha se instala primero en modo mínimo funcional,
luego se especializa en sucesivas pasadas hasta alcanzar su configuración completa.

### Documentos normativos de obligatorio cumplimiento

El agente bos DEBE seguir estos documentos en todo momento durante el desarrollo.
Son normas irrenunciables. Violarlas = ficha rechazada por el Bibliotecario.

| Documento | Ruta | Regula |
|-----------|------|--------|
| **SBOS-049 — Context Plane** | `BOS_V8/BOS_V8_SBOS-049-CONTEXT-PLANE.md` | ctx_id obligatorio en toda operación. Propagación W3C Trace Context + OTel Baggage. Estructura del ctx_id. Context Registry. |
| **SBOS-050 — Port Catalog** | `BOS_V8/BOS_V8_SBOS-050-PORT-CATALOG.md` | Rangos de puertos. Tabla maestra de NO DISPONIBLES. Principio P9: HTTP vetado entre daemons. 3 puertos externos. Deny-all. |
| **SBOS-047 — ISMS** | `BOS_V8/BOS_V8_SBOS-047-ISMS-ISO27001.md` | 20 controles ISO 27001. PHVA. ctx_id en audit_events (A.8.15). Secretos en Vault. |
| **ORQUESTA-043 — JSON-RPC** | `fabrica/context-fabrica/doctrina/json-RPC/` | Protocolo de comunicación obligatorio. Convención `namespace.agente.accion`. Errores HTTP 200. Nomenclatura. |
| **ADR-017 — Versiones** | `CLAUDE.md` | Versiones canónicas verificadas. Prohibido `latest`, beta, RC. |
| **ADR-014 — Soberanía** | `CLAUDE.md` | El agente bos no interfiere en tareas de otros agentes. |

---

## Parte I — Objetivo Final Verificable

### Qué debe existir al terminar el bootstrap

```
Cluster K8s (kubeadm) ← 1 nodo control-plane, Containerd, Calico CNI 100%
├── NetworkPolicies default-deny activas
├── Calico BGP o VXLAN funcionando (pod-to-pod communication)
├── MetalLB para LoadBalancer
├── Linkerd mTLS sidecar injection
├── Kyverno admission control
│
├── 19 FICHAS INICIALES INSTALADAS Y VERIFICADAS:
│   ┌──────────────────────────────────────────────────────────────┐
│   │ Ficha              │ Server │ Puerto   │ Estado requerido     │
│   ├──────────────────────────────────────────────────────────────┤
│   │ 1. sbos-bootstrap-os   │ S-HOST │ —        │ HEALTHY (kernel, pods) │
│   │ 2. sbos-bootstrap-k8s  │ S-HOST │ —        │ HEALTHY (kubeadm, Calico) │
│   │ 3. sbos-bootstrap-hard │ S-HOST │ —        │ HEALTHY (CIS hardening) │
│   │ 4. postgresql          │ S01    │ 5432     │ HEALTHY + WAL logical │
│   │ 5. redis               │ S01    │ 6379     │ HEALTHY (PONG DB0/1/2) │
│   │ 6. minio               │ S01    │ 9000     │ HEALTHY (bucket created) │
│   │ 7. vault               │ S02    │ 8200     │ HEALTHY (unsealed, AppRole) │
│   │ 8. keycloak            │ S03    │ 8080     │ HEALTHY (realm master OK) │
│   │ 9. oauth2-proxy        │ S02    │ 4180     │ HEALTHY │
│   │ 10. kong               │ S02    │ 8000/8443│ HEALTHY (migrations OK) │
│   │ 11. nginx              │ S02    │ 80/443   │ HEALTHY │
│   │ 12. certbot            │ S02    │ —        │ HEALTHY (certs issued) │
│   │ 13. linkerd            │ S03    │ —        │ HEALTHY (mTLS active) │
│   │ 14. kyverno            │ S03    │ —        │ HEALTHY (policies active) │
│   │ 15. prometheus         │ S12    │ 9090     │ HEALTHY (scraping) │
│   │ 16. grafana            │ S12    │ 3000     │ HEALTHY (dashboards loaded) │
│   │ 17. prometheus-alert   │ S12    │ 9093     │ HEALTHY │
│   │ 18. grafana-alloy      │ S12    │ 12345    │ HEALTHY │
│   │ 19. sbos-notifier       │ S06    │ 28200-   │ HEALTHY (Push MFA │
│   │                         │        │ 28205    │  funcional)       │
│   └──────────────────────────────────────────────────────────────┘
```

### Verificación final automatizada

```bash
bosctl bootstrap verify
# Debe retornar:
#   19/19 fichas HEALTHY
#   Calico: BGP established, node mesh OK
#   Linkerd: mTLS active, all pods injected
#   Kyverno: policies enforcing
#   NetworkPolicy: default-deny active en todos los namespaces
#   Vault: unsealed, AppRole sbos-pods creado
#   Keycloak: realm master accesible, health/ready 200
#   PostgreSQL: WAL logical activo, slot bkernel_slot creado
```

---

## Parte II — Desarrollo de Fichas (HITL + Agente, UNA SOLA VEZ)

### Las 3 pasadas son iteraciones de desarrollo, NO fases del instalador

El instalador certificado NO configura fichas en runtime. Simplemente las despliega.
Toda la configuración se hace **durante el desarrollo**, iterando cada ficha hasta
que está perfecta. El HITL y el agente bos trabajan juntos en este proceso.

```
PROCESO DE DESARROLLO (HITL + bos, ocurre UNA SOLA VEZ por ficha):

  Iteración 1: hacer que arranque
    └── El agente desarrolla la ficha. El HITL la prueba en nspawn.
        ¿Funciona? → NO → corregir y repetir.
        ¿Funciona? → SÍ → pasar a iteración 2.

  Iteración 2: hacer que sea segura
    └── Agregar TLS, Vault, NetworkPolicies, auth.
        ¿Funciona? → NO → corregir y repetir.
        ¿Funciona? → SÍ → pasar a iteración 3.

  Iteración 3: hacer que sea producción
    └── Agregar HA, réplicas, monitoreo, backup.
        ¿Funciona? → NO → corregir y repetir.
        ¿Funciona? → SÍ → FICHA TERMINADA. Empaquetar.

FICHA TERMINADA = los 3 archivos (manifest.yml, yaml_engine.yml, task_catalog.sh)
ya contienen TODO lo necesario. El instalador solo hace: cargar ficha → desplegar.
```

### Qué contiene una ficha terminada

Cada ficha empaqueta su configuración completa en sus archivos declarativos.
El instalador no decide nada — la ficha ya lo tiene todo:

```
servers/S01/postgresql/
├── manifest.yml       ← identidad, dependencias, puertos, health checks, Vault paths
├── yaml_engine.yml    ← StatefulSet, Service, PVC, NetworkPolicy, ConfigMap, TLS
├── task_catalog.sh    ← install, repair, migrate, test, status, uninstall
└── resources/         ← configs, certs references, SQL migrations, dashboards
```

### Tabla de estado final de cada ficha (cómo queda cuando está TERMINADA)

| Ficha | Configuración final (ya empaquetada en la ficha) |
|-------|--------------------------------------------------|
| **postgresql** | **Patroni HA 3 nodos** con etcd DCS. **WAL logical** (pgoutput). **pgvector** (búsqueda vectorial). **pgBackRest PITR**. **PgBouncer** pool. **TimescaleDB**. TLS Vault PKI. `scram-sha-256`. Credenciales Vault. NetworkPolicy. PV Retain 100GB. Velero backup. |
| **redis** | **Sentinel 3 nodos** (HA). Password Vault. 3 DBs (cache, ctx_id, streams). Persistencia AOF+RDB. Streams con consumer groups. TLS Vault PKI. NetworkPolicy. |
| **vault** | **Vault 2.0.1 HA** Raft 3 nodos. TLS Vault PKI. Auto-unseal Transit. AppRole `sbos-pods`. Secret engine KV v2. **PKI engine** (certificados internos). Audit log. NetworkPolicy. |
| **keycloak** | **Keycloak 26.6.2 producción** (`start` optimizado). TLS Vault PKI. **5 SPIs SKULL**. Realm master. OIDC clients. Session settings. **2+ réplicas** Infinispan. Rolling updates sin pérdida sesiones. NetworkPolicy. |
| **calico** | BGP/VXLAN, default-deny-all activo, NetworkPolicies por namespace, IP pools configurados, node mesh |
| **kong** | TLS, plugin Lua SBOS-Context, JWT validation, rate limiting, kong_db en PostgreSQL, admin API restringida |
| **linkerd** | mTLS activo en todos los namespaces, auto-inject, ServiceProfile por servicio |
| **kyverno** | enforce mode, políticas SBOS (probes obligatorios, no hostPort, OCI signed), NetworkPolicy default-deny validation |
| **prometheus** | Scrape de todos los daemons (9400-9499), Alertmanager integrado, reglas SBOS, targets desde Vault |
| **grafana** | OAuth2 Keycloak, dashboards SBOS precargados, datasources PostgreSQL+Prometheus+Loki |
| **nginx** | TLS Let's Encrypt, hardening headers CSP/HSTS, ModSecurity WAF, proxy_pass a Kong, HTTP→HTTPS redirect |
| **certbot** | Certificado producción Let's Encrypt, auto-renewal cron cada 60 días |
| **minio** | TLS, políticas IAM, bucket sbos-backups creado, credenciales en Vault |
| **oauth2-proxy** | Claims validation contra Keycloak, allowed_groups, cookie secure |
| **alertmanager** | Reglas SBOS (lag WAL, Vault sealed, DLQ depth, pod down), routing a bnotify |
| **alloy** | Pipelines de parsing SBOS, extracción ctx_id de logs, envío a Loki |
| **kyverno-policies** | ClusterPolicies: require-probes, forbid-hostport, verify-oci-signature, require-networkpolicy |
| **sbos-bootstrap-os** | Kernel modules, sysctl, /data/, Podman, herramientas base |
| **sbos-bootstrap-k8s** | kubeadm, containerd, Calico, namespaces, storageclass |
| **sbos-bootstrap-hard** | CIS hardening, UFW deny-all, Calico default-deny enforcement, Kyverno enforce |

---

## Parte III — Orden Topológico de Instalación

### DAG de dependencias resuelto

```
Nivel 0 — OS (sin dependencias)
  S-HOST: sbos-bootstrap-os
      │
Nivel 1 — Kubernetes (depende nivel 0)
  S-HOST: sbos-bootstrap-k8s (kubeadm + containerd + Calico básico)
      │
Nivel 2 — Almacenamiento (depende nivel 1)
  S01: postgresql, redis, minio
      │
Nivel 3 — Seguridad base (depende nivel 2)
  S02: vault (modo mínimo)
  S03: keycloak (start-dev)
      │
Nivel 4 — Gateway (depende nivel 3)
  S02: oauth2-proxy, kong (modo mínimo), nginx
  S03: kyverno (audit), linkerd (básico)
      │
Nivel 5 — Observabilidad (depende nivel 4)
  S06: sbos-notifier (notificaciones + Push MFA)
  S12: prometheus, grafana, alertmanager, alloy
      │
Nivel 6 — Hardening (depende todo lo anterior)
  S-HOST: sbos-bootstrap-hardening
  S02: certbot
  Calico: default-deny-all
  Kyverno: audit→enforce
      │
─── HASTA AQUÍ: PRIMERA PASADA COMPLETA (19 fichas mínimo funcional) ───
      │
Nivel 7 — Especialización (Pasada 2 sobre las 18 fichas)
  TLS en todos los servicios
  Vault como fuente de secretos
  NetworkPolicies por namespace
  Keycloak start producción + SPIs
      │
─── PASADA 2 COMPLETA (19 fichas con seguridad) ───
      │
Nivel 8 — Alta Disponibilidad (Pasada 3)
  Patroni, Redis Sentinel, Vault HA, Keycloak multi-réplica
      │
─── PASADA 3 COMPLETA (19 fichas producción) ───
```

---

## Parte IV — Interfaz Visual de Instalación (UX del Usuario)

El instalador debe ofrecer una experiencia visual similar a la instalación de un sistema
operativo (Ubuntu, Windows). No es una línea de comandos — es una interfaz que guía al
usuario desde el inicio hasta el sistema operativo listo.

### Principios de UX

| # | Principio | Implementación |
|---|-----------|---------------|
| **UX1** | El usuario nunca ve una línea de comando | Toda la interacción es mediante pantallas visuales (TUI o Web UI) |
| **UX2** | Progreso siempre visible | Barra de progreso global + por ficha + paso actual |
| **UX3** | Solo pedir datos cuando se necesitan | Formularios contextuales, no un formulario gigante al inicio |
| **UX4** | El usuario puede dejar la instalación y volver | Si se interrumpe, al retomar detecta lo ya instalado y continúa |
| **UX5** | Cada pantalla tiene ayuda contextual | "¿Qué es un tenant?", "¿Por qué necesito este dato?" |
| **UX6** | Validación en el momento | Si un campo es inválido, se marca antes de avanzar |
| **UX7** | Todo en español | Sin excepciones |

### Arquitectura de la UI de Instalación

```
┌──────────────────────────────────────────────────────────────┐
│                   INSTALADOR SBOS v1.0                       │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                                                        │  │
│  │   [PANTALLA ACTUAL]                                    │  │
│  │                                                        │  │
│  │   Las pantallas cambian según la fase:                  │  │
│  │   - Bienvenida / info del sistema                       │  │
│  │   - Formularios (datos del tenant, admin, dominio)      │  │
│  │   - Progreso (barras, logs en vivo)                     │  │
│  │   - Completado (resumen, accesos)                        │  │
│  │                                                        │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ [████████████████████░░░░░░░░░] 65%                      │  │
│  │ Instalando: postgresql (ficha 4/19)                      │  │
│  │ Paso: create_replication_slot                            │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  [Ayuda] [Anterior]              [Siguiente] [Instalación   │
│                                              automática]    │
└──────────────────────────────────────────────────────────────┘
```

### Secuencia de pantallas

```
PANTALLA 1 — BIENVENIDA
  ┌─────────────────────────────────────────────┐
  │          SBOS — Sovereign Business          │
  │           Operating System                  │
  │                                             │
  │  Bienvenido a la instalación de SBOS.       │
  │  Este proceso instalará el sistema          │
  │  operativo empresarial en su servidor.      │
  │                                             │
  │  Tiempo estimado: ~48 minutos               │
  │  Fichas a instalar: 19                      │
  │                                             │
  │  Ubuntu 26.04 LTS detectado ✅              │
  │  Kernel 7.0 ✅                              │
  │  RAM: 16 GB ✅                              │
  │  Disco: 250 GB disponible ✅                │
  │                                             │
  │         [Comenzar instalación]              │
  └─────────────────────────────────────────────┘

PANTALLA 2 — CONFIGURACIÓN DEL TENANT
  ┌─────────────────────────────────────────────┐
  │          Datos de la Empresa                │
  │                                             │
  │  Razón social: [___________________]        │
  │  NIT/CUIT/RFC: [___________________]        │
  │  País: [▼ Bolivia]                          │
  │  Dominio: [___________].sksistemas.com      │
  │                                             │
  │  ¿Qué es el tenant? ℹ️                       │
  │  Es el identificador único de su empresa    │
  │  en el sistema. Se usa para aislar sus      │
  │  datos de los de otras empresas.            │
  │                                             │
  │         [Anterior]    [Siguiente]           │
  └─────────────────────────────────────────────┘

PANTALLA 3 — ADMINISTRADOR PRINCIPAL
  ┌─────────────────────────────────────────────┐
  │       Cuenta de Administrador               │
  │                                             │
  │  Email:    [___________________]            │
  │  Nombre:   [___________________]            │
  │  Contraseña: [_________________]            │
  │  Confirmar:  [_________________]            │
  │                                             │
  │  ⚠️ Esta cuenta tiene acceso total al       │
  │  sistema. Guarde estas credenciales.         │
  │                                             │
  │  □ Activar MFA (recomendado)                │
  │                                             │
  │         [Anterior]    [Siguiente]           │
  └─────────────────────────────────────────────┘

PANTALLA 4 — CONFIRMACIÓN
  ┌─────────────────────────────────────────────┐
  │         Resumen de Instalación              │
  │                                             │
  │  Empresa: Constructora Andina S.R.L.        │
  │  Dominio: constructora.sksistemas.com       │
  │  Admin: ivan@constructora.com               │
  │                                             │
  │  Componentes a instalar (19):               │
  │  ✅ PostgreSQL 18.4                          │
  │  ✅ Redis 8.6.2                             │
  │  ✅ Keycloak 26.6.2                         │
  │  ... (19 fichas listadas)                   │
  │                                             │
  │  ¿Desea modo interactivo o automático?      │
  │  [Interactivo] [Automático]                 │
  │                                             │
  │         [Anterior]    [Instalar]            │
  └─────────────────────────────────────────────┘

PANTALLA 5 — PROGRESO DE INSTALACIÓN
  ┌─────────────────────────────────────────────┐
  │      Instalando SBOS...                     │
  │                                             │
  │  ┌─────────────────────────────────────┐    │
  │  │████████████████████░░░░░░░░░░░░░░░░░│ 65%│
  │  └─────────────────────────────────────┘    │
  │                                             │
  │  Ficha actual: postgresql (4/19)            │
  │  ├── ✅ create_pv                           │
  │  ├── ✅ deploy_statefulset                  │
  │  ├── 🔄 wait_ready (45s transcurridos)      │
  │  ├── ⬜ enable_wal_logical                  │
  │  ├── ⬜ create_replication_slot             │
  │  └── ⬜ create_databases                    │
  │                                             │
  │  Completadas: postgresql, redis, vault      │
  │  Actual: keycloak                           │
  │  Pendientes: kong, nginx, certbot... (12)   │
  │                                             │
  │            [Ver log detallado]              │
  └─────────────────────────────────────────────┘

PANTALLA 6 — COMPLETADO
  ┌─────────────────────────────────────────────┐
  │     ✅ Instalación Completada                │
  │                                             │
  │  19/19 fichas instaladas y verificadas       │
  │  Tiempo total: 47 minutos                    │
  │                                             │
  │  🌐 Panel de administración:                 │
  │     https://constructora.sksistemas.com      │
  │                                             │
  │  👤 Credenciales de administrador:            │
  │     Email: ivan@constructora.com             │
  │     (la contraseña fue configurada por usted) │
  │                                             │
  │  📊 Monitoreo:                               │
  │     https://constructora.sksistemas.com/     │
  │     monitor                                  │
  │                                             │
  │  💡 Próximos pasos:                          │
  │     • Configure sus impuestos en SmartTax    │
  │     • Agregue empleados en OrangeHRM         │
  │     • Active backup automático               │
  │                                             │
  │           [Abrir panel de administración]    │
  └─────────────────────────────────────────────┘
```

### Datos que se solicitan durante la instalación

| Momento | Dato solicitado | Obligatorio | Uso |
|---------|----------------|-------------|-----|
| Pantalla 2 | Razón social | Sí | Nombre del tenant en Keycloak y seed file |
| Pantalla 2 | NIT/CUIT/RFC | Sí | Facturación electrónica, cumplimiento fiscal |
| Pantalla 2 | País | Sí | Jurisdicción fiscal (BO/AR/MX), moneda, locale |
| Pantalla 2 | Dominio | Sí | Subdominio en sksistemas.com, certificados TLS |
| Pantalla 3 | Email admin | Sí | Cuenta administradora inicial del realm |
| Pantalla 3 | Nombre admin | Sí | Display name en Keycloak |
| Pantalla 3 | Contraseña admin | Sí | Credencial inicial (se fuerza cambio al primer login) |
| Pantalla 3 | Activar MFA | No | Push MFA vía sbos-notifier |

### Implementación técnica

La UI se comunica con el daemon bos vía Unix socket (`/run/bos/bos.sock`):

```go
// internal/installer/ui.go

type InstallerUI struct {
    socket *net.UnixConn       // conexión al daemon bos
    screen Screen              // pantalla actual
    seed   *SeedFile           // datos recolectados del usuario
}

type Screen interface {
    Render() string            // renderizar la pantalla actual (TUI)
    Handle(input string) error // procesar input del usuario
    Next() Screen              // siguiente pantalla (nil = terminar)
}

// Pantallas concretas
type WelcomeScreen struct { systemInfo SystemInfo }
type TenantFormScreen struct { seed *SeedFile }
type AdminFormScreen struct { seed *SeedFile }
type ConfirmScreen struct { seed *SeedFile; fichas []Ficha }
type ProgressScreen struct { 
    bootstrap *BootstrapEngine
    events    chan BootstrapEvent  // recibe señales __SBOS__STEP__*
    progress  float64              // 0.0 a 1.0
    currentStep string
}
type CompletedScreen struct { result BootstrapResult }
```

### Flujo de comunicación UI ↔ Daemon

```
UI (TUI/Web)                     bos daemon
    │                                │
    │── POST /api/v1/bootstrap/start │
    │   (con seed file del usuario)  │
    │                                │── inicia bootstrap
    │                                │── emite __SBOS__STEP__* por WebSocket
    │◄── WebSocket: eventos en vivo  │
    │                                │
    │── actualiza barra de progreso  │
    │── muestra paso actual          │
    │                                │── completa ficha
    │◄── WebSocket: ficha OK         │
    │                                │
    │ ... (x19 fichas) ...           │
    │                                │
    │◄── WebSocket: DONE             │
    │── muestra pantalla completado  │
```

### La UI NO es opcional — es parte del contrato de certificación

El Operador (pane 3) verifica que la UI funciona correctamente:

- [ ] C-09: Pantalla de bienvenida muestra info del sistema correctamente
- [ ] C-10: Formularios de tenant y admin validan campos (email inválido → error)
- [ ] C-11: Barra de progreso se actualiza en tiempo real con cada ficha
- [ ] C-12: Pantalla de completado muestra URLs y credenciales correctas
- [ ] C-13: Modo automático funciona (--unattended con seed file preexistente)

---

### Información Detallada Durante la Instalación

El instalador debe mostrar información exhaustiva de cada componente que se instala.
No basta con una barra de progreso — el usuario debe entender QUÉ se instala,
PARA QUÉ sirve en SBOS, y POR QUÉ es necesario.

#### Nivel 1 — Visión general (siempre visible)

```
┌──────────────────────────────────────────────────────────────┐
│  Ficha 4/19: PostgreSQL 18.4                                 │
│  ┌──────────────────────────────────────────────────────┐    │
│  │███████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░│68% │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  📦 Componente: PostgreSQL 18.4-alpine (imagen OCI)          │
│  📏 Tamaño: 145 MB                                           │
│  🔧 Función en SBOS: Motor de base de datos relacional.      │
│     Almacena todos los datos de las aplicaciones: facturas,  │
│     empleados, clientes, configuraciones. Es el bus de       │
│     eventos del sistema mediante WAL (Write-Ahead Log).      │
│  📋 Dependencias: PersistentVolume /data/postgres (100 GB)   │
│                                                              │
│  Paso actual (3/6): Configurando WAL lógico                  │
│  ├── ✅ 1. create_pv               (PersistentVolume 100GB)  │
│  ├── ✅ 2. deploy_statefulset      (StatefulSet + Service)   │
│  ├── 🔄 3. enable_wal_logical      (wal_level=logical)       │
│  ├── ⬜ 4. create_replication_slot (bkernel_slot pgoutput)   │
│  ├── ⬜ 5. create_databases        (10 bases de datos)       │
│  └── ⬜ 6. verify_health           (pg_isready, WAL check)   │
│                                                              │
│  [Ver detalle técnico]  [Ver log en vivo]                    │
└──────────────────────────────────────────────────────────────┘
```

#### Nivel 2 — Detalle técnico (al expandir "Ver detalle técnico")

```
┌──────────────────────────────────────────────────────────────┐
│  DETALLE TÉCNICO — PostgreSQL 18.4                            │
│                                                              │
│  📦 Paquetes y librerías instalados:                          │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ Librería        │ Versión   │ Función en SBOS         │    │
│  ├──────────────────────────────────────────────────────┤    │
│  │ libpq-dev       │ 18.4      │ Cliente nativo PG,      │    │
│  │                 │           │ usado por bKernel para   │    │
│  │                 │           │ CDC mediante WAL         │    │
│  │ pgoutput        │ nativo    │ Plugin de replicación    │    │
│  │                 │ PG18      │ lógica. Permite a        │    │
│  │                 │           │ bKernel leer cambios      │    │
│  │                 │           │ sin modificar apps       │    │
│  │ uuid-ossp       │ 1.1       │ Generación de UUIDs.     │    │
│  │                 │           │ Usado por todas las apps │    │
│  │ pg_stat_state…  │ nativo    │ Monitoreo de queries.    │    │
│  │                 │           │ Consumido por Prometheus │    │
│  │ timescaledb     │ 2.18      │ Series temporales para   │    │
│  │                 │           │ métricas de monitoreo    │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  🔌 Puertos y red:                                           │
│  • ContainerPort: 5432 (interno del pod)                     │
│  • ClusterIP: 8100 (dentro de K8s, accesible por apps)       │
│  • Externo: NUNCA (solo ClusterIP, sin NodePort)             │
│                                                              │
│  💾 Almacenamiento:                                          │
│  • PV: sbos-postgres-pv (100 GB, Retain, hostPath)           │
│  • Ruta en host: /data/postgres/pgdata                       │
│  • WAL: /data/postgres/pg_wal                                │
│                                                              │
│  🔐 Seguridad:                                               │
│  • TLS: Vault PKI (certificados rotativos)                   │
│  • Autenticación: md5 → migrate a scram-sha-256 en Pasada 2  │
│  • NetworkPolicy: solo tráfico desde namespace sbos-system   │
│                                                              │
│  [Cerrar]                                                    │
└──────────────────────────────────────────────────────────────┘
```

#### Nivel 3 — Log en vivo (al expandir "Ver log en vivo")

```
┌──────────────────────────────────────────────────────────────┐
│  LOG EN VIVO — PostgreSQL 18.4                                │
│                                                              │
│  [14:32:01] Pulling image: postgres:18.4-alpine              │
│  [14:32:15] Image pulled (145 MB)                             │
│  [14:32:16] Creating PersistentVolume sbos-postgres-pv       │
│  [14:32:16] PV bound to /data/postgres (Retain)              │
│  [14:32:17] Creating StatefulSet postgresql (1 réplica)      │
│  [14:32:18] Pod postgresql-0 starting...                     │
│  [14:32:25] Init container: permissions check (OK)           │
│  [14:32:30] PostgreSQL initializing data directory           │
│  [14:32:45] PostgreSQL ready — accepting connections         │
│  [14:32:46] Setting wal_level=logical                        │
│  [14:32:47] Creating replication slot bkernel_slot           │
│  [14:32:47] Slot created (pgoutput, LSN 0/0)                 │
│  [14:32:48] Creating database: keycloak_db (OK)              │
│  [14:32:48] Creating database: kong_db (OK)                  │
│  [14:32:48] Creating database: vault_db (OK)                 │
│  [14:32:49] Creating database: bkernel_db (OK)               │
│  [14:32:49] Creating database: biedata_db (OK)               │
│  [14:32:49] Creating database: bsearch_db (OK)               │
│  [14:32:50] Creating database: bauth_db (OK)                 │
│  [14:32:50] Creating database: tryton_db (OK)                │
│  [14:32:50] Creating database: grafana_db (OK)               │
│  [14:32:51] Creating database: notifier_db (OK)              │
│  [14:32:51] Extension uuid-ossp enabled (10 databases)       │
│  [14:32:52] Health check: pg_isready → accepting connections │
│  [14:32:52] Ficha postgresql: INSTALADA Y VERIFICADA ✅      │
│                                                              │
│  [Cerrar]                                                    │
└──────────────────────────────────────────────────────────────┘
```

#### Pantalla de error detallada

Cuando algo falla, el instalador NO muestra un error genérico. Muestra:

```
┌──────────────────────────────────────────────────────────────┐
│  ❌ ERROR — Ficha 4/19: PostgreSQL (Paso 3/6)                 │
│                                                              │
│  Paso fallido: enable_wal_logical                            │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ Error:                                                │    │
│  │   could not write to configuration file               │    │
│  │   /var/lib/postgresql/data/pgdata/postgresql.conf     │    │
│  │                                                      │    │
│  │ Causa:                                                │    │
│  │   No space left on device                             │    │
│  │   Ruta: /data/postgres                                │    │
│  │   Disponible: 12 MB                                   │    │
│  │   Requerido: 100 GB (PV configurado)                  │    │
│  │                                                      │    │
│  │ Acciones sugeridas:                                   │    │
│  │   1. Verificar espacio en disco:                      │    │
│  │      df -h /data/postgres                             │    │
│  │   2. Ampliar el volumen si es posible:                │    │
│  │      lvextend -L +50G /dev/vg0/data                   │    │
│  │   3. O reducir el PV en manifest.yml:                 │    │
│  │      storage: 50Gi (mínimo recomendado)               │    │
│  │   4. Reintentar instalación:                           │    │
│  │      bosctl bootstrap resume                          │    │
│  │                                                      │    │
│  │ Estado antes del error:                                │    │
│  │   ✅ Paso 1: create_pv (OK)                           │    │
│  │   ✅ Paso 2: deploy_statefulset (OK)                  │    │
│  │   ❌ Paso 3: enable_wal_logical (FALLÓ)               │    │
│  │   ⬜ Paso 4: create_replication_slot (pendiente)      │    │
│  │   ⬜ Paso 5: create_databases (pendiente)             │    │
│  │   ⬜ Paso 6: verify_health (pendiente)                 │    │
│  │                                                      │    │
│  │ Datos YA instalados (NO se perderán):                  │    │
│  │   ✅ PostgreSQL 18.4 (StatefulSet corriendo)           │    │
│  │   ✅ PersistentVolume sbos-postgres-pv (100 GB)       │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  [Reintentar]  [Saltar este paso]  [Diagnóstico avanzado]    │
└──────────────────────────────────────────────────────────────┘
```

#### Catálogo de errores comunes que el instalador debe detectar

| Tipo de error | Síntoma | Causa probable | Acción sugerida |
|--------------|---------|---------------|-----------------|
| **Espacio en disco** | `No space left on device` | PV más grande que el volumen físico | `df -h`, ampliar volumen o reducir PV |
| **Permisos** | `Permission denied` en `/data/*` | UID/GID incorrecto en hostPath | `chown -R 999:999 /data/postgres` |
| **Puerto ocupado** | `bind: address already in use :5432` | Otro PostgreSQL corriendo en el host | `ss -tlnp \| grep 5432`, detener el otro servicio |
| **DNS / red** | `Could not resolve host` | CoreDNS no funcional o NetworkPolicy bloqueando | `kubectl logs -n kube-system -l k8s-app=kube-dns` |
| **Imagen no disponible** | `ImagePullBackOff` o `ErrImagePull` | Registry inaccesible o imagen no existe | Verificar conectividad, usar `podman pull` manual |
| **Falta módulo kernel** | `modprobe: FATAL: Module br_netfilter not found` | Kernel no compatible o módulo no instalado | `apt install linux-modules-extra-$(uname -r)` |
| **Vault sealed** | `vault status: Sealed = true` | Reinicio de pod Vault | Ejecutar `vault operator unseal` con las keys |
| **Certificado TLS vencido** | `certificate has expired` | Certbot no renovó a tiempo | `certbot renew --force-renewal` |
| **Dependencia circular** | `Init:CrashLoopBackOff` en cascada | Orden de instalación incorrecto | Verificar DAG de dependencias, instalar en orden |
| **Memoria insuficiente** | `OOMKilled` en pods | Límites de memoria muy bajos | Aumentar `resources.limits.memory` en el manifest |

#### Funcionalidad de reanudación

Si la instalación se interrumpe (error, apagón, Ctrl+C), al reanudar:

```bash
bosctl bootstrap resume
```

El instalador:
1. Carga `.sbos_state.json` y detecta el último paso completado
2. Verifica que las fichas ya instaladas siguen HEALTHY
3. Reanuda desde la ficha y paso donde se quedó
4. NO reinstala lo que ya está funcionando

```
┌──────────────────────────────────────────────────────────────┐
│  REANUDANDO INSTALACIÓN...                                   │
│                                                              │
│  Fichas ya instaladas (3/19):                                │
│  ✅ 1. sbos-bootstrap-os     (HEALTHY)                       │
│  ✅ 2. sbos-bootstrap-k8s    (HEALTHY)                       │
│  ✅ 3. postgresql            (HEALTHY)                       │
│  ⚠️ 4. redis                 (DEGRADED — requiere reparación) │
│                                                              │
│  Reanudando en: ficha 4 (redis), paso 2/3                    │
│  Último paso completado: deploy_statefulset ✅               │
│  Siguiente paso: enable_aof_persistence                      │
│                                                              │
│  [Continuar instalación]                                     │
└──────────────────────────────────────────────────────────────┘
```

---

## Parte V — Especificación de Desarrollo por Ficha

El instalador simplemente hace `kubectl apply -f` de los manifests de la ficha.
**Toda la inteligencia está en los archivos de la ficha, no en el instalador.**

Cada ficha tiene un `task_catalog.sh` con 6 tareas estándar:

```bash
# Toda ficha implementa estas 6 tareas:
task_install   # desplegar la ficha (kubectl apply, crear recursos)
task_repair    # verificar y reparar si algo falló
task_test      # probar que la ficha funciona (health, conexiones)
task_status    # mostrar estado actual (pods, servicios, métricas)
task_migrate   # actualizar de versión anterior a esta
task_uninstall # remover la ficha limpiamente
```

El instalador solo invoca `task_install` en orden topológico. Si falla, invoca
`task_repair`. Si pasa, invoca `task_test` para verificar.
```

---

## Parte V-B — El PostgreSQL Auxiliar Anti-Pérdida

Antes de tocar cualquier ficha, el IAM Installer despliega un **PostgreSQL auxiliar**
como red de seguridad. Este auxiliar garantiza que un fallo durante el bootstrap
no corrompa datos existentes.

**Regla de oro:** El PG principal **nunca recibe una escritura durante el bootstrap.**
Todas las operaciones van al auxiliar. Solo después de verificación exitosa se sincronizan.

```
ANTES:    PG principal ──pg_basebackup──→ PG auxiliar (idéntico)
DURANTE:  CREATE DATABASE, INSERT... → PG auxiliar (principal INTACTO)
ÉXITO:    PG aux → pg_dump/pg_restore → PG principal → destruir aux
FALLO:    destruir auxiliar (principal sin un solo cambio)
```

---

## Parte VI — Calico 100% Configurado

Calico no se considera "instalado" hasta que pasa estas verificaciones:

```bash
# 1. BGP establecido (o VXLAN si el entorno no soporta BGP)
calicoctl node status
# Esperado: Calico process is running, BGP peering established

# 2. IP pools correctos
calicoctl get ippool
# Esperado: default-ipv4-ippool con CIDR configurado

# 3. NetworkPolicy default-deny (Pasada 2)
kubectl get networkpolicy -A | grep default-deny
# Esperado: default-deny-all en todos los namespaces

# 4. Pod-to-pod communication
kubectl run test-pod --image=busybox:1.37 --rm -it --restart=Never -- ping -c 1 <otro-pod-ip>
# Esperado: 0% packet loss

# 5. Node mesh (multi-nodo)
calicoctl get bgppeer
# Esperado: node-to-node mesh
```

---

## Parte VII — Plan de Desarrollo (HITL + Agente bos)

El desarrollo de las 18 fichas ocurre UNA SOLA VEZ. El HITL y el agente bos
iteran sobre cada ficha hasta que queda perfecta. Cuando las 18 están terminadas,
el instalador simplemente las despliega.

### Proceso de desarrollo de una ficha

```
1. HITL asigna ficha al agente bos: "desarrolla la ficha postgresql"
2. Agente bos crea los 3 archivos: manifest.yml, yaml_engine.yml, task_catalog.sh
3. HITL prueba en nspawn: bosctl ficha test postgresql
4. ¿Funciona? → NO → HITL reporta errores → agente corrige → volver a paso 3
5. ¿Funciona? → SÍ → FICHA TERMINADA → commit → siguiente ficha
```

El instalador NO participa en este proceso. Solo se usa `bosctl ficha test`
para probar cada ficha individualmente en nspawn.

### Orden de desarrollo de fichas

| # | Ficha | Depende de | Prueba de aceptación |
|---|-------|-----------|----------------------|
| 1 | sbos-bootstrap-os | — | kernel modules, Podman, /data/ |
| 2 | sbos-bootstrap-k8s | #1 | kubeadm init OK, Calico node status, nodo Ready |
| 3 | postgresql | #2 | pg_isready, WAL logical, slot bkernel_slot |
| 4 | redis | #2 | PONG DB0/1/2 |
| 5 | minio | #2 | bucket creado, health 200 |
| 6 | vault | #2, #3, #4 | unsealed, AppRole, secret engine |
| 7 | keycloak | #3 | health/ready 200, realm master |
| 8 | oauth2-proxy | #7 | proxy funcional KC→app |
| 9 | kong | #3, #7 | proxy 8000, admin 8001, migrations OK |
| 10 | nginx | #9 | HTTP→HTTPS redirect, Kong proxy pass |
| 11 | certbot | #10 | certificado emitido |
| 12 | linkerd | #2 | mTLS active, pods injected |
| 13 | kyverno | #2 | policies audit mode |
| 14 | prometheus | #2 | scraping targets |
| 15 | grafana | #14 | dashboards cargados |
| 16 | alertmanager | #14 | reglas base activas |
| 17 | grafana-alloy | #2 | recolección logs |
| 18 | sbos-notifier | #6, #7, #9 | Push MFA funcional, topics ntfy creados, templates cargados |
| 19 | sbos-bootstrap-hard | #3-#17 | CIS hardening, Calico default-deny, Kyverno enforce |

### Cuando todas las fichas están terminadas

El instalador ya NO configura nada. Solo ejecuta:

```bash
# El instalador certificado simplemente despliega fichas terminadas:
bosctl bootstrap start
# Lee el DAG de dependencias → despliega las 18 fichas en orden → verifica
```

---

## Parte VIII — Criterio de Certificación

El Operador (pane 3) certifica el instalador completo en nspawn blindado:

```
bosctl bootstrap start    # Desplegar las 19 fichas terminadas
bosctl bootstrap verify   # Verificar 13 criterios C-01 a C-13

Resultado esperado:
  Bootstrap: COMPLETED
  Fichas instaladas: 19/19
  Fichas HEALTHY: 19/19
  Calico: BGP established, default-deny active
  Linkerd: mTLS active
  Kyverno: enforce mode
  Vault: unsealed, AppRole creado
  Keycloak: production mode, SPIs cargados
```

Esto es lo que el Operador (pane 3) verifica con los 13 criterios:

| ID | Criterio | Verificación | Esperado |
|----|----------|-------------|----------|
| **C-01** | Daemons activos | `systemctl is-active bkernel` × todos | `active` |
| **C-02** | Healthchecks OK | `curl :{port}/health` × todos los daemons | HTTP 200 |
| **C-03** | ctx_id propaga | `bosctl context create --test` → audit_events | ctx_id presente |
| **C-04** | Calico funcional | `calicoctl node status` | BGP established |
| **C-05** | WAL slot activo | `pg_replication_slots WHERE slot_name='bkernel_slot'` | `active=true` |
| **C-06** | Redis responde | `redis-cli PING` DB0, DB1, DB2 | PONG ×3 |
| **C-07** | Idempotencia | 2 ejecuciones de bootstrap | 0 cambios en 2ª |
| **C-08** | Limpieza+reinstala | `bootstrap reset --force` → `bootstrap start` | sin errores |
| **C-09** | Pantalla bienvenida | Info sistema correcta (Ubuntu, RAM, disco) | ✅ |
| **C-10** | Validación formularios | Email inválido → error, NIT vacío → error | ✅ |
| **C-11** | Progreso en vivo | WebSocket emite `__SBOS__STEP__*` en tiempo real | ✅ |
| **C-12** | Pantalla completado | URLs, credenciales, próximos pasos correctos | ✅ |
| **C-13** | Modo automático | `--unattended --seed-file=tenant.yml` | sin interacción |

---

_SKULL · SBOS · Especificación IAM Installer + 19 Fichas · v3.1 · Junio 2026_
_Destinatario: agente bos (pane 1) · Verificador: sbos-operador (pane 3)_
