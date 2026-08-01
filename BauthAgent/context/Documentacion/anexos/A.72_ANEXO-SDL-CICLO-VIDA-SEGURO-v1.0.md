# A.72 — Ciclo de Vida de Desarrollo Seguro (SDL) — bAuth Identity Control Plane

| Metadato | Valor |
|----------|-------|
| **Tipo de anexo** | B+C+D — Respaldo normativo · Justificación de decisión · Verificación de madurez |
| **Versión** | 1.0.0 |
| **Fecha** | 2026-08-01 |
| **Respalda a** | `2.09_MANUAL-SEGURIDAD-v1.0.md` §3, §4, §7, §11 |
| **También referenciado desde** | `A.71_INFORME-CUMPLIMIENTO-ISO27001-2022-v1.0.md` §4.6 |
| **Normas base** | ISO/IEC 27001:2022 A.8.25 · NIST SP 800-218 (SSDF) · OWASP SAMM v2.0 · OWASP ASVS 5.0 · NIST SP 800-53 R5.2 SA-3 |

---

## §1 Propósito y cómo citarlo

Este anexo documenta el **Ciclo de Vida de Desarrollo Seguro (SDL)** de bAuth: las prácticas,
controles y artefactos que demuestran que la seguridad está integrada en cada fase del
desarrollo — desde los requisitos hasta el despliegue — no añadida como capa posterior.

Satisface el control **ISO/IEC 27001:2022 A.8.25 (Secure Development Life Cycle)** con
evidencia verificable para cada una de las 6 fases del ciclo.

**Convención de cita:** `A.72 §N` (ej. `A.72 §4` = Fase 2 Diseño Seguro).

---

## §2 Marco normativo — qué exige A.8.25

### 2.1 ISO/IEC 27001:2022 A.8.25

El control establece que las organizaciones deben aplicar reglas de desarrollo seguro a los
sistemas de información que construyen. Los requisitos clave son:

| Req | Descripción |
|-----|-------------|
| **R1** | Política de desarrollo seguro — reglas establecidas y aplicadas formalmente |
| **R2** | Requisitos de seguridad definidos antes de iniciar el desarrollo |
| **R3** | Modelado de amenazas durante la fase de diseño |
| **R4** | Revisión de código con perspectiva de seguridad antes de producción |
| **R5** | Pruebas de seguridad (SAST, DAST, pen-test) antes de release |
| **R6** | Principios de arquitectura segura — defense-in-depth, least privilege, fail-closed |
| **R7** | Gestión de dependencias — control de componentes de terceros y vulnerabilidades |

### 2.2 NIST SP 800-218 SSDF — grupos de actividades

El Secure Software Development Framework organiza las prácticas en 4 grupos:

| Grupo SSDF | Descripción | Fase bAuth |
|-----------|-------------|------------|
| **PW — Prepare** | Establecer entorno y herramientas de desarrollo seguro | §3 Requisitos |
| **PS — Protect** | Proteger el software y su cadena de suministro | §5 Codificación |
| **PO — Produce** | Producir software bien asegurado | §4 Diseño + §5 Código |
| **RV — Respond** | Responder a vulnerabilidades en software publicado | §7 Prueba + §8 Despliegue |

### 2.3 OWASP SAMM v2.0 — dominios de madurez

| Dominio SAMM | Práctica evaluada | Estado bAuth |
|-------------|-------------------|:------------:|
| Governance | Política de seguridad + educación | ✅ CLAUDE.md DOC-SBOS-001 N3 |
| Design | Evaluación de amenazas + requisitos de seguridad | ✅ STRIDE + ADRs |
| Implementation | Codificación segura + gestión de dependencias | ✅/⚠️ Rust + cargo audit manual |
| Verification | Revisión de código + pruebas de seguridad | ✅/⚠️ Revisor + sin CI automático |
| Operations | Gestión de vulnerabilidades + hardening | ⚠️ bos + sin DAST CI |

---

## §3 Fase 1 — Requisitos de Seguridad

*ISO A.8.25 R2 · NIST SSDF PW.1 · OWASP SAMM Design-Security_Requirements*

### 3.1 El DDL como especificación formal de seguridad

El DDL de bAuth no es solo un esquema de base de datos. Es la **especificación formal de
los requisitos de seguridad** del sistema. Cada tabla lleva un campo `Estándar:` en su
`COMMENT ON TABLE` que vincula la decisión de diseño con la norma que la origina.

Esto demuestra que los requisitos de seguridad fueron definidos **antes de escribir el código**
— son constraints de diseño embebidos en el esquema, no anotaciones posteriores.

**Muestra representativa de las 181 referencias normativas embebidas:**

