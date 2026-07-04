# SBOS-004-RULES
## Reglas de Negocio — Estandar HUMAN-DOC (Enriquecido V8)
### SKULL · SBOS v1.1-V8 · Mayo 2026

---

## 1. Reglas Inviolables — Principios de Arquitectura

Estos principios son restricciones de diseno, no aspiraciones. Toda decision que contradiga cualquiera requiere aprobacion ARB explicita y ADR documentado.

| ID | Regla | Alcance | Consecuencia si se viola |
|---|---|---|---|
| P1 | sbos_k8s_core() es el UNICO kubectl apply | Core SP-01 | Pierde trazabilidad de cambios en cluster |
| P2 | pre_install es guardian — si falla, ABORT | Fichas | Sin bypass, ficha no se instala |
| P3 | Catalogo global NUNCA nombra apps concretas | Core SP-01 | Core crece por apps (viola P4) |
| P4 | Core nunca crece para soportar apps nuevas | Core SP-01 | Acoplamiento con apps |
| P5 | yaml_engine.yml no contiene logica Bash | Fichas | Mezcla declarativo/imperativo |
| P6 | Todas las funciones de task_catalog.sh terminan con export -f | Fichas | Funciones no disponibles en subshells |
| P7 | Ciclo Absorber/Ejecutar/Liberar obligatorio | Fichas | Contaminacion entre fichas |
| P8 | STATE_MANAGER.py es la UNICA escritura en .sbos_state.json | Core SP-01 | Estado inconsistente |
| P9 | Idempotencia: --dry-run=client + kubectl apply -f - | Toda operacion | Operaciones no repetibles |
| P10 | Toda funcion Bash con return 0 o return 1 explicitos | Core SP-01 | Codigos de retorno ambiguos |
| P11 | update nunca reinstala — aplica solo delta por drift_check | Fichas | Reinstalacion innecesaria |
| P12 | repair siempre diagnostica antes de actuar | Fichas con criticality: true | Reparacion ciega |
| P13 | Todo evento de instalacion se emite en tiempo real | Core SP-01 | Perdida de observabilidad |
| P14 | cold nunca ejecuta automaticamente — requiere aprobacion humana | Fichas cold | Accion destructiva sin HITL |
| P15 | Pull-only para actualizaciones de flota | Release Plane | SKULL puede empujar codigo sin consentimiento |

---

## 2. Reglas Inviolables — Soberania y Datos

| ID | Regla | Tipo |
|---|---|---|
| S1 | Los datos del cliente NUNCA salen de su infraestructura | Soberania |
| S2 | bKernel consolida SIN modificar apps ni sus BDs (cero invasion) | Arquitectonica |
| S3 | 100% open source, licencias OSI-approved exclusivamente | Legal |
| S4 | Toda app del stack DEBE soportar PostgreSQL | Arquitectonica |
| S5 | Toda app DEBE ser gobernada por Keycloak | Arquitectonica |
| S6 | K8s desde el dia 1 — no existe modo "sin Kubernetes" | Operacional |
| S7 | Secrets via Vault — cero passwords en texto claro | Seguridad |
| S8 | Daemons soberanos en el host (systemd, NO pods K8s) | Arquitectonica |
| S9 | Docker VETADO — exclusivamente Podman/OCI | Operacional |

---

## 3. Reglas de Seguridad — Zero Trust (NIST SP 800-207)

| Principio NIST | Implementacion SBOS |
|---|---|
| Todos los recursos no confiables | Linkerd mTLS entre todos los pods |
| Comunicaciones aseguradas siempre | TLS 1.3 obligatorio, mTLS interno |
| Acceso por sesion | JWT Keycloak: access 5min, refresh 30min |
| Politica dinamica | H-RBAC con horario, ubicacion, score conductual |
| Monitoreo de integridad | Wazuh agent en servidores, Kyverno en pods |
| Autenticacion/autorizacion universal | Keycloak OIDC (usuarios), mTLS (servicios), Vault (secrets) |
| Mejora continua de postura | Wazuh SIEM + OpenMetadata + Airflow analytics |

---

## 4. Reglas de Compliance / Legales

