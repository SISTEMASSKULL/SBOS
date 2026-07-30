---
name: bauth-identidad
description: >
  El modelo de identidad y autorización de bAuth: dominios D00-D15 + D98 + D99 (18 total),
  átomos (permisos atómicos), BitMask 64-bit, roles (DAG + SoD), usuarios, Context Plane
  y multi-tenancy. Úsala cuando trabajes con el almacén de identidad, árbol de privilegios,
  asignación de roles, validación de atributos o política AtomLang.
---

# Skill — bAuth: Modelo de Identidad y Autorización

**Fuente de verdad:** `context/Documentacion/` — Fase 1 (Identificación) + Fase 2 (Protección §átomo/rol/política).  
**Principio:** todo lo que bAuth autoriza parte de un átomo, vive en un dominio y se computa con BitMask.

---

## 1 · Los 18 Dominios de Identidad (D00–D15 + D98 + D99)

**Manual:** `1.01_MANUAL-DOMINIOS-v1.0.md`  
**Definición canónica de dominios y bloques:** `context/Documentacion/anexos/A.65.03.01_FORMALIZACION-DOMINIOS-BLOQUES-CANONICOS-v1.0.md`  
**SSOT de bloques en BD:** `bauth.idn_roles_template` en SBOSDB (134 bloques · 18 dominios · depth=2 verificado 2026-07-28)

> **Regla:** los dominios D00-D15 + D98 + D99 son la estructura actualmente en BD. La enumeración D00-D13 en documentación anterior es una versión previa — usar A.65.03.01 como referencia definitiva.

Cada dominio = un plano de evaluación del PDP. Ver skill `bauth-ddl` para la estructura SQL de cada dominio.

| Dominio | Tipo | Rol |
|---------|------|-----|
| D00 · Identidad Organizacional | Plano base | 37 sub-dominios, árbol N-to-N, multi-tenant |
| D1 · Lógico | Autorización | Permisos clásicos de aplicación |
| D2 · Físico | Localización | Control de acceso físico |
| D3 · Temporal | Tiempo | Restricciones de horario |
| D4 · Calendario | Eventos | Integración bcalendar |
| D5 · Financiero | Montos/límites | Autorización de transacciones |
| D6 · Red | Conectividad | IP/subnet/geo permitidos |
| D7 · Geoespacial | Ubicación física | Zona GPS permitida |
| D8 · Delegación | Proxy | Actuar en nombre de otro |
| D9 · Biométrico | Corporal | Datos biométricos |
| D10 · Dispositivo | Postura | Device posture/trust |
| D11 · Contexto | Runtime | Factores dinámicos en tiempo real |
| D12 · Blockchain | Immutable | Registro ECDSA en Besu — WORM |
| D99 · Admin Global | Garante | bglobal + criptografía de atributos + versionado de normas |

**Árbol D00:** `1.06_MANUAL-D00-IDENTIDAD-v2.0.md` (v2.1.0 · 37 dominios · N-to-N · visibilidad).

---

## 2 · Átomos — la unidad mínima de permiso

**Manual:** `1.03_MANUAL-ATOMOS-v1.0.md` · **Catálogo:** `anexos/A.05_ANEXO-CATALOGO-ATOMOS-DOMINIOS-v1.0.md`  
**Tipos:** `anexos/A.59_ANEXO-TIPOS-ATOMOS-DOMINIOS-v1.0.md` · **Propiedades:** `anexos/A.68_CATALOGO-PROPIEDADES-ATOMOS-v1.0.md`

Un átomo es un permiso indivisible definido por `(dominio, verbo)`. Tiene:
- **Código único** en el catálogo global (≈ 6,000 átomos definidos)
- **Posición de bit** en el BitMask del dominio al que pertenece
- **Propiedades** (requerido/opcional, SoD pair, nivel AAL, etc.)

**Verbos:** `1.02_MANUAL-VERBOS-v1.0.md` — el vocabulario canónico de acciones.

**AtomLang** (`2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md`): lenguaje de configuración del árbol de políticas.
Gramática + compilador en `2.13`. Respaldo normativo: `A.45-A.51`.

---

## 3 · BitMask 64-bit — cálculo O(1) de privilegios

**Manual:** `1.04_MANUAL-BITMASK-v1.0.md`  
**Código:** `anexos/A.17_ANEXO-BITMASK-CODIGO-v1.0.md`

