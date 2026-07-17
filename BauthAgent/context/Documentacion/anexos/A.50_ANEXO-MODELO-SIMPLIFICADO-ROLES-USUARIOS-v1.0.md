# A.50 — Modelo Simplificado: Árbol → Átomo → Rol → Usuario → BitMask
## Tipo B+C — Respaldo normativo y comparativa industria: por qué bAuth es más simple que Cedar, OPA y XACML

**Versión:** 1.1.0
**Fecha:** 2026-07-14
**Tipo de anexo:** B (normativo/industria) + C (justificación de decisión técnica)
**Respalda a:** [2.13 MANUAL-ATOMLANG-LENGUAJE §7](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) · [2.15 Motor de Identidad](../2.15_MANUAL-MOTOR-IDENTIDAD-v1.0.md) · [1.06 D00 Identidad v2.0](../1.06_MANUAL-D00-IDENTIDAD-v2.0.md)
**Fuentes absorbidas:** `DISENO-MOTOR-IDENTIDAD-v1.0.md` · `ATOMLANG-DEFINICION-CANONICA-v2.0.md` §9 · `ATOMLANG-INDUSTRIA-APRENDIZAJE-v1.0.md`
**Normas base:** ANSI INCITS 359-2004 (RBAC) · NIST SP 800-162 (ABAC) · NIST SP 800-53 AC-3/AC-5/AC-6 · ISO 27001:2022 A.5.15-18 · NIST SP 800-63A/B

---

## §1 Propósito y cómo citarlo

Este anexo documenta el **modelo simplificado de bAuth**: un pipeline lineal de 5 pasos que
unifica lo que la industria separa en dos sistemas (policy engine + identity source). Explica
por qué este modelo es más simple que Cedar, OPA/Rego y XACML 3.0, con evidencia comparativa.

**Cómo citarlo:** `A.50 §N` (ej. "ver pipeline de 5 pasos: A.50 §2").

---

## §2 El pipeline de 5 pasos

```
PASO 1 — DEFINIR (arquitecto de seguridad, una vez)
┌─────────────────────────────────────────────────────────┐
│ Construye el árbol maestro en el dashboard.              │
│ Políticas + reglas fabrican átomos.                     │
│ Define conjuntos en D98.                                │
│ Persiste en: bauth.atom_tree (PostgreSQL, 1 tabla)      │
└─────────────────────────────────────────────────────────┘

PASO 2 — COMPILAR (atomc, automático)
┌─────────────────────────────────────────────────────────┐
│ atomc validate: verifica G-01..G-10 + D97 + D96         │
│ atomc compile: emite IR en privilege_atom_compiled      │
│ Átomos válidos → D95 (ACTIVO)                           │
│ Átomos corruptos → desaparecen de D95                   │
└─────────────────────────────────────────────────────────┘

PASO 3 — ASIGNAR átomos a roles (arquitecto de identidad)
┌─────────────────────────────────────────────────────────┐
│ En D98: roles y conjuntos definidos.                     │
│ privilege_role_atom: INSERT (rol X tiene átomo Y)       │
│ compute_rol_bitmask(): RolBitMask precalculado           │
│ Persiste en: idn_role_template.rol_bitmask_base64        │
└─────────────────────────────────────────────────────────┘

PASO 4 — INSCRIBIR usuarios a roles (admin / RRHH)
┌─────────────────────────────────────────────────────────┐
│ idn_user_role: INSERT (usuario Z tiene rol X)           │
│ Usuario hereda TODOS los átomos del rol.                 │
│ Solo se define: identidad + rol base.                    │
│ Opcional: átomos extra o bloqueados (privilege_user_atom)│
│ UserBitMask = OR(RolBitMask de roles activos)            │
│             + átomos extra - átomos bloqueados           │
│ Persiste en: idn_user_template.rol_bitmask_base64        │
│ Cache: Redis (TTL 30s)                                   │
└─────────────────────────────────────────────────────────┘

PASO 5 — EVALUAR (PDP, runtime, automático)
┌─────────────────────────────────────────────────────────┐
│ Llega solicitud: usuario Z intenta APPROVE sobre X       │
│ PDP: resolve("d3.ventas.aprobacion.approve") → pos 2000 │
│ PDP: UserBitMask[2000] == 1? → Permit (<0.5ns)          │
│ PEP: concede acceso                                     │
│ Auditoría: INSERT en privilege_atom_audit (WORM)         │
│                                                         │
│ SIN combining algorithms en runtime.                     │
│ SIN evaluación anidada de PolicySets.                    │
│ SIN PIP externo obligatorio.                             │
│ SOLO bits.                                               │
└─────────────────────────────────────────────────────────┘
```

---

## §3 Las tres vistas del árbol (filtro progresivo)

El dashboard ofrece tres vistas sobre el mismo árbol. No son árboles distintos — son
**filtros** sobre el árbol maestro.

### Vista GENERAL
Sin filtro. El árbol completo. Para el arquitecto de seguridad.

