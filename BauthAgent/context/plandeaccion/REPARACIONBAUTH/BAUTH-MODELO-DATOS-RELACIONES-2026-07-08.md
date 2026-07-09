# BAUTH-MODELO-DATOS-RELACIONES-2026-07-08.md

**Versión:** 1.0 · **Fecha:** 2026-07-08
**Propósito:** Documentar el modelo de datos completo de bAuth — entidades, relaciones,
diferencias, compatibilidades, y el concepto METHOD_BUNDLE que emerge de la sesión
de diseño del demo `rol-template-builder.html`.
Esta documentación sirve de referencia para el diseño de DDL y para retomar
el contexto en sesiones futuras.

---

## 1. VISIÓN GENERAL — QUÉ ADMINISTRA bAuth

bAuth administra **identidades y privilegios** sobre un modelo de **12 dominios**:

```
D1 Lógico · D2 Físico · D3 Financiero · D4 Temporal · D5 Biométrico · D6 Geoespacial
D7 Red · D8 Contexto · D9 Credenciales · D10 Delegación · D11 Auditoría · D12 Blockchain
```

Cada dominio es una **dimensión de control de acceso independiente** pero relacionada.
El mismo actor (usuario o rol) puede tener privilegios distintos en cada dominio,
con métodos de autenticación, políticas y atributos específicos por dominio.

---

## 2. LAS CINCO ENTIDADES CENTRALES

### 2.1 `privilege_atom` — Átomo de privilegio

**Qué es:** La unidad mínima indivisible de permiso. Representa una acción concreta
sobre un módulo de una aplicación del ecosistema SBOS.

**Estructura canónica:**
```
App → Módulo → Grupo → Verbo
slug: {app}.g{group_code}.d{domain_code}.{verbo_slug}
```

**Campos clave:**
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | TEXT PK | Identificador demo (at1, at5809…) |
| `app` | TEXT | Aplicación (Tryton, Keycloak, Kong, Vault, bHnexus, Besu…) |
| `mod` | TEXT | Módulo dentro de la app |
| `grp` | TEXT | Grupo funcional dentro del módulo |
| `vrb` | TEXT | Verbo de acción (create, read, update, delete, ejecutar, firmar…) |
| `slug` | TEXT UNIQUE | Slug canónico — fuente de verdad |
| `pos` | INTEGER | Posición en la tabla VPS (1–5808 existentes, 5809+ demo) |
| `dc` | INTEGER | Domain code (1–12) — **un átomo pertenece a UN solo dominio** |

**Regla crítica:** `dc` es fijo. Un átomo de D2 NUNCA puede asignarse a D1.
El slug codifica el dominio: `.d2.` en el slug confirma `dc=2`.

**Cobertura actual en VPS:** 5808 átomos, casi todos `dc=1` (Lógico).
Posiciones 5809+ reservadas para nuevos dominios.

---

### 2.2 `cfg_policy_library` — Biblioteca de políticas

**Qué es:** Árbol jerárquico de configuraciones de comportamiento del sistema.
Define el QUÉ y CÓMO de la autenticación y el control de acceso.

**Jerarquía (ltree en PostgreSQL):**
```
FRAMEWORK → DOMAIN → POLICY_SET → POLICY → RULE → PROPERTY
```

**Campos clave:**
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | TEXT PK | Identificador único |
| `lt` | ENUM | Nivel: FRAMEWORK, DOMAIN, POLICY_SET, POLICY, RULE, PROPERTY |
| `path` | LTREE | Ruta jerárquica completa |
| `name` | TEXT | Nombre del nodo |
| `dm` | TEXT[] | **Array de dominios** — una política puede pertenecer a N dominios |
| `vt` | TEXT | Value type: TEXT, BOOLEAN, INTEGER, FLOAT, ENUM |
| `def` | TEXT | Valor por defecto |
| `std` | TEXT | Estándar de referencia (NIST, PCI DSS, etc.) |

**Diferencia clave con `privilege_atom`:**
Una política puede pertenecer a **múltiples dominios** (`dm = ['D1', 'D9']`).
Un átomo pertenece a **exactamente un dominio** (`dc = 1`).

**Solo los nodos hoja con `vt` son asignables** al rol/usuario
(POLICY, RULE, PROPERTY que tengan tipo de valor).

---

### 2.3 `AUTH_METHODS` — Catálogo de métodos de autenticación

**Qué es:** Los 22 métodos de autenticación que bAuth puede orquestar.
No son tablas de asignación — son el **catálogo de lo posible**.

**Campos clave:**
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | TEXT PK | Identificador (am1…am22) |
| `name` | TEXT | Nombre del método |
| `code` | TEXT | Código técnico (password, totp, webauthn-pw…) |
| `aal` | ENUM | AAL1, AAL2, AAL3 — nivel de garantía |
| `mfa` | BOOLEAN | Si es factor múltiple por naturaleza |
| `cat` | TEXT | Familia técnica (knowledge, possession, inherence…) |
| `domains` | INTEGER[] | **Dominios donde el método es aplicable** |
| `std` | TEXT | Estándar que lo define |

