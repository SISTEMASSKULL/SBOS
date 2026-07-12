# Anexo A.13 — Las Decisiones Arquitectónicas (ADR-001 … ADR-D12)
## Documento de respaldo: los 11 ADRs del daemon con su estado VIGENTE

**Tipo:** ANEXO — documento de respaldo del corpus
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Estatus:** FUENTE AUTOSUFICIENTE — contiene los 11 ADRs ÍNTEGROS (traslado fiel, §3)
**Respalda a:** carta rectora (0.00) · todos los manuales (las decisiones irreversibles que los fundan)
**Fuentes de origen (cita histórica):** `adrs/ADR-001..010 + ADR-D12`

---

## 1. Propósito y cómo citarlo

Respaldo de las decisiones arquitectónicas del daemon — **con su estado real actual**, que en
varios casos difiere del campo "Estado" escrito dentro del ADR (los ADRs son append-only; su
vigencia la determina la cadena de reemplazos). **Cómo citarlo:** `A.13 ADR-009` · `A.13 §2`
(la tabla de vigencia).

## 2. La tabla de vigencia — el estado REAL de cada decisión

| ADR | Decisión | Estado escrito | **Estado VIGENTE (2026-07-11)** |
|---|---|---|---|
| ADR-001 | Stack Rust 1.85+ + Java 21 | Propuesto | **Parcialmente superado:** Rust vigente; las SPIs Java fueron **eliminadas** con la limpieza post-ADR-010 (bAuth cubre esos flujos nativo — 9.01 §10) |
| ADR-002 | Interface Dual: WebSocket RPC + JSON-RPC 2.0 sobre Unix socket | Aceptado | **VIGENTE** (ADR-020 del ecosistema) |
| ADR-003 | BitMask 64-bit 2 capas + DAG herencia OR | Aceptado (con nota SUPERSEDED) | **SUPERSEDED por ADR-009** — el DAG + closure table SIGUE vigente; la estructura de bits cambió al BitMask Dual |
| ADR-004 | bAuth framework orquestador, no engine monolítico | Aceptado | **VIGENTE** — reforzado: hoy bAuth es además el motor nativo (la orquestación es interna, no de motores externos) |
| ADR-005 | Argon2id como hashing obligatorio | Aceptado | **VIGENTE** (parámetros por tier en `auth_config` — 2.01 §7.4; resolución A.02 U3) |
| ADR-006 | Doble motor de firma: interno (bóveda PKI) + externo (ADSIB/SIN) | Aceptado | **VIGENTE** (A.08 · 2.04) |
| ADR-007 | Keycloak: 3 realms por tenant | Aceptado | **OBSOLETO — Keycloak fue eliminado de la solución** (limpieza total post-ADR-010; bAuth es autosuficiente: motor nativo + OIDC Provider propio — 2.01 §11; el modelo realm-por-tenant fue reemplazado por la multi-tenancy nativa — 1.12). Se conserva como registro histórico |
| ADR-008 | Simbiosis trilateral bAuth-KC-Tryton | Aceptado | **REEMPLAZADO por ADR-010** (lo declara el propio ADR-010) — `bauth_db` como única fuente de verdad SIGUE vigente; la simbiosis con motores externos terminó |
| ADR-009 | **BitMask Dual: label encoding + one-hot** | Aceptado (reemplaza ADR-003) | **VIGENTE** — la decisión central del motor de privilegios (A.03 §6 · 1.04) |
| ADR-010 | **Deprecación de Tryton como motor de autorización** | ACEPTADO | **VIGENTE** — y extendido de facto: la limpieza posterior eliminó también Keycloak (`src/spi` no existe; commit `409095b`). **bAuth es autosuficiente** |
| ADR-D12 | Blockchain como dominio de soberanía 12 | Aceptado | **VIGENTE** (A.12 · 5.02) |
| ADR-011 | **Centralización del transporte en el Gestor de Canales Protegidos** | Aceptado | **VIGENTE (2026-07-11)** — nombre normativo NIST 800-63B «authenticated protected channel»; resuelve la dispersión de transportes (20+ archivos); manual 2.12 · contrato PLT-17 (A.43) |
| ADR-012 | **Centralización de la criptografía en el Módulo Criptográfico** | Aceptado | **VIGENTE (2026-07-11)** — nombre normativo NIST FIPS 140-3 «cryptographic module»; resuelve la dispersión de primitivas de cifrado (34+ archivos; no existe `src/crypto/`): frontera única, algoritmos aprobados, self-tests, agilidad PQC. Análogo a ADR-011 para el cifrado. Contrato CORE-11 (A.43) · ficha A.42 §10.ter · 2.01 §13.3. **Distinto del motor de métodos** (`MethodRegistry`/PAM, ya existe) |
| ADR-013 | **Arquitectura de Motores Únicos** (modularización de bAuth) | Aceptado | **VIGENTE (2026-07-11) — PRINCIPIO RECTOR de la reparación.** Toda capacidad transversal = UN motor: **trait + registro + frontera única + fail-closed + punto único de cambio**. Generaliza ADR-011/012 (no son piezas sueltas: son motores del catálogo). Catálogo verificado: BitMask ✅, Métodos 🔄 (A.44), **Políticas/PDP 🔄 partido+fail-open** (`bitmask/registry.rs`+`domain/policy*`), Canales ⬜ (PLT-17), Cripto ⬜ (CORE-11), Firma 🔄, Auditoría 🔄. Si cambian métodos/políticas → se toca UN punto |

