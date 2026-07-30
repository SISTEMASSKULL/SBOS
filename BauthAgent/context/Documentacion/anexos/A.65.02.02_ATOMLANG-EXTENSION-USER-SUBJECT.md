# A.65.02.02 — AtomLang: Extensión User Subject (USER / USERSET / userunset)

**Versión:** 1.0.0  
**Fecha:** 2026-07-20  
**Estado:** ESPECIFICACIÓN PENDIENTE DE IMPLEMENTACIÓN  
**Referencia:** A.65.02.01 §G-02 · `tools/atomc/src/parser/ast.rs` · `tools/atomc/src/lexer/mod.rs`  
**Estándares base:** XACML 3.0 §5.5 (Target) · NIST SP 800-53 AC-3 · ANSI INCITS 359-2004 RBAC N3

---

## 1. Propósito

Este documento especifica la extensión del sistema de sujetos (`Subject`) de AtomLang para soportar
overrides a nivel de usuario individual, diferenciados de los overrides a nivel de rol.

La extensión surge de la resolución del gap G-02 (cadena de precedencia DENY) y formaliza la
separación entre dos planos de control que hoy comparten la misma infraestructura:

| Plano | Para qué | Kinds actuales | Kinds nuevos |
|-------|----------|----------------|--------------|
| **Rol** | Políticas estructurales del catálogo | `ROL`, `SET`, `unset` | — (ya existen) |
| **Usuario** | Overrides individuales de personas | — | `USER`, `USERSET`, `userunset` |

Sin esta separación, el compilador no puede distinguir si un override aplica a "todos los cajeros"
(rol) o a "Juan en particular" (usuario), lo que impide construir correctamente la jerarquía de
precedencia del algoritmo de resolución de conflictos.

---

## 2. Estado actual del código

### 2.1 `parser/ast.rs` — enum Subject (línea ~101)

```rust
// ESTADO ACTUAL
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind")]
pub enum Subject {
    #[serde(rename = "ROL")]
    Rol { role_id: String },

    #[serde(rename = "SET")]
    Set { set_id: String },

    #[serde(rename = "ANY")]
    Any,
}
```

### 2.2 `parser/ast.rs` — struct Target (línea ~89)

```rust
// ESTADO ACTUAL
pub struct Target {
    pub subject: Subject,
    pub resource: String,
    pub environment: Vec<AttributeRef>,
    /// Roles excluidos explícitamente de este nodo aunque pertenezcan al SET
    /// del subject. Prioridad sobre subject.set_id. R-D98-06/R-D98-07 (A.47 §3.2).
    #[serde(default)]
    pub unset: Vec<String>,
}
```

---

## 3. Extensión requerida

### 3.1 `parser/ast.rs` — enum Subject extendido