**Diferencia con las otras entidades:**
`domains[]` es una clasificación de **aplicabilidad técnica** (basada en estándares
internacionales — NIST, FIDO, ISO), no una asignación. Es el catálogo de qué
métodos PUEDE usar cada dominio según los estándares.

---

### 2.4 `idn_tipo_atributo` / `ATTRS` — Atributos de identidad

**Qué es:** Vocabulario controlado de tipos de atributos que puede tener un actor.
Define el QUÉ del perfil de identidad.

**Campos clave:**
| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | TEXT PK | Identificador (a1001, a2102…) |
| `code` | INTEGER | Código numérico canónico |
| `cat` | TEXT | Categoría (personal, contacto, documento, ubicacion, financiero…) |
| `sub` | TEXT | Subcategoría (nombres, emails, identidad, bancario…) |
| `name` | TEXT | Nombre técnico del atributo |
| `nom` | TEXT | Nombre legible en español |
| `fmt` | TEXT | Formato (TEXT, EMAIL, E164, IBAN, DATE_ISO, COUNTRY_CODE…) |
| `dc` | INTEGER | Dominio primario donde el atributo es relevante |

**Diferencia con las demás entidades:**
Un atributo tiene un dominio primario (`dc`) pero puede ser relevante en múltiples
contextos. A diferencia del átomo, el atributo describe **QUIÉN ES** el actor,
no **QUÉ PUEDE HACER**.

---

### 2.5 `bos_rol_template` / `bos_user_template` — Templates de rol y usuario

**Qué son:** Las tablas de **asignación dinámica** — la instancia concreta de
privilegios de un rol o usuario específico.

**Estructura interna (JSONB por dominio):**
```json
{
  "d": {
    "1": {
      "pols":  { "p1-ct": "password,passkey", "pr9-aal": "AAL2" },
      "meths": {
        "assigned":    ["am1", "am2"],
        "required":    ["am2"],
        "alternative": ["am12"]
      },
      "attrs": ["a1001", "a2102", "a2106"],
      "atoms": { "at4": {"p": true}, "at1214": {"p": false} }
    },
    "9": { ... }
  }
}
```

**Diferencia rol vs usuario:**
- `bos_rol_template`: define el template base — **la norma**
- `bos_user_template`: tiene dos capas:
  - `locked`: heredado del rol (solo lectura para el usuario)
  - `extra`: configuración específica del usuario (puede añadir, no quitar lo locked)

---

## 3. TABLA DE DIFERENCIAS Y COMPATIBILIDADES

| Entidad | Pertenece a dominio | Multi-dominio | Es catálogo | Es asignación | Puede eliminarse |
|---------|--------------------|--------------|-----------|--------------------|--------------|
| `privilege_atom` | **1 dominio fijo** (`dc`) | No | Sí (catálogo) | No | No (1-5808 intocables) |
| `cfg_policy_library` | N dominios (`dm[]`) | **Sí** | Sí (catálogo) | No | No |
| `AUTH_METHODS` | N dominios (`domains[]`) | **Sí** | Sí (catálogo) | No | No |
| `idn_tipo_atributo` | 1 dominio primario (`dc`) | Contextual | Sí (catálogo) | No | No |
| `bos_rol_template.d[N].atoms` | 1 dominio (el N) | No | No | **Sí** | Sí |
| `bos_rol_template.d[N].pols` | 1 dominio (el N) | No | No | **Sí** | Sí |
| `bos_rol_template.d[N].meths` | 1 dominio (el N) | No | No | **Sí** | Sí |
| `bos_rol_template.d[N].attrs` | 1 dominio (el N) | No | No | **Sí** | Sí |

**Compatibilidad de asignación:**
- Un átomo `dc=2` solo puede asignarse al dominio D2 del template
- Una política `dm=['D1','D9']` puede asignarse a D1 o a D9 del template
- Un método `domains=[1,3,9]` solo aparece en el pool cuando el dominio activo es 1, 3 o 9
- Un atributo `dc=6` aparece en el pool cuando el dominio activo es D6

---

## 4. EL FLUJO DE ASIGNACIÓN DE MÉTODOS — 3 NIVELES

Este es el flujo central de la UI de administración:

```
CATÁLOGO (pool lateral)
    │
    │  [+] Agregar        → sin efecto en políticas/atributos/átomos
    ▼
ASIGNADOS (d[N].meths.assigned)
    │                │
    │ [→Req]         │ [→Alt]
    ▼                ▼
REQUERIDOS      ALTERNATIVOS
(d[N].meths     (d[N].meths
 .required)      .alternative)
    │                │
    └──────┬─────────┘
           │  DISPARA METHOD_BUNDLE
           ▼
    Auto-agrega al rol en dominio N:
    · políticas del bundle  → d[N].pols
    · atributos del bundle  → d[N].attrs
    · átomos del bundle     → d[N].atoms
```

