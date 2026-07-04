# SBOS-006-ADR
## Decisiones de Arquitectura — Estandar HUMAN-DOC (Enriquecido V8)
### SKULL · SBOS v1.3-V8 · Mayo 2026

---

## 1. Indice de Decisiones

| ID | Titulo | Fecha | Estado |
|---|---|---|---|
| ADR-001 | WAL de PostgreSQL como EventBus nativo | 2026-01 | ✅ Aceptada |
| ADR-002 | Daemons soberanos como systemd fuera de K8s | 2026-01 | ✅ Aceptada |
| ADR-003 | IAM Installer como daemon residente, no script | 2026-01 | ✅ Aceptada |
| ADR-004 | Keycloak como unico proveedor de identidad | 2025-09 | ✅ Aceptada |
| ADR-005 | PostgreSQL como unica BD relacional | 2025-09 | ✅ Aceptada |
| ADR-006 | Veto de n8n — bCompass como reemplazo | 2025-11 | ✅ Aceptada |
| ADR-007 | Firma Ed25519 de artefactos del Release Plane | 2026-01 | ✅ Aceptada |
| ADR-008 | Fichas como unidad atomica de despliegue | 2025-09 | ✅ Aceptada |
| ADR-009 | Rust para CPU-bound, Go para I/O-bound | 2026-03 | ✅ Aceptada |
| ADR-010 | Estrategia API Gateway — Mantener Kong OSS 3.9.x LTS | 2026-04 | ✅ Aceptada |

---

## 2. Proceso ARB (Architecture Review Board)

### Cuando se requiere ADR
- Afecta principios inquebrantables (Keycloak, PostgreSQL, licencias)
- Modifica protocolo WAL o slots de replicacion
- Introduce dependencias en daemons soberanos
- Cambia canal de distribucion Ed25519
- Impacta S01 (dataserver) o S03 (identityserver)
- **Cambio de modelo de licenciamiento o distribucion de un componente del stack** ← anadido por ADR-010

### Proceso
1. Abrir RFC como GitHub Issue con label `architecture-decision`
2. 5 dias habiles para comentarios
3. Decision en reunion mensual ARB
4. Si aprobada: Arquitecto Lead formaliza como ADR en 48h

### Composicion ARB
- CTO (obligatorio)
- Arquitecto Lead (obligatorio)
- 1 representante tecnico de dominio (rotativo)
- Quorum: 3 miembros

---

## 3. Catalogo de ADRs

### ADR-001 — WAL como EventBus nativo

| Campo | Valor |
|---|---|
| Decision | WAL de PostgreSQL con pgoutput es el bus de eventos. No se usa Kafka, RabbitMQ, Redis Streams, n8n |
| Razon | Cero invasion: apps solo escriben en su BD, WAL hace el resto. Sin infra adicional. Ordering causal por LSN |
| Rechazadas | Kafka+Debezium (modifica PG), MuleSoft/Boomi (SaaS, viola soberania), Redis Streams (apps deben publicar), RabbitMQ (sin orden causal), Polling (latencia) |
| Trade-offs | Dependencia unica en PG (mitigado: Patroni HA). Slots requieren gestion explicita. max_slot_wal_keep_size |

### ADR-002 — Daemons systemd fuera de K8s

| Campo | Valor |
|---|---|
| Decision | Daemons corren como systemd en host Ubuntu, no como pods K8s |
| Razon | Acceso directo al WAL via socket Unix (<100ms). Independientes del ciclo de vida K8s |
| Rechazadas | DaemonSet K8s (latencia CNI), Pod con hostNetwork (seguridad), Sidecar junto a PG (acoplamiento) |
| Trade-offs | Punto ciego observabilidad (requiere OTEL Collector). Binarios fuera de fichas K8s. Sin horizontal scaling |

### ADR-003 — IAM Installer como daemon residente

| Campo | Valor |
|---|---|
| Decision | Daemon residente systemd con Bash (OS) + Python (orquestacion), no script de una pasada |
| Razon | Reconciliacion continua, rollback <30s, API REST+WebSocket para Core UI, gestion de flota |
| Rechazadas | Script Bash largo (sin estado, sin API), Cron (sin tiempo real), ArgoCD (no gestiona systemd), Ansible (procedimental) |
| Trade-offs | Complejidad bootstrapping. Dos lenguajes. Estado en .sbos_state.json (punto de fallo) |

### ADR-004 — Keycloak como unico IdP

