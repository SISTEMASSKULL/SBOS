# SBOS-MP06
## Plan Maestro de Desarrollo: Implementación del SO Empresarial bos
### Memoria Persistente entre Sesiones — 10 Etapas hacia SBOS v0.9

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-MP06
**Estado:** ACTIVO — documento vivo, se actualiza al final de cada sesión
**Propósito:** Memoria completa del plan de desarrollo para continuar sin
retroalimentación al cambiar de sesión o de chat.
**Objetivo final:** bos funcional instalando las 16 fichas del producto
bootstrap en K8s real. SBOS v0.9 listo para cliente piloto Q3 2026.

---

## CONCEPTO CENTRAL — LEER ANTES DE CUALQUIER TRABAJO

**bos es el Sistema Operativo Empresarial** que corre sobre Ubuntu Server.
Su rol es instalar, vigilar, reparar y actualizar todo el stack SBOS.
Sin bos, nada del SBOS existe.

```
Ubuntu Server 24.04 LTS  (base del hardware)
        │
        └── bos.service  (el SO empresarial — daemon residente Go)
                │
                ├── Instala fichas (unidades atomicas de despliegue)
                ├── Vigila salud SO → K8s → Fichas
                ├── Repara automaticamente con Sagas
                ├── Gestiona flota via SKULL Release Plane
                │
                ├── bkernel.service  (kernel de datos — Rust/WAL)
                ├── biedata.service  (integracion exterior — Rust)
                ├── bcompass.service (IA soberana — Go)
                ├── bsearch.service  (busqueda federada — Go)
                ├── bauth.service    (identidad — Go)
                ├── bhnexus.service  (nexus host — Go)
                └── banexus.service  (nexus agent — Go)
```

**ANALOGIA CORRECTA:**
- bos       = Ubuntu/Debian (el SO completo)
- bkernel   = Linux kernel  (kernel de datos via WAL)
- Fichas    = paquetes apt/rpm
- bosctl    = apt/dpkg CLI
- Core UI   = GNOME/KDE (interfaz grafica)

**ANALOGIA INCORRECTA — NO USAR:**
- ~~bos = systemd~~
- ~~bos = kernel~~
- ~~bkernel = kernel del SO~~  (bkernel es el kernel de DATOS, no del SO)

---

## ARQUITECTURA DEL ARTEFACTO bos

```
/opt/bos/
├── bos              ← binario Go estatico (CGO_ENABLED=0)
│                      Este es el SO empresarial completo.
│                      Contiene: servidor HTTP, Unix socket,
│                      orquestacion Python, executor Bash.
└── bosctl           ← CLI Go para administracion local

/etc/bos/
├── bos.toml         ← configuracion del daemon
├── .sbos_state.json ← estado persistente (solo STATE_MANAGER escribe)
├── *.jsonl          ← eventos para replay WebSocket
└── blibs/
    ├── core/        ← los 4 archivos maestros Bash
    │   ├── 00_MASTER_INSTALL_SBOS.sh
    │   ├── 00_TASK_CATALOG_SBOS.sh
    │   ├── 00_YAML_ENGINE_SBOS.sh
    │   └── 00_ARCHITECTURE_SBOS.yml
    └── servers/     ← fichas del catalogo
        └── dataserver/postgresql/
            ├── manifest.yml
            ├── yaml_engine.yml
            ├── task_catalog.sh
            └── resources/k8s/pod.yml

/etc/systemd/system/
└── bos.service      ← daemon residente, Restart=always
```

**DECISION DE ARQUITECTURA DEFINITIVA (no revertir):**
- `bos` = binario Go. Lenguaje: Go 1.22+. Sin CGO. Binario estatico.
- Los 4 archivos maestros = Bash. Viven en /etc/bos/blibs/core/
- Los 16 modulos Python = orquestacion interna del daemon Go
- task_catalog.sh de cada ficha = Bash. NUNCA migrara a .so ni Cython.
- task_catalog.so NO EXISTE en bos. Solo existe en bkernel/biedata (Rust).

