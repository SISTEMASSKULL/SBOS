# Anexo A.31 — Los atributos de identidad: `idn_identidad_atributo` SIN DDL
## Documento de respaldo de sustentación: el estado crudo del almacén de atributos

**Tipo:** ANEXO — respaldo de sustentación (tipo **D** verificación de código + **B** industria)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** MANUAL-ATRIBUTOS (1.07) · MANUAL-D00 (1.06) · A.02 §B2-§B3 (los campos 1:N del usuario) · MANUAL-USER-TEMPLATE (1.08 §3)
**Verificación de código:** `DDLs/` (búsqueda `idn_identidad_atributo`) — leída 2026-07-11
**Normas base:** SCIM RFC 7643 (atributos multivaluados) · ISO 24760-1 §6 (atributos de identidad) · ABAC NIST 800-162

---

## 1. Propósito

Estado crudo del almacén de atributos de identidad. **Cómo citarlo:** `A.31 §2`.

## 2. El estado crudo — la tabla no existe en el DDL

| Verificación | Evidencia | Resultado |
|---|---|---|
| `idn_identidad_atributo` / `idn_tipo_atributo` en el DDL | `grep -rn 'idn_identidad_atributo' DDLs/` | **0 menciones** — la tabla no está en el esquema |

**Traducción cruda:** el corpus documenta profusamente `idn_identidad_atributo` como el destino de los
campos 1:N de la identidad — los emails, teléfonos, direcciones del UserTemplate (A.02 §B2, regla
de 1.08 §3), los atributos extensibles de D00 (1.06), el catálogo de tipos de atributo. **Pero
la tabla NO existe en el DDL.** Es una brecha ya declarada por la carta rectora (0.00 §8 pilar V
Directory: *"idn_identidad_atributo sin DDL"*) — aquí confirmada con grep.

**Consecuencia:** los campos multivaluados del UserTemplate (B2/B3) no tienen hoy dónde
materializarse según el modelo documentado; o se guardan en el JSONB del template (contra la
regla de 1.08 §3 que dice que los 1:N van a `idn_identidad_atributo`), o no se guardan. El pilar Directory
(V) queda en L1-L2 en esta pieza.

## 3. Lo que FALTA — específico

| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| **AT1** | **DDL de `idn_identidad_atributo` + `idn_tipo_atributo`** — el catálogo de tipos y la tabla de valores 1:N | SCIM (multivaluados) · ISO 24760-1 §6 · 1.07 | **P1** (pilar Directory) |
| AT2 | Migrar los campos 1:N del UserTemplate JSONB (emails/phones/addresses) a `idn_identidad_atributo` una vez exista | 1.08 §3 (regla de almacenamiento) | P2 |
| AT3 | Clasificación por atributo (PUBLIC/INTERNAL/CONFIDENTIAL/RESTRICTED) + enmascaramiento | ISO A.5.12 · 2.10 | P2 |
| AT4 | Extensibilidad (atributos definidos por tenant) | ABAC 800-162 | P3 |

## 4. Verificación de completitud

| Verificación | Resultado |
|---|---|
| Tabla `idn_identidad_atributo` en DDL | ❌ **no existe** (0 menciones) — hallazgo crudo |
| Coherencia con 0.00 §8 | ✅ confirma la brecha declarada con grep |
| Coherencia con A.02 §B2/§B3 | La materialización de los 1:N del usuario espera esta tabla |

## 5. Referencias e historial

**Del código:** `DDLs/` (grep idn_identidad_atributo = 0). **Del proyecto:** 1.07 · 1.06 · 1.08 §3 · A.02 §B2 · 0.00 §8.
**Industria:** [SCIM RFC 7643](https://datatracker.ietf.org/doc/html/rfc7643) · [ISO 24760-1](https://www.iso.org/standard/77582.html) · [NIST 800-162 ABAC](https://csrc.nist.gov/pubs/sp/800/162/upd2/final)

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial (tipo D+B): el estado crudo — **`idn_identidad_atributo` tiene 0 menciones en el DDL** (verificado), la tabla documentada como destino de los campos 1:N de la identidad (A.02 §B2, D00) NO existe en el esquema (confirma la brecha de 0.00 §8 pilar Directory con grep). Brechas AT1 (DDL de idn_identidad_atributo/idn_tipo_atributo P1), AT2 (migrar 1:N del JSONB), AT3 (clasificación), AT4 (extensibilidad por tenant). |