| Tabla | Estándar referenciado | Requisito específico |
|-------|----------------------|---------------------|
| `bglobal.global_config` | NIST SP 800-53 CM-6/CM-7 | Configuration Settings, Least Functionality |
| `bauth.idn_identity_entity` | ISO 27001 A.8.2 · NIST SP 800-53 AC-2 · GDPR Art. 32 | Gestión de cuentas · clasificación · privacidad |
| `bauth.idn_tenant_fal_config` | NIST SP 800-63-4 §5 · OIDC Core 1.0 · RFC 9449 · RFC 8705 | FAL1/2/3, DPoP, mTLS |
| `bauth.sig_algorithm` | FIPS 203/204/205 · RFC 8410 | PQC ML-DSA-65, SLH-DSA, ML-KEM |
| `bauth.ses_session_log` | ISO 27001 A.8.15 · NIST SP 800-63B | Logging de sesiones, AAL |
| `bauth.idn_roles_template_history` | ISO 27001 A.8.9 · NIST AC-3 | Configuración auditada WORM |
| `bauth.aud_event_log` | ISO 27001 A.8.15 · NIST AU-3 | Auditoría forense |
| `bauth.idn_roles_ver_b01_retention_policy` | ISO 27001 A.8.10 · GDPR Art. 17 · Ley 843 Bolivia | Retención con `legal_basis` NOT NULL |

### 3.2 Estándares que gobiernan el sistema completo

| Familia | Norma | Área que cubre |
|---------|-------|---------------|
| Identidad | NIST SP 800-63B Rev.4 (2024) | Contraseñas, MFA, AAL1-3 |
| Identidad | NIST SP 800-63A IAL1-3 | Proofing de identidad |
| RBAC | ANSI INCITS 359-2004 | Estándar formal de roles |
| Zero Trust | NIST SP 800-207 | Política por sesión, ctx_id, evaluación continua |
| Acceso | NIST SP 800-53 R5.2 AC-2/5/6 | Gestión de cuentas, SoD, least privilege |
| Criptografía | FIPS 203/204/205 (PQC 2024) | ML-KEM, ML-DSA, SLH-DSA |
| Firma | RFC 8410 · Ley 164 Bolivia | Ed25519 · ADSIB RSA-SHA256 |
| OAuth/OIDC | RFC 6749/7636/8705/9449 | PKCE, mTLS, DPoP |
| WebAuthn | W3C FIDO2 | Autenticación sin contraseña |
| Auditoría | ISO 27001:2022 A.8.15 | Logging forense, hash-chain |
| Privacidad | GDPR Art. 5/25/32 | Privacy by design, retención |
| Bolivia | SIN RND 102100000011 · Ley 164 | Facturación electrónica, firma digital |

---

## §4 Fase 2 — Diseño Seguro

*ISO A.8.25 R3+R6 · NIST SSDF PW.4+PW.5 · OWASP SAMM Design-Threat_Assessment*

### 4.1 Modelado de Amenazas — STRIDE

La arquitectura de seguridad de bAuth parte de un modelo de amenazas STRIDE completo.
Cada amenaza está **cableada a una regla de seguridad de red verificable** (NRS) — el modelo
no es teórico: cada fila tiene un método de verificación por comando.

| Amenaza STRIDE | Vector de Ataque Concreto | Contramedida | Regla verificable |
|----------------|--------------------------|-------------|-------------------|
| **S**poofing (suplantar Kong) | TCP a :9443 desde namespace no autorizado | mTLS + NetworkPolicy deny-all entre namespaces | NRS-04: `kubectl describe networkpolicy` |
| **T**ampering (ctx_id en tránsito) | MITM en red K8s entre pods | TLS 1.3 exclusivo en toda conexión inter-servicio | NRS-01: `openssl s_client -tls1_3` |
| **R**epudiation (validación sin registro) | Operador niega acceso que sí concedió | `audit_event` WORM por cada validación (hash-chain SHA-256) | NRS-09: `SELECT count(*) FROM aud_event_log` |
| **I**nformation Disclosure (enumerar ctx_ids) | GET con UUIDs aleatorios para descubrir contextos válidos | Rate limit + sin endpoint de listado + UUID v4 estricto | NRS-07: `curl -X GET /context/<uuid-random>` → 404 sin revelar existencia |
| **D**enial of Service (saturar endpoint) | 10,000 req/s desde pod comprometido | Rate limit 100 req/s por IP + timeout 2s | NRS-08: `hey -n 1000 -c 100 …` → 429 tras límite |
| **E**levation of Privilege (ctx_id tenant A → recursos de B) | ctx_id robado de logs o memoria compartida | BitMask evaluado por request con `tenant_id` hardbound + ctx_id TTL corto | NRS-06: cualquier ctx_id de otro tenant → DENY inmediato |

### 4.2 Principio rector — superficie mínima de ataque

La regla de reducción de superficie (en orden de preferencia):

```
1. ELIMINAR   → ¿se puede no exponerlo? (el endpoint que no existe no se ataca)
2. UNIFICAR   → ¿un endpoint en vez de seis?
3. MINIMIZAR  → ¿solo los campos necesarios en la respuesta?
4. PROTEGER   → lo que queda: TLS, rate limit, validación, auditoría
```

Materializado en bAuth: **Interface Dual sobre UN socket Unix** (`/run/bos/bauth.sock`, 0660
grupo `bosagent`) en vez de puertos TCP abiertos. HTTP entre daemons: **PROHIBIDO** (SBOS-050 P9).

### 4.3 Defensa en Profundidad — las 6 capas