---

## STACK TECNOLOGICO DEL PROYECTO

| Componente | Tecnologia | Version | Notas |
|---|---|---|---|
| Host | Ubuntu Server | 24.04 LTS | NO actualizar a 25.04 (interim) |
| Contenedores testbench | Podman rootless | 4.9.3 | Migrar a 5.x con Ubuntu 26.04 LTS |
| Runtime contenedores | crun | latest | Mas ligero que runc |
| Build imagenes | Buildah | latest | Daemonless |
| Estado testbench | PostgreSQL | 18-alpine | Embebido en pod del motor |
| Daemon bos | Go | 1.22+ | CGO_ENABLED=0, binario estatico |
| bkernel + biedata | Rust | 1.85+ | Edition 2024, MUSL target |
| bcompass,bsearch,bauth,bhnexus,banexus | Go | 1.22+ | I/O-bound |
| Fichas (motor) | Bash | 5.x | task_catalog.sh permanece en Bash |
| Manifiestos fichas | YAML K8s | v1 | podman play kube desde dia 1 |
| Seguridad | Ed25519 | RFC 8032 | Firma todos los artefactos |
| Orquestacion destino | Kubernetes | kubeadm | Calico + MetalLB |

---

## LAS 10 ETAPAS DEL PLAN

---

### ETAPA 0 — Rectificacion documental
**Estado:** COMPLETADA (Marzo 2026)
**Duracion:** 0.5 sesiones

**Cambios aplicados:**
1. SBOS-AYUDA-MEMORIA: corregida analogia bos=SO, bkernel=kernel de datos
2. SBOS-AYUDA-MEMORIA: corregida version Podman 5.x → 4.9.3
3. SBOS-018 §11.1: eliminada oracion incorrecta sobre task_catalog.so
4. SBOS-MP06: creado (este documento) con plan maestro completo

**Criterio de completitud:** CUMPLIDO

---

### ETAPA 1 — Motor Core: los 4 archivos maestros Bash
**Estado:** PENDIENTE — PROXIMA ETAPA
**Duracion estimada:** 1-2 sesiones
**Prerequisito en VPS:** Ubuntu 24.04 LTS con acceso SSH

**Objetivo:** El motor generico del instalador funcionando.
Sin estos 4 archivos, ninguna ficha puede ejecutarse.
Estos archivos son el corazon de bos y no saben que aplicaciones existen.

**Entregables:**
```
/opt/sbos-dev/
├── Makefile
├── core/
│   ├── 00_MASTER_INSTALL_SBOS.sh
│   ├── 00_TASK_CATALOG_SBOS.sh
│   ├── 00_YAML_ENGINE_SBOS.sh
│   └── 00_ARCHITECTURE_SBOS.yml
├── validate_sp01.py
└── tests/
    └── test_core.sh
```

**Descripcion de cada archivo:**

`00_MASTER_INSTALL_SBOS.sh` — Punto de entrada. Recibe:
`comando + ficha_id`. Valida args, localiza ficha en servers/,
absorbe task_catalog.sh (source), ejecuta la accion, libera
funciones (unset -f). Comandos: install|update|repair|remove|
status|probe|lint.

`00_TASK_CATALOG_SBOS.sh` — Funciones Bash GENERICAS.
NUNCA menciona nombres de apps concretas (Principio P3).
Grupos: validaciones, K8s genericas, esperas, filesystem,
ciclo de vida. ~30 funciones en Etapa 1, crece con las fichas.

`00_YAML_ENGINE_SBOS.sh` — Interprete declarativo.
Lee yaml_engine.yml con yq. Ejecuta fases en orden.
Contiene sbos_k8s_core() — UNICO punto de kubectl apply (P1).
Implementa ciclo Absorber→Ejecutar→Liberar (P7).
Implementa diagnosis_first en repair (P14).
Parsea senales __SBOS__STEP_* de stdout.

