# DIAGNÓSTICO Y PLAN — Proceso Framework cfg_policy_library
**Fecha:** 2026-07-07  
**Autor:** bauth-developer  
**Estado:** BORRADOR — pendiente aclaraciones del humano

---

## 1. Flujo actual (cómo funciona hoy)

```
bauth_fw_01..16.sql
  └─ INSERT INTO framework_raw (source_name, content JSON)

bauth_20__framework_politicas.sql
  ├─ FASE 2: TRUNCATE framework_raw      ← borra todo en cada ejecución
  ├─ FASE 3: TRUNCATE cfg_policy_library ← borra todo en cada ejecución
  │           + CTE recursivo (explota JSON → ~9,142 nodos)
  ├─ FASE 4: UPDATE content_es (traducción automática)
  └─ FASE 5: UPDATE domain_map por fuente ← AQUÍ ESTÁN LOS BUGS

bauth_43__framework_sync.sql
  └─ INSERT INTO ath_policy_dN
     SELECT FROM cfg_policy_library WHERE domain_map @> ARRAY['Dx']
     ON CONFLICT DO UPDATE  ← ya es idempotente
```

**Problemas identificados:**
1. Las FASE 2 y 3 hacen TRUNCATE → el proceso se re-ejecuta completo en cada arranque
2. FASE 5 tiene 8 asignaciones de domain_map incorrectas (D5 biométrico contaminado)
3. Los ath_policy_dN dependen de que cfg_policy_library esté bien poblada antes de correr

---

## 2. Flujo deseado (lo que el usuario describió)

```
JSON (revisado una sola vez)
  └─ carga inicial → framework_raw → cfg_policy_library
                      ↑ solo se ejecuta UNA VEZ

cfg_policy_library = tabla CRUD maestra
  - se validan y corrigen los registros aquí
  - los CRUDs de nuevas políticas se hacen sobre esta tabla
  - NO sobre los JSON

cfg_policy_library → ath_policy_dN / ath_config_dN
  - poblado desde la tabla validada
  - determinista (domain_map correcto)
  - no depende de JSON en runtime
```

---

## 3. Errores de domain_map identificados (FASE 5)

### 3.1 Por fuente (source)

| Fuente | Domain actual | Corrección propuesta | Justificación |
|--------|--------------|---------------------|---------------|
| `fido2_ctap_2.2` | `D5, D7` ❌ | `D7, D9` | FIDO2 es protocolo de autenticación (D9) sobre red (D7). No es biométrico. El autenticador PUEDE usar biometría localmente, pero el protocolo CTAP no define biometría. |
| `nist_sp_800_63b_rev4` | `D9, D5, D8` ❌ | `D9, D8` | 800-63B cubre credenciales (D9) y contexto de autenticación (D8). La biometría la cubre NIST SP 800-76 e ISO/IEC 19794. Quitar D5. |
| `industry_enterprise` | `D5, D9, D7` ❌ | `D9, D7` | Contenido es prácticas enterprise (Okta, BeyondCorp, Microsoft Entra). No hay biometría. Quitar D5. |

### 3.2 Por section_name dentro de `policies_framework`

| Section name | Domain actual | Corrección propuesta | Justificación |
|---|---|---|---|
| `modern_authentication_policies` | `D5` ❌ | `D9` | Autenticación moderna = Passkeys, WebAuthn, FIDO2 = credenciales D9 |
| `next_generation_protections` | `D5` ❌ | `D7, D9` | Next-gen protections = red + credenciales, no biometría |
| `edge_authentication_policies` | `D5` ❌ | `D2, D7` | Autenticación en el borde = acceso físico D2 + red D7 |

### 3.3 Por section_name dentro de `authentication_framework`

| Section name | Domain actual | Corrección propuesta | Justificación |
|---|---|---|---|
| `behavioralAuthentication` | `D5` ❌ | `D8, D9` | Autenticación conductual = contexto D8 + credenciales D9 |
| `webSocketAccessControl` | `D5` ❌ | `D7` | Control de acceso WebSocket = red D7 |

**Nota:** `advancedBiometrics` → `D5` ✓ es correcto. Esa sección sí pertenece a D5.

---

## 4. Cambios propuestos

### Cambio A — `bauth_20__framework_politicas.sql` (migration existente)

**A.1** Remover TRUNCATE de FASE 2 (framework_raw):
```sql
-- ANTES:
TRUNCATE TABLE bauth.framework_raw RESTART IDENTITY CASCADE;

-- DESPUÉS: eliminar esta línea
-- Los bauth_fw_NN.sql ya son idempotentes (UNIQUE en source_name)
```