| Campo | Valor |
|---|---|
| Decision | Keycloak 26.x es el unico proveedor de identidad de todo el stack |
| Razon | Revocacion inmediata (JWT 5min), H-RBAC unificado, multi-tenancy por realm, SPIs extensibles |
| Rechazadas | Auth0/Okta (SaaS, viola soberania), LDAP (sin OIDC), Authentik (ecosistema SPIs menor), Auth nativa por app (sin revocacion) |
| Trade-offs | SPOF identidad (mitigado: SLO 99.99%). Curva de aprendizaje alta |

### ADR-005 — PostgreSQL como unica BD relacional

| Campo | Valor |
|---|---|
| Decision | PostgreSQL es la unica BD relacional. MySQL solo para 3 apps legacy (OrangeHRM, FreePBX, Easy!Appointments) via SymmetricDS |
| Razon | WAL como bus requiere PG. Observabilidad unificada. Un solo equipo DBA. Un solo backup |
| Rechazadas | BD nativa por app (sin bus WAL unificado), MySQL para todo (sin replicacion logica), Multi-DB (complejidad operacional) |
| Trade-offs | 3 apps MySQL excepcionadas. Dependencia total en PG (mitigado: Patroni HA 3 nodos) |

### ADR-006 — Veto de n8n

| Campo | Valor |
|---|---|
| Decision | n8n eliminada del stack. SBOS AI Tools (MIT, SKULL) la reemplaza |
| Razon | Sustainable Use License no es OSI-approved — viola principio P9 de licencias libres |
| Rechazadas | Mantener n8n con licencia actual (riesgo legal), Temporal.io (complejo), Apache Airflow solo (sin orquestacion de workflows) |

### ADR-007 — Firma Ed25519 del Release Plane

| Campo | Valor |
|---|---|
| Decision | Todos los artefactos del Release Plane se firman con Ed25519. El cliente verifica firma antes de aplicar |
| Razon | Supply chain security: nadie puede inyectar codigo en el canal de distribucion sin la clave privada de SKULL |
| Rechazadas | GPG (overhead), RSA (mas lento), Sin firma (riesgo supply chain) |

### ADR-008 — Fichas como unidad atomica

| Campo | Valor |
|---|---|
| Decision | La ficha (manifest.yml + yaml_engine.yml + resources/) es la unidad atomica de despliegue |
| Razon | Catalogo dinamico, reconciliacion automatica, distribucion firmada, rollback uniforme, FICHA_LINTER |
| Rechazadas | Helm Charts (no gestiona systemd), Scripts imperativos (no idempotentes), ArgoCD ApplicationSets (no gestiona host), Ansible (procedimental) |
| Trade-offs | Curva de aprendizaje. Formato propietario |

### ADR-009 — Rust para CPU-bound, Go para I/O-bound

| Campo | Valor |
|---|---|
| Decision | Rust: bkernel, biedata (CDC+ETL, latencia determinista). Go: bcompass, bsearch, bauth, bhnexus, banexus (I/O, concurrencia goroutines) |
| Razon | Rust sin GC para SLO WAL <500ms P99. Go goroutines (2-4KB) para 10K+ conexiones WebSocket |
| Rechazadas | Rust para todo (30-40% mas lento en I/O-bound), Go para todo (GC inaceptable en CDC), Python (arranque lento, GIL), Java/JVM (overhead memoria+GC) |
| Trade-offs | Polyglot stack (Rust+Go+Python+Bash). Bus Factor Rust es riesgo mas alto. Ramp-up 2-4 semanas para Rust |

### ADR-010 — Estrategia API Gateway — Mantener Kong OSS 3.9.x LTS

| Campo | Valor |
|---|---|
| **Estado** | ✅ Aceptada — Opcion A: Mantener Kong OSS 3.9.x (LTS activo hasta 2027) |
| **Fecha** | Abril 2026 |
| **Decisor** | Super Usuario (ARB unipersonal) |
| **Revision obligatoria** | Q1 2027 — abrir RFC-002 antes de que expire el LTS de Kong 3.9.x |

**Contexto:**

Kong Gateway OSS era el API Gateway del SBOS (S02 gatewayserver, ficha `kong`), distribuido bajo Apache 2.0. En marzo 2025, Kong Inc. cambio su modelo de distribucion con la version 3.10 sin anuncio prominente: (1) dejo de publicar imagenes OCI precompiladas para Kong OSS — los usuarios deben construir desde fuente; (2) elimino el "free mode" de Kong Enterprise — Kong 3.10+ sin licencia activa opera en modo degradado. La ultima version con imagen OCI oficial sin restricciones es **Kong OSS 3.9.x**, con soporte LTS hasta 2027.

**Decision:** Mantener Kong OSS 3.9.x (LTS activo hasta 2027). No actualizar mas alla de 3.9.x hasta el horizonte v2.0 (Q2-Q3 2027).