Ninguna capa confía en que la anterior hizo su trabajo:

```
┌─ CAPA 1 · Transporte   TLS 1.3 · ECDHE+AES-256-GCM+SHA384 · mTLS donde hay identidad (NRS-01/03)
├─ CAPA 2 · Red          NetworkPolicy deny-all · solo tráfico declarado (NRS-04)
├─ CAPA 3 · Superficie   1 endpoint por propósito, no 6 (NRS-05)
├─ CAPA 4 · Respuesta    solo los campos necesarios · secretos NUNCA (NRS-06/10)
├─ CAPA 5 · Entrada      validación centralizada allowlist (SAN-01→12)
└─ CAPA 6 · Auditoría    cada validación/error → audit_event WORM (NRS-09)
```

### 4.4 Zero Trust en comunicaciones internas (NIST SP 800-207)

bAuth implementa los 7 principios de Zero Trust en el tráfico entre daemons — no hay
"red interna de confianza":

| Principio ZTA | Implementación concreta |
|---------------|------------------------|
| Recursos accesibles solo vía red segura | Unix socket 0660 grupo `bos` / `wss://` |
| Comunicación segura sin importar ubicación | TLS 1.3 + mTLS en toda conexión |
| Acceso por sesión individual | ctx_id único con TTL por request |
| Política dinámica por atributos | BitMask + DomainRegistry evaluados en cada request |
| Monitoreo continuo | validación de ctx_id en CADA request sin excepción |
| AuthN/AuthZ estrictas | promote solo post-auth · invalidate inmediato en revocación |
| Máxima telemetría | traceparent W3C + audit_event por operación |

### 4.5 Decisiones Arquitectónicas de Seguridad

Los ADRs son el registro formal de las decisiones de diseño con impacto de seguridad.
Cada ADR documenta: contexto → decisión → alternativas consideradas → consecuencias.

---

#### ADR-001 — Stack tecnológico: Rust 1.85+ MUSL

**Estado:** VIGENTE · Fecha: 2026-06-20

**Contexto:** bAuth necesita alta concurrencia, binario estático distribuible y seguridad
de memoria sin GC para el daemon de identidad.

**Decisión:** Rust 1.85+ (tokio, MUSL, LTO) para el daemon core completo.

| Alternativa evaluada | Por qué se rechazó |
|---------------------|-------------------|
| Go 1.22+ | GC introduce latencia en evaluación BitMask; sin garantías de memoria en tiempo de compilación |
| Python 3.14 | GIL limita concurrencia; sin binario estático; rendimiento 10× inferior en crypto |
| 100% Java 21 | JVM no produce binario estático; startup lento; consumo de memoria elevado |

**Impacto de seguridad:** Ownership model → imposibilidad de use-after-free y data races
en evaluación BitMask. Binario MUSL estático → no carga librerías del SO en runtime
(defense against dependency confusion attacks). Evaluación BitMask < 0.5ns.

---

#### ADR-002 — Interface Dual: WebSocket RPC + JSON-RPC 2.0 sobre Unix socket

**Estado:** VIGENTE · Fecha: 2026-06-20

**Contexto:** bAuth debe ser invocable tanto por humanos (CLI `bauthctl`) como por daemons
(biedata, bkernel). SBOS-050 P9 prohíbe HTTP entre daemons.

**Decisión:** Interface Dual sobre **un único** Unix socket `/run/bos/bauth.sock`
(0660, grupo `bosagent`). Vía 1 = WebSocket RPC para CLI; Vía 2 = JSON-RPC 2.0 para daemons.

| Alternativa evaluada | Por qué se rechazó |
|---------------------|-------------------|
| HTTP REST | Viola SBOS-050 P9 · requiere puerto TCP adicional · superficie TCP expuesta |
| gRPC exclusivo | No apto para CLI humano sin protobuf toolchain · JSON-RPC más accesible |
| Dos sockets separados | Complejidad operativa innecesaria · dos puntos de administración |

**Impacto de seguridad:** Superficie mínima real — un solo socket Unix con permisos de
grupo elimina spoofing inter-daemon. MitM imposible sin acceso físico al socket.

---

#### ADR-003+009 — BitMask Dual: AtomBitMask (label) + RolBitMask (one-hot) + DAG herencia OR

**Estado:** VIGENTE (ADR-003 corregido por ADR-009) · Fecha: 2026-06-20

**Contexto:** El sistema necesita evaluar permisos en < 0.5ns por request sin consultar
la base de datos en cada operación, soportando herencia jerárquica de roles (NIST RBAC §4.2).

**Decisión:** BitMask Dual de 64 bits con DAG de herencia OR.
- `AtomBitMask`: identifica un átomo individual (label — identificador).
- `RolBitMask`: combina múltiples átomos (one-hot — posición de bit = presencia de átomo).
- Herencia: `mask_eff(senior) = mask_own(senior) | mask_eff(junior₁) | ...`
- Verificación: `(mask_eff & bit_operación) != 0` → una sola instrucción CPU.
- Almacenamiento: `closure_table(ancestro_id, descendiente_id, profundidad)` — un JOIN sin recursión.