```rust
/// Sujeto de una política AtomLang — define a QUIÉN aplica el átomo.
///
/// Plano de rol (estructural — catálogo de roles del sistema):
///   ROL   → un rol específico por role_id
///   SET   → un conjunto de roles por set_id (definido en el catálogo)
///   ANY   → cualquier sujeto sin restricción (átomo general)
///
/// Plano de usuario (overrides individuales — personas concretas):
///   USER    → una persona específica por user_id (idn_identity_entity.id)
///   USERSET → un conjunto de usuarios por user_set_id
///
/// Jerarquía de precedencia (mayor → menor):
///   userunset > unset > USER > USERSET > SET > ROL > ANY
///
/// Regla: los kinds de usuario (USER, USERSET) SIEMPRE tienen mayor precedencia
/// que los kinds de rol (ROL, SET) para el mismo átomo normalizado.
/// Un USER puede revocar lo que su ROL otorga, y viceversa.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind")]
pub enum Subject {
    /// Aplica a un rol específico del catálogo.
    /// El role_id debe existir en idn_roles_template (tipo='dominio' o 'bloque').
    #[serde(rename = "ROL")]
    Rol { role_id: String },

    /// Aplica a todos los roles que pertenecen al set_id.
    /// El set_id es una clave de agrupación definida en el catálogo de roles.
    #[serde(rename = "SET")]
    Set { set_id: String },

    /// Aplica a cualquier sujeto sin restricción — átomo general del sistema.
    /// Es el piso base: cualquier sujeto más específico lo sobreescribe.
    #[serde(rename = "ANY")]
    Any,

    // ── EXTENSIÓN NUEVA ──────────────────────────────────────────────────────

    /// Override directo para un usuario específico (persona física o cuenta de servicio).
    /// user_id referencia idn_identity_entity.id — debe ser UUID válido.
    ///
    /// Este kind tiene mayor precedencia que cualquier kind de rol (ROL, SET)
    /// para el mismo átomo normalizado. Permite que Juan tenga PERMIT aunque
    /// su rol tenga DENY, o viceversa.
    ///
    /// Uso: cuando la excepción aplica a UNA persona, no a su rol.
    /// El override queda registrado en privilege_atom_grant con user_id = juan_id.
    #[serde(rename = "USER")]
    User { user_id: String },

    /// Override para un conjunto de usuarios (no de roles).
    /// user_set_id es una clave de agrupación de personas (ej: "equipo_auditoria_2026").
    ///
    /// Mayor precedencia que ROL y SET. Menor precedencia que USER directo.
    /// Permite overrides temporales o de proyecto sin tocar la estructura de roles.
    ///
    /// Los miembros del user_set se resuelven en idn_identity_entity en tiempo
    /// de compilación del árbol (no en runtime).
    #[serde(rename = "USERSET")]
    UserSet { user_set_id: String },
}
```

### 3.2 `parser/ast.rs` — struct Target extendido

```rust
/// Target XACML 3.0 §5.5 — define el alcance de un átomo: quién (subject),
/// sobre qué recurso (resource), en qué condiciones de entorno (environment).
///
/// unset y userunset son EXCLUSIONES, no efectos — no llevan effect propio.
/// Solo indican que ese rol/usuario queda fuera del SET/USERSET aunque
/// pertenezca a él por definición del set.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Target {
    /// A quién aplica este átomo (plano rol o plano usuario).
    pub subject: Subject,

    /// Identificador del recurso protegido.
    /// Para WS_RPC: "bauth.token.validate"
    /// Para JSON_RPC: "biedata.rpc/sale.create"
    /// Para GRPC: "/bauth.AuthService/Evaluate"
    /// Para UNIX_SOCKET: "/run/bos/bauth.sock#session.open"
    /// Para HTTP_EXT: "/api/v1/auth/login" (solo entrada externa)
    pub resource: String,

    /// Atributos de entorno que deben cumplirse para que el átomo aplique
    /// (hora, IP, dispositivo, etc. — evaluados por los dominios D04-D13).
    #[serde(default)]
    pub environment: Vec<AttributeRef>,

    /// Roles excluidos explícitamente del SET del subject, aunque pertenezcan
    /// a él por definición del set.
    ///
    /// Precedencia: unset > SET (R-D98-06/R-D98-07, A.47 §3.2).
    /// Solo válido cuando subject.kind == SET. El compilador emite
    /// ATOMC-E-062 si se usa con subject.kind != SET.
    #[serde(default)]
    pub unset: Vec<String>,

    // ── EXTENSIÓN NUEVA ──────────────────────────────────────────────────────

    /// Usuarios excluidos explícitamente del USERSET del subject, aunque
    /// pertenezcan a él por definición del user_set.
    ///
    /// Precedencia: userunset > USERSET > cualquier kind de rol.
    /// Solo válido cuando subject.kind == USERSET. El compilador emite
    /// ATOMC-E-063 si se usa con subject.kind != USERSET.
    ///
    /// Caso de uso: el equipo de auditoría tiene PERMIT para ver reportes
    /// financieros (USERSET), pero Juan está bajo investigación y queda
    /// explícitamente excluido (userunset: ["juan_id"]).
    #[serde(default)]
    pub userunset: Vec<String>,
}
```

### 3.3 `lexer/mod.rs` — struct RawTarget extendido