**Lectura de conjunto:** la cadena ADR-003→009 (BitMask) y ADR-008→010(→limpieza KC) son las
dos evoluciones mayores; todo manual y anexo del corpus se lee bajo su estado VIGENTE, no bajo
el campo "Estado" interno del ADR.

## 3. Traslado fiel — los 11 ADRs íntegros

### ADR-001 — Elección del Stack Tecnológico: Rust 1.85+ + Java 21

**Estado:** Propuesto · **Fecha:** 2026-06-20 · **Autor:** sbos-coordinador

---

#### Contexto

bAuth es el daemon de identidad del SBOS. Necesita:
1. Alta concurrencia para sync loop (60s reconcile con KC+Tryton)
2. Comunicación con Keycloak vía Admin REST API (HTTP)
3. Comunicación con Tryton vía JSON-RPC (TCP)
4. Implementar 5 SPIs Java para Keycloak (Authenticator, Condition, Validator)
5. Binario estático para distribución en bootstrap (sin runtime dependencies)

#### Decisión

**Rust 1.85+ (tokio, MUSL, LTO) para el daemon core + Java 21 para los 5 SPIs de Keycloak.**

- **Rust:** daemon principal (bauth.service), CLI (bauthctl), servidor JSON-RPC, engine registry, PrivilegeEngine, sync loop, cache Redis
- **Java 21:** 5 SPIs de Keycloak (RolTemporalAuthenticator, RolGeoAuthenticator, RolRoleValidityAuthenticator, RolUserConfiguredCondition, RolStepUpCondition)

#### Alternativas Consideradas

| Alternativa | Pros | Contras | Rechazo |
|------------|------|--------|---------|
| **Go 1.22+** (100% Go) | Stack único, GC rápido, compilación cruzada | SPIs Keycloak requieren Java — puente gRPC/FFI añade complejidad y latencia | Go para I/O-bound; Rust elegido por zero-cost abstractions y seguridad de memoria |
| **Python 3.14** | Rápido prototipado, bibliotecas | GIL limita concurrencia, sin binario estático nativo, rendimiento 10x menor que Rust en crypto | Descartado para producción |
| **100% Java 21** | Integración nativa con KC SPIs | Consumo memoria (JVM), binario no estático, startup lento | Java solo para SPIs — el core Rust aprovecha MUSL+LTO para <15MB binario estático |

#### Consecuencias

**Positivas:**
- Binario Rust MUSL estático < 15MB, sin dependencias runtime
- Zero-cost abstractions: evaluación BitMask en < 0.5ns
- Seguridad de memoria sin GC (ownership model)
- Java 21 para SPIs = integración nativa con KC sin puentes ni serialización adicional

**Negativas:**
- Dos lenguajes = dos toolchains, dos pipelines CI
- Equipo necesita competencia en Rust + Java
- Comunicación entre Rust y SPIs vía KC Admin REST API (no directa)

**Riesgos mitigados:**
- Curva de aprendizaje Rust: mitigada con documentación exhaustiva y patrones establecidos (tokio, serde, tonic)
- Divergencia Rust/Java: mitigada con contratos de API documentados (JSON Schema, gRPC proto)