### Vista ROL
Filtrada por `Target.Subject SET(conjunto)`. Solo se muestran las ramas donde la Regla
aplica al rol filtrado. Las reglas `subject: ANY` siempre visibles.

```
FILTRO: rol ∈ SET(vendedores)
Árbol completo: ~100 átomos → Vista Rol: 5 átomos visibles
```

### Vista USUARIO
Todo lo de la Vista Rol + atributos del usuario + reglas específicas (overrides).

```
USUARIO "Juan Pérez"
  ├── HEREDADO del rol vendedor_senior (5 átomos)
  ├── ATRIBUTOS: nombre, email, sucursal, cargo
  └── EXCEPCIONES:
        ✅ descuento_tier1_extendido (override positivo)
        ❌ transferencia_bloqueada (override negativo)
```

---

## §4 Comparativa detallada con la industria

### 4.1 Cedar (AWS)

**Fortalezas:** verificación formal con SMT solver (Z3), compilado a IR, benchmarks de 4-11 µs,
open source en Rust, política como código separada de la aplicación.

**Debilidades:** requiere un identity source externo (LDAP, SAML) para resolver `principal in
Group("...")`. El motor de políticas y la asignación a usuarios son dos sistemas que se integran.

**Qué aprendimos:** el concepto de editor visual multi-modo (IFTTT + Visual + Code sincronizados)
del Cedar Observer UI de Lucid Computing. La separación Policy Store → Engine → Identity Source
es el patrón estándar de la industria — y es justamente lo que bAuth unifica.

### 4.2 OPA/Rego (CNCF)

**Fortalezas:** ecosistema cloud-native masivo (Kubernetes, Envoy, Istio), lenguaje Rego
expresivo, ecosistema de herramientas (Playground, LSP, Regal linter, VS Code), `opa test`
para pruebas de políticas.

**Debilidades:** curva de aprendizaje Datalog pronunciada para administradores IAM, interpretado
(no compilado), evaluación por request (sin precomputación como el BitMask), sin verificación
formal.

**Qué aprendimos:** el modelo LSP (Language Server Protocol) para integrar atomc con cualquier
editor. El concepto de Playground online. El ecosistema de herramientas alrededor del lenguaje
(linter, formateador, test runner).

### 4.3 XACML 3.0 (OASIS)

**Fortalezas:** estándar internacional de facto para gobierno, financiero y defensa. Arquitectura
completa PAP/PDP/PEP/PIP. Combining algorithms formales. Obligations y Advice.

**Debilidades:** XML verboso (80+ líneas por regla simple), sin implementación de referencia
dominante, combining algorithms anidados que producen comportamiento difícil de predecir,
sin separación entre definición y evaluación (el PDP evalúa PolicySets directamente).

**Qué aprendimos:** la base conceptual (PolicySet/Policy/Rule, Target/Condition/Effect,
combining algorithms) que AtomLang adopta. La diferencia clave: AtomLang USA combining
algorithms en la fábrica (compile time), NO en runtime. El PDP solo ve bits.

### 4.4 Tabla comparativa

| | Cedar (AWS) | OPA/Rego | XACML 3.0 | **bAuth / AtomLang** |
|---|---|---|---|---|
| **Superficie de autoría** | 3 modos: IFTTT + Visual + Code | Editor de texto + LSP | XML en editor genérico | **Constructor visual: paleta + drop + formularios** |
| **Sintaxis** | `permit`/`forbid` + `when`/`unless` | Datalog (`package`, `import`, reglas) | XML verboso (80+ líneas) | **Sin sintaxis. Objetos predefinidos con valores de catálogo.** |
| **Curva aprendizaje** | Media (hay que aprender Cedar) | Alta (Datalog no es intuitivo) | Alta (XML + XACML semántica) | **Baja. No hay lenguaje que aprender.** |
| **Modelo de evaluación** | Compiled → IR → engine. Forbid overrides Permit | Interpretado. `opa eval` por request | PDP con PolicySets anidados + combining algorithms recursivos | **BitMask precomputado. `bitmask[pos] == 1` → Permit. <0.5ns.** |
| **Conflictos runtime** | forbid > permit (estático) | Orden de prioridad. Conflicto = error | 6 combining algorithms (orden importa) | **Sin conflictos. Cada átomo es una posición independiente. La fábrica ya resolvió.** |
| **Asignación a usuarios** | Identity source externo: `principal in Group("...")` | `input.user.groups[_]` desde el PEP | PIP externo: atributos del sujeto | **Inscripción directa. Usuario → rol → átomos. Herencia automática.** |
| **Roles y grupos** | Groups como entidades en el store | Groups como atributos del input | Subject Category (custom, no estándar) | **D98: conjuntos nativos. `SET(vendedores)`. Sin sintaxis. Sin store externo.** |
| **Verificación** | SMT solver (Z3). Análisis estático de políticas | `opa test`. Sin verificación formal | Sin verificación formal en el estándar | **D97 normativa. atomc validate. Trazabilidad a ISO/NIST por campo.** |
| **Integración** | Policy Store + Identity Source (2 sistemas) | Policy Engine + External Data (2 sistemas) | PAP + PIP + PDP + PEP (4 componentes) | **1 sistema. 5 pasos lineales. Sin integraciones.** |

