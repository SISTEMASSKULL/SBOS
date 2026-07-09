# BAUTH — Registro de ALTER TABLE: idn_role_template
## Fecha: 2026-07-09 · Autor: bauth-developer · VPS: 13.140.128.230

> **Propósito:** Este documento registra los cambios aplicados via ALTER TABLE en la VPS.
> Sirve de guía para corregir el `CREATE TABLE bauth.idn_role_template` en:
> `DDLs/migrations/sbos_00__esquema_base.sql` (líneas 2449-2495)
> **REGLA:** los migrations solo tienen CREATE TABLE — nunca ALTER TABLE.
> Cuando se corrija el DDL, integrar estas columnas directamente en el CREATE TABLE original.

---

## Columnas agregadas (ALTER TABLE ejecutado 2026-07-09)

### 1. `role_name TEXT NOT NULL DEFAULT ''`
- **Norma:** ANSI INCITS 359 §3 — nombre legible del rol
- **Uso:** Nombre en español para mostrar en UI y reportes
- **Ejemplo:** `'Director General'`, `'Cajero'`, `'Superusuario SBOS'`
- **Población:** Extraído del campo `template->>'n'` existente en JSONB

### 2. `role_description TEXT`
- **Norma:** ISO 27001:2022 A.5.15 + NIST SP 800-53 AC-2
- **Uso:** Descripción completa del rol: responsabilidades, alcance, restricciones
- **Ejemplo:** `'Máximo permiso global. Crea administradores de plataforma...'`
- **Población:** Extraído del catálogo BAUTH-CATALOGO-ROLES-EMPRESARIALES.md v2.1

### 3. `scope TEXT`
- **Norma:** ISO/IEC 24760-2:2015 §6 + NIST SP 800-53 AC-2
- **Uso:** Ámbito del rol: nombre del sector CAEB, dominio funcional, o área organizacional
- **Ejemplo:** `'Global'`, `'Sector A - Agricultura'`, `'Módulo bAuth'`, `'Finanzas'`

### 4. `classification TEXT NOT NULL DEFAULT 'INTERNO'`
- **Norma:** ISO 27001:2022 A.8.2 — Clasificación de la información
- **Check:** `('PUBLICO','INTERNO','CONFIDENCIAL','RESERVADO')`
- **Valores por tier:**
  | Tier | classification |
  |------|---------------|
  | SU | RESERVADO |
  | BIZ_N1, BIZ_N2, M2M | CONFIDENCIAL |
  | BIZ_N3, BIZ_N4, BIZ_N5 | INTERNO |
  | EXT_N0, VISITANTE | PUBLICO |

### 5. `risk_level TEXT NOT NULL DEFAULT 'BAJO'`
- **Norma:** ISO 27001:2022 A.5.15 + NIST SP 800-53 AC-2
- **Check:** `('BAJO','MEDIO','ALTO','CRITICO')`
- **Valores por tier:**
  | Tier | risk_level |
  |------|-----------|
  | SU | CRITICO |
  | BIZ_N1, BIZ_N2, M2M | ALTO |
  | BIZ_N3, BIZ_N4 | MEDIO |
  | BIZ_N5, EXT_N0, VISITANTE | BAJO |

### 6. `review_period_days INTEGER NOT NULL DEFAULT 90`
- **Norma:** ISO 27001:2022 A.5.15 + NIST SP 800-53 AC-2(j)
- **Uso:** Cada cuántos días debe revisarse la asignación de este rol
- **Valores por tier:**
  | Tier | Días |
  |------|------|
  | SU | 30 |
  | BIZ_N1, BIZ_N2, BIZ_N3, M2M | 90 |
  | BIZ_N4, BIZ_N5 | 180 |
  | EXT_N0, VISITANTE | 365 |

### 7. `role_type TEXT NOT NULL DEFAULT 'OPERATIVO'`
- **Norma:** SBOS — clasificación funcional para organigramas
- **Check:** `('SISTEMA','EJECUTIVO','DIRECTIVO','GERENCIAL','TECNICO_PROFESIONAL','OPERATIVO','ASESOR','CONSULTOR','EXTERNO','FAMILIAR','HOGAR','FISICO','MAQUINA','VISITANTE')`
- **Mapeo tier → role_type:**
  | Tier | role_type default |
  |------|------------------|
  | SU | SISTEMA |
  | BIZ_N1 | EJECUTIVO |
  | BIZ_N2 | DIRECTIVO |
  | BIZ_N3 | GERENCIAL |
  | BIZ_N4 | TECNICO_PROFESIONAL |
  | BIZ_N5 | OPERATIVO |
  | M2M | MAQUINA |
  | EXT_N0 | EXTERNO |
  | VISITANTE | VISITANTE |