```rust
// En RawTarget agregar campo paralelo a unset:
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RawTarget {
    pub subject: RawSubject,
    pub resource: String,
    #[serde(default)]
    pub environment: Vec<RawAttributeRef>,
    #[serde(default)]
    pub unset: Vec<String>,

    // ── EXTENSIÓN NUEVA ──────────────────────────────────────────────────────
    /// Usuarios excluidos de USERSET. Paralelo a unset pero para plano usuario.
    /// Validado por ATOMC-E-063 (solo válido con subject.kind == USERSET).
    #[serde(default)]
    pub userunset: Vec<String>,
}
```

### 3.4 `lexer/mod.rs` — enum RawSubject extendido

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind")]
pub enum RawSubject {
    #[serde(rename = "ROL")]
    Rol { role_id: String },

    #[serde(rename = "SET")]
    Set { set_id: String },

    #[serde(rename = "ANY")]
    Any,

    // ── EXTENSIÓN NUEVA ──────────────────────────────────────────────────────
    #[serde(rename = "USER")]
    User { user_id: String },

    #[serde(rename = "USERSET")]
    UserSet { user_set_id: String },
}
```

---

## 4. Algoritmo de resolución de conflictos (normalización en dos pasos)

Este algoritmo es el que implementa el compilador AtomLang cuando encuentra dos o más átomos
con la misma clave normalizada (`atom_id` + `condition` sin sujeto ni efecto).

```
ENTRADA: lista de átomos con la misma clave normalizada (detectados en PASO 1)
SALIDA:  efecto final para el usuario_actual en este átomo

PASO 1 — Detección de equivalencia estructural
  Para cada átomo en la política:
    clave_normalizada = (atom_id + condition)   // sin subject, sin effect
    agrupar por clave_normalizada

  Para cada grupo con más de un átomo:
    → entrar al PASO 2 (hay potencial conflicto)

PASO 2 — Resolución por jerarquía de Subject
  Para el usuario_actual y sus roles:

  2.1 ¿usuario_actual está en userunset de algún átomo del grupo?
        SÍ → efecto = DENY (veto de exclusión usuario — máxima prioridad)
        NO → continuar

  2.2 ¿algún rol del usuario_actual está en unset de algún átomo del grupo?
        SÍ → ese rol queda excluido del SET de ese átomo
             (solo afecta al átomo con ese unset — continuar con el resto)

  2.3 ¿existe átomo con subject = USER { usuario_actual }?
        SÍ → efecto = effect de ese átomo (override directo de usuario)
             FIN (no seguir evaluando)
        NO → continuar

  2.4 ¿existe átomo con subject = USERSET que contenga a usuario_actual?
        SÍ → efecto = effect de ese átomo
             FIN
        NO → continuar

  2.5 ¿existe átomo con subject = SET que contenga algún rol del usuario?
        SÍ → efecto = effect de ese átomo (excluyendo roles en unset del §2.2)
             FIN
        NO → continuar

  2.6 ¿existe átomo con subject = ROL que coincida con algún rol del usuario?
        SÍ → efecto = effect de ese átomo
             FIN
        NO → continuar

  2.7 ¿existe átomo con subject = ANY?
        SÍ → efecto = effect de ese átomo (piso base general)
        NO → efecto = DENY (default cerrado — sin regla aplicable = denegado)

CASO ESPECIAL G-02a — colisión en el mismo nivel de Subject:
  Si en cualquier paso 2.3-2.7 hay DOS átomos con el mismo Subject kind
  para el mismo sujeto y efectos contradictorios:
    → emitir ATOMC-E-CON-001: "átomo duplicado con efectos contradictorios"
    → compilación FALLA
    → el árbol visual muestra los dos nodos adyacentes para revisión del operador