`00_ARCHITECTURE_SBOS.yml` — Registro global.
Mapea nombre_tarea → funcion_bash para tareas globales.
Es el arbitro de la frontera global vs especifico.

`validate_sp01.py` — Validador de los 14 principios.
Verifica: kubectl solo en sbos_k8s_core (P1), no hay nombres
de apps en catalogo global (P3), funciones con export -f (P6),
solo STATE_MANAGER escribe en .sbos_state.json (P8), kubectl
create con --dry-run (P9).

**Criterio de completitud:**
- `python validate_sp01.py --file core/00_TASK_CATALOG_SBOS.sh` = exit 0
- `python validate_sp01.py --file core/00_YAML_ENGINE_SBOS.sh` = exit 0
- `bash tests/test_core.sh` pasa: ciclo A→E→L con ficha dummy funciona
- El motor puede absorber un task_catalog.sh de prueba, ejecutarlo y
  liberarlo sin contaminacion entre fichas

**Prompt para iniciar esta etapa:**
```
Continuamos con el proyecto SBOS. Lee la Ayuda Memoria y SBOS-MP06.
Etapa actual: 1 — Motor Core + 4 archivos maestros.
Objetivo: crear /opt/sbos-dev/core/ con los 4 archivos maestros Bash
y validate_sp01.py. Criterio: validate_sp01.py pasa con exit 0
contra los 4 archivos y el ciclo Absorber-Ejecutar-Liberar esta probado.
```

---

### ETAPA 2 — Testbench Podman + primera ficha postgresql
**Estado:** PENDIENTE
**Duracion estimada:** 2-3 sesiones
**Prerequisito:** Etapa 1 completa + Podman 4.9.3 instalado en VPS

**Objetivo:** El motor ejecutando la ficha postgresql en Podman.
Este es el prototipo del daemon bos y el validador de fichas.

**Entregables:**
```
/opt/sbos-dev/
├── testbench/
│   ├── testbench.sh        ← CLI: install|uninstall|status|certify
│   ├── engine.sh           ← algoritmo Kahn + recursion dependencias
│   ├── schema.sql          ← fichas_state + knowledge_base + relations
│   └── pod-engine.yml      ← pod Podman con PostgreSQL 18-alpine
└── fichas/
    └── postgresql/
        ├── manifest.yml
        ├── yaml_engine.yml
        ├── task_catalog.sh
        └── resources/k8s/pod.yml
```

**Criterio de completitud:**
- `testbench.sh install postgresql` → sbos-postgresql corriendo
- `pg_isready` = OK, estado en KB = INSTALADA_OK
- `testbench.sh uninstall postgresql` → limpio
- Segunda ejecucion de install → idempotente (no duplica)

**Prompt para iniciar esta etapa:**
```
Continuamos con el proyecto SBOS. Lee la Ayuda Memoria y SBOS-MP06.
Etapa actual: 2 — Testbench Podman + ficha postgresql.
Etapa 1 completada. Los 4 archivos maestros estan en /opt/sbos-dev/core/.
Objetivo: crear testbench Podman y primera ficha postgresql.
testbench.sh install postgresql debe terminar con sbos-postgresql
corriendo y estado INSTALADA_OK en la knowledge base.
```

---

### ETAPA 3 — Sprint 1: fichas P1 datos e identidad base
**Estado:** PENDIENTE
**Duracion estimada:** 2-3 sesiones
**Prerequisito:** Etapa 2 completa

**Fichas:** redis, vault, pgadmin
**Todas dependen de postgresql — Kahn resuelve el orden.**

**Criterio de completitud:**
- `testbench.sh install pgadmin` resuelve postgresql → pgadmin auto
- Kahn validado con dependencias reales
- Knowledge base aprende patron: app_web necesita postgresql

