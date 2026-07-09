# BAUTH-EVALUACION-VIABILIDAD-ATOMIZACION — ¿Es viable y certificable?
## Evaluación técnica + normativa de la propuesta domain.app.module.verb · 2026-06-30

**Pregunta:** *"¿Es viable reconfigurar ahora las reglas como átomos? ¿Mantiene las exigencias de las normas internacionales? ¿Podemos certificarnos con este modelo?"*

---

## PARTE 1 — VIABILIDAD TÉCNICA

### 1.1 Estado actual de la infraestructura

| Componente | Estado actual | ¿Soporta la migración? |
|-----------|--------------|:---:|
| `privilege_atom` | 1,059 átomos · `atom_code` INTEGER (16M capacity) | ✅ Agregar columnas sin romper |
| `privilege_role_atom` | 212 asignaciones rol↔átomo | ✅ Agregar `value` JSONB |
| `RolBitMask` | `BitVec<u64, Lsb0>` dinámico | ✅ Sin límite de átomos |
| `FastPath` | `bits[position]` — O(1) | ✅ Misma velocidad para átomos de regla |
| `DomainEvaluator` | 12 evaluadores con cortocircuito | ✅ Evaluar átomos RULE requiere extender, no reescribir |

**Conclusión técnica:** La infraestructura actual SOPORTA la migración sin cambios estructurales.
Solo se requiere ALTER TABLE (agregar columnas) + migración de datos.

### 1.2 Qué cambia y qué no

| Aspecto | Sigue IGUAL | Cambia |
|---------|:---:|:---:|
| **Motor BitMask** | ✅ FastPath O(1), RolBitMask, herencia DAG | — |
| **Catálogo de átomos** | ✅ `privilege_atom` como registro único | Se agregan átomos de tipo RULE |
| **Asignación rol↔átomo** | ✅ `privilege_role_atom` | Se agrega columna `value` para átomos RULE |
| **Evaluación runtime** | ✅ `bauth.access.evaluate` | Se extiende para átomos RULE (leer valor + comparar) |
| **Dashboard** | ✅ Árbol d.a.m.v | Unificado: acciones + reglas en el mismo árbol |
| **cfg_policy_library** | ✅ Biblioteca de referencia | Se mantiene como fuente documental |
| **Workflow de aprobación** | ✅ draft→proposed→approved | Se aplica a átomos RULE |
| **ath_policy_d*** | — | ❌ ELIMINADAS (absorbidas por átomos RULE) |
| **ath_config_d*** | — | ❌ ELIMINADAS (absorbidas por átomos RULE) |
| **cfg_validation_rule** | — | ❌ ELIMINADA (validation en el átomo) |
| **fin_limit** | — | ❌ ELIMINADA (valores en privilege_role_atom) |

### 1.3 Impacto en la compilación

Los handlers afectados son:

| Handler | Impacto |
|---------|---------|
| `bauth.policy.domain.evaluate` | ALTO — reescribir para usar atoms en vez de ath_policy_d* |
| `bauth.policy.domain.list` | ALTO — reescribir para consultar privilege_atom |
| `bauth.policy.create/update/delete` | MEDIO — ahora opera sobre privilege_atom |
| `bauth.access.evaluate` | BAJO — extender para átomos RULE (ya soporta átomos ACTION) |
| `bauth.role.compute_mask` | NULO — el mismo algoritmo, solo más átomos |
| `bauth.dashboard.panel4` | BAJO — el árbol ya está implementado |
| `bauth.dashboard.panel11` | NULO — ya muestra átomos |

**Estimación de esfuerzo:** ~20-30 horas de desarrollo para la migración completa.
**Riesgo:** BAJO. Se puede hacer incrementalmente sin romper runtime.

---

## PARTE 2 — COMPATIBILIDAD CON ESTÁNDARES INTERNACIONALES

### 2.1 Lo que los estándares REALMENTE exigen

| Estándar | Control | ¿Exige un modelo de datos específico? | ¿Exige UN proceso específico? |
|---------|---------|:---:|:---:|
| **ISO 27001:2022 A.8.9** | Configuration Management | ❌ No | ✅ Sí — baseline, change control, monitoring |
| **ISO 27001:2022 A.5.1** | Policies for Information Security | ❌ No | ✅ Sí — defined, documented, approved, communicated, reviewed |
| **NIST SP 800-53 CM-3** | Configuration Change Control | ❌ No | ✅ Sí — determine, review, approve, document, implement, audit |
| **PCI DSS 4.0 6.5.1** | Change Control Procedures | ❌ No | ✅ Sí — reason, impact, approval, testing, rollback |
| **SOC 2 CC8.1** | Change Management | ❌ No | ✅ Sí — authorize, design, configure, document, test, approve |