**Regla de exclusividad:** Un mismo método NO puede estar simultáneamente
en `required` y `alternative`. Si está en uno, primero debe retirarse.

**Regla de reversión:** Cuando se quita un método de `required` o `alternative`,
vuelve a `assigned` (no al pool). Los ítems del bundle que se auto-agregaron
NO se revierten automáticamente (pueden haberse modificado por el administrador).

---

## 5. EL CONCEPTO METHOD_BUNDLE — RELACIÓN CENTRAL

### 5.1 Definición

Un **Method Bundle** es la definición estática de qué políticas, atributos y átomos
son **técnicamente necesarios** para que un método de autenticación funcione
en un dominio específico, según los estándares internacionales.

**Relación:** `(method_id × domain_code) → { N políticas, N atributos, N átomos }`

```
am2 (TOTP) × D1 (Lógico) → {
  políticas:  [pr4-td (drift TOTP), pr9-aal (AAL mínimo), r9-mfar (MFA requerido)]
  atributos:  [a2102 (email trabajo), a2106 (email recuperación)]
  átomos:     [at1453 (crear usuario KC), at1463 (ejecutar en KC)]
}
```

### 5.2 Justificación por estándares

Cada ítem del bundle viene de un requerimiento de estándar:

| Componente del bundle | Fuente del requerimiento |
|----------------------|--------------------------|
| Atributo `email_recuperacion` para Password | NIST 800-63B §5.1.1 — recovery channel |
| Política `drift_steps` para TOTP | RFC 6238 §5.2 — time drift tolerance |
| Política `two_factor_required` para TOTP en D3 | PCI DSS 4.0 §8.4 |
| Atributo `biometric_template` para Biométrico | ISO/IEC 30107-3 — enrollment |
| Átomo `registrar` para WebAuthn | Keycloak Required Actions — enrollment |
| Política `ley164_compliance` para EdDSA en D12 | Bolivia Ley 164 Art.13 |
| Atributo `public_key` para ECDSA | ANSI X9.62 — key enrollment |

### 5.3 Estructura de la tabla DDL propuesta

```sql
-- Catálogo estático de bundles por (método × dominio)
CREATE TABLE bauth_method_bundle (
  method_code     VARCHAR(50)  NOT NULL,  -- am1, am2, etc.
  domain_code     SMALLINT     NOT NULL,  -- 1-12
  required_pols   TEXT[]       NOT NULL DEFAULT '{}',  -- IDs de cfg_policy_library
  required_attrs  TEXT[]       NOT NULL DEFAULT '{}',  -- códigos de idn_tipo_atributo
  required_atoms  TEXT[]       NOT NULL DEFAULT '{}',  -- slugs de privilege_atom
  std_justif      TEXT,                   -- justificación normativa
  PRIMARY KEY (method_code, domain_code)
);
```

**HITL requerido antes de ejecutar este DDL en VPS.**

### 5.4 Diferencia entre bundle y asignación directa

| | Bundle (catálogo) | Asignación directa |
|--|-------------------|--------------------|
| **Quién lo define** | bAuth (diseño del sistema) | El administrador en la UI |
| **Cuándo se aplica** | Al promover a Req/Alt | Manualmente en cualquier momento |
| **Es obligatorio** | Sí (prerrequisito técnico) | No (opcional, adicional) |
| **Se puede sobrescribir** | Sí (el admin puede modificar después) | — |
| **Se revierte al quitar** | No (por diseño — el admin decidió) | Sí si el admin lo quita |

---

## 6. FLUJO COMPLETO DE DATOS AL ACTIVAR UN MÉTODO

**Escenario:** Administrador promueve `am2 (TOTP)` a `Requerido` en `D1 Lógico`

```
1. promoteToReq(dc=1, id='am2')

2. Mover am2: assigned → required en RT.d[1].meths

3. Consultar METHOD_BUNDLES['am2:1']:
   pols  = ['pr4-td', 'pr9-aal', 'r9-mfar']
   attrs = ['a2102', 'a2106']
   atoms = ['at1453', 'at1463']

4. Auto-agregar políticas (con su valor por defecto):
   RT.d[1].pols['pr4-td']  = '1'        (drift: 1 step)
   RT.d[1].pols['pr9-aal'] = 'AAL2'     (mínimo AAL2)
   RT.d[1].pols['r9-mfar'] = 'true'     (MFA requerido)

5. Auto-agregar atributos (si no están ya):
   RT.d[1].attrs → añadir 'a2102', 'a2106'

6. Auto-agregar átomos (si no están ya):
   RT.d[1].atoms['at1453'] = {p: true}
   RT.d[1].atoms['at1463'] = {p: true}

7. refresh() — re-renderizar el árbol de dominios

8. Mostrar notificación al admin:
   "TOTP activado en D1. Se agregaron automáticamente:
    · 3 políticas (NIST 800-63B, RFC 6238)
    · 2 atributos (email trabajo, email recuperación)
    · 2 átomos (Keycloak: crear usuario, ejecutar)"
```