| Regla | Norma | Jurisdiccion | Estado |
|---|---|---|---|
| Datos personales en infraestructura del cliente | LGPD, Ley 25.326, Ley 21.719, DS 016-2024-JUS | Brasil, Argentina, Chile, Peru | Cumplimiento nativo por diseno |
| Notificacion de brechas en 72h | GDPR Art. 33, LGPD | UE, Brasil | Protocolo en SBOS-023-Breach |
| Cifrado en reposo y en transito | ISO 27001 A.8.24, A.8.26 | Internacional | PostgreSQL + LUKS + TLS 1.3 |
| Auditoria de acceso | ISO 27001 A.8.15, A.8.16 | Internacional | Wazuh + bAuth access_log |
| Licencias libres sin excepcion | Politica SKULL | Interno | Vetadas: BSL, SSPL, Sustainable Use |
| Cumplimiento tributario SIN Bolivia | Ley 843, DS 24051, normativa SIN/SIAT | Bolivia | Via biedata — SIAT API |
| Cumplimiento AFIP Argentina | RG factura electronica | Argentina | Via biedata — AFIP WS |
| Cumplimiento SAT Mexico | CFDI 4.0 | Mexico | Via biedata — SAT WS |

---

## 5. Reglas de Fronteras Arquitectonicas

| ID | Frontera | Invariante |
|---|---|---|
| F1 | sbos_k8s_core() es el unico kubectl apply | Trazabilidad |
| F2 | bKernel NO ejecuta DDL en BDs de apps | Cero invasion |
| F3 | Fichas no se llaman entre si | Desacoplamiento |
| F4 | IAM Installer NO es pod K8s | Independencia |
| F5 | hostserver NO instala software de negocio | Separacion infra/negocio |
| F6 | biedata es el UNICO con acceso a red exterior | Control exfiltracion |
| F7 | bCompass es el UNICO que invoca Ollama | Trazabilidad LLM |
| F8 | Daemons no se llaman entre si directamente | Independencia de fallos |

---

## 6. Reglas de Calidad de Codigo

### Bash
- `#!/usr/bin/env bash` + `set -euo pipefail` obligatorio
- `local` para variables en funciones
- `yq eval` para YAML — nunca grep/sed
- `${SBOS_DIR}` — nunca /opt/sbos hardcodeado
- Logging via `python3 "${LOGGER_PY}"` — nunca echo
- Senales __SBOS__STEP_START__, __SBOS__STEP_OK__, __SBOS__STEP_ERROR__
- Finales de linea: LF Unix — NUNCA CRLF

### Python
- Type hints en todas las funciones publicas
- Docstrings en clases y funciones publicas
- `from pathlib import Path` — nunca os.path
- Logging via LOGGER.py — nunca print()
- subprocess via PROCESS_MANAGER.py — nunca subprocess.run() directo
- Manejo explicito de excepciones — sin `except Exception: pass`

### Rust (bKernel, biedata)
- `#![deny(unsafe_code)]` salvo C ABI explicito
- clippy --deny warnings obligatorio
- cargo fmt --check antes de merge
- Sin .unwrap() ni .expect() en produccion
- Tipos de error propios con thiserror::Error
- Tests integracion + prueba de carga 1000 ejecuciones sin memory leak

### Go (bos, bCompass, bSearch, bAuth, bhnexus, banexus)

#### Formato y lint
- `gofmt -s` obligatorio — el CI rechaza codigo sin formatear
- `goimports` para gestion de imports: agrupa stdlib / externos / internos en ese orden
- `golangci-lint run` obligatorio antes de merge — configuracion en `.golangci.yml` en raiz de cada daemon
- `go vet ./...` — cero warnings tolerados
- `go build -race ./...` en CI para deteccion de race conditions

Linters habilitados minimos en `.golangci.yml`:
```
errcheck, gosimple, govet, ineffassign, staticcheck,
unused, gofmt, goimports, misspell, revive, gosec,
bodyclose, noctx, contextcheck
```

#### Errores
- Los errores son valores — nunca ignorar un error retornado sin justificacion explicita
- Wrapping obligatorio con contexto: `fmt.Errorf("operacion X en recurso Y: %w", err)`
- Tipos de error propios cuando el caller necesita distinguir el tipo: implementar `Error() string` y `Unwrap() error`
- `errors.Is` / `errors.As` para comparacion y extraccion — nunca comparacion de strings
- Sin `panic()` en codigo de produccion — solo en `init()` para configuracion invalida irrecuperable
- Cada error se maneja exactamente una vez en el call stack — no loguear y tambien retornar
- Nunca suprimir errores con `_` salvo en defer de Close() con justificacion comentada