---

## §5 Por qué funciona: la complejidad se resuelve en la fábrica, no en runtime

La diferencia arquitectónica fundamental entre bAuth y la industria es **cuándo** se resuelve
la complejidad:

```
INDUSTRIA (Cedar, OPA, XACML):
  Admin define políticas → Runtime evalúa políticas + resuelve identidad + combina resultados
  └── La complejidad está en RUNTIME. Cada request es una evaluación completa.

bAUTH:
  Admin define políticas → atomc compila átomos → átomos → roles → usuarios → BitMask
  └── La complejidad está en COMPILE TIME. Cada request es un array lookup.
```

Esto es lo mismo que hace un compilador: el código fuente es complejo (funciones, tipos,
control de flujo), pero el binario compilado es simple (instrucciones de máquina). El
cerebro humano trabaja con la versión compleja (el árbol); la máquina trabaja con la
versión simple (el BitMask).

---

## §6 Referencias

### Documentos del proyecto
- [2.13 Manual AtomLang v2.0](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) §7, §9
- [A.49 Constructor visual](A.49_ANEXO-EDITOR-VISUAL-ATOMLANG-v1.0.md)
- [1.04 Manual BitMask](../1.04_MANUAL-BITMASK-v1.0.md)
- [1.08 Manual User Template](../1.08_MANUAL-USER-TEMPLATE-v1.0.md)
- [1.09 Manual Roles](../1.09_MANUAL-ROLES-v1.0.md)

### Industria
- Cedar Policy Language — [github.com/cedar-policy](https://github.com/cedar-policy/)
- Cedar Management Platform — [github.com/aws-samples/sample-cedar-policy-management-platform](https://github.com/aws-samples/sample-cedar-policy-management-platform)
- OPA/Rego — [openpolicyagent.org](https://www.openpolicyagent.org/)
- OASIS XACML 3.0 — [docs.oasis-open.org/xacml/3.0/](http://docs.oasis-open.org/xacml/3.0/xacml-3.0-core-spec-os-en.html)

### Normas
ANSI INCITS 359-2004 · NIST SP 800-162 · NIST SP 800-53 · ISO 27001:2022 · ISO 24760-2:2025

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-14 | Primera edición. Documenta el modelo simplificado de 5 pasos (definir → compilar → asignar → inscribir → evaluar), las tres vistas del árbol filtradas progresivamente (General/Rol/Usuario), comparativa detallada con Cedar, OPA/Rego y XACML 3.0 en 9 dimensiones, y la tesis arquitectónica: la complejidad se resuelve en la fábrica (compile time), no en runtime. |


---

## §7 — v1.1.0: Motor de Identidad en el pipeline (2026-07-14)

El Paso 1 del modelo simplificado ahora incluye el **Motor de Identidad** como validador
de datos antes de la compilación de átomos:

```
PASO 1 — DEFINIR (arquitecto de seguridad, una vez)
┌─────────────────────────────────────────────────────────┐
│ Construye el árbol maestro en el dashboard.              │
│                                                         │
│ 1a. Identidad: crea entidades en idn_identidad_entidad             │
│     (tenant → bdomain → bsubdomain → pos → actor)       │
│ 1b. Atributos: asigna atributos en idn_identidad_atributo          │
│     Motor de Identidad valida cada set()                 │
│     (validate → verify → format)                         │
│ 1c. Políticas: define reglas en el árbol de políticas    │
│     Las reglas fabrican átomos (incluidos D00)           │
│                                                         │
│ Persiste en: idn_identidad_entidad + idn_identidad_atributo                  │
└─────────────────────────────────────────────────────────┘

PASO 2 — COMPILAR (atomc, automático)
  atomc validate: verifica G-01..G-10 + D97 + D96
  atomc compile: emite IR en privilege_atom_compiled
  Átomos válidos → D95 (ACTIVO)

PASO 3 — ASIGNAR átomos a roles (arquitecto de identidad)
  Átomos D00 + D1-D13 → privilege_role_atom
  compute_rol_bitmask() → RolBitMask precalculado

PASO 4 — INSCRIBIR usuarios a roles (admin / RRHH)
  Usuario (idn_identidad_entidad actor) → idn_user_role
  UserBitMask = OR(RolBitMask de roles activos)

PASO 5 — EVALUAR (PDP, runtime)
  UserBitMask[pos] == 1 → Permit (<0.5ns)
```

### Dos motores, un pipeline

| Motor | Opera sobre | Verbos | Fase |
|---|---|---|---|
| **Motor de Identidad** | idn_identidad_entidad, idn_identidad_atributo | validate, verify, format | Paso 1 (creación) |
| **Motor BitMask** | privilege_atom, UserBitMask | read, write, approve... | Paso 5 (evaluación) |

Ambos usan el mismo lenguaje AtomLang. El motor de identidad asegura datos correctos.
El motor BitMask asegura acceso correcto.