**Prompt para iniciar:**
```
Continuamos con SBOS. Lee Ayuda Memoria y SBOS-MP06.
Etapa actual: 3. Etapas 1 y 2 completas.
postgresql corre en Podman. Objetivo: fichas redis, vault, pgadmin
con dependencias reales resueltas por Kahn.
```

---

### ETAPA 4 — Sprint 2: identidad y gateway
**Estado:** PENDIENTE
**Duracion estimada:** 2-3 sesiones
**Prerequisito:** Etapa 3 completa

**Fichas:** keycloak, kong, nginx, oauth2-proxy
**keycloak depende de postgresql. kong depende de keycloak.**

**Criterio de completitud:**
- `testbench.sh install kong` resuelve postgresql → keycloak → kong
- SSO funcional end-to-end en Podman

**Prompt para iniciar:**
```
Continuamos con SBOS. Lee Ayuda Memoria y SBOS-MP06.
Etapa actual: 4. Etapas 1-3 completas.
Objetivo: fichas keycloak, kong, nginx, oauth2-proxy con SSO funcional.
```

---

### ETAPA 5 — Sprint 3: correo completo
**Estado:** PENDIENTE
**Duracion estimada:** 1-2 sesiones
**Prerequisito:** Etapa 4 completa
**Nota:** 79% del codigo viene del TODOIAM legacy. Principalmente migracion.

**Fichas:** mailserver, postfixadmin, roundcube, cypht

**Criterio de completitud:**
- Correo funcional end-to-end
- Roundcube accesible con SSO Keycloak

**Prompt para iniciar:**
```
Continuamos con SBOS. Lee Ayuda Memoria y SBOS-MP06.
Etapa actual: 5. Etapas 1-4 completas. SSO funcional.
Objetivo: fichas correo (mailserver, postfixadmin, roundcube, cypht).
Tenemos codigo TODOIAM legacy al 79%. Migrarlo al formato ficha SBOS.
```

---

### ETAPA 6 — Sprint 4: observabilidad + ERP
**Estado:** PENDIENTE
**Duracion estimada:** 2 sesiones
**Prerequisito:** Etapa 5 completa

**Fichas:** prometheus, grafana, tryton, alertmanager

**Criterio de completitud:**
- Grafana con dashboards del cluster Podman
- Tryton accesible con SSO
- Prometheus scrapeando todos los contenedores

**Prompt para iniciar:**
```
Continuamos con SBOS. Lee Ayuda Memoria y SBOS-MP06.
Etapa actual: 6. Etapas 1-5 completas. Correo funcional.
Objetivo: fichas prometheus, grafana, tryton, alertmanager.
```

---

### ETAPA 7 — 16 fichas bootstrap completas en Podman
**Estado:** PENDIENTE
**Duracion estimada:** 2-3 sesiones
**Prerequisito:** Etapas 1-6 completas

**Objetivo:** La secuencia completa de SBOS-031 ejecutando en Podman.
Este es el sistema base completo validado antes de K8s.

**Fichas (orden DAG de SBOS-031):**
sbos-bootstrap-os (bash host) →
sbos-bootstrap-k8s (bash host) →
sbos-bootstrap-platform (bash host) →
sbos-k8s-network-validator →
postgresql → redis → minio → vault → keycloak →
nginx → kong → linkerd → kyverno →
prometheus → grafana →
sbos-bootstrap-hardening (bash host)

**NOTA IMPORTANTE:** Las fichas bootstrap-* son Tipo 1 (workload.type: bash).
En el testbench Podman se ejecutan como scripts locales en el host,
no como contenedores. Esta es la UNICA diferencia con K8s real.

**Criterio de completitud:**
- `testbench.sh install-product bootstrap` ejecuta 16 fichas en orden
- Estado final en KB: SISTEMA_BASE_COMPLETO
- Todos los servicios responden a health checks

**Prompt para iniciar:**
```
Continuamos con SBOS. Lee Ayuda Memoria y SBOS-MP06.
Etapa actual: 7. Etapas 1-6 completas. 20 fichas individuales funcionando.
Objetivo: install-product bootstrap ejecuta las 16 fichas de SBOS-031
en el orden DAG correcto en Podman.
```