#### Goroutines y concurrencia
- `context.Context` como primer parametro en toda funcion que haga I/O o pueda bloquearse
- Toda goroutine debe tener una condicion de terminacion explicita: `ctx.Done()`, canal de senal, o `sync.WaitGroup`
- `errgroup.Group` (golang.org/x/sync/errgroup) para grupos de goroutines con manejo de error unificado
- Sin goroutines globales — toda goroutine se crea dentro de la funcion que controla su ciclo de vida
- `sync.Mutex` para proteger estado compartido — nunca variables de paquete accedidas desde multiples goroutines sin sincronizacion
- Ratio goroutines/CPU: worker pools con tamano configurable, nunca `go func()` ilimitado en loops
- Canales tipados por direccion en firmas de funcion: `jobs <-chan Task`, `results chan<- Result`

#### Context
- `context.Background()` solo en `main()` y en raices de tests
- `context.WithTimeout` para toda operacion con red o BD — nunca esperas indefinidas
- No almacenar context en structs — siempre pasarlo como parametro
- No pasar `nil` como context — usar `context.TODO()` si el contexto correcto no esta disponible aun

#### Dependencias y modulos
- `go.mod` con version de Go pinada: `go 1.22` (nunca rango)
- `go mod tidy` obligatorio antes de commit — CI verifica que go.sum este limpio
- Sin dependencias de `vendor/` — modulos resueltos desde el proxy oficial
- CGO_ENABLED=0 para binarios de produccion — binarios 100% estaticos
- `go build -ldflags="-s -w"` para minimizar tamano del binario en releases

#### Estructura de paquetes
- Un paquete por responsabilidad — sin paquetes `utils`, `helpers`, `common`
- Nombres de paquete en minusculas, una sola palabra, sin guiones ni underscores
- Interfaces definidas en el paquete que las consume, no en el que las implementa
- No usar variables globales de paquete para estado mutable — inyectar dependencias via constructores
- `internal/` para codigo que no debe ser importado por otros modulos

#### Testing
- `go test -race -count=1 ./...` — race detector siempre activo en CI
- Tests unitarios en el mismo paquete (caja blanca) o paquete `_test` (caja negra) segun corresponda
- Table-driven tests para casos multiples del mismo comportamiento
- Mocks solo para interfaces externas (KC Admin API, Vault API) — BD real en integration tests
- Cobertura minima por daemon: bos ≥ 80%, bCompass ≥ 75%, bSearch ≥ 75%, bAuth ≥ 85%, bhnexus ≥ 70%, banexus ≥ 70%
- `testify/assert` y `testify/require` para assertions — no comparaciones manuales con t.Errorf

#### Logging y observabilidad
- `github.com/rs/zerolog` — logging estructurado JSON, nivel configurable por variable de entorno
- Sin `fmt.Println` ni `log.Printf` en codigo de produccion — siempre via zerolog
- Campos obligatorios en cada log de error: `daemon`, `operation`, `error`
- `github.com/prometheus/client_golang` para metricas — exponer en puerto dedicado por daemon
- `context.Context` propagado a todas las operaciones para trazabilidad de request_id

#### Seguridad especifica Go
- `gosec` habilitado en golangci-lint — cero issues de severidad alta o critica
- Sin interpolacion de strings en queries SQL — siempre parametros posicionales (`$1`, `$2`)
- `crypto/rand` para generacion de tokens — nunca `math/rand`
- TLS configurado con `tls.Config{MinVersion: tls.VersionTLS13}` — nunca TLS < 1.3
- Secrets leidos de Vault en startup — nunca hardcodeados ni en flags de linea de comandos

#### Pipeline CI/CD Go (orden obligatorio)
```
1. gofmt -l .                         → cero archivos sin formatear
2. go vet ./...                       → cero warnings
3. golangci-lint run                  → cero issues (con .golangci.yml del daemon)
4. go test -race -count=1 ./...       → cero fallos, cero races
5. go build -ldflags="-s -w" -o bin/  → binario estatico
6. ed25519 sign                       → firma verificable por bos
```

---

## 7. Politica de Licencias de Software

### Aclaracion fundamental — "Apache" designa una licencia, no un servidor web

En el ecosistema del SBOS el termino "Apache" puede referirse a dos cosas completamente distintas que no deben confundirse:

**Apache HTTP Server** es el servidor web que historicamente compitio con NGINX. **No forma parte del stack SBOS.** El SBOS utiliza NGINX como servidor web y proxy inverso, y Kong como API Gateway. El Apache HTTP Server no aparece en ninguna ficha del catalogo y no debe incorporarse.