**A.2** Cambiar FASE 3 de TRUNCATE+CTE a INSERT idempotente:
```sql
-- ANTES:
TRUNCATE TABLE bauth.cfg_policy_library RESTART IDENTITY CASCADE;
WITH RECURSIVE tree AS (...)
INSERT INTO cfg_policy_library ...

-- DESPUÉS:
WITH RECURSIVE tree AS (...)
INSERT INTO bauth.cfg_policy_library (section_name, parent_path, node_type, ...)
SELECT section_name, parent_path, node_type, ...
FROM tree
ON CONFLICT (json_path, source) DO NOTHING;
-- Solo inserta si no existe → proceso se ejecuta una sola vez
```

**A.3** Corregir FASE 5 con las 8 correcciones de domain_map (sección 3 arriba).

---

### Cambio B — Nuevo seed `bauth_fw_seed__d5_biometrico.sql` (nuevo archivo)

INSERTs directos en `cfg_policy_library` con las 19 políticas/configs de D5 biométrico ya validadas contra normas ISO/IEC 19794-x, ISO/IEC 30107-3:2023, NIST SP 800-76.

- `source = 'iso_biometric_standards'`
- `domain_map = ARRAY['D5']`
- Contenido: los 9 configs y 10 políticas que ya diseñamos en bauth_20__ath_config_d5 y bauth_32__ath_policy_d5
- ON CONFLICT DO NOTHING (idempotente)

**Propósito:** D5 no tiene fuente JSON propia en framework_raw. Todo el contenido biométrico D5 debe venir de este seed estático validado contra normas.

---

### Cambio C — Seeds D5 existentes

`bauth_20__ath_config_d5.sql` y `bauth_32__ath_policy_d5.sql` se mantienen como están.
Son los registros "manuales" con código BIOMETRIC_* validados individualmente.
Los LIB-* vendrán de bauth_43__ una vez que cfg_policy_library tenga los datos de D5.

---

## 5. Lo que NO cambia

- `bauth_fw_01__` a `bauth_fw_16__`: se mantienen tal cual (cargan JSON en framework_raw)
- `bauth_43__framework_sync.sql`: se mantiene tal cual (ya es idempotente con ON CONFLICT DO UPDATE)
- Todos los seeds `bauth_NN__ath_*` existentes: sin cambios
- Los datos de ath_policy_d1..d12 ya poblados: sin tocar

---

## 6. Puntos abiertos — necesito aclaraciones del humano

Deja tus comentarios aquí:

**P1.** ¿El proceso de carga inicial (framework_raw → cfg_policy_library) se ejecuta en el mismo script
que el migration DDL, o en un paso separado?

> Tu respuesta: Si pero solo uan vez ya despues el cfg_policy_library ya tiene los datos en ahi mismo hay qeu clasificarlos por dominios y extraer lo rules para luego hacer ua  combinacion de rules y polices, una vez en la tabla cfg_policy_library lo verificas si esta acorde con las normas y estandares, como te decia esa es nuestro resplado de la bibliote ace politicas. y de ahi see ctren a las tablas por dominio

**P2.** ¿cfg_policy_library debe tener los 9,142 nodos del CTE (árbol completo) o solo los nodos
significativos (profundidad 1-3, las secciones y grupos principales)?

> Tu respuesta: No necesariamente como te digo una vez ya en al cfg_policy_library itera en la tabla y verifica en internet la valides de la politica, y si no sirve o no esta de acuerdo a las normas marcala para borrar, cuando ya tengamos todas las politicas verificadas y clasificadas, hacemso un conteo y verificamos si todos los domeinos estan cubiertos con politicas. esa tabal cfg_policy_library sera meuntra biblioteca de politicas como ya esta validada selleccionada y limpia hay que vaciarlo a un seed para que ese seed vuelva va a llenar la tbala cfg_policy_library y los pasos anteriores a esta ya no serian validos.

**P3.** Los seeds `bauth_fw_NN__` actualmente insertan en `framework_raw`. ¿Quieres que en el
futuro inserten DIRECTAMENTE en `cfg_policy_library` (eliminando framework_raw del flujo), o
`framework_raw` se mantiene como archivo histórico de los JSON originales?

> Tu respuesta: cfg_policy_library sera nuestra biblioteca de politicas como ya esta validada selleccionada y limpia hay que vaciarlo a un seed para que ese seed vuelva va a llenar la tbala cfg_policy_library y los pasos anteriores a esta ya no serian validos.

**P4.** ¿El seed estático de D5 biométrico (`bauth_fw_seed__d5_biometrico.sql`) debe tener
profundidad 1 (una fila por sección ISO, con el JSON completo en `content`) o debe explotar
igual que el CTE (una fila por cada sub-nodo del JSON)?

> Tu respuesta: Verificalo tu de la manera mas logica, robusta y profesioanl

**P5.** Hay 8 correcciones de domain_map. ¿Las apruebas todas, o quieres revisar alguna
individualmente antes de aplicar?

> Tu respuesta: Primero resuelve las anteriores preguntas.