---

## 7. RELACIONES ENTRE ENTIDADES — DIAGRAMA CONCEPTUAL

```
                    ┌─────────────────────────┐
                    │    cfg_policy_library    │
                    │  dm: ['D1','D9','D11']   │
                    │  (N dominios por nodo)   │
                    └───────────┬─────────────┘
                                │ asigna a
                    ┌───────────▼─────────────┐
                    │   bos_rol_template       │
                    │   d[N].pols              │◄──── método activo (Req/Alt)
                    │   d[N].meths             │      dispara METHOD_BUNDLE
                    │   d[N].attrs             │◄──── método activo (Req/Alt)
                    │   d[N].atoms             │◄──── método activo (Req/Alt)
                    └──────────────────────────┘
                         ▲           ▲
              asigna a   │           │  asigna a
┌─────────────────────┐  │           │  ┌─────────────────────┐
│   privilege_atom    │  │           │  │  idn_tipo_atributo  │
│   dc: 1 (un solo)   │  │           │  │  dc: dominio primario│
│   5808 en VPS       │  │           │  │  fmt: EMAIL, E164…   │
└─────────────────────┘  │           │  └─────────────────────┘
                         │           │
┌─────────────────────┐  │           │
│    AUTH_METHODS     │──┘           │
│  domains: [1,3,9]   │  ──────────►│  METHOD_BUNDLE
│  22 métodos         │    (method × domain) → {pols, attrs, atoms}
└─────────────────────┘
```

---

## 8. CATÁLOGO METHOD_BUNDLES — REFERENCIA COMPLETA (demo)

Formato: `'methodId:domainCode'` → `{ pols[], attrs[], atoms[] }`

Las claves de este catálogo corresponden a IDs reales del demo
(`rol-template-builder.html`) y serán la base para el DDL de
`bauth_method_bundle` en la VPS.

### am1 — Password / Memorized Secret
```
am1:1 (D1 Lógico)      pols:[p1-ct, r9-req, pr9-au, pr9-rn]  attrs:[a2102, a2106]  atoms:[at1453, at1454]
am1:3 (D3 Financiero)  pols:[r3-2fa, pr3-t]                   attrs:[a7001, a7005]  atoms:[at5815, at5816]
am1:7 (D7 Red)         pols:[p2-es, r9-mfar]                  attrs:[a2102]         atoms:[at1816, at1817]
am1:8 (D8 Contexto)    pols:[p8-ea, p8-sc]                    attrs:[a2101]         atoms:[at5843, at5844]
```

### am2 — TOTP (RFC 6238)
```
am2:1 (D1 Lógico)      pols:[pr4-td, pr9-aal, r9-mfar]        attrs:[a2102, a2106]  atoms:[at1453, at1463]
am2:3 (D3 Financiero)  pols:[r3-2fa, pr4-td]                   attrs:[a2101, a7001]  atoms:[at5815, at5817]
am2:4 (D4 Temporal)    pols:[pr4-t2, pr4-td]                   attrs:[a9002]         atoms:[at5821, at5822]
am2:7 (D7 Red)         pols:[p2-es, pr4-td]                    attrs:[a2001]         atoms:[at5837, at5838]
am2:8 (D8 Contexto)    pols:[p8-ea, pr4-td]                    attrs:[a2101]         atoms:[at5843, at5845]
```

### am3 — HOTP (RFC 4226)
```
am3:1 (D1 Lógico)      pols:[r9-mfar, pr9-aal]                attrs:[a2102]         atoms:[at1453, at1463]
am3:3 (D3 Financiero)  pols:[r3-2fa]                           attrs:[a7001]         atoms:[at5815, at5817]
am3:4 (D4 Temporal)    pols:[pr4-t2]                           attrs:[a9002]         atoms:[at5821]
```

### am4 — WebAuthn Passwordless
```
am4:1 (D1 Lógico)      pols:[p1-ct, pr9-aal]                  attrs:[a2102, a6002]  atoms:[at1453, at1211]
am4:3 (D3 Financiero)  pols:[r3-2fa]                           attrs:[a7001]         atoms:[at5815]
am4:5 (D5 Biométrico)  pols:[r9-req]                           attrs:[a1101, a1102]  atoms:[at5828, at5829]
am4:6 (D6 Geoespacial) pols:[p2-es]                            attrs:[a4001, a4002]  atoms:[at5834, at5835]
am4:7 (D7 Red)         pols:[p2-es, pr9-aal]                   attrs:[a2102]         atoms:[at1816, at1819]
am4:9 (D9 Credenciales)pols:[r9-req, pr9-aal]                  attrs:[a3001]         atoms:[at2421, at2424]
```