**Hallazgo fundamental:** NINGÚN estándar internacional exige UN modelo de datos específico
para almacenar políticas. Los estándares exigen PROCESOS y CONTROLES.

Mientras los procesos se cumplan (aprobación, trazabilidad, revisión, rollback), el auditor
NO audita el esquema de base de datos. Audita la EVIDENCIA de que los controles funcionan.

### 2.2 Cómo el modelo atómico CUMPLE cada requisito

| Requisito del estándar | Cómo lo cumple el modelo atómico |
|------------------------|----------------------------------|
| **Políticas definidas y documentadas** | Cada átomo RULE tiene `atom_slug`, `atom_name`, `standard_ref`. Documentado en `cfg_policy_library`. |
| **Aprobadas por management** | Workflow `lifecycle`: draft→proposed→approved. `proposed_by` ≠ `approved_by` (SoD). |
| **Comunicadas** | El Dashboard muestra el estado. Los cambios aprobados se propagan automáticamente. |
| **Revisadas periódicamente** | Reconcile loop (60s) + `sync_log` + review triggers en el Dashboard. |
| **Baseline documentada** | `cfg_policy_library` + `framework_raw` = baseline inmutable de referencia. |
| **Control de cambios** | Todo cambio en átomos RULE pasa por el workflow. `privilege_atom` tiene `created_at`, `updated_at`. |
| **Monitoreo de drift** | Reconcile loop detecta diferencias entre `cfg_policy_library` y átomos activos. |
| **Pruebas pre-implementación** | `bauth.policy.simulate` permite evaluar átomos RULE antes de activarlos. |
| **Rollback** | Revertir `lifecycle` → reconciliar → runtime refleja el estado anterior. |
| **Audit trail** | `privilege_atom_audit` (WORM) + `sync_log` + hash-chain SHA-256 + Merkle D12. |

### 2.3 Lo que el auditor VA A VER (y le va a gustar)

```
Evidencia que el auditor revisa en una certificación ISO 27001:

1. ✍️ POLÍTICA DE SEGURIDAD DE LA INFORMACIÓN
   → Documento formal aprobado por la dirección. NO es la base de datos.
   → Se cumple: existe, está firmada, se revisa anualmente.

2. 📋 CONFIGURATION BASELINE
   → "Muéstreme la configuración base de su sistema de autenticación"
   → Mostramos: cfg_policy_library (9,142 entradas documentadas con fuente y estándar)
   → Mostramos: framework_raw (16 documentos JSON fuente, inmutables)

3. 🔄 REGISTRO DE CAMBIOS
   → "Muéstreme quién cambió qué política, cuándo, y quién lo aprobó"
   → Mostramos: privilege_atom_audit (WORM) con hash-chain verificable
   → Mostramos: sync_log con drift detection

4. 🧪 PRUEBAS PRE-CAMBIO
   → "¿Cómo prueban que un cambio no rompe la seguridad?"
   → Mostramos: bauth.policy.simulate — evaluamos antes de activar

5. 🔙 ROLLBACK
   → "¿Qué pasa si un cambio causa un incidente?"
   → Mostramos: revertir lifecycle → reconcile loop → sistema vuelve al estado anterior en <60s

6. 👥 SoD
   → "¿La misma persona puede proponer Y aprobar un cambio?"
   → Mostramos: proponente ≠ aprobador. Forzado por el Dashboard.
```

**El auditor NUNCA pregunta:** "¿Sus políticas están en una tabla llamada ath_policy_d3 o en privilege_atom con atom_type='RULE'?" Eso es irrelevante para la certificación.

---

## PARTE 3 — COMPARATIVA: MODELO ACTUAL vs MODELO ATÓMICO

### 3.1 Para el desarrollador (que integra bAuth)

| Aspecto | Modelo actual (6 tablas) | Modelo atómico (unificado) |
|---------|-------------------------|---------------------------|
| ¿Cuántas tablas necesita entender? | 6 | 2 |
| ¿Cómo asigna una regla a un rol? | Busca en ath_policy_d*, busca en RoleTemplate JSONB, busca en fin_limit... | `privilege_role_atom (role_id, atom_id, value)` |
| ¿Cómo verifica si un usuario tiene una regla? | Multi-paso: ath_loader → ath_converter → evaluate | FastPath O(1): `bits[atom_position]` |