**Apache License 2.0** es un documento legal de licenciamiento open source creado por la Apache Software Foundation (ASF) en 2004. Comparte el nombre "Apache" unicamente porque la misma fundacion lo creo — no tiene relacion funcional con el servidor web. Es una licencia permisiva (sin copyleft), que otorga derechos explicitos de patente, es compatible con GPL v3, y es la segunda licencia open source mas usada en el mundo despues de MIT. La utilizan proyectos como Kubernetes, Android, TensorFlow y Swift.

La razon por la que Apache License 2.0 figura en la politica de licencias del SBOS es que varias piezas **fundacionales e irrenunciables** del stack se distribuyen bajo ella:

| Componente SBOS | Servidor logico | Licencia |
|---|---|---|
| Kubernetes | Infraestructura (todos) | Apache 2.0 |
| Calico (CNI) | Infraestructura (todos) | Apache 2.0 |
| Prometheus | S12 monitorserver | Apache 2.0 |
| Grafana Alloy | S12 monitorserver | Apache 2.0 |
| Kong Gateway OSS ≤ 3.9.x | S02 gatewayserver | Apache 2.0 |
| Apache Airflow | S07 reportserver | Apache 2.0 |
| Apache Superset | S07 reportserver | Apache 2.0 |
| OpenMetadata | S07 reportserver | Apache 2.0 |
| Qdrant | S15 aiserver | Apache 2.0 |
| Flowise | S15 aiserver | Apache 2.0 |
| Traccar | S13 geoserver | Apache 2.0 |
| Velero | S14 opsserver | Apache 2.0 |
| Trivy | S14 opsserver | Apache 2.0 |
| Goss | S14 opsserver | Apache 2.0 |
| Certbot | S02 gatewayserver | Apache 2.0 |
| ModSecurity + OWASP CRS | S02 gatewayserver | Apache 2.0 |

Eliminar Apache 2.0 de las licencias aceptadas haria tecnicamente inviable el stack del SBOS, ya que afectaria directamente la infraestructura de orquestacion (Kubernetes), observabilidad (Prometheus), gateway (Kong), inteligencia artificial (Qdrant) y backup (Velero).

### Licencias aceptadas

| Licencia | Tipo | Ejemplos en SBOS |
|---|---|---|
| MIT | Permisiva | Patroni, pgBackRest, Rocket.Chat, Mattermost, Redis, daemons SKULL |
| Apache 2.0 | Permisiva con patente explicita | Kubernetes, Prometheus, Kong OSS ≤3.9, Airflow, Superset, Qdrant |
| GPL v2 | Copyleft | OrangeHRM, Wazuh, Zabbix, FreePBX |
| GPL v3 | Copyleft | Tryton, Paperless-NGX, GNU Health |
| AGPL v3 | Copyleft fuerte | Grafana OSS, Loki, Tempo, GitLab CE, Bareos |
| LGPL v2.1/v3 | Copyleft debil | JasperReports CE, librerias de sistema |
| MPL 2.0 | Copyleft de archivo | RabbitMQ, Taiga |
| BSD 2/3-clause | Permisiva | PgBouncer, Redis alternativo |
| PostgreSQL License | Permisiva | PostgreSQL, PgAdmin 4 |
| ISC | Permisiva | Componentes de red menores |

Cualquier licencia no listada debe evaluarse y aprobarse por el ARB antes de incorporarse al stack.

### Licencias vetadas

| Licencia | Razon del veto | Afecta en el SBOS |
|---|---|---|
| Business Source License (BSL) | No es OSI-approved. Restricciones comerciales con fecha de liberacion no garantizada | HashiCorp Vault, Elasticsearch, Directus — aceptados como excepcion ARB: autoalojamiento libre, restriccion aplica solo a servicios gestionados por terceros |
| Server Side Public License (SSPL) | No es OSI-approved. Obliga a liberar toda la infraestructura que envuelve al software | Sin componentes SSPL en el stack |
| Sustainable Use License | No es OSI-approved. Restringe uso comercial | Razon del veto de n8n (ADR-006) |
| Commons Clause | Anade restriccion comercial sobre licencias otherwise libres | Sin componentes Commons Clause en el stack |
| Cualquier "Source Available" no OSI | Codigo visible pero no libre — viola principio S3 | Evaluacion requerida caso por caso |

### ⚠ Riesgo activo — Kong Gateway 3.10+ (detectado Abril 2026)