### am5 — WebAuthn 2FA
```
am5:1 (D1 Lógico)      pols:[p1-ct, r9-mfar, pr9-aal]         attrs:[a2102, a6002]  atoms:[at1453, at1211]
am5:3 (D3 Financiero)  pols:[r3-2fa]                           attrs:[a7001]         atoms:[at5815]
am5:5 (D5 Biométrico)  pols:[r9-req]                           attrs:[a1101, a1102]  atoms:[at5828, at5829]
am5:6 (D6 Geoespacial) pols:[p2-es]                            attrs:[a4001, a4002]  atoms:[at5834, at5835]
am5:9 (D9 Credenciales)pols:[r9-req, r9-mfar]                  attrs:[a3001]         atoms:[at2421, at2424]
```

### am6 — Passkey (FIDO2 sincronizable)
```
am6:1 (D1 Lógico)      pols:[p1-ct, pr9-aal]                  attrs:[a2102, a6002]  atoms:[at1453, at1211]
am6:2 (D2 Físico)      pols:[p2-es]                            attrs:[a4001, a4010]  atoms:[at5809, at5811]
am6:5 (D5 Biométrico)  pols:[r9-req]                           attrs:[a1101, a1102]  atoms:[at5828, at5829]
am6:6 (D6 Geoespacial) pols:[p2-es]                            attrs:[a4001, a4002]  atoms:[at5834, at5835]
am6:9 (D9 Credenciales)pols:[r9-req, pr9-aal]                  attrs:[a3001]         atoms:[at2421, at2424]
```

### am7 — X.509 mTLS / PIV / CAC
```
am7:1  (D1 Lógico)      pols:[p1-ct, pr9-aal, r9-req]          attrs:[a3001,a2102,a6002] atoms:[at2424,at2421,at1211]
am7:2  (D2 Físico)      pols:[p2-es, r9-req]                   attrs:[a3001, a4001]  atoms:[at5809, at5812]
am7:3  (D3 Financiero)  pols:[r3-2fa, r3-fd]                   attrs:[a3001, a7001]  atoms:[at5815, at5816]
am7:6  (D6 Geoespacial) pols:[p2-es]                            attrs:[a4001, a1105]  atoms:[at5834, at5835]
am7:9  (D9 Credenciales)pols:[r9-req, pr9-aal]                  attrs:[a3001, a3101]  atoms:[at2421, at2424]
am7:11 (D11 Auditoría)  pols:[p11-ae]                           attrs:[a3001]         atoms:[at5853, at5854]
am7:12 (D12 Blockchain) pols:[r12-le, p12-vp]                  attrs:[a3001, a3101]  atoms:[at5858, at5860]
```

### am8 — Smart Card / NFC (PACS)
```
am8:2 (D2 Físico)      pols:[p2-es, r9-req]                   attrs:[a4001, a4010]  atoms:[at5809,at5811,at5812]
am8:7 (D7 Red)         pols:[p2-es]                            attrs:[a4001]         atoms:[at5837, at5840]
am8:9 (D9 Credenciales)pols:[r9-req]                           attrs:[a3001]         atoms:[at2421, at2424]
```

### am9 — Kerberos
```
am9:1 (D1 Lógico)      pols:[p1-ct, pr9-aal]                  attrs:[a2102,a6001,a6002] atoms:[at1211, at1332]
am9:7 (D7 Red)         pols:[p2-es]                            attrs:[a6001]         atoms:[at5837, at5840]
```

### am10 — SAML 2.0
```
am10:1  (D1 Lógico)     pols:[p1-fi, p1-lm]                   attrs:[a2102,a6001,a6002] atoms:[at1332, at1453]
am10:10 (D10 Delegación)pols:[r10-exc]                         attrs:[a6002, a6001]  atoms:[at5848, at5849]
am10:11 (D11 Auditoría) pols:[p11-ae]                          attrs:[a2102]         atoms:[at5855, at5856]
```

### am11 — Social Brokering
```
am11:1 (D1 Lógico)     pols:[p1-fi, p1-ct]                    attrs:[a2101,a1001,a1004] atoms:[at1453, at1456]
```

### am12 — CIBA (Backchannel Auth)
```
am12:1 (D1 Lógico)      pols:[r9-mfar, pr9-aal]               attrs:[a2001, a2101]  atoms:[at1453, at5843]
am12:3 (D3 Financiero)  pols:[r3-2fa]                          attrs:[a7001, a2001]  atoms:[at5815, at5816]
am12:6 (D6 Geoespacial) pols:[p2-es]                           attrs:[a4001, a2001]  atoms:[at5835, at5836]
am12:8 (D8 Contexto)    pols:[p8-ea, p8-sc]                   attrs:[a2001]         atoms:[at5843, at5845]
```