**Impacto de seguridad:** Privilege escalation requiere alterar el DAG en `idn_roles_template`
(auditado por `idn_roles_template_history` WORM + hash-chain SHA-256). Evaluación en < 0.5ns
evita ataques de timing que revelan la lógica de autorización.

---

#### ADR-004 — bAuth como orquestador, no como monolito

**Estado:** VIGENTE · Fecha: 2026-06-20

**Contexto:** Un sistema de autenticación puede construirse como monolito (un proceso que
hace todo) o como framework que orquesta componentes especializados.

**Decisión:** bAuth es un **framework orquestador** que implementa el patrón "Director de
Orquesta". Cada componente (PrivilegeEngine, PolicyEngine, AuthMethodRegistry, SignatureEngine)
tiene una responsabilidad única y límites de módulo ≤ 200 líneas (DOC-SBOS-001 N3).

**Impacto de seguridad:** Cero god-classes con superficie de ataque total. Cada componente
es auditable de forma aislada. La separación de responsabilidades limita el blast radius de
una vulnerabilidad en un componente.

---

#### ADR-005 — Argon2id como hash exclusivo de contraseñas

**Estado:** VIGENTE · Fecha: 2026-06-20

**Contexto:** NIST SP 800-63B Rev.4 (2024) y OWASP ASVS 2.4.3 recomiendan Argon2id.
Los algoritmos legacy son vulnerables a hardware moderno (GPU, FPGA, ASIC).

**Decisión:** Argon2id como algoritmo exclusivo para contraseñas nuevas.
Parámetros diferenciados por criticidad del tier:

| Tier | t (time) | m (memory) | p (parallelism) |
|------|----------|------------|----------------|
| SU | 5 | 128 MB | 2 |
| SYS | 3 | 64 MB | 2 |
| BIZ N3-N5 | 3 | 64 MB | 2 |
| BIZ N1-N2 / EXT | 2 | 32 MB | 1 |

Algoritmos deprecados: SHA1, MD5, bcrypt, PBKDF2-SHA256 (este último solo para verificar
hashes legacy durante migración, nunca para nuevas credenciales).

**Impacto de seguridad:** Resistencia demostrada a GPU/FPGA/ASIC. Memory-hard → el ataque
de fuerza bruta paralela requiere RAM proporcional, haciendo inviable el cracking masivo.

---

#### ADR-006 — Doble motor de firma digital

**Estado:** VIGENTE · Fecha: 2026-06-20

**Decisión:** Dos motores de firma operando en paralelo:
- **Interno:** Vault PKI con Ed25519 (EdDSA, RFC 8410) — firma con validez en el ecosistema SBOS.
- **Externo:** ADSIB RSA-SHA256 (Ley 164 Bolivia) — firma con validez jurídica ante el Estado boliviano.

**Impacto de seguridad:** No-repudio dual verificable internamente (PKI soberana) y
externamente (autoridad estatal). Una operación crítica (factura SIN, contrato) tiene dos
firmas independientes que se validan por vías distintas.

---

#### ADR-010 — Deprecación de Keycloak y Tryton — bAuth autosuficiente

**Estado:** VIGENTE (reemplaza ADR-008) · Fecha: 2026-06-28

**Decisión:** Keycloak y Tryton dejan de participar en la pila de autenticación/autorización
de SBOS. bAuth pasa a ser **completamente autosuficiente**:
- Motor de autenticación: implementado nativamente en Rust (`domain/auth_methods/`).
- Motor de autorización: `DomainRegistry` + `PolicyEngine` (XACML/ABAC) sobre 18 dominios.
- OIDC Provider: propio, sin Keycloak.

**Impacto de seguridad:** Eliminación de dependencias externas = eliminación de superficie
de ataque en la cadena de suministro. Sin realms KC que sincronizar, sin APIs externas que
comprometer, sin SPIs Java en la JVM. Todo el stack de identidad es código Rust auditable.

> **Nota histórica:** Los ADRs anteriores a ADR-010 (ADR-007 KC 3 realms, ADR-008 simbiosis
> trilateral bAuth-KC-Tryton) son registro histórico. Su contenido ya no aplica al sistema
> actual. Se conservan como evidencia de la evolución de la arquitectura.

---

#### ADR-D12 — Blockchain dominio D12

**Estado:** VIGENTE · Fecha: posterior a ADR-010

**Decisión:** El dominio D12 incorpora Besu (Ethereum compatible) para operaciones de
alto valor: anclaje de evidencias, firmas ECDSA con validez en blockchain público.

**Impacto de seguridad:** No-repudio externo inmutable — una evidencia anclada en blockchain
no puede ser modificada retroactivamente sin que la red lo detecte. Relevante para contratos
notariales y operaciones con validez jurídica interorganizacional.

---

## §5 Fase 3 — Codificación Segura

*ISO A.8.25 R1+R4 · NIST SSDF PS.2+PW.6 · OWASP SAMM Implementation-Secure_Coding*

### 5.1 Política de codificación segura — DOC-SBOS-001 N3

Las siguientes reglas son **obligatorias** en bAuth y verificadas por el Revisor en cada
commit. No son aspiraciones — su violación es causa de rechazo de la entrega.