**Situacion:** En marzo 2025 Kong Inc. cambio fundamentalmente su modelo de distribucion con la version 3.10. Los cambios criticos son dos: primero, Kong dejo de publicar imagenes OCI precompiladas para Kong OSS en Docker Hub y en su registro oficial — los usuarios deben construir la imagen desde fuente. Segundo, el "free mode" de Kong Gateway Enterprise fue eliminado — correr Kong 3.10+ sin licencia Enterprise activa se comporta como licencia expirada, con funcionalidad degradada.

**Implicacion para el SBOS:** La ficha `kong` del stack usa Kong OSS bajo Apache 2.0. La ultima version con imagen OCI oficial disponible sin restricciones es **Kong OSS 3.9.x**, con soporte hasta 2027. Actualizar a 3.10+ sin decision formal implica carga operacional no planificada (build propio, escaneo, parcheo) o riesgo legal (uso de Enterprise sin licencia).

**Decision provisional en vigor:** No actualizar Kong mas alla de 3.9.x hasta resolucion formal del ARB mediante ADR-010. Toda actualizacion de la ficha `kong` requiere aprobacion ARB explicita.

**Estado formal:** Ver **ADR-010** en SBOS-006-ADR y SBOS-048-ADR-CATALOG — estado: `🔄 En evaluacion ARB`.

**Opciones bajo analisis en ADR-010:**
- Permanecer en Kong OSS 3.9.x (LTS activo hasta 2027) con build propio cuando sea necesario
- Migrar a Envoy Gateway (CNCF, Apache 2.0, sin restricciones de distribucion, respaldado por Google)
- Usar imagenes comunitarias verificadas de Kong OSS 3.10+ (ej: Tetrate, unico partner oficial de Envoy Gateway)

---

## 8. Jerarquia de Fuentes

En caso de conflicto:

```
1 (maxima) → Archivos HUMAN-DOC (este corpus)
2          → Normativa legal / regulaciones oficiales (SIN, AFIP, SAT, GDPR, ISO)
3          → Estandares tecnicos (NIST, OWASP, CIS, CNCF)
4          → Documentacion oficial de APIs/software adoptado
5          → Documentos conceptuales originales SBOS
6 (menor)  → Ideas o asunciones no verificadas
```

---

## 9. Smart* Enriquecimiento — Invariantes Fiscales (SBOS Smart Tax)

El subproyecto Smart Tax introduce invariantes fiscales que deben tratarse como reglas de negocio imperativas dentro del SBOS. Estas reglas tienen fuerza de compliance para las operaciones fiscales en Bolivia:

### Invariantes universales (todos los sectores)

| ID | Invariante | Consecuencia si se viola |
|---|---|---|
| INV-001 | SHA-256 del GZIP, nunca del XML plano | Rechazo SIN codigo 969 |
| INV-002 | Milisegundos en CUF siempre 3 digitos | CUF incorrecto > 17 chars |
| INV-003 | NIT del emisor con padding a 13 digitos | Rechazo SIN |
| INV-004 | Cadena base CUF = exactamente 53 digitos | CUF invalido |
| INV-005 | Redondeo HALF-UP obligatorio en CADA operacion | Diferencia de centavos en totales |
| INV-006 | Importe por unidad (precioUnitario) SIN descuentos | Base imponible incorrecta |
| INV-007 | DescuentoNivel = "Ninguno" SIEMRP BOLIVIA | Rechazo sector educativo/seguros |
| INV-008 | montoTotalSujetoIva = suma de importes con ICE 0 y NoSujeto=No | Rechazo SIN |
| INV-009 | montoTotal = montoTotalSujetoIva + montoTotalNoSujetoIva | Diferencia de centavos |
| INV-010 | NULO y cero NO son lo mismo en XML | Rechazo SIN por esquema XSD |

### Regla de compliance fiscal

Toda operacion de facturacion que atraviese biedata hacia SIN/AFIP/SAT debe cumplir las invariantes definidas en `SBOS_TAX_E1_INVARIANTES_FISCALES.md`. bKernel debe validar estas invariantes antes de emitir el evento de integracion fiscal.

---

## ENRIQUECIMIENTO SBOS (Primera Versión)

### SBOS-018-010-1: Estandares YAML y Contratos de Daemons Soberanos (desde SBOS-018-Standards-v1_0.md)

**yaml_engine.yml** -- Cero logica Bash, solo declaraciones `task:` + `params:`. `update_strategy` obligatorio en tareas de fase `update` (`hot`/`warm`/`cold`). `drift_check: true` por defecto. `maintenance_window: true` en toda tarea `cold`.