### am13 — Conditional OTP / Step-Up
```
am13:1 (D1 Lógico)      pols:[r9-mfar, pr9-aal, pr4-t2]       attrs:[a2001, a2102]  atoms:[at5843, at5847]
am13:4 (D4 Temporal)    pols:[pr4-t2, pr4-td]                  attrs:[a9002]         atoms:[at5821, at5822]
am13:6 (D6 Geoespacial) pols:[p2-es]                           attrs:[a4001, a4002]  atoms:[at5835, at5836]
am13:7 (D7 Red)         pols:[p2-es]                           attrs:[a2001]         atoms:[at5837, at5838]
am13:8 (D8 Contexto)    pols:[p8-ea]                           attrs:[a2001]         atoms:[at5843, at5844]
```

### am14 — Device Authorization (RFC 8628)
```
am14:1 (D1 Lógico)      pols:[pr9-aal, p1-ct]                 attrs:[a2102, a6001]  atoms:[at1332, at1456]
am14:4 (D4 Temporal)    pols:[pr4-t1, pr4-t2]                 attrs:[a9002]         atoms:[at5821, at5822]
am14:6 (D6 Geoespacial) pols:[p2-es]                          attrs:[a4001]         atoms:[at5834]
am14:7 (D7 Red)         pols:[p2-es]                          attrs:[a6001]         atoms:[at5837, at5840]
am14:8 (D8 Contexto)    pols:[p8-ea]                          attrs:[a2001]         atoms:[at5843, at5845]
```

### am15 — Recovery Codes
```
am15:1 (D1 Lógico)      pols:[p1-ct, r9-req]                  attrs:[a2106, a2102]  atoms:[at1453, at1456]
am15:9 (D9 Credenciales)pols:[r9-req]                          attrs:[a2106, a3001]  atoms:[at2424]
```

### am16 — Email OTP
```
am16:1 (D1 Lógico)      pols:[p1-ct]                          attrs:[a2101, a2106]  atoms:[at1453, at1456]
am16:8 (D8 Contexto)    pols:[p8-ea]                          attrs:[a2101]         atoms:[at5843, at5845]
```

### am17 — Client Credentials (M2M)
```
am17:1  (D1 Lógico)      pols:[p1-ct, pr9-aal]                attrs:[a6001, a6002]  atoms:[at1332, at1342]
am17:3  (D3 Financiero)  pols:[r3-2fa]                         attrs:[a7001]         atoms:[at5815, at5817]
am17:6  (D6 Geoespacial) pols:[p2-es]                          attrs:[a6001]         atoms:[at5835, at5836]
am17:9  (D9 Credenciales)pols:[r9-req]                         attrs:[a3001, a3101]  atoms:[at2300, at2303]
am17:12 (D12 Blockchain) pols:[r12-le]                         attrs:[a3101]         atoms:[at5858, at5862]
```

### am18 — Token Exchange
```
am18:1  (D1 Lógico)      pols:[p1-lm, pr9-aal]                attrs:[a6001, a6002]  atoms:[at1332, at1342]
am18:4  (D4 Temporal)    pols:[pr4-t2]                         attrs:[a9002]         atoms:[at5821, at5822]
am18:8  (D8 Contexto)    pols:[p8-sc]                          attrs:[a2101]         atoms:[at5843, at5847]
am18:10 (D10 Delegación) pols:[r10-exc]                        attrs:[a6002]         atoms:[at5848, at5849]
am18:11 (D11 Auditoría)  pols:[p11-ae]                         attrs:[a2102]         atoms:[at5853, at5855]
```

### am19 — Biométrico Lector (huella/iris/rostro)
```
am19:2 (D2 Físico)      pols:[p2-es, r9-req]                  attrs:[a1101,a1102,a4010] atoms:[at5809, at5812]
am19:5 (D5 Biométrico)  pols:[r9-req]                          attrs:[a1101, a1102]  atoms:[at5826,at5827,at5829]
```

### am20 — ECDSA secp256k1 (Blockchain)
```
am20:9  (D9 Credenciales)pols:[r9-req, pr9-aal]                attrs:[a3001, a3101]  atoms:[at2300,at2301,at2424]
am20:11 (D11 Auditoría)  pols:[p11-ae, p12-vp]                attrs:[a3101]         atoms:[at5853, at5854]
am20:12 (D12 Blockchain) pols:[r12-le, p12-ea]                attrs:[a3101]         atoms:[at5858,at5860,at5861]
```