- **Override:** roles con id ILIKE '%asesor%' o '%consultor%' → ASESOR/CONSULTOR
- **Override:** roles de familia → FAMILIAR; hogar → HOGAR; acceso físico → FISICO

### 8. `applies_to_size TEXT NOT NULL DEFAULT 'TODAS'`
- **Norma:** SBOS — segmentación por tamaño de empresa
- **Check:** `('TODAS','MULTINACIONAL','GRANDE','MEDIANA','PEQUENA','MICRO')`
- **Uso:** Filtro para onboarding rápido. Una empresa MICRO no ve roles de MULTINACIONAL.
- **Población:** La mayoría = 'TODAS'. Roles gerenciales complejos (CEO con Junta Directiva) = 'MULTINACIONAL'/'GRANDE'

### 9. `is_collaborative BOOLEAN NOT NULL DEFAULT false`
- **Norma:** SBOS — indica que el rol es colaborativo (externo a la jerarquía lineal)
- **Uso:** Los roles colaborativos (asesores, consultores, auditores externos) aparecen en el
  organigrama pero no pertenecen a ningún nivel jerárquico fijo. Se enlazan mediante
  `parent_id` al área que los contrata pero con `is_collaborative=true`.
- **true para:** ASESOR, CONSULTOR, AUDITOR_EXTERNO, PERITO, NOTARIO_EXTERNO

---

## Cambios adicionales ejecutados

### hierarchy_level actualizado por tier
```
SU=1, BIZ_N1=2, BIZ_N2=3, BIZ_N3=4, BIZ_N4=5, BIZ_N5=6, M2M=2, EXT_N0=7, VISITANTE=8
```

### loa_required / mfa_required / audit_level actualizados por tier
```
SU:       loa=3, mfa=true,  audit='full'
BIZ_N1:   loa=3, mfa=true,  audit='full'
BIZ_N2:   loa=2, mfa=true,  audit='full'
BIZ_N3:   loa=2, mfa=true,  audit='basic'
BIZ_N4:   loa=1, mfa=false, audit='basic'
BIZ_N5:   loa=1, mfa=false, audit='basic'
M2M:      loa=2, mfa=true,  audit='full'
EXT_N0:   loa=1, mfa=false, audit='none'
VISITANTE:loa=1, mfa=false, audit='basic'
```

---

## DDL corregido (integrar en sbos_00__esquema_base.sql líneas 2449-2495)

Agregar estas columnas al bloque `-- Metadata` del CREATE TABLE original:

```sql
    -- Identificación legible (ANSI INCITS 359 + ISO 27001 A.5.15 + NIST AC-2)
    role_name           TEXT        NOT NULL DEFAULT '',
    role_description    TEXT,
    scope               TEXT,
    -- Gobernanza (ISO 27001 A.8.2 + A.5.15 + NIST SP 800-53 AC-2(j))
    classification      TEXT        NOT NULL DEFAULT 'INTERNO'
        CHECK (classification IN ('PUBLICO','INTERNO','CONFIDENCIAL','RESERVADO')),
    risk_level          TEXT        NOT NULL DEFAULT 'BAJO'
        CHECK (risk_level IN ('BAJO','MEDIO','ALTO','CRITICO')),
    review_period_days  INTEGER     NOT NULL DEFAULT 90,
    -- Organigrama (SBOS)
    role_type           TEXT        NOT NULL DEFAULT 'OPERATIVO'
        CHECK (role_type IN ('SISTEMA','EJECUTIVO','DIRECTIVO','GERENCIAL',
                             'TECNICO_PROFESIONAL','OPERATIVO','ASESOR','CONSULTOR',
                             'EXTERNO','FAMILIAR','HOGAR','FISICO','MAQUINA','VISITANTE')),
    applies_to_size     TEXT        NOT NULL DEFAULT 'TODAS'
        CHECK (applies_to_size IN ('TODAS','MULTINACIONAL','GRANDE','MEDIANA','PEQUENA','MICRO')),
    is_collaborative    BOOLEAN     NOT NULL DEFAULT false,
```

---

## Estado pendiente

### Completado 2026-07-09
- [x] Poblar `role_description` con texto completo del catálogo (367/367 roles — AA-1 verificado)
- [x] Poblar `scope` por sector CAEB y dominio funcional (367/367)
- [x] Poblar `role_name` para todos los roles (367/367)
- [x] Generar seed via pg_dump: `DDLs/seeds/bauth_48__idn_role_template.sql` (v2.1.0 · 367 INSERTs)

### Pendiente
- [ ] Poblar `applies_to_size` para roles que solo aplican a empresas grandes/multinacionales
- [ ] Corregir `parent_id` de §3/§4 para árbol de organigrama
- [ ] Integrar columnas en CREATE TABLE de sbos_00__esquema_base.sql (líneas 2449-2495)