**route_engine.yml** (SBOS AI Tools) -- Obligatorio: al menos una fase, `task:` con nombre, `params:` (puede vacio). Toda tarea debe pertenecer al catalogo global del motor o al `route_catalog.so` de la ruta. Referencias a outputs deben apuntar a outputs declarados en fases anteriores. Sin referencias circulares. `on_failure: retry(n)` con n entre 1 y 5. `llm_prompt` siempre declara `model:` explicitamente.

**box_engine.yml** (SBOS Data Integration) -- Fase `extract` (si existe) siempre precede a `transform` y `load`. `on_failure: retry(n)` maximo n:3 para cajas de integracion externa. Cajas `type: import` nunca tienen `destination: stack_db` como fuente. Cajas `type: export` nunca tienen `source: external_api` como destino.

**manifest.yml** de daemons soberanos -- `identity.id` en snake_case, `version` formato N.N, `governance.category` siempre declarado (1|2|3). Para rutas SBOS AI Tools: `route_type` obligatorio (`analyst|agent|flow|report`). `trigger.type` obligatorio (`schedule|message|manual|event`).

### SBOS-018-010-2: Estandares SBOS Data RAG (bsearch_config) (desde SBOS-018-Standards-v1_0.md)

Todo bloque `bsearch_config` en `manifest.yml` de ficha debe cumplir:

```yaml
bsearch_config:
  enabled: true                  # OBLIGATORIO
  priority: 1-10                 # OBLIGATORIO — orden de indexacion
  schema_discoverer: true|false  # OBLIGATORIO — analisis semantico LLM
  index_entities:                # OBLIGATORIO si enabled: true
    - entity: "<nombre>"         # snake_case
      table: "<schema>.<tabla>"  # formato schema.tabla obligatorio
      searchable_fields: []      # al menos un campo
      display_template: ""       # obligatorio — template de resultado
```

Reglas: `priority` entre 1 y 10. `table` siempre `schema.tabla`. `searchable_fields` con al menos un campo. `display_template` referencia al menos un campo de `searchable_fields`.

### SBOS-018-010-3: Regla de Oro — Global vs Individual (desde SBOS-018-Standards-v1_0.md)

Si la funcion menciona el nombre de una app concreta -> va en el `task_catalog.sh` individual de esa ficha. Si opera sobre K8s de forma generica sin saber que app es -> va en `00_TASK_CATALOG_SBOS.sh` global.

Aplica tambien a daemons soberanos:

| Ambito | Motor | Catalogo global | Catalogo especifico |
|--------|-------|-----------------|---------------------|
| Ficha IAM Installer | Core (SP-01) | `00_TASK_CATALOG_SBOS.sh` | `task_catalog.sh` de la ficha |
| Ruta SBOS AI Tools | bCompass | Tareas globales (`llm_prompt`, `db_query`) | `route_catalog.so` de la ruta |
| Caja SBOS Data Integration | biedata | Tareas globales (`http_fetch`, `csv_parse`) | `box_catalog.so` de la caja |

### SBOS-018-010-4: Validadores Automaticos en CI/CD (desde SBOS-018-Standards-v1_0.md)

Los validadores son pasos bloqueantes del `make release`. Exit != 0 -> ABORT release. No existen flags `--warn-only` ni `--skip`.

**validate_sp01.py** -- Verifica cumplimiento de los 14 Principios Inquebrantables:

| Verificacion | Principio | Falla si |
|---|---|---|
| kubectl fuera de `sbos_k8s_core` | P1 | Cualquier archivo llama `kubectl` directamente |
| Nombres de apps en catalogo global | P3 | `00_TASK_CATALOG_SBOS.sh` menciona apps concretas |
| subprocess fuera de PROCESS_MANAGER | P5 | Python usa `subprocess.run()` directamente |
| Funciones sin `export -f` | P6 | Funcion Bash sin `export -f` al final |
| Escritura directa a `.sbos_state.json` | P8 | Codigo fuera de STATE_MANAGER.py escribe en ese archivo |
| kubectl create sin `--dry-run` | P9 | kubectl create sin flag de idempotencia |
| Tareas cold sin maintenance_window | P14 | Tarea cold sin `maintenance_window: true` |
| Calidad Python | -- | `print()`, `os.path`, `except Exception: pass`, type hints faltantes |

**validate_sp02.py** -- Verifica contratos YAML de daemons soberanos:

| Tipo | Flag | Verifica |
|---|---|---|
| `route_engine.yml` | `--type route` | Fases validas, tareas referenciadas, outputs declarados, sin ciclos |
| `box_engine.yml` | `--type box` | Orden de fases, n de retry, direccion de la caja |
| `manifest.yml` | `--type manifest` | id snake_case, version semver, governance.category presente |
| `bsearch_config` | `--type bsearch` | priority en rango, table con schema, searchable_fields no vacio |

### SBOS-018-010-5: Justificacion Rust vs Go por Daemon (desde SBOS-018-Standards-v1_0.md)

| Criterio | Rust | Go |
|----------|------|----|
| Modelo de memoria | Ownership + borrow checker (zero GC) | Garbage Collector concurrente |
| Latencia | Determinista, sin pausas GC | Predecible, GC de baja latencia |
| Concurrencia | async/await + tokio (zero-cost) | Goroutines (2-4 KB) + channels |
| Workloads I/O-bound | Excelente (mas verboso) | Excelente + idiomatico |
| Tiempo desarrollo | Mayor (borrow checker) | Rapido (sintaxis minimalista) |
| Caso ideal en SBOS | WAL CDC, parseo archivos grandes, ETL transaccional | WebSocket, HTTP APIs, Redis Streams |

Regla de asignacion: **Rust** -> bkernel, biedata (latencia determinista, sin GC). **Go** -> bcompass, bsearch, bauth, bhnexus, banexus (I/O-bound, alta concurrencia de red). **Go + Python + Bash** -> bos (naturaleza hibrida de orquestacion).

### SBOS-018-010-6: Stack Tecnologico por Daemon (desde SBOS-018-Standards-v1_0.md)

| Daemon | Lenguaje | Runtime/Librerias clave | Puerto metricas |
|--------|----------|------------------------|-----------------|
| bos (IAM Installer) | Go + Python + Bash | net/http, zerolog, pyproject.toml | 9090 |
| bkernel (Data Kernel) | Rust | tokio, pgwire-replication, deadpool-postgres, serde | 9100 |
| biedata (Data Integration) | Rust | tokio, calamine, reqwest, quick-xml, russh | 9101 |
| bcompass (AI Tools) | Go | pgx/v5, go-redis, go-openai, zerolog | 9102 |
| bsearch (Data RAG) | Go | meilisearch-go, gin-gonic, pgx/v5, redis/go-redis | 9103 |
| bauth (Auth Enforce) | Go | kolo/xmlrpc, coder/websocket, golang-jwt, pgx/v5 | 9104 |
| bhnexus/banexus (Nexus) | Go | coder/websocket, pgx/v5, fsnotify | 9105/9106 |

### SBOS-018-010-7: Toolchain de Desarrollo por Lenguaje (desde SBOS-018-Standards-v1_0.md)

**Rust** -- cargo build/test/check/clippy/fmt/audit, cross (MUSL target), cargo flamegraph, tokio-console, rust-analyzer.

**Go** -- go build/test/vet, golangci-lint, gofmt/goimports, govulncheck, dlv debug, pprof, gopls.

### SBOS-018-010-8: Pipeline CI/CD por Tipo de Daemon (desde SBOS-018-Standards-v1_0.md)

**Pipeline Rust** (bkernel, biedata): cargo fmt --check -> cargo clippy -D warnings -> cargo check --all-features -> cargo test --all-features -> cargo audit -> cross build --release (MUSL) -> ed25519 sign.

**Pipeline Go** (bcompass, bsearch, bauth, bhnexus, banexus): gofmt -l | grep -c . (0 diffs) -> go vet ./... -> golangci-lint run -> go test -race -count=1 ./... -> go test -coverprofile (>=80%) -> govulncheck -> go build -ldflags="-s -w" -> ed25519 sign.

### SBOS-018-010-9: Estructura de Repositorios por Daemon (desde SBOS-018-Standards-v1_0.md)

| Repositorio | Lenguaje | Binario | Notas |
|---|---|---|---|
| sbos-bos | Go + Python + Bash | bos | IAM Installer + modulos Python de fichas |
| sbos-bkernel | Rust | bkernel | CDC WAL, latencia critica, releases controlados |
| sbos-biedata | Rust | biedata | ETL + parseo Excel, misma cadencia que bkernel |
| sbos-bcompass | Go | bcompass | Orquestador LLM, iteracion rapida por rutas nuevas |
| sbos-bsearch | Go | bsearch | Motor de busqueda, evolucion junto a Meilisearch |
| sbos-bauth | Go | bauth | Cambios alineados con Keycloak releases |
| sbos-bnexus | Go | bhnexus + banexus | Repo unificado: protocolo host y agente mismo codigo |