### am21 — EdDSA Ed25519 (Vault / ADSIB)
```
am21:9  (D9 Credenciales)pols:[r9-req, pr9-aal]                attrs:[a3001, a3101]  atoms:[at2300,at2421,at2424]
am21:11 (D11 Auditoría)  pols:[p11-ae]                         attrs:[a3101]         atoms:[at5853, at5854]
am21:12 (D12 Blockchain) pols:[r12-le, p12-ea]                attrs:[a3101]         atoms:[at5858, at5860]
```

### am22 — Geolocation Auth (GPS / IP / Wi-Fi)
```
am22:1 (D1 Lógico)      pols:[p1-ct, pr9-aal]                 attrs:[a4001,a4002,a1105] atoms:[at5843, at5845]
am22:6 (D6 Geoespacial) pols:[p2-es]                          attrs:[a4001,a4002,a1105] atoms:[at5831,at5834,at5835]
am22:8 (D8 Contexto)    pols:[p8-ea]                          attrs:[a4001]         atoms:[at5843, at5844]
```

---

## 9. CREDENCIALES vs ATRIBUTOS DE IDENTIDAD — DISTINCIÓN CRÍTICA PARA POBLAR LA BD

### 9.1 El error conceptual que hay que evitar (ilustrado con Password)

Durante el diseño del demo surgió la pregunta: "¿deberían `password` y `confirmpassword`
ser atributos de identidad en `idn_tipo_atributo`?". La respuesta es **NO**, y esto
aplica como principio a todo el modelo de METHOD_BUNDLES.

**La distinción fundamental** (fuente: ICAM Canadian Centre for Cyber Security, NIST 800-63B-4):

```
IDENTIDAD  = descripción durable del actor en el sistema
             → nombre, CI, cargo, email, país, fecha nacimiento
             → se almacena en idn_tipo_atributo / idn_atributo

CREDENCIAL = evidencia presentada CADA VEZ que el actor actúa
             → password hash, OTP seed, clave pública, template biométrico
             → se almacena en tabla de credenciales SEPARADA (ej. credential en Keycloak)
```

`password` y `confirmpassword` son **campos de formulario efímeros** — no son atributos
persistentes del perfil de identidad. El hash Argon2id que se almacena NO es un atributo
recuperable; es un secreto unidireccional en la tabla de credenciales.

Microsoft Defender for Identity cataloga como **vulnerabilidad de seguridad** cuando
credenciales se almacenan en atributos de usuario.

Keycloak confirma esta separación arquitectónica: configurar atributos de usuario y
configurar passwords son comandos sobre **APIs completamente separadas**
(`/users/{id}/attributes` vs `/users/{id}/credentials`).

---

### 9.2 La regla general para todos los métodos de autenticación

Al diseñar el bundle de cualquier método, aplicar el siguiente criterio:

| Tipo de dato | ¿Va en `idn_tipo_atributo`? | ¿Va en tabla de credenciales? | ¿Va en `cfg_policy_library`? |
|---|---|---|---|
| Hash de contraseña | ❌ NUNCA | ✅ Sí (credential store) | — |
| Seed TOTP | ❌ NUNCA | ✅ Sí (credential store) | — |
| Template biométrico | ❌ NUNCA | ✅ Sí (biometric store) | — |
| Clave pública Ed25519 / ECDSA | ❌ NUNCA | ✅ Sí (PKI / Vault) | — |
| Email del actor | ✅ Sí (atributo de contacto) | — | — |
| Email de recuperación | ✅ Sí (atributo D9) | — | — |
| CI / NIT / Pasaporte | ✅ Sí (atributo de documento) | — | — |
| País / Ciudad | ✅ Sí (atributo de ubicación D6) | — | — |
| Complejidad mínima de password | — | — | ✅ Sí (policy) |
| Timeout de sesión | — | — | ✅ Sí (policy) |
| MFA requerido | — | — | ✅ Sí (policy) |

**Pregunta diagnóstico:** "¿Este dato sigue siendo verdad aunque el actor cambie su contraseña?"
- Si **SÍ** → es un atributo de identidad (`idn_tipo_atributo`)
- Si **NO** → es una credencial o un valor efímero, NO va en atributos

---

### 9.3 Lo que SÍ corresponde al bundle de Password en D1 (ejemplo corregido)

| Componente | Qué agregar | Por qué |
|---|---|---|
| **Políticas** | `p1-ct` (credential_types), `r9-req` (blocklist screening), `pr9-au` (allow_unicode), `pr9-rn` (require_numeric) | NIST 800-63B-4 §5.1.1 — control del verificador |
| **Atributos** | `a2106` (email_recuperacion), `a2101` (email_personal) | Canal de reset — NIST 800-63B-4 exige tener definido el canal de recuperación |
| **Átomos** | `keycloak.credentials.create`, `keycloak.credentials.update`, `keycloak.credentials.read` | Permisos para operar el **módulo de credenciales** de Keycloak — NO sobre un "atributo password" |