### 3.2 Para el admin (que usa el Dashboard)

| Aspecto | Modelo actual | Modelo atómico |
|---------|-------------|---------------|
| ¿Dónde crea una nueva regla? | ¿ath_policy_d3? ¿cfg_policy_library? ¿cfg_validation_rule? No está claro. | UN solo lugar: árbol d.a.m.v → "Nuevo átomo" |
| ¿Dónde asigna valor a un rol? | RoleTemplate JSONB (denormalizado, difícil de validar) | `privilege_role_atom.value` (relacional, con FK) |
| ¿Cómo ve el estado? | Panel 4 para políticas, Panel 11 para átomos — separados | UN solo árbol con checkboxes (acciones) + campos (reglas) |

### 3.3 Para el auditor (que certifica)

| Aspecto | Modelo actual | Modelo atómico |
|---------|-------------|---------------|
| ¿Están todas las políticas en un solo lugar? | ❌ Dispersas en 6 tablas | ✅ `privilege_atom` unificado |
| ¿Cada cambio tiene trazabilidad? | ⚠️ Depende de la tabla | ✅ `privilege_atom_audit` WORM para TODO |
| ¿Hay baseline documentada? | ✅ cfg_policy_library (se mantiene) | ✅ cfg_policy_library (se mantiene) |

---

## PARTE 4 — VEREDICTO

### 4.1 ¿Es viable?

**SÍ.** La infraestructura actual soporta la migración sin cambios estructurales mayores.
Solo ALTER TABLE + migración de datos + extensión de 3 handlers. Esfuerzo: ~20-30h.

### 4.2 ¿Mantiene las exigencias de las normas?

**SÍ.** Los estándares NO exigen un modelo de datos específico. Exigen PROCESOS: aprobación,
trazabilidad, baseline, revisión, rollback. Todos se preservan y MEJORAN con el modelo atómico
porque están centralizados en un solo sistema en vez de dispersos en 6 tablas.

### 4.3 ¿Podemos certificarnos?

**SÍ.** El modelo atómico es MÁS AUDITABLE que el actual:
- Un solo lugar donde buscar políticas (privilege_atom) en vez de 6
- Un solo mecanismo de asignación (privilege_role_atom) en vez de JSONB + relacional mixto
- Un solo motor de evaluación (FastPath + PolicyPath) para acciones y reglas
- Una sola tabla de auditoría (privilege_atom_audit WORM) con hash-chain + Merkle D12

### 4.4 ¿Cuándo migrar?

| Fase | Qué | Cuándo |
|:---:|------|--------|
| **Ahora** | Extender `privilege_atom` con `atom_type`, `data_type`, `validation` (ALTER TABLE, sin impacto) | Este sprint |
| **Ahora** | Extender `privilege_role_atom` con `value`, `customized` (ALTER TABLE, sin impacto) | Este sprint |
| **Siguiente** | Migrar `ath_policy_d*` existentes a átomos RULE (script SQL + verificación) | Sprint próximo |
| **Después** | Reescribir `bauth.policy.domain.evaluate` para usar átomos RULE | Sprint próximo |
| **Final** | Marcar `ath_policy_d*`, `ath_config_d*`, `cfg_validation_rule` como DEPRECADO | Release siguiente |

---

## PARTE 5 — RECOMENDACIÓN FINAL

**Proceder con la migración.** El modelo atómico:

1. ✅ Es técnicamente viable con la infraestructura actual
2. ✅ Cumple TODOS los requisitos de ISO 27001, NIST 800-53, PCI DSS, SOC 2
3. ✅ Es MÁS auditable y certificable que el modelo actual
4. ✅ Simplifica el desarrollo (menos tablas, un solo motor)
5. ✅ Simplifica el Dashboard (un solo árbol d.a.m.v)
6. ✅ Reduce el riesgo de errores (menos lugares donde buscar políticas)
7. ✅ Es incremental (no requiere big bang — se migra dominio por dominio)

**Riesgo principal a gestionar:** La migración de `ath_policy_d*` existentes a átomos RULE
debe preservar las personalizaciones del admin (columna `customized`).

---

*BAUTH-EVALUACION-VIABILIDAD-ATOMIZACION.md v1.0 · 2026-06-30*