---

### ETAPA 8 — Daemon bos en Go
**Estado:** PENDIENTE
**Duracion estimada:** 3-4 sesiones
**Prerequisito:** Etapa 7 completa

**Objetivo:** Convertir el testbench Bash en el daemon Go real.
La logica ya esta validada en Bash — esta etapa es reescritura
en el lenguaje definitivo con todas las garantias de produccion.

**Entregables:**
```
/opt/sbos-dev/
└── cmd/
    ├── bos/
    │   ├── main.go              ← entry point + systemd sd_notify
    │   ├── server/              ← HTTP API + Unix socket bosctl
    │   ├── state/               ← STATE_MANAGER (Go)
    │   ├── engine/              ← YAML_ENGINE wrapper → exec Bash
    │   ├── resolver/            ← DEPENDENCY_RESOLVER Kahn en Go
    │   ├── health/              ← HEALTH_CHECKER
    │   ├── saga/                ← INSTALL_RUNNER con compensaciones
    │   └── release/             ← RELEASE_MANAGER Ed25519
    └── bosctl/
        └── main.go              ← CLI completo
```

**Criterio de completitud:**
- `bosctl install postgresql` funciona via daemon Go en Ubuntu 24.04
- `systemctl status bos` = active (running)
- `bosctl status` muestra fichas instaladas
- El daemon sobrevive un `systemctl restart bos` sin perder estado

**Prompt para iniciar:**
```
Continuamos con SBOS. Lee Ayuda Memoria y SBOS-MP06.
Etapa actual: 8. Etapa 7 completa. 16 fichas funcionando en Podman.
Objetivo: daemon bos en Go con bosctl CLI.
bosctl install postgresql debe funcionar via bos.service.
```

---

### ETAPA 9 — Migracion Podman → K8s real
**Estado:** PENDIENTE
**Duracion estimada:** 2-3 sesiones
**Prerequisito:** Etapa 8 completa + VPS con kubeadm

**Objetivo:** Las mismas fichas funcionando en K8s.
Los YAML K8s ya existen desde Etapa 2.
La migracion es cambiar runtime de podman play kube a kubectl apply.

**Criterio de completitud:**
- `bosctl install-product bootstrap` ejecuta 16 fichas en K8s real
- `kubectl get pods -A` muestra todos en Running
- `bosctl status` muestra SISTEMA_BASE_COMPLETO

**Prompt para iniciar:**
```
Continuamos con SBOS. Lee Ayuda Memoria y SBOS-MP06.
Etapa actual: 9. Etapa 8 completa. daemon bos funcionando.
Objetivo: migrar fichas de Podman a K8s real.
VPS tiene kubeadm instalado. Los YAML K8s ya existen.
```

---

### ETAPA 10 — Certifier + Release Plane basico
**Estado:** PENDIENTE
**Duracion estimada:** 2 sesiones
**Prerequisito:** Etapa 9 completa

**Objetivo:** Pipeline de certificacion + firma Ed25519.
Una ficha no puede publicarse sin pasar los 5 niveles del certifier.

**Entregables:**
- `testbench.sh certify postgresql` → 5 niveles → firma SHA-256
- `validate_sp02.py` contra fichas reales
- Release Server local con artefactos firmados
- `bos` verifica firma Ed25519 antes de instalar cualquier ficha

**Criterio de completitud:**
- `make release FICHA=postgresql` genera artefacto firmado
- `bos` rechaza fichas sin firma o con firma invalida

**Prompt para iniciar:**
```
Continuamos con SBOS. Lee Ayuda Memoria y SBOS-MP06.
Etapa actual: 10. Etapas 1-9 completas. SBOS v0.9 casi listo.
Objetivo: certifier 5 niveles + firma Ed25519 en Release Plane basico.
```

---

## TABLA RESUMEN DEL PLAN