| Regla | Descripción | Impacto de Seguridad |
|-------|-------------|---------------------|
| **Cero `unwrap()` en producción** | Usar `Result<T, BauthError>` con mensajes en español | Previene panic que expone estado interno del proceso |
| **Cero `clone()` innecesario** | Usar borrows y lifetimes apropiados | Previene copias inseguras de datos sensibles en memoria |
| **Módulos ≤ 800 líneas** | Dividir en submódulos cuando tiene sentido semántico | Limita la superficie de revisión y auditoría |
| **Funciones ≤ 50 líneas** | Extraer helpers si excede | Impide lógica de seguridad dispersa en funciones largas |
| **Parámetros tipados** | Prohibido `String` genérico sin newtype · usar enums con `#[derive]` | Previene type confusion y mass assignment |
| **Prohibido código monolítico** | Modularización obligatoria, responsabilidades únicas | Cero god-classes con superficie de ataque total |
| **Documentación obligatoria (español)** | Cada función, struct, parámetro documentado con propósito | Permite auditoría real sin ejecutar el código |
| **AA-1 Evidencia** | Toda afirmación verificable requiere salida de `verificar_afirmacion.sh` | Previene "security theater" — afirmaciones sin prueba |

### 5.2 Seguridad de memoria — garantías del compilador Rust

| Propiedad | Vulnerabilidad que previene | Relevancia en IAM |
|-----------|---------------------------|------------------|
| **Ownership model** | Use-after-free · double-free | Imposibilidad de reutilizar tokens ya liberados de memoria |
| **Borrow checker** | Data races · race conditions | Evaluación BitMask thread-safe sin locks explícitos |
| **No null pointers** (`Option<T>`) | Null dereference | Ningún ctx_id puede ser null — el tipo lo garantiza en compilación |
| **Error handling explícito** (`Result<T,E>`) | Silent failure | Un hash fallido no "silencia" el error y no pasa la autenticación |
| **MUSL static binary** | Dependency confusion attacks | El binario no carga librerías del SO en runtime |
| **Lifetimes** | Dangling pointers | Referencias a contextos de sesión nunca sobreviven a la sesión |

### 5.3 Las 12 Reglas de Sanitización de Entrada (SAN)

Toda entrada es hostil hasta validarse. Cada regla está mapeada a OWASP/CWE y es un
requisito verificable — no una guía de estilo.

| Regla | Qué exige | Norma base |
|-------|-----------|-----------|
| **SAN-01** | Allowlist sobre denylist — definir exactamente qué se ACEPTA, rechazar el resto | OWASP Input Validation |
| **SAN-02** | Validación centralizada — todo input por UNA sola función de validación | OWASP Secure Coding |
| **SAN-03** | Canonicalizar ANTES de validar (UTF-8 NFC, URL-decode exactamente una vez) | CWE-22, CWE-74 |
| **SAN-04** | Rechazar en fallo con 400 — nunca "sanitizar silenciosamente" y continuar | OWASP ASVS V2.1 |
| **SAN-05** | Tipo estricto — no usar strings donde van números o UUIDs | API3:2023 |
| **SAN-06** | Límites de longitud en TODO campo, array y número — sin asumir tamaño máximo implícito | OWASP ASVS V2.3 |
| **SAN-07** | Encoding de salida específico por contexto (SQL → queries parametrizadas, JSON → escape) | OWASP ASVS V1.1 |
| **SAN-08** | Sin input de usuario directo en comandos OS — usar APIs, nunca concatenación de shell | CWE-78 |
| **SAN-09** | UUID v4 estricto para todos los IDs — rechazar IDs secuenciales o predecibles | API1:2023 (BOLA) |
| **SAN-10** | Mass Assignment Protection — DTOs intermedios, nunca unmarshal directo al modelo de dominio | API3:2023 |
| **SAN-11** | File upload: verificar MIME + magic bytes + escaneo + nombre generado por servidor | OWASP ASVS V12 |
| **SAN-12** | Header validation — validar Content-Type, Origin, X-SBOS-* antes de procesar el cuerpo | OWASP ASVS V14.4 |

**SAN-09 y SAN-10 son especialmente críticos para bAuth:** los IDs de identidad son UUID v4
estrictos (rechazar cualquier otro formato) y los templates entran siempre por DTO intermedio,
nunca por `unmarshal` directo al modelo de dominio.

### 5.4 Las 10 Reglas de Seguridad de Red (NRS)

Cada regla tiene su método de verificación por comando — no son aspiraciones:

| Regla | Qué exige | Verificación |
|-------|-----------|-------------|
| **NRS-01** | TLS 1.3 mínimo · cipher ECDHE+AES-256-GCM+SHA384 exclusivo · sin TLS 1.2/SSL | `openssl s_client -tls1_3 -connect …` |
| **NRS-02** | HTTP PROHIBIDO entre daemons · solo `wss://` o Unix socket · excepción Kong→BOS :9443 | `ss -tlnp | grep :94` → solo :9443 |
| **NRS-03** | mTLS obligatorio donde ambos extremos tienen identidad verificable | Cert presente en ambos lados |
| **NRS-04** | NetworkPolicy **deny-all** por defecto · solo tráfico declarado explícitamente | `kubectl describe networkpolicy` |
| **NRS-05** | Un endpoint por propósito · alertar si un daemon expone >3 | Revisar surface area total |
| **NRS-06** | Respuesta mínima · solo los campos que el consumidor necesita · DTO ≠ domain model | Auditoría de respuestas JSON-RPC |
| **NRS-07** | Sin listado sin auth · ID debe ser UUID válido · existencia no revelada en error | `GET /context/<uuid-random>` → 404 |
| **NRS-08** | Rate limiting en cada endpoint · default 100 req/s por IP · 429 tras el límite | `hey -n 1000 -c 100 …` → 429 |
| **NRS-09** | Cada validación/error de seguridad → `audit_event` WORM (ctx_id, IP, resultado) | `SELECT count(*) FROM aud_event_log WHERE …` |
| **NRS-10** | Secretos NUNCA en respuesta, logs ni query strings · Vault para todo secreto | `grep -r "password\|secret\|token" src/` → 0 hardcoded |

---

## §6 Fase 4 — Revisión de Código

*ISO A.8.25 R4 · NIST SSDF RV.1 · OWASP SAMM Verification-Code_Review*

### 6.1 Revisor ORQUESTA — auditor independiente en cada commit

El agente **Revisor** de la fábrica ORQUESTA ejecuta después de cada commit de cualquier
agente desarrollador. Opera en modo solo-lectura — nunca modifica código.

| Verificación | Qué busca | Consecuencia de fallo |
|-------------|-----------|----------------------|
| **DOC-SBOS-001 N3** | Código sin documentación, funciones > 50 líneas | Entrega rechazada |
| **Alucinaciones** | Afirmaciones que no coinciden con el código real | Entrega rechazada + reporte al Bibliotecario |
| **Valores hardcodeados** | Secrets, URLs, IPs, límites de seguridad en código | Entrega rechazada |
| **Patrones inseguros** | `unwrap()`, `clone()` innecesario, strings sin validación | Entrega rechazada |
| **OWASP Top 10** | Inyección SQL/command, XSS, BOLA, Mass Assignment | Entrega rechazada |
| **AA-1 Evidencia** | Toda afirmación sin evidencia con timestamp+SHA256 | Afirmación inválida |

**Principio de independencia (ORQUESTA-056):** el agente que escribe el código no puede
auditarse a sí mismo. El Revisor es siempre un agente distinto al desarrollador. Ninguna
entrega se auto-aprueba.

### 6.2 Protocolo AA-1 — evidencia obligatoria

Toda afirmación verificable sobre el sistema (compila, existe, retorna N, cumple norma X)
**debe adjuntar** la salida de `scripts/verificar_afirmacion.sh "<descripción>" <comando>`,
que produce:

- Timestamp ISO 8601 de la verificación
- SHA256 del comando ejecutado y de su salida completa
- Estado de salida del proceso (0 = éxito verificado)

**Sin evidencia AA-1 = RECHAZO automático del Revisor.** No existe la afirmación de
seguridad sin prueba reproducible con timestamp.

---

## §7 Fase 5 — Pruebas de Seguridad

*ISO A.8.25 R5 · NIST SSDF RV.3 · OWASP SAMM Verification-Security_Testing*

### 7.1 Testeador ORQUESTA — verificación empírica en el entorno real

El agente **Testeador** verifica en el entorno de producción real (VPS), completamente
aparte de las pruebas que el agente desarrollador pudo haber hecho. Su dictamen es
**VERDADERO / FALSO** con evidencia reproducible. Nunca modifica código.

| Verificación | Qué valida | Estado |
|-------------|-----------|:------:|
| Login end-to-end en bAuth real | Credenciales → JWT emitido con BitMask correcto | ✅ |
| WORM integridad | Intentos de UPDATE/DELETE en `idn_roles_template_history` → error PERMISSION DENIED | ✅ |
| Hash-chain | Modificar un registro pasado rompe la cadena SHA-256 detectable | ✅ |
| Argon2id parámetros | Hash de contraseña con t/m/p según tier en VPS real | ✅ |
| Rate limiting por endpoint | 100 req/s → 429 confirmado en VPS | ⚠️ AA-1 pendiente |
| NetworkPolicy deny-all aplicada | `kubectl describe networkpolicy` en VPS | ⚠️ producto bos · pendiente |
| Rotación de certificados Vault | PKI emite cert < 24h y rota en producción | ⚠️ pendiente |

### 7.2 Suite de pruebas Rust

| Módulo | Cobertura | Tests clave |
|--------|-----------|-------------|
| `domain/bitmask.rs` | BitMask dual | OR de herencia, violaciones SoD, escalada de privilegios |
| `domain/password_policy.rs` | Argon2id + NIST | Screening, hash, verificación, parámetros por tier |
| `domain/identity_proofing.rs` | IAL1-3 | Verificación de documento, liveness check |
| `engine/` | 18 métodos auth | WebAuthn W3C §7.2 (372 tests) · mTLS RFC 8705 · TOTP |
| `server/jsonrpc.rs` | Anti-DoS | Req/s → timeout + 429 bajo carga extrema |