### SBOS-018-010-10: Matriz de Riesgos Tecnicos por Daemon (desde SBOS-018-Standards-v1_0.md)

| Daemon | Riesgo principal | Severidad | Mitigacion |
|---|---|---|---|
| bkernel | Complejidad borrow checker en manejo de LSN | Media | Tokio + tipos wrapper. Tests exhaustivos de replay |
| biedata | calamine sin soporte de formato (solo lectura valores) | Media | Documentar limitacion. rust_xlsxwriter para escritura |
| bcompass | GC pauses durante streaming LLM largo (>30s) | Baja | context.Context timeout. Streaming chunked |
| bsearch | Go plugin system (.so) inestable entre versiones | Media | Fijar version Go en CI. Interfaz minima en plugin API |
| bhnexus/banexus | Memory leak en goroutines sin cierre correcto | Media | SetReadDeadline + SetWriteDeadline. pprof en produccion |
| bauth | Latencia Tryton XML-RPC en onboarding masivo | Baja | Pool goroutines XML-RPC. Circuit breaker por timeout |
| bos | Modulos Python sin recompilar tras cambio de logica | Media | Cython en pre-release. Tests integracion fichas en CI |

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1 Principios Core | SBOS-018 v1.0 | §1 Los 14 Principios Inquebrantables |
| §2 Soberania | SBOS-001-VISION v4.0 | §10 Principios Rectores (P1-P15) |
| §3 Zero Trust | SBOS-023 v1.0 | §1 Modelo Zero Trust, §2 Vectores |
| §4 Compliance | SBOS-023 v1.0, SBOS-030 v1.0, SBOS-011-Tributario | §compliance, §SoA, §SIAT |
| §5 Fronteras | SBOS-002-ARCH v4.0 | §16 Fronteras que No se Cruzan |
| §6 Bash, Python, Rust | SBOS-018 v1.0 | §2 Bash, §3 Python, §4 Rust |
| §6 Go | Investigacion web 2025-2026 — golangci-lint v2 docs, JetBrains GoLand Blog, GitLab Go Guide | Mejores practicas produccion Go 1.22+ |
| §7 Aclaracion Apache | Investigacion web — Apache Software Foundation, FOSSA, Wikipedia | Apache License 2.0 vs Apache HTTP Server |
| §7 Tabla componentes | SBOS-005-STACK v1.0 | §3 Servidores logicos con licencias por app |
| §7 Riesgo Kong 3.10 | Investigacion web — Kong GitHub discussions #14405 #14628, kong.com changelog, Tasrie IT | Kong business model change marzo 2025 |
| §7 Licencias vetadas | SBOS-001-VISION v4.0, SBOS-003-STACK v4.0, ADR-006 | P9, §auditoria licencias, veto n8n |
| §8 Jerarquia | HUMAN-DOC-STANDARD | §politica de fuentes |
| §9 Smart* | SBOS_TAX_E1_INVARIANTES_FISCALES.md | Invariantes fiscales universales, tabla INV-001 a INV-010 |
| §10 SBOS-018-010-1 a SBOS-018-010-10 | SBOS-018-Standards-v1_0.md | YAML/Contract YAML standards, bsearch_config, Global vs Individual rule, validadores CI/CD (validate_sp01/sp02), Rust vs Go justificacion, stack tecnologico por daemon, toolchain, pipeline CI/CD, repos por daemon, matriz de riesgos |

---

## Fuentas de Enriquecimiento V8

| Fuente | Tipo | Contenido aportado |
|---|---|---|
| BOS_V6_SBOS-004-RULES.md | V6 (canonico) | Contenido base completo preservado |
| SBOS_TAX_E1_INVARIANTES_FISCALES.md (Smart Tax) | Smart* | Invariantes fiscales universales, reglas de compliance fiscal, implicaciones de validacion |
| SBOS-018-Standards-v1_0.md | SBOS (V8) | YAML standards, contract YAML for daemons, bsearch_config standards, Global vs Individual rule, validate_sp01/sp02 validators, Rust vs Go justification, stack tech per daemon, toolchain, CI/CD pipeline, repo structure, risk matrix |

---

_SKULL · SBOS · SBOS-004-RULES · HUMAN-DOC v1.1-V8 · Mayo 2026_
_Enriquecimiento V8: Smart* invariantes fiscales (INV-001 a INV-010) + reglas de compliance fiscal_