**Razon:**
- El LTS de Kong 3.9.x cubre el horizonte completo de SBOS v1.0 GA (Sep 2026) y v1.5 Enterprise (Dic 2026)
- El costo operacional de construir imagenes propias de Kong 3.10+ no justifica el beneficio a corto plazo
- La migracion a Envoy Gateway (Opcion B) tiene costo de migracion alto que distrae del desarrollo de los daemons soberanos
- Decision conservadora coherente con el principio de estabilidad del stack

**Alternativas rechazadas:**

| Opcion | Descripcion | Razon del rechazo |
|---|---|---|
| B — Envoy Gateway (CNCF, Apache 2.0) | Migrar el API Gateway a Envoy | Costo de migracion de rutas y plugins alto en este momento. Re-evaluar en Q1 2027 cuando el equipo tenga mas integrantes |
| C — Imagenes comunitarias Kong 3.10+ | Usar builds de Tetrate u otros partners | Dependencia de tercero no auditado por SKULL — viola el principio de cadena de confianza |

**Consecuencias:**
- `+` Estabilidad del stack para v1.0 y v1.5
- `+` Sin carga operacional adicional hasta 2027
- `+` Continuidad total — sin migracion de rutas ni plugins
- `-` Deuda tecnica con fecha conocida: Q1 2027
- `-` Requiere nuevo ADR antes de que expire el LTS

**Restriccion operacional activa:** La ficha `kong` no debe actualizarse mas alla de la version 3.9.x hasta resolucion formal en Q1 2027. Toda actualizacion de la ficha `kong` requiere aprobacion ARB explicita con nuevo ADR.

**Proxima accion programada:** Abrir RFC-002 en Q1 2027 para evaluar migracion a Envoy Gateway o continuidad con imagen propia de Kong.

---

## 4. Decisiones Pendientes

No hay decisiones pendientes. ADR-001 a ADR-010 estan todas en estado **✅ Aceptada**.

**Proxima accion programada:** Abrir RFC-002 en Q1 2027 para evaluar estrategia API Gateway post-LTS Kong 3.9.x (revision obligatoria de ADR-010).

---

## 5. V7 Enriquecimiento — Decisiones Arquitectonicas de bAuth (BAUTH-DECISIONES-ARQUITECTURA)

El V7 introduce decisiones arquitectonicas especificas para el dominio de identidad que complementan los ADRs fundacionales:

### Decision V7-D01 — BitmaskBundle 3×uint64 en lugar de BitMask 64-bit monolotico

| Campo | Valor |
|---|---|
| **Decision** | Reemplazar el BitMask 64-bit unico por un BitmaskBundle de 3×uint64: PhysicalDomainMask, LogicalDomainMask, FinancialDomainMask |
| **Razon** | El modelo anterior colapsaba tecnologias concretas (VDI=Fedora, ERP=Tryton) en lugar de dominios abstractos. La separacion permite evaluacion independiente por dominio y escalabilidad futura |
| **Estandares** | H-RBAC (ANSI/INCITS 359-2004), NIST SP 800-63B, ISO/IEC 27001 A.5.3 |
| **Rechazadas** | SAM-128 monolotico (error de diseno), BitMask 64-bit con ampliacion (mantiene colision conceptual), uint128 (AVX-512 no disponible en hardware objetivo) |
| **Trade-offs** | 3 operaciones atomicas en lugar de 1. Compatibilidad hacia atras requiere mapeo de mascara antigua a nuevo bundle |

### Decision V7-D02 — AND NOT (`&^`) para KillSwitch de emergencia

| Campo | Valor |
|---|---|
| **Decision** | Usar operador AND NOT (`&^` en Go) para revocacion de emergencia, en lugar de NAND (incorrecto en el diseno SAM-128 original) |
| **Razon** | NAND no es reversible ni correcto semantica de bits. AND NOT permite limpiar bits especificos sin afectar otros |
| **Corrige** | Error en Protocolo SAM-128 §3.2 |

### Decision V7-D03 — Conflict Matrix XOR para SoD

| Campo | Valor |
|---|---|
| **Decision** | Usar XOR entre LogicalDomainMask de dos roles para detectar conflictos de Segregacion de Funciones (SoD), en lugar de NAND |
| **Razon** | XOR detecta exactamente los bits donde dos roles difieren. Un bit a 1 en el XOR indica que ese permiso esta presente en un rol y ausente en el otro — conflicto potencial. NAND no puede expresar esta relacion |
| **Estandares** | ISO 27001 A.5.3 (Segregation of Duties), NIST SP 800-53 AC-5 |

### Decision V7-D04 — Keycloak 26.6.1 como version canónica