| Etapa | Nombre | Sesiones | Entregable clave | Estado |
|-------|--------|----------|-----------------|--------|
| 0 | Rectificacion documental | 0.5 | 4 inconsistencias eliminadas | COMPLETADA |
| 1 | Motor Core + 4 archivos maestros | 1-2 | validate_sp01.py pasa | PROXIMA |
| 2 | Testbench + postgresql | 2-3 | testbench.sh install postgresql | - |
| 3 | Sprint 1: datos base | 2-3 | Kahn con dependencias reales | - |
| 4 | Sprint 2: identidad y gateway | 2-3 | SSO funcional | - |
| 5 | Sprint 3: correo | 1-2 | Email end-to-end | - |
| 6 | Sprint 4: observabilidad + ERP | 2 | Grafana + Tryton | - |
| 7 | 16 fichas bootstrap en Podman | 2-3 | Sistema base validado | - |
| 8 | Daemon bos en Go | 3-4 | bosctl + bos.service | - |
| 9 | Podman → K8s real | 2-3 | Fichas en K8s real | - |
| 10 | Certifier + Release Plane | 2 | Firma Ed25519 | - |
| **Total** | | **~22-28 sesiones** | **SBOS v0.9 piloto** | |

---

## PROTOCOLO DE CONTINUIDAD ENTRE SESIONES

Al finalizar cada sesion de trabajo:

1. Actualizar este documento (SBOS-MP06):
   - Marcar etapa como COMPLETADA o PARCIAL
   - Documentar exactamente que se hizo y que falta
   - Actualizar el prompt de inicio de la siguiente etapa

2. Actualizar SBOS-AYUDA-MEMORIA-PROYECTO.md §9:
   - Seccion ETAPA ACTUAL con nombre y numero
   - Prompt exacto para continuar

3. Commit con mensaje:
   `[ETAPAn-PARCIAL] descripcion` o `[ETAPAn-COMPLETA] descripcion`

**Con este protocolo, la proxima sesion empieza en 60 segundos
leyendo este documento — sin retroalimentacion, sin confusion.**

---

## REGLAS DE ORO DEL DESARROLLO

1. **Un concepto = un archivo.** No duplicar logica entre etapas.

2. **Codigo ejecutable siempre.** Ningun pseudocodigo, ningun placeholder.
   Todo lo que se escribe debe poder ejecutarse en Ubuntu 24.04.

3. **Cristalizar descubrimientos.** Si durante el trabajo se descubre
   algo nuevo (un puerto, un timing, una dependencia), documentarlo
   inmediatamente en la ficha correspondiente.

4. **Idempotencia obligatoria.** Ejecutar cualquier operacion dos veces
   debe producir el mismo resultado. Sin excepciones.

5. **Validar antes de avanzar.** No pasar a la siguiente etapa sin
   que el criterio de completitud de la etapa actual este cumplido.

6. **bos = el SO empresarial.** Nunca confundirlo con bkernel (kernel
   de datos) ni con systemd ni con el kernel de Linux.

---

## INCONSISTENCIAS CORREGIDAS (no reintroducir)

| Documento | Error | Correccion |
|-----------|-------|------------|
| SBOS-018 §11.1 | task_catalog.so (Cython) | task_catalog.sh (Bash, definitivo) |
| SBOS-AYUDA-MEMORIA Prompt | Podman 5.x | Podman 4.9.3 (Ubuntu 24.04) |
| SBOS-AYUDA-MEMORIA §1 | bos=systemd, bkernel=kernel SO | bos=SO empresarial, bkernel=kernel datos |
| Conversacion (no en docs) | bos.so como biblioteca | bos=binario Go estatico, no .so |

---

*SKULL · SBOS · SBOS-MP06 · Plan Maestro de Desarrollo · v1.0 · Marzo 2026*
*Clasificacion: GESTION DE PROYECTO — Memoria de Desarrollo*
*Actualizar al final de cada sesion de trabajo.*