```

---

## 5. Nuevos códigos de error del compilador

| Código | Severidad | Condición | Mensaje |
|--------|-----------|-----------|---------|
| `ATOMC-E-063` | ERROR | `userunset` usado con `subject.kind != USERSET` | "`userunset` solo es válido cuando el sujeto es USERSET" |
| `ATOMC-E-064` | ERROR | `USER.user_id` no existe en `idn_identity_entity` | "user_id '{id}' no encontrado en el catálogo de identidades" |
| `ATOMC-E-065` | ERROR | `USERSET.user_set_id` no definido en el catálogo | "user_set_id '{id}' no encontrado en el catálogo de conjuntos de usuarios" |
| `ATOMC-E-CON-001` | ERROR | Dos átomos con mismo Subject kind y sujeto, efectos opuestos | "Átomo '{atom_id}' tiene efectos contradictorios para el mismo sujeto '{sujeto}': {SI} vs {NO}" |
| `ATOMC-W-033` | WARNING | `USER` override revierte el efecto de su propio rol | "El override USER '{user_id}' contradice el efecto de su rol '{role_id}' para '{atom_id}' — confirmar intención" |

---

## 6. Ejemplo YAML completo — antes y después

### Antes (solo ROL/SET/ANY)

```yaml
# Solo se podía bloquear/permitir a nivel de rol
atoms:
  - atom_id: tryton.ventas.pagar
    verb_id: ejecutar
    target:
      subject:
        kind: SET
        set_id: cajeros
      resource: tryton/sale/payment
      unset:
        - rol_cajero_suspendido
    condition:
      property_id: monto
      operator: lt
      value: 1000
    effect:
      decision: Permit
```

### Después (con USER/USERSET/userunset)

```yaml
# Regla base para el set de cajeros
- atom_id: tryton.ventas.pagar
  verb_id: ejecutar
  target:
    subject:
      kind: SET
      set_id: cajeros
    resource: tryton/sale/payment
    unset:
      - rol_cajero_suspendido   # roles excluidos del set
  condition:
    property_id: monto
    operator: lt
    value: 1000
  effect:
    decision: Permit

# Override individual: Juan tiene Deny aunque sea cajero
- atom_id: tryton.ventas.pagar
  verb_id: ejecutar
  target:
    subject:
      kind: USER
      user_id: "018f2a3b-1c4d-7e5f-8a9b-0c1d2e3f4a5b"  # UUID de Juan
    resource: tryton/sale/payment
  condition:
    property_id: monto
    operator: lt
    value: 1000
  effect:
    decision: Deny

# Override para un grupo de usuarios especiales (equipo auditoría)
- atom_id: tryton.ventas.pagar
  verb_id: ejecutar
  target:
    subject:
      kind: USERSET
      user_set_id: equipo_auditoria_2026
    resource: tryton/sale/payment
    userunset:
      - "018f2a3b-dead-beef-0000-000000000001"  # María excluida del equipo auditoría
  condition:
    property_id: monto
    operator: lt
    value: 1000
  effect:
    decision: Permit
```

---

## 7. Archivos a modificar en el compilador

| Archivo | Cambio | Prioridad |
|---------|--------|-----------|
| `src/parser/ast.rs` | Agregar variants `User` y `UserSet` a `Subject` | ALTA |
| `src/parser/ast.rs` | Agregar campo `userunset: Vec<String>` a `Target` | ALTA |
| `src/lexer/mod.rs` | Agregar variants `User` y `UserSet` a `RawSubject` | ALTA |
| `src/lexer/mod.rs` | Agregar campo `userunset: Vec<String>` a `RawTarget` | ALTA |
| `src/lexer/mod.rs` | Agregar validación ATOMC-E-063/064/065 | ALTA |
| `src/parser/mod.rs` | Agregar lowering de `RawSubject::User/UserSet` a `Subject::User/UserSet` | ALTA |
| `src/diagnostics/codes.rs` | Agregar E-063, E-064, E-065, E-CON-001, W-033 | ALTA |
| `src/parser/mod.rs` | Implementar algoritmo de resolución §4 (paso 2.1-2.7) | ALTA |

---

## 8. Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-20 | Creación. Especificación completa de la extensión USER/USERSET/userunset para AtomLang. Surge del cierre del gap G-02 (cadena de precedencia DENY) en GAPS-DDL-PRIVILEGIOS.md. Documenta el estado actual del código, los cambios requeridos en los 4 archivos Rust, el algoritmo de resolución en dos pasos, 5 nuevos códigos de error, y ejemplo YAML completo. |