#### Referencias
- [Rust Programming Language](https://www.rust-lang.org/)
- [Tokio — Async Runtime](https://tokio.rs/)
- [Keycloak SPI Reference](https://www.keycloak.org/docs/latest/server_development/)
- [MUSL libc](https://musl.libc.org/)


---

### ADR-002 — Interface Dual: WebSocket RPC + JSON-RPC 2.0 sobre Unix Socket

**Estado:** Aceptado · **Fecha:** 2026-06-20

---

#### Contexto

bAuth debe ser invocable tanto por humanos (CLI `bauthctl`, Core UI) como por otros daemons y agentes IA (biedata, bkernel, sagas automatizadas). La comunicación entre daemons está restringida por SBOS-050 P9: HTTP vetado entre daemons. Solo se permite Unix socket o WebSocket.

#### Decisión

**Interface Dual sobre un mismo Unix socket `/run/bos/bauth.sock` (0660, grupo bosagent):**

- **Vía 1 — WebSocket RPC**: para `bauthctl` CLI y Core UI (administración humana, comandos interactivos)
- **Vía 2 — JSON-RPC 2.0**: para biedata, bkernel, bauth, bsearch y agentes IA (invocación programática, sagas, automatización)

El socket multiplexa ambos protocolos — WebSocket upgrade vs JSON-RPC directo se discrimina por el primer byte de la request.

#### Alternativas

| Alternativa | Problema |
|------------|---------|
| HTTP REST | Violaría SBOS-050 P9 (HTTP vetado entre daemons). Requiere puerto TCP adicional. |
| gRPC exclusivo | No apto para CLI humano (requiere protobuf toolchain). JSON-RPC es más accesible para agentes IA. |
| Dos sockets separados | Complejidad innecesaria. Un socket = un punto de administración. |

#### Consecuencias

- 14 métodos JSON-RPC documentados (B18.T09-T14): roltemplate.*, usertemplate.*, auth.validate, ctx.*, sign.*, dominio.evaluate
- Todos los daemons y smarts siguen el mismo patrón (ADR-020 generalizado)
- Sin puertos TCP adicionales — cumple SBOS-050 P9

#### Referencias
- ADR-020 (Interface Dual obligatoria para todos los daemons)
- SBOS-050 P9 (Port Catalog: HTTP vetado entre daemons)
- JSON-RPC 2.0 Specification


---

### ADR-003 — BitMask 64-bit de 2 Capas + DAG con Herencia OR

> ⚠️ **SUPERSEDED — JUNIO 2026:** Este ADR describía el modelo BitMask anterior. Ha sido reemplazado por el **BitMask Dual** (`SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`). Se necesitará un nuevo ADR-D12 para documentar la decisión de incorporar blockchain. La decisión de usar DAG + Closure Table se mantiene vigente; la implementación específica de bits cambió de "2 capas sobre u64" a "BitMask Átomo + Rol BitMask".

**Estado:** Aceptado · **Fecha:** 2026-06-20

---

#### Contexto

bAuth necesita un motor de privilegios que evalúe permisos en < 0.5ns por request. El sistema maneja dos tipos de permisos: sistema (crear módulos, tenants) y negocio (ventas, facturación, inventario). La herencia jerárquica de roles (NIST RBAC §4.2) requiere que un rol senior herede automáticamente todos los permisos de sus roles junior.

#### Decisión

**BitMask de 64 bits en 2 capas con Grafo Acíclico Dirigido (DAG) para herencia mediante OR bitwise.**

- Capa 1 (bits 0–31): privilegios de sistema — asignables solo a SU y SYS
- Capa 2 (bits 32–63): privilegios de negocio — asignables a BIZ y EXT
- Herencia: `mask_eff(senior) = mask_own(senior) | mask_eff(junior₁) | mask_eff(junior₂) | ...`
- Verificación: `(mask_eff & bit_operación) != 0` (una sola instrucción CPU)
- Almacenamiento: tabla `rol_closure(ancestro_id, descendiente_id, profundidad)` — una consulta JOIN sin recursión

#### Alternativas

| Alternativa | Problema |
|------------|---------|
| SAM-128 monolítico (128 bits en 1 capa) | Sin separación sistema/negocio. Evaluación más lenta (2× uint64 vs 4× uint64). Sobrecarga de bits. |
| RBAC con listas ACL por recurso | O(n) evaluación. No escala a 368 roles con múltiples dominios. |
| ABAC puro (XACML) | Evaluación > 1ms. Complejidad innecesaria para el modelo de negocio SBOS. |

#### Consecuencias

**Positivas:**
- Evaluación en < 0.5ns (AND bitwise es 1 ciclo CPU)
- Separación clara sistema/negocio = SoD implícito (BIZ nunca toca capa 1)
- Closure table SQL resuelve herencia en 1 JOIN sin CTE recursivo
- 186 aristas documentadas en BAUTH-CADENAS-JERARQUIA.md

**Riesgos:**
- 64 bits pueden ser insuficientes si se requieren >64 permisos por capa
- Mitigación: BitmaskBundle extensible (7×uint64 ya definido para dominios)

#### Referencias
- NIST RBAC Model §4.2 — Role Hierarchies as Partial Orders (DAG)
- BAUTH-CATALOGO-ROLES-EMPRESARIALES.md v2.0 §6
- BAUTH-CADENAS-JERARQUIA.md v1.1


---

### ADR-004 — bAuth como Framework Orquestador, No como Engine Monolítico

**Estado:** Aceptado · **Fecha:** 2026-06-20

---

#### Contexto

Un sistema de autenticación puede construirse como monolito (un solo proceso que hace todo) o como framework que orquesta motores especializados. bAuth debe sincronizar Keycloak (Java), Tryton (Python), OAuth2-Proxy (Go), y NEXUS (Go) — todos con APIs, protocolos y modelos de datos diferentes.

#### Decisión

**bAuth es un framework que implementa el patrón "Director de Orquesta".** No autentica usuarios directamente. En cambio, sincroniza, configura y orquesta 4+ motores especializados:

- **KeycloakEngine**: Admin REST API → realms, roles, users, auth flows, composite roles
- **TrytonEngine**: JSON-RPC → grupos, ir.model.access, ir.rule (5 capas enforcement)
- **OAuth2ProxyEngine**: archivos .cfg + SIGHUP → proxy de autenticación por aplicación
- **BhnexusEngine**: gRPC + WebSocket mTLS → puente físico-digital

Cada motor implementa el trait `AuthEngine` (Rust): `name()`, `covered_domains()`, `sync_role()`, `sync_user()`, `reconcile()`.

#### Alternativas

| Alternativa | Problema |
|------------|---------|
| Monolito (todo en Rust) | Keycloak es Java — los SPIs deben ejecutarse en la JVM de KC. Tryton es Python — su API JSON-RPC es la única forma segura de interactuar. |
| Microservicios independientes | Complejidad operativa (N servicios, N CI/CD, N monitoreos). bAuth centraliza la orquestación. |
| bAuth como proxy transparente | Latencia añadida en cada request de autenticación. Solo necesario para ctx_id (Kong PEP). |

#### Consecuencias

- 6 reglas del framework documentadas en BAUTH-ARQUITECTURA-FRAMEWORK.md
- Open/Closed: nuevos motores se agregan sin modificar el core (EngineRegistry)
- Degradación graciosa: si un motor falla, los demás siguen operando
- bauth_db es la única fuente de verdad — los motores son réplicas operacionales

#### Referencias
- BAUTH-ARQUITECTURA-FRAMEWORK.md v1.0
- BAUTH-CONTRATO-SYMBIOSIS.md v1.0
- GoF Design Patterns: Strategy, Composite, SPI/Plugin


---

### ADR-005 — Argon2id como Algoritmo de Hashing Obligatorio

**Estado:** Aceptado · **Fecha:** 2026-06-20

---

#### Contexto

NIST SP 800-63B Rev.4 (2024) y OWASP ASVS 2.4.3 recomiendan Argon2id como algoritmo de hashing de contraseñas. Los algoritmos legacy (SHA1, MD5, bcrypt) son vulnerables a ataques con hardware moderno (GPU, FPGA, ASIC). PBKDF2-SHA256 requiere 310,000+ iteraciones para ser seguro, haciendo la verificación lenta.

#### Decisión

**Argon2id como algoritmo exclusivo de hashing de contraseñas para nuevos roles.**

Parámetros diferenciados por criticidad del tier:
- SU: t=5 (time cost), m=128MB (memory), p=2 (parallelism)
- SYS: t=3, m=64MB, p=2
- BIZ_N3-N5: t=3, m=64MB, p=2
- BIZ_N1-N2: t=2, m=32MB, p=1
- EXT_N0: t=2, m=32MB, p=1

Algoritmos deprecados: SHA1, MD5, bcrypt. PBKDF2-SHA256 solo para verificación de hashes legacy durante migración.

#### Alternativas

| Alternativa | Problema |
|------------|---------|
| PBKDF2-SHA256 | 310K iteraciones = lento en verificación. Vulnerable a GPU/FPGA. NIST ya no lo recomienda para nuevas implementaciones. |
| bcrypt | Límite de 72 bytes de input. Vulnerable a FPGA. No memory-hard. |
| scrypt | Menos analizado que Argon2id. Parámetros más difíciles de configurar correctamente. |

#### Consecuencias

- Argon2id es memory-hard: requiere 32-128MB por hash, haciendo ataques GPU/ASIC prohibitivamente costosos
- Parámetros por tier: roles de alto privilegio tienen hashes más costosos de atacar
- Migración transparente: al hacer login, si el hash es legacy → verificar con algoritmo antiguo → re-hash con Argon2id

#### Referencias
- NIST SP 800-63B Rev.4 (2024) §5.1.1.2
- OWASP ASVS 4.0.3 §2.4.3
- Argon2 RFC 9106


---

### ADR-006 — Doble Motor de Firma Digital: Interno (Vault PKI) + Externo (ADSIB/SIN)

**Estado:** Aceptado · **Fecha:** 2026-06-20

---

#### Contexto

El SBOS requiere firma digital para dos propósitos fundamentalmente distintos:

1. **Documentos internos** (sagas, estados, eventos CDC, logs, contratos entre tenants): requieren velocidad, automatización, y gestión interna de certificados. No necesitan validez legal externa.
2. **Documentos externos** (facturación electrónica SIN, contratos con proveedores, declaraciones juradas): requieren validez legal plena según Ley 164 de Bolivia, certificados emitidos por ADSIB, y cumplimiento con la PKI nacional (ATT → ADSIB).

Un solo motor no puede satisfacer ambos requisitos — la PKI interna usa EdDSA (rápido, moderno) mientras que ADSIB exige RSA-SHA256 (legado regulatorio).

#### Decisión

**Dos motores de firma digital independientes:**

| Característica | Motor Interno | Motor Externo |
|---------------|--------------|---------------|
| Autoridad | Vault PKI (SBOS Root CA) | ATT → ADSIB |
| Algoritmo | EdDSA Ed25519 | RSA-SHA256 |
| Vigencia certificado | 24h (M2M) – 365d (Apps) | 365d |
| Validez legal externa | No | Sí (Ley 164) |
| Formatos | PAdES, XAdES, CAdES, JWS | XAdES (SIN), PAdES |
| Consumidores | bos-agent, bkernel, biedata | SmartTax, Admin Tenant |

#### Alternativas

| Alternativa | Problema |
|------------|---------|
| Motor único con ADSIB para todo | Lentitud (RSA), costo (certificados ADSIB por daemon), innecesario para firmas internas |
| Motor único con PKI interna para todo | Sin validez legal externa. SIN rechazaría facturas. |
| Delegar firma externa a cada tenant | Complejidad: cada tenant gestiona sus propios certificados ADSIB. bAuth centraliza. |

#### Consecuencias

- Separación clara de responsabilidades: interno = ecosistema, externo = mundo real
- Cumplimiento Ley 164 Bolivia (Art. 78-83): firma ADSIB tiene plena validez jurídica
- Gestión centralizada de certificados ADSIB en Vault KV v2

#### Referencias
- SBOS-BAUTH-DIGITAL-SIGNATURE-ENGINES.md v1.0
- Ley 164 Bolivia (Ley General de Telecomunicaciones)
- DS 1793/3527 (Reglamento TIC + Firma Digital Automática)
- ADSIB-FD-POLT-015 v2.3


---

### ADR-007 — Keycloak: 3 Realms por Tenant — Aislamiento Total

**Estado:** Aceptado · **Fecha:** 2026-06-20

---

#### Contexto

Keycloak puede operar en dos modelos multi-tenant:
1. **Un realm con grupos por tenant**: todos los usuarios en el mismo realm, separados por grupos y roles.
2. **Un realm por tenant**: cada empresa/organización tiene su propio realm aislado.

El SBOS maneja 3 categorías de usuarios con requisitos de seguridad muy diferentes: roles sistémicos (SU, SYS), empleados de empresas (BIZ), y clientes externos (EXT).

#### Decisión

**3 realms por tenant con políticas de seguridad diferenciadas:**

| Realm | Usuarios | Password Policy | Token TTL | AAL |
|-------|----------|----------------|-----------|-----|
| `sbos-system` | SU, SYS_N1-N2, SYS_N4 (M2M) | `length(15)_argon2id_t5_m128` | 5-15 min | AAL2-3 |
| `tenant-{id}` | BIZ_N1-N5 (empleados) | `length(12)_argon2id_t3_m64` | 30-60 min | AAL1-2 |
| `tenant-{id}-ext` | EXT_N0 (clientes) | `length(8)_argon2id_t2_m32` | 24h | AAL1 |

#### Alternativas

| Alternativa | Problema |
|------------|---------|
| 1 realm multi-tenant con grupos | Fuga de políticas: no se pueden aplicar políticas de contraseña diferentes por grupo en KC. Un cliente externo (AAL1) y un admin (AAL3) en el mismo realm comparten políticas. |
| 1 realm por tenant (sin sbos-system) | Roles sistémicos mezclados con roles de negocio. SU de SBOS en el mismo realm que empleados de ACME — inaceptable. |
| 1 realm por tipo de usuario (3 totales) | Todos los tenants comparten realm de clientes. Aislamiento insuficiente entre empresas. |

#### Consecuencias

- Aislamiento total: un cliente de ACME no puede autenticarse contra el realm de EMPRESA-X
- Políticas de contraseña y token TTL específicas por categoría de usuario
- bAuth gestiona realms via Keycloak Admin REST API (B12)
- Cada tenant tiene 2 realms (tenant-{id} + tenant-{id}-ext) creados durante el alta (Saga Tenant B19.T14)

#### Referencias
- Keycloak 26.6.2 Server Administration Guide
- BAUTH-CONTRATO-SYMBIOSIS.md v1.0
- BOS_V8 §4 (Keycloak Architecture)


---

### ADR-008 — Simbiosis Trilateral bAuth-KC-Tryton: bauth_db como Única Fuente de Verdad

**Estado:** Aceptado · **Fecha:** 2026-06-20

---

#### Contexto

En un sistema con tres componentes que gestionan identidad (bAuth, Keycloak, Tryton), debe existir UNA sola fuente de verdad. Si Keycloak y Tryton pueden modificar la identidad independientemente, se produce drift y corrupción de datos. La pregunta es: ¿quién es el dueño de la identidad?

#### Decisión

**bauth_db (PostgreSQL) es la ÚNICA fuente de verdad. Keycloak y Tryton son réplicas operacionales que reflejan el estado definido en bauth_db.**

- bAuth declara el estado deseado (RolTemplate, UserTemplate)
- Sync Engine calcula el diff entre estado deseado (bauth_db) y real (KC, Tryton)
- Reconcile loop cada 60 segundos detecta y corrige drift automáticamente
- Si KC o Tryton son destruidos, bAuth los reconstruye desde cero (bootstrap simbiótico)
- Idempotencia absoluta: ejecutar sync 1 o 1000 veces produce el mismo resultado

#### Alternativas

| Alternativa | Problema |
|------------|---------|
| Keycloak como fuente de verdad | KC no almacena estructura organizacional (departamentos, sucursales, zonas). Tryton quedaría incompleto. |
| Tryton como fuente de verdad | Tryton no maneja authentication flows, MFA, WebAuthn. KC quedaría incompleto. |
| Sincronización bidireccional sin dueño claro | Conflictos de merge. ¿Quién gana si KC y Tryton tienen valores diferentes para el mismo usuario? |

#### Consecuencias

- Reconcile loop 60s: GET /roles + /users en KC, search_read en Tryton → comparar con bauth_db → corregir
- Degradación graciosa: KC caído → cache Redis responde. Tryton caído → sync encolado. Ambos caídos → identidad congelada (read-only). bauth_db caído → CRÍTICO.
- Bootstrap desde cero: con bauth_db intacto, bAuth reconstruye todo KC + Tryton sin intervención humana

#### Referencias
- BAUTH-CONTRATO-SYMBIOSIS.md v1.0
- BAUTH-ARQUITECTURA-FRAMEWORK.md v1.0


---

### ADR-009 — BitMask Dual: Label Encoding + One-Hot Encoding

**Estado:** Aceptado · **Fecha:** 2026-06-21 · **Reemplaza:** ADR-003

---

#### Contexto

El ADR-003 estableció un BitMask de 64 bits en 2 capas (32 sistema + 32 negocio) con herencia DAG mediante OR bitwise. Durante la validación del modelo, se descubrió un defecto de seguridad: aplicar OR directamente sobre códigos de átomo (label encoding) produce escalamiento silencioso de privilegios.

**Prueba del defecto:** `código(nuevo)=1`, `código(editar)=2`, `código(eliminar)=3`. El OR acumulado de dos átomos con códigos `1|2|1|2 = 3` produce el código 3 = "eliminar" — un permiso que nadie otorgó. El resultado es un código válido del catálogo, pasa revisiones superficiales, y es indistinguible de un permiso legítimo.

**Raíz del error:** usar la misma estructura numérica para dos propósitos distintos — identificar un átomo (label encoding) y combinar permisos entre roles (flags).

#### Decisión

**Separar en dos estructuras independientes con codificaciones distintas:**

1. **BitMask Átomo (64 bits, label encoding):** Identifica UN átomo específico de forma compacta. Estructura: Dominio Contextual [8 res][4 dom][9 app][11 grupo] + Dominio Lógico [6 res][2 política][24 átomo]. Operaciones válidas: igualdad, AND con máscara fija para extraer campos. **NUNCA OR/AND/XOR entre dos BitMask Átomo.**

2. **Rol BitMask (N bits, one-hot encoding):** Combina los átomos de un rol. Cada átomo del catálogo global ocupa una posición de bit fija e independiente. Operaciones válidas: OR (unión), AND (intersección/mínimo privilegio), AND NOT (remoción selectiva), XOR (delta entre estados, máximo 2 operandos).

La herencia DAG + Closure Table se mantienen vigentes, pero operan sobre el Rol BitMask (one-hot), no sobre el BitMask Átomo (label).

#### Alternativas

| Alternativa | Problema |
|------------|---------|
| Mantener ADR-003 (2 capas sobre 1 u64) | Escalamiento silencioso de privilegios demostrado |
| SAM-128 (128 bits) | Misma raíz de error. XOR para SoD es incorrecto (ver SBOS-BITMASK-ANALISIS-SAM128) |
| ACL por recurso | O(n) evaluación, no escala |
| ABAC puro (XACML) | Latencia > 1ms, incompatible con Fast-Path < 0.5ns |

#### Consecuencias

**Positivas:**
- Escalamiento de privilegios matemáticamente imposible: cada átomo tiene su propio bit independiente
- El OR sobre Rol BitMask produce exactamente la unión de conjuntos
- La delegación por AND garantiza mínimo privilegio: `delegado = senior & junior`
- El BitMask Átomo (64 bits) es compacto para transmisión y almacenamiento
- SoD se implementa con Conflict Matrix estática (pares de átomos incompatibles), no con XOR

**Negativas:**
- Dos estructuras que mantener en vez de una
- El Rol BitMask crece con el catálogo (N bits = cantidad de átomos). Mitigación: 500 átomos = 63 bytes; 5000 átomos = 625 bytes — manejable en JWT
- Requiere reescritura de `domain/bitmask.rs` (B1.T03, B1.T04) y actualización de B2-B8

#### Referencias

- `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md` — Especificación completa + DDL `bos_privilege`
- `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7 — bAuth administra el BitMask, no KC ni Tryton-PDP
- `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md` — Análisis del error XOR en SAM-128
- `BAUTH-CATALOGO-ROLES-EMPRESARIALES.md` v2.1 §6 — Modelo dual documentado
- NIST RBAC Model §4.2 — DAG hierarchies
- RFC 6962 §2.1 — Domain-separated Merkle tree hashing (referencia para domain separation en leaf/node)


---

### ADR-010 — Deprecación de Tryton como Motor de Autorización

**Estado:** ACEPTADO · **Fecha:** 2026-06-28 · **Autor:** agente-bauth
**Reemplaza:** ADR-008 (Simbiosis bAuth-KC-Tryton) · **Impacto:** B13 completo, B10-B11 simplificados

---

#### Decisión

**Tryton ERP deja de ser un motor de autorización en SBOS.** Las 5 capas de enforcement
que antes delegábamos a Tryton (`ir.model.access`, `ir.rule`, `ir.model.button`,
`ir.model.field`, `ir.action.groups`) ahora las resuelve bAuth directamente con su
propio motor de políticas.

La simbiosis **trilateral** bAuth↔Keycloak↔Tryton pasa a ser **bilateral** bAuth↔Keycloak.
Keycloak sigue siendo el motor de identidad (OIDC, SAML, WebAuthn). La autorización
es 100% bAuth.

---

#### Razones

##### 1. bAuth implementa un superconjunto de las capacidades de Tryton

| Capa Tryton | Reemplazo en bAuth | Archivo |
|------------|-------------------|---------|
| `ir.model.access` (CRUD por modelo) | `ath_policy_d1` — rule types: `scope`, `max_records`, `record_filter`, `field_restriction`, `data_classification` | `ath_converter.rs` |
| `ir.rule` (SQL por zona) | `ath_policy_d1` — `record_filter`, `field_restriction` | `ath_converter.rs` |
| `ir.model.button` (control de botones) | `ath_policy_d3` — `dual_approval`, `approval_chain`, `sod` | `ath_converter.rs` |
| `ir.model.field` (restricción de campos) | `ath_policy_d1` — `field_restriction` | `ath_converter.rs` |
| `ir.action.groups` (menús visibles) | `ath_policy_d1` — `data_classification` | `ath_converter.rs` |

##### 2. bAuth es objetivamente superior

| Dimensión | Tryton (deprecado) | bAuth (actual) |
|-----------|-------------------|----------------|
| Motor | Python interpretado, SQL por registro | Rust nativo, operaciones bitwise |
| Latencia | ~5-50ms por decisión | <0.5ns FastPath, <5ms PolicyPath |
| Dominios | 1 (lógico-negocio) | 12 (D1-D12) |
| Tipos de regla | 5 fijos | 62 data-driven, extensibles |
| Resolución de conflictos | No existe | XACML 3.0 deny-overrides + detector automático |
| Simulación | No existe | PolicySimulator dry-run |
| Auditoría | Log Python genérico | WORM inmutable ISO 27001 A.8.9 |
| Zero Trust | No | NIST SP 800-207, ctx_id obligatorio |
| Hot reload | Reinicio requerido | SIGHUP, rollback automático |

##### 3. Tryton nunca se implementó en bAuth

- `src/engine/tryton_engine.rs` **no existe** — el directorio `engine/` solo contiene `mod.rs`
- Los 22 átomos de B13 en REGISTRO-ESTADO.md están marcados 📄 (diseño), nunca pasaron a código
- El trait `AuthEngine` se definió pero sin implementación Tryton
- `tryton_user_id` en `idn_user_template` es una columna legacy sin código que la use
- `tryton_action_visibility` es una tabla de bAuth, no de Tryton

##### 4. Simplifica la arquitectura

```
ANTES (3 motores):                   AHORA (2 motores):
┌────────┐                            ┌────────┐
│ bAuth  │──► Keycloak (identidad)    │ bAuth  │──► Keycloak (identidad)
│        │──► Tryton   (autorización) │        │──► bAuth   (autorización — 12 dominios propios)
│        │──► Vault    (firma)        │        │──► Vault   (firma)
└────────┘                            └────────┘
```

---

#### Consecuencias

##### Lo que se depreca

| Elemento | Acción |
|----------|--------|
| B13 — TrytonEngine (22 átomos) | Marcado 📄 DEPRECADO en REGISTRO-ESTADO.md |
| `tryton_user_id` en `idn_user_template` | Columna legacy — mantener para compatibilidad, no usar |
| `tryton_status` en `bos_sync_log` | Columna legacy — mantener, no actualizar |
| `tryton_action_visibility` | Tabla de bAuth para visibilidad contextual — renombrar o clarificar |
| ADR-008 (Simbiosis trilateral) | Reemplazado por este ADR-010 |
| Referencias a Tryton en 67 documentos | Este ADR es la fuente de verdad. Los documentos heredan. |

##### Lo que se simplifica

| Gate | Antes | Ahora |
|------|-------|-------|
| B10 — RolTemplate | Sync a KC + Tryton | Sync solo a Keycloak |
| B11 — UserTemplate | Provisioning en KC + Tryton | Provisioning solo en Keycloak |
| B12 — KeycloakEngine | 1 de 2 motores | Único motor externo |
| B13 — TrytonEngine | 22 átomos planeados | DEPRECADO |

##### Lo que NO cambia

- Keycloak sigue siendo el motor de identidad (OIDC, SAML, WebAuthn, MFA)
- Vault sigue siendo el motor de firma digital (Ed25519)
- Besu/Arbitrum siguen siendo el motor de anclaje blockchain (D12)
- La arquitectura de engines con trait `AuthEngine` se mantiene — simplemente tiene 1 implementación menos

---

#### Referencias

- `ath_converter.rs` — 62 rule types que reemplazan las 5 capas Tryton
- `evaluate.rs` — Motor XACML 3.0 que evalúa políticas sin delegar a ERP externo
- `policy_admin.rs` — CRUD, conflictos, simulación, auditoría, hot reload (capacidades que Tryton no tiene)
- `REGISTRO-ESTADO.md` §B13 — marcado DEPRECADO
- `BAUTH-CONTRATO-SYMBIOSIS.md` — actualizado a arquitectura bilateral

---

*ADR-010 · bAuth Identity Core v3.0 · 2026-06-28*


---

### ADR-D12 — Incorporación de Blockchain como Dominio de Soberanía 12

**Estado:** Aceptado · **Fecha:** 2026-06-21

---

#### Contexto

SBOS opera 11 dominios de soberanía (D1–D11) que cubren identidad, autorización y auditoría. El dominio D11 (Auditoría) provee registros inmutables WORM a nivel de base de datos, pero tiene un límite preciso: no ofrece **verificabilidad por un tercero que no confía en la infraestructura de SBOS**. Si un regulador, banco corresponsal o auditor externo necesitan confirmar la integridad de los registros sin depender de la palabra de SBOS, D11 llega a su techo natural.

Adicionalmente, el modelo de negocio del proyecto contempla liquidación entre múltiples entidades (comercios, agentes, sucursales) que no confían entre sí y que se beneficiarían de un mecanismo de liquidación verificable sin banco corresponsal en cada operación.

#### Decisión

**Incorporar un dominio de soberanía número 12 (D12 — Blockchain) con dos variantes complementarias:**

##### Variante A — Ancla de Auditoría (obligatoria)

Publicar periódicamente el Merkle root de lotes de eventos de `bauth_audit_events` en una blockchain pública (Arbitrum One, capa 2 de Ethereum). Esto permite que cualquier tercero verifique matemáticamente que un registro de auditoría no fue alterado después de su fecha, sin depender de SBOS.

- **Stack:** Arbitrum One (L2), Hyperledger Besu (cliente), `ethers-rs` (Rust), Merkle tree RFC 6962 con Keccak-256
- **Frecuencia:** Gold tier (cada 1 hora, estándar VCP v1.1)
- **Costo:** ~$0.15/mes en gas
- **Impacto en latencia:** Ninguno — operación asíncrona, no bloquea el hot path
- **Smart contract:** `AuditAnchor.sol` (Solidity 0.8.26) — solo almacena Merkle roots

##### Variante B — Motor de Liquidación (condicionada a madurez del negocio)

Operar una red permisionada Hyperledger Besu con consenso QBFT para liquidación on-chain entre entidades del consorcio que no confían entre sí.

- **Stack:** Hyperledger Besu QBFT (red permisionada), 4-7 validadores, `SettlementEngine.sol`
- **Finalidad:** 1 bloque = 2 segundos (QBFT finalidad inmediata)
- **Costo:** ~$260/mes en VPS (sin HSM), ~$800/mes con HSM FIPS
- **Custodia:** Gestionada (nunca auto-custodia) — Vault + SoftHSM2/HSM vía PKCS#11

##### Variante C — Reemplazar BitMask (descartada)

No recomendada. El BitMask Fast-Path resuelve autorización en < 0.5ns; reemplazarlo por verificación en cadena reintroduciría latencia de segundos donde se requieren nanosegundos.

#### Alternativas

| Alternativa | Problema |
|------------|---------|
| No incorporar blockchain | Sin verificabilidad externa. D11 solo es inmutable para quien confía en SBOS |
| OpenTimestamps (Bitcoin) | Sin smart contracts. Sin capacidad de liquidación (Var B) |
| Cadena propia pública con token | Riesgo regulatorio máximo. Complejidad innecesaria |
| Cosmos SDK | Complejidad de SDK. Ecosistema más pequeño que EVM |
| Ripple/XRP Ledger | Propietario. Sin permisos para red propia |

#### Consecuencias

**Positivas:**
- Verificabilidad externa sin confianza (propiedad única vs Okta/Auth0/Entra ID)
- Cumplimiento regulatorio: el reglamento ETF Bolivia reconoce "blockchain" como categoría explícita
- Diferenciación competitiva: 4 productos vendibles (Compliance-in-a-Box, Billetera White-Label, IAM Soberano, Trust Layer)
- Stack 100% open source (Apache 2.0, MIT, MPL 2.0)
- Sin vendor lock-in: cada componente implementa un estándar abierto

**Negativas:**
- Nueva dependencia operativa: RPC de Arbitrum (Var A), red Besu QBFT (Var B)
- Complejidad adicional: ~164h de desarrollo para ambas variantes
- Regulatorio: requiere declarar "blockchain" en carta de intención ETF
- El gas de Arbitrum, aunque mínimo ($0.15/mes), requiere monitoreo

#### Referencias

- `SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md` v2.1 — Tesis completa de arquitectura + productos
- `SBOS-BAUTH-EVALUACION-INTEGRAL-v2.2.md` — Evaluación integral con 47 gaps + soluciones + presupuesto
- `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md` — DDL `bos_blockchain` (Apéndice D)
- RFC 6962 — Certificate Transparency (Merkle tree specification)
- VCP v1.1 — VeritasChain Protocol (tier system for anchoring frequency)
- Hyperledger Besu Documentation — QBFT consensus, permissioning, PKCS#11 HSM
- Reglamento ETF Bolivia (2025) — Categoría "blockchain"
- NIST SP 800-57 — Key Management


---

## 4. Referencias e historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial: tabla de vigencia REAL de los 11 ADRs (ADR-007 obsoleto por eliminación de Keycloak; ADR-008 reemplazado por ADR-010; ADR-003 superseded por ADR-009; ADR-001 parcialmente superado — SPIs eliminadas; el resto vigente) y traslado fiel íntegro en orden. |