### 7.3 Gap P2 identificado — Pipeline CI de seguridad automático

Este es el único gap de A.8.25 en bAuth. La automatización de pruebas de seguridad en CI
no está implementada:

| Herramienta | Propósito | Estado |
|------------|-----------|:------:|
| `cargo audit` | Vulnerabilidades en crates Rust (RUSTSEC advisory database) | ❌ manual |
| `cargo clippy --deny warnings` | Lints de seguridad como regla de merge | ❌ no obligatorio en CI |
| DAST / fuzzing sobre socket Unix | Pruebas de caja negra sobre la API JSON-RPC | ❌ sin implementar |
| `trivy` sobre binario MUSL | Vulnerabilidades en dependencias del sistema | ❌ sin CI |

**Prioridad:** P2 — no bloquea la operación ni representa un riesgo activo inmediato,
pero es requisito baseline de A.8.25 R5 para el año 2026. Responsable: DevOps/bos
(infraestructura CI/CD).

---

## §8 Fase 6 — Despliegue Seguro

*ISO A.8.25 R1 · NIST SSDF DS.2 · OWASP SAMM Operations-Environment_Management*

### 8.1 Modelo de despliegue

bAuth se despliega como `bauth.service` (systemd, `Type=notify`, `WatchdogSec=30`) en el
host físico/VPS, no como pod Kubernetes. Los pods K8s solo alojan infraestructura
(PostgreSQL 18, Redis, Vault, Kong). Esta distinción es una decisión de soberanía y
seguridad: el daemon de identidad no comparte el plano de aislamiento con la infraestructura.

### 8.2 Controles de seguridad en la unit de systemd

| Control | Parámetro | Propósito de seguridad |
|---------|-----------|----------------------|
| Watchdog automático | `WatchdogSec=30` | Reinicio si el proceso se cuelga > 30s; impide bloqueo silencioso |
| Socket con permisos mínimos | `srw-rw---- bos bosagent` | Solo procesos del grupo `bosagent` acceden al socket |
| Binario MUSL estático | `< 15MB` sin deps runtime | Sin librerías del SO cargables en runtime (no dependency confusion) |
| Notificación systemd | `Type=notify` | El OS sabe exactamente cuándo el daemon está listo y cuándo falla |

### 8.3 Verificaciones post-despliegue

| Verificación | Comando | Norma |
|-------------|---------|-------|
| Socket presente y protegido | `ls -la /run/bos/bauth.sock` → `srw-rw---- bos bosagent` | ADR-002 |
| Servicio activo | `systemctl is-active bauth` → `active` | systemd |
| WatchdogSec operativo | `systemctl show bauth -p WatchdogSec` → `30s` | systemd |
| Sin puertos TCP de bAuth abiertos | `ss -tlnp \| grep :945` → vacío (solo :9443 de Kong→BOS) | SBOS-050 |
| TLS 1.3 en :9443 | `openssl s_client -tls1_3 -connect localhost:9443` → handshake ok | NRS-01 |

---

## §9 Estado de Madurez SDL

| Fase | Madurez | Brechas activas |
|------|:-------:|----------------|
| F1 — Requisitos de seguridad | ✅ ROBUSTO | — |
| F2 — Diseño seguro | ✅ ROBUSTO | — |
| F3 — Codificación segura | ✅ ROBUSTO | Función `sanitize` única (SAN-02) pendiente verificación AA-1 |
| F4 — Revisión de código | ✅ ROBUSTO | — |
| F5 — Pruebas de seguridad | ⚠️ PARCIAL | **P2: pipeline CI SAST/DAST/cargo-audit sin automatizar** |
| F6 — Despliegue seguro | ✅ ROBUSTO | NetworkPolicy deny-all: evidencia AA-1 pendiente (responsabilidad bos) |

**Scoring ISO 27001:2022 A.8.25:**

| Requisito | Estado | Evidencia |
|-----------|:------:|-----------|
| R1 — Política de codificación | ✅ | DOC-SBOS-001 N3 + AA-1 obligatorio (§5.1) |
| R2 — Requisitos de seguridad | ✅ | 181 refs normativas DDL + 15 estándares base (§3) |
| R3 — Modelado de amenazas | ✅ | STRIDE→NRS 6 filas cableadas (§4.1) |
| R4 — Revisión de código | ✅ | Revisor ORQUESTA independiente + AA-1 (§6) |
| R5 — Pruebas de seguridad | ⚠️ | Testeador VPS ✅ · CI automático SAST/DAST ❌ P2 |
| R6 — Arquitectura segura | ✅ | STRIDE + ZTA + 6 capas + 8 principios (§4.2–4.4) |
| R7 — Gestión de dependencias | ⚠️ | `cargo audit` manual · sin automatización CI |

**Calificación final: P (2/3)** — 5 requisitos completos, 2 parciales por el gap P2 de CI.

---

## §10 Comparativa con la Industria 2026