| Campo | Valor |
|---|---|
| **Decision** | Fijar Keycloak 26.6.1 como version canonica (patch de seguridad sobre 26.6.0, publicado 14 abril 2026) |
| **Razon** | Corrige CVE-2026-4366 (SSRF) y CVE-2026-4633 (user enumeration). Es la version estable mas reciente con soporte activo |
| **Estandares** | NIST SP 800-63B-4 (Jul 2025), FIPS 203/204/205 (Ago 2024) |

---

## 6. Smart* Enriquecimiento — Decisiones de Arquitectura por Subproyecto

### Smart Tax — Decisiones Fiscales (SBOS_TAX_DECISIONS.md, SBOS_TAX_E2_DECISIONES_RAMA_LOGICA.md)

| ID | Decision | Razon |
|---|---|---|
| ST-D01 | SHA-256 del GZIP, no del XML plano | Cumplimiento SIN Bolivia (codigo 969 si incorrecto) |
| ST-D02 | Milisegundos CUF siempre 3 digitos con str_pad | Longitud exacta 17 chars requerida por SIN |
| ST-D03 | Redondeo HALF-UP obligatorio en cada operacion | Diferencia de centavos invalida factura |
| ST-D04 | PHP 8.2 + CodeIgniter para modulo fiscal (legado) | Compatibilidad con codigo existente validado contra SIN |

### Smart Rates — Decisiones Consolidadas (SBOS-Rates-020-DECISIONES-CONSOLIDADAS.md)

| ID | Decision | Razon |
|---|---|---|
| SR-D01 | Pricing engine como motor Go independiente | Rendimiento en calculo de tarifas en tiempo real |
| SR-D02 | Reglas de pricing en YAML declarativo (no codigo) | Auditabilidad y modificacion sin deploy |
| SR-D03 | Cache de tarifas en Redis con TTL configurable | Reduccion de latencia en consultas frecuentes |

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1 Indice ADR-001 a 009 | SBOS-025 v1.0 | Tabla indice 9 ADRs |
| §1 ADR-010 estado actualizado | SBOS-COMPLETITUD-v2 §3 + SBOS-COMPLETITUD-v3 T-A9 | Estado elevado a "Aceptada" |
| §2 Proceso ARB | SBOS-025 v1.0, SBOS-025-ARB | Proceso para nuevas decisiones, template RFC |
| §3 ADR-001 a 009 | SBOS-025 v1.0 | ADR-001 a ADR-009 completos |
| §3 ADR-010 texto completo | SBOS-COMPLETITUD-v2 §3 + Kong GitHub #14405 #14628 + SBOS-COMPLETITUD-v3 T-A9 | Decision formal Kong OSS 3.9.x LTS |
| §4 Pendientes | SBOS-COMPLETITUD-v2 §3 | RFC-001 resuelto, RFC-002 programado Q1 2027 |
| §5 V7 | BOS_V7_SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1_0.md | D01-D04: BitmaskBundle, AND NOT KillSwitch, XOR Conflict Matrix, Keycloak 26.6.1 |
| §5 V7 | BOS_V7_SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md | Correcciones SAM-128 |
| §6 Smart* | SBOS_TAX_DECISIONS.md, SBOS_TAX_E2_DECISIONES_RAMA_LOGICA.md, SBOS-Rates-020-DECISIONES-CONSOLIDADAS.md | Decisiones de subproyectos |

---

## Fuentas de Enriquecimiento V8

| Fuente | Tipo | Contenido aportado |
|---|---|---|
| BOS_V6_SBOS-006-ADR.md | V6 (canonico) | Contenido base completo preservado |
| BOS_V7_SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1_0.md | V7 | D01-D04: BitmaskBundle, AND NOT, XOR Conflict Matrix, KC 26.6.1 |
| BOS_V7_SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md | V7 | Correcciones SAM-128, KillSwitch, Conflict Matrix |
| SBOS_TAX_DECISIONS.md (Smart Tax) | Smart* | Decisiones fiscales ST-D01 a ST-D04 |
| SBOS_TAX_E2_DECISIONES_RAMA_LOGICA.md (Smart Tax) | Smart* | Decisiones de rama logica fiscal |
| SBOS-Rates-020-DECISIONES-CONSOLIDADAS.md (Smart Rates) | Smart* | Decisiones consolidadas SR-D01 a SR-D03 |

---

_SKULL · SBOS · SBOS-006-ADR · HUMAN-DOC v1.3-V8 · Mayo 2026_
_Enriquecimiento V8: V7 decisiones de identidad (BitmaskBundle, AND NOT, XOR, KC 26.6.1) + Smart* decisiones fiscales y de pricing_