**BitMask Dual:** cada identidad tiene 2 máscaras de 64 bits por dominio:
- `operational_mask` — lo que puede hacer ahora
- `trust_mask` — nivel de confianza acumulada

**DomainRegistry:** estructura en memoria que mapea `(dominio, verbo)` → posición de bit.
Consulta O(1) — sin SQL en el camino caliente de autorización.

**Catálogo de roles con BitMask Dual:** `anexos/A.03_ANEXO-CATALOGO-ROLES-v1.0.md`

---

## 4 · Roles — DAG + SoD

**Manual:** `1.09_MANUAL-ROLES-v1.0.md` · **Motor de Roles:** `2.17_MANUAL-MOTOR-ROLES-v1.0.md`  
**RolTemplate:** `1.08_MANUAL-USER-TEMPLATE-v1.0.md` (v6.0) · `2.17.01_MANUAL-ROLES-TEMPLATE-v1.0.md`

Los roles son un DAG (Directed Acyclic Graph) que hereda átomos de padres a hijos.  
- **SoD (Separation of Duties):** pares de átomos mutuamente excluyentes — el sistema aplica SoD en el momento de la asignación.
- **Cadenas de jerarquía:** `anexos/A.04_ANEXO-CADENAS-JERARQUIA-v1.0.md`
- **Merge temporal de roles:** `anexos/A.51_ANEXO-MERGE-ROLES-TEMPORAL-v1.0.md`
- **Ciclo de vida átomos en roles (DAG):** `anexos/A.60_ANEXO-CICLO-VIDA-ATOMOS-ROLES-v1.0.md`
- **Diseño BD Roles:** `anexos/A.61_ANEXO-DISENO-BD-ROLES-v1.0.md`

---

## 5 · Usuarios y Atributos

**Usuarios:** `1.08_MANUAL-USER-TEMPLATE-v1.0.md` · **Atributos:** `1.07_MANUAL-ATRIBUTOS-v2.0.md` (v2.0)  
**Motor de Identidad:** `2.15_MANUAL-MOTOR-IDENTIDAD-v1.0.md` · **Uso:** `2.16_MANUAL-USO-MOTOR-IDENTIDAD-v1.0.md`  
**UserTemplate:** `anexos/A.02_ANEXO-USERTEMPLATE-v1.0.md` (v6.0 — FUENTE AUTOSUFICIENTE)

El Motor de Identidad valida datos de usuario contra políticas AtomLang — validación de atributos en tiempo real.

- **Capas acumulativas de atributos:** `anexos/A.53_ANEXO-ENTIDAD-CAPAS-ATRIBUTOS-v1.0.md`
- **Diseño BD Identidad:** `anexos/A.56_ANEXO-DISENO-BD-IDENTIDAD-v1.0.md`
- **Aislamiento multi-tenant (RLS):** `anexos/A.22_ANEXO-AISLAMIENTO-MULTITENANT-v1.0.md`

---

## 6 · Context Plane (ctx_id)

**Manual:** `1.11_MANUAL-CONTEXT-PLANE-v1.0.md` · `anexos/A.14_ANEXO-CONTEXT-PLANE-B16-v1.0.md`  
**Norma:** SBOS-049 — obligatorio en TODO request (ISO 27001 A.8.15)

`ctx_id` es el identificador de contexto de sesión que fluye por TODOS los componentes.
Lo genera bAuth al inicio de una sesión; lo propagan todos los daemons. Es la clave de trazabilidad.

---

## 7 · Multi-tenancy e IDaaS

**Manual:** `1.12_MANUAL-MULTITENANCY-IDAAS-v1.0.md`  
**Schemas:** `bauth.tenant.*` + `bauth.idp.*`  
**Aislamiento:** RLS en PostgreSQL — cada tenant ve solo sus datos.  
**IDaaS:** bAuth como proveedor de identidad para tenants externos.

---

## Mapa de dependencias (Fase 1)

```
Dominios (1.01) → Verbos (1.02) → Átomos (1.03) → BitMask (1.04)
                                              ↓
                                        DDL-Seeds (1.05)
                                              ↓
                            D00-Identidad (1.06) ← Atributos (1.07)
                                    ↓                    ↓
                             User/Template (1.08)   Roles (1.09)
                                    ↓
                            Aplicaciones (1.10)
                                    ↓
                             Context Plane (1.11) → Multi-tenancy (1.12)
                                                         ↓
                                              Motor Versionado (1.13)
```