Los átomos operan sobre la **tabla de credenciales de Keycloak** (`credential`),
no sobre ningún atributo de identidad. El verbo `read` no expone el hash —
expone metadatos: tipo de credencial, fecha de último cambio, estado activo/desactivado.

---

### 9.4 Trabajo pendiente de investigación minuciosa por método

El catálogo de bundles en §8 fue construido con la lógica conceptual correcta
(se incluyeron emails de recuperación, documentos de identidad, etc.) pero
**cada método requiere revisión método × dominio** antes de poblar la BD, verificando:

1. **¿Los atributos del bundle son atributos de identidad o credenciales disfrazadas?**
   - `a1101` (fecha_nacimiento) para Biométrico D5 → ✅ atributo de identidad
   - `a1102` (género) para Biométrico D5 → ✅ atributo demográfico para template
   - El template biométrico en sí → ❌ no va en `idn_tipo_atributo`, va en biometric store

2. **¿Los átomos del bundle operan sobre el módulo correcto?**
   - Para X.509 mTLS: los átomos son de **Vault PKI** (emisión de certificados), no de un "atributo certificado"
   - Para ECDSA: los átomos son de **Besu / Vault** (firma on-chain), no de un "atributo clave pública"

3. **¿Las políticas del bundle son las mínimas necesarias o hay más por estándar?**
   - Para TOTP: ¿se necesita política de `window_size` además de `drift_steps`?
   - Para X.509: ¿se necesita política de `key_length_minimum` (RFC 8705)?
   - Para Biométrico: ¿se necesita política de `liveness_detection` (ISO/IEC 30107-3 PAD)?

4. **¿Hay atributos del bundle que dependen de la jurisdicción?**
   - Bolivia: `a3001` (CI) + `a3101` (NIT) para métodos con validez legal (EdDSA, ECDSA)
   - Internacional: `a3013` (pasaporte) como alternativa a CI para mismos métodos

**Métodos que requieren investigación más profunda antes de poblar:**

| Método | Dominio(s) | Aspecto crítico a verificar |
|--------|-----------|------------------------------|
| am5 WebAuthn 2FA | D5, D9 | ¿Qué datos del autenticador FIDO2 son atributos vs credential store? |
| am7 X.509 mTLS | D9, D11, D12 | ¿Qué campos del certificado son atributos de identidad? (Subject DN, SANs) |
| am19 Biométrico | D2, D5 | Template biométrico → NO es atributo. ¿Qué SÍ es atributo? |
| am20 ECDSA | D9, D12 | Clave pública → NO es atributo. ¿Qué átomos exactos de Besu/Vault? |
| am21 EdDSA | D9, D12 | Igual que ECDSA + validación Ley 164 Bolivia (ADSIB) |
| am12 CIBA | D1, D8 | ¿Qué atributos de dispositivo son necesarios para backchannel? |

**Regla de oro para poblar la BD:**
> Antes de insertar cualquier ítem en el bundle de un método,
> verificar si ese dato puede existir SIN que el actor tenga ese método.
> Si puede existir independientemente → es atributo de identidad.
> Si solo existe PORQUE el actor usa ese método → es parte de la credencial, no del atributo.

---

## 10. IMPLICACIONES PARA EL DDL (pendiente HITL)

1. **`bauth_method_bundle`** — tabla catálogo con las relaciones definidas en §8
2. **`bauth_auth_method_catalog`** — tabla para `AUTH_METHODS` (actualmente en código)
3. **`bauth_credential`** — tabla separada de `idn_atributo` para almacenar credenciales
   (hash, seed OTP, template biométrico, clave pública) — NUNCA mezclar con atributos
4. **Columna `domain_map INTEGER[]`** en `privilege_atom` para métodos que aplican en N dominios
5. **Trigger en `bos_rol_template`** — al insertar en `d[N].meths.required` o `.alternative`,
   consultar `bauth_method_bundle` y poblar `d[N].pols`, `d[N].attrs`, `d[N].atoms`

**Todo cambio DDL en VPS requiere aprobación de Iván (HITL obligatorio).**

---

**Versión:** 1.1 · **Actualizado:** 2026-07-08
**Cambios v1.1:** Agregada §9 — distinción Credencial vs Atributo de identidad,
regla general para todos los métodos, pendientes de investigación por método.
**Fuentes:** NIST SP 800-63B-4 · ICAM Canadian Centre for Cyber Security ·
Curity IAM Credential Management · Microsoft Defender for Identity ·
Keycloak Secure Credentials Store Design (GitHub keycloak-community)

**Demo:** `BauthAgent/context/demos/rol-template-builder.html`
**Próximo paso:** Investigación minuciosa por método (§9.4) antes de poblar `bauth_method_bundle` en VPS