| Práctica SDL | bAuth | Industria baseline 2026 | Posición |
|-------------|:-----:|:----------------------:|:--------:|
| Política de codificación segura documentada | ✅ | Baseline | Alineado |
| Modelado de amenazas STRIDE | ✅ cableado a NRS | Estándar en IAM | Superior (NRS verificables) |
| ADRs con decisiones de seguridad | ✅ 8 ADRs | Raro en práctica | Superior |
| Revisión por agente independiente | ✅ | Code review humano | Superior en automatización |
| Pruebas en entorno real (no mock) | ✅ | Staging env | Superior en fidelidad |
| Lenguaje memory-safe (Rust) | ✅ | Tendencia 2026 | Alineado |
| Pipeline CI con SAST automático | ❌ | **Baseline obligatorio** | **Brecha P2** |
| DAST sobre API en CI | ❌ | Estándar | **Brecha P2** |
| SCA (`cargo audit`) automatizado | ❌ | Estándar Rust | **Brecha P2** |
| Threat model en el DDL (Estándar:) | ✅ 181 refs | Sin equivalente | Único diferenciador |

---

## §11 Mapa Anexo → Manuales

| Sección | Manual que respalda | Sección del manual |
|---------|--------------------|--------------------|
| §3 Requisitos de Seguridad | `2.09_MANUAL-SEGURIDAD-v1.0.md` | §1 Normas base |
| §4.1 STRIDE | `2.09_MANUAL-SEGURIDAD-v1.0.md` | §3 Modelo de amenazas |
| §4.2–4.4 Arquitectura + ZTA | `2.09_MANUAL-SEGURIDAD-v1.0.md` | §4 Defensa en profundidad · §5 Zero Trust |
| §4.5 ADRs | `0.00_MANUAL-DIRECTRICES-IAM-ENTERPRISE.md` | Todas las decisiones arquitectónicas |
| §5.3 Reglas SAN | `2.09_MANUAL-SEGURIDAD-v1.0.md` | §7 Reglas de sanitización |
| §5.4 Reglas NRS | `2.09_MANUAL-SEGURIDAD-v1.0.md` | §6 Reglas de seguridad de red |
| §6 Revisión de código | `0.00_MANUAL-DIRECTRICES-IAM-ENTERPRISE.md` | Regla AA-1 + Revisor |
| §7 Pruebas + gap CI | `2.09_MANUAL-SEGURIDAD-v1.0.md` | §11.1 Estado del arte · §11.4 P2 |
| §8 Despliegue | `1.01_MANUAL-IAM-INSTALLER-v1.0.md` | Fase de despliegue |
| §9 Estado de madurez | `A.71_INFORME-CUMPLIMIENTO-ISO27001-2022-v1.0.md` | §4.6 A.8.25 |

---

## §12 Fuentes históricas (ya consolidadas en este anexo)

> Los siguientes documentos son el origen del conocimiento importado. Una vez construido
> este anexo, el lector no necesita consultarlos. Se citan únicamente como registro histórico.

| Documento de origen | Contenido importado | Sección en este anexo |
|--------------------|--------------------|----------------------|
| `context/plandeaccion/adrs/ADR-001 a ADR-010 + D12` | Decisiones arquitectónicas | §4.5 |
| `SBOS-054-NETWORK-SECURITY.md` v1.3.0 | STRIDE, NRS-01→10, SAN-01→12, ZTA | §4.1, §5.3, §5.4 |
| `CLAUDE.md` (proyecto + daemon) | DOC-SBOS-001 N3, AA-1, reglas de codificación | §5.1, §6 |
| `Estándar:` comments en SBOS_db_V2_DDL.sql | 181 referencias normativas | §3.1 |

---

## §13 Normas y estándares primarios

- ISO/IEC 27001:2022 A.8.25 — Secure Development Life Cycle
- NIST SP 800-218 v1.1 (SSDF) — Secure Software Development Framework
- OWASP SAMM v2.0 — Software Assurance Maturity Model
- OWASP ASVS 5.0 §14 — Secure Coding Requirements
- NIST SP 800-53 R5.2 SA-3 — System Development Life Cycle
- NIST SP 800-53 R5.2 SA-11 — Developer Testing and Evaluation
- OWASP API Top 10 2023 — BOLA, Broken Auth, Mass Assignment
- Microsoft STRIDE Threat Modeling (Adam Shostack, 2014)
- Rust Secure Coding Guidelines — ANSSI-FR (https://anssi-fr.github.io/rust-guide/)

---

## §14 Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-08-01 | Versión inicial. Importa y consolida todo el conocimiento SDL de bAuth: ADR-001→010+D12 (8 decisiones arquitectónicas completas), modelo STRIDE→NRS cableado (6 amenazas), 12 reglas SAN, 10 reglas NRS, protocolo Revisor ORQUESTA + AA-1, suite de pruebas Rust, modelo de despliegue systemd. Score A.8.25: P(2/3) — 5/7 requisitos cubiertos, gap P2 en CI SAST/DAST/cargo-audit. Vinculado como anexo de respaldo de `2.09_MANUAL-SEGURIDAD-v1.0.md`. |
