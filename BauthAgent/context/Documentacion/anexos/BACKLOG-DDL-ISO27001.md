# BACKLOG DDL — Tareas pendientes derivadas de A.71 (ISO 27001:2022)

| Metadato | Valor |
|----------|-------|
| **Propósito** | Acumulador de trabajo entre sesiones — NO es un spec formal |
| **Origen** | Revisión discrepancia por discrepancia de A.71 v1.3.0 |
| **Última sesión** | 2026-08-01 |
| **Score actual** | 83 % — 102/123 — v1.9.0 |

---

## REGLAS DE ESTE DOCUMENTO

- Se agrega una tarea cuando el usuario confirma que el gap es REAL y requiere trabajo.
- Cada tarea lista **todos los artefactos** que se deben actualizar (no solo el DDL).
- Al ejecutar una tarea → mover a sección `## COMPLETADAS` con commit y fecha.
- Al final de la sesión → procesar en bloque (DDL → kardex → seeds → A.71).

---

## PENDIENTES

---

### T-BACKLOG-001 — Módulo de lecciones aprendidas de incidentes (A.5.27)

**Estado:** PENDIENTE  
**Prioridad:** P2 (MEDIO)  
**Control ISO:** A.5.27 — Aprendizaje de incidentes de seguridad  
**Gap confirmado por:** Usuario — 2026-08-01  

**Por qué es un gap real:**  
A.5.27 exige que la organización use el conocimiento adquirido de incidentes de seguridad
para reducir la probabilidad o impacto de futuros incidentes. El DDL actual captura
el incidente crudo en `aud_event_log` y `ses_caep_event_log` (evidencia) pero no persiste:
- el vínculo incidente → causa raíz
- las medidas correctivas con responsable y fecha
- la verificación de efectividad (ciclo PDCA Check)

Este conocimiento necesita tablas propias — es trazabilidad/auditoría, NO pertenece a
`idn_roles_template` (roles_template es gobernanza de acceso y políticas, no gestión de incidentes).

**Diseño propuesto — 4 tablas:**

```sql
-- TABLA 1: cabecera del incidente
bauth.inc_incident
  inc_id         UUID PK (uuidv7)
  tenant_id      UUID FK → bauth.idn_tenant NOT NULL
  incident_type  TEXT NOT NULL   -- ver seeds T060: MC-INCI-TYPE
  severity       TEXT NOT NULL   -- CRITICAL / HIGH / MEDIUM / LOW
  detected_at    TIMESTAMPTZ NOT NULL
  resolved_at    TIMESTAMPTZ
  caep_event_ref UUID FK → bauth.ses_caep_event_log  -- evidencia origen (nullable)
  aud_event_ref  UUID FK → bauth.aud_event_log        -- evidencia origen (nullable)
  summary        TEXT NOT NULL
  ctx_id         TEXT NOT NULL
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()

-- TABLA 2: análisis de causa raíz (una por incidente)
bauth.inc_root_cause
  cause_id           UUID PK
  inc_id             UUID FK → bauth.inc_incident NOT NULL
  cause_category     TEXT NOT NULL    -- ver seeds T060: MC-INCI-CAUSE
  description        TEXT NOT NULL
  contributing_factors JSONB          -- factores secundarios
  ctx_id             TEXT NOT NULL
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()

-- TABLA 3: medidas correctivas (varias por incidente, secuenciadas)
bauth.inc_corrective_action
  action_id        UUID PK
  inc_id           UUID FK → bauth.inc_incident NOT NULL
  sequence_nr      INTEGER NOT NULL DEFAULT 1
  action_type      TEXT NOT NULL    -- ver seeds T060: MC-INCI-ACTION
  target_table     TEXT             -- qué tabla del DDL fue modificada
  target_record_id UUID             -- qué registro exactamente
  description      TEXT NOT NULL
  implemented_by   UUID FK → bauth.idn_identity_entity  -- quién implementó
  implemented_at   TIMESTAMPTZ
  status           TEXT NOT NULL DEFAULT 'PENDING'   -- MC-INCI-ACTION-STATUS
  ctx_id           TEXT NOT NULL
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()

-- TABLA 4: revisión de efectividad (ciclo PDCA — Check)
bauth.inc_effectiveness_review
  review_id            UUID PK
  inc_id               UUID FK → bauth.inc_incident NOT NULL
  review_date          TIMESTAMPTZ NOT NULL
  reviewer_id          UUID FK → bauth.idn_identity_entity
  reincidence_detected BOOLEAN NOT NULL DEFAULT false
  verdict              TEXT NOT NULL    -- EFFECTIVE / PARTIALLY_EFFECTIVE / INEFFECTIVE / PENDING
  findings             TEXT
  next_review_date     DATE
  ctx_id               TEXT NOT NULL
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
```

**Referencias de la industria:**
- ISO 27001:2022 A.5.27 — Learning from information security incidents
- NIST SP 800-61 Rev.3 — Post-incident activity, lessons learned report
- ITIL 4 Problem Management — Known Error Database (KEDB)
- SOC 2 CC7.4 — Incident response effectiveness review

**Artefactos a actualizar al ejecutar:**

| Artefacto | Acción requerida |
|-----------|-----------------|
| `DDLs/SBOS_db_V2_DDL.sql` o migration nueva | Crear las 4 tablas `inc_*` |
| `DDLs/SBOS_db_V2_DDL_MANUAL.md` | Documentar las 4 tablas (HITL — no editar solo) |
| `A.65.02_ANEXO-NUEVA-DDL-v1.0.md` | Agregar T-codes para las 4 tablas nuevas |
| `DDLs/seeds/bglobal_T060__menu_context.sql` | Nuevos ENUMs: MC-INCI-TYPE, MC-INCI-CAUSE, MC-INCI-ACTION, MC-INCI-ACTION-STATUS |
| `DDLs/seeds/bglobal_T061__menu_context_checks.sql` | CHECK constraints para los 4 nuevos menús contextuales |
| `A.65.04_INVENTARIO-MENUS-CONTEXTUALES.md` | Documentar los 4 nuevos MC con Concepto + Valores válidos |
| `A.71_INFORME-CUMPLIMIENTO-ISO27001-2022-v1.0.md` | Actualizar A.5.27: EP(1/3) → P(2/3) o C(3/3) + §3.4 |
| `A.65.03.01.NN` (si aplica) | Si las tablas inc_* se asignan a un dominio de identidad |

**Impacto en score A.71:**  
A.5.27: EP(1/3) → C(3/3) = +2 puntos → score 96+2 = 98/123 = **79.7 %**

---

### T-BACKLOG-002 — Tabla de clasificación formal de información (A.5.12)

**Estado:** PENDIENTE  
**Prioridad:** P1 (ALTO)  
**Control ISO:** A.5.12 — Clasificación de información  
**Gap confirmado por:** Análisis A.71 §3.2.1 — usuario por confirmar en revisión  

**Por qué es un gap:**  
La clasificación existe solo como `COMMENT ON TABLE` en el DDL (marcadores como `IDENTIDAD |`, `PAM JIT |`).
No existe una tabla formal de clasificación ni columna `data_class` en tablas con PII.
Sin tabla formal, no se puede auditar automaticamente qué datos son CONFIDENTIAL vs PUBLIC.

**Diseño propuesto:**

```sql
-- TABLA: catálogo de niveles de clasificación
bauth.cfg_information_classification
  class_id           UUID PK (uuidv7)
  class_code         TEXT NOT NULL UNIQUE    -- MC-INFOCLS: PUBLIC / INTERNAL / CONFIDENTIAL / RESTRICTED
  class_name         JSONB NOT NULL          -- {es: "...", en: "..."}
  retention_days     INTEGER NOT NULL
  masking_required   BOOLEAN NOT NULL DEFAULT false
  encryption_at_rest BOOLEAN NOT NULL DEFAULT false
  handling_rules     JSONB                   -- instrucciones de manejo por nivel
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()

-- COLUMNA ADICIONAL en tablas con PII:
-- idn_identity_entity, idn_user, idn_identidad_atributo, pam_credential_ref...
ALTER TABLE bauth.idn_identity_entity
  ADD COLUMN IF NOT EXISTS data_class TEXT
  REFERENCES bauth.cfg_information_classification(class_code);
```

**Artefactos a actualizar:**

| Artefacto | Acción requerida |
|-----------|-----------------|
| `DDLs/SBOS_db_V2_DDL.sql` | Crear `cfg_information_classification` + ALTER de tablas PII |
| `DDLs/SBOS_db_V2_DDL_MANUAL.md` | Documentar (HITL) |
| `A.65.02` | T-code nuevo para `cfg_information_classification` |
| Seeds T060 | Nuevo ENUM MC-INFOCLS (PUBLIC / INTERNAL / CONFIDENTIAL / RESTRICTED) |
| Seeds T061 | CHECK en columna `data_class` |
| `A.65.04` | Documentar MC-INFOCLS |
| `A.71` | Actualizar A.5.12: P(2/3) → C(3/3) + §3.2.1 |

**Impacto en score A.71:**  
A.5.12: P(2/3) → C(3/3) = +1 punto → score +1

---

### T-BACKLOG-003 — Política de retención y eliminación programada (A.8.10)

**Estado:** PENDIENTE  
**Prioridad:** P2 (MEDIO)  
**Control ISO:** A.8.10 — Eliminación de información  
**Gap confirmado por:** Análisis A.71 §4.2.2 — usuario por confirmar en revisión  

**Por qué es un gap:**  
Las tablas WORM son no-eliminables por diseño (correcto). Pero no existe:
- Una tabla de política de retención que defina cuándo eliminar datos NO-WORM
- Un mecanismo de purga programada (pg_cron job o trigger)
- Cobertura de `idn_identity_requirement.max_age_days` es parcial (solo atributos IAL, no datos generales)

**Diseño preliminar:**

```sql
-- TABLA: políticas de retención por tipo de dato
bauth.cfg_retention_policy
  policy_id    UUID PK
  table_name   TEXT NOT NULL
  column_name  TEXT                  -- NULL = aplica a toda la tabla
  retention_days INTEGER NOT NULL
  purge_action TEXT NOT NULL         -- DELETE / ANONYMIZE / ARCHIVE
  exemption    TEXT                  -- ej: 'WORM' → no aplica purga
  legal_basis  TEXT                  -- referencia normativa (Ley 164, GDPR, etc.)
  is_active    BOOLEAN NOT NULL DEFAULT true
  ctx_id       TEXT NOT NULL
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
```

**Artefactos a actualizar:**

| Artefacto | Acción requerida |
|-----------|-----------------|
| `DDLs/SBOS_db_V2_DDL.sql` | Crear `cfg_retention_policy` |
| `DDLs/SBOS_db_V2_DDL_MANUAL.md` | Documentar (HITL) |
| `A.65.02` | T-code nuevo |
| Seeds T060 | ENUM MC-RETENTION-ACTION (DELETE / ANONYMIZE / ARCHIVE) |
| Seeds T061 | CHECK en `purge_action` |
| `A.65.04` | MC-RETENTION-ACTION con Concepto + Valores |
| `A.71` | Actualizar A.8.10: EP(1/3) → P(2/3) o C(3/3) + §4.2.2 |

**Impacto en score A.71:**  
A.8.10: EP(1/3) → C(3/3) = +2 puntos → score +2

---

### T-BACKLOG-004 — Etiquetado automático de información via trigger (A.5.13)

**Estado:** PENDIENTE  
**Prioridad:** P3 (BAJA)  
**Control ISO:** A.5.13 — Etiquetado de información  
**Dependencia:** REQUIERE T-BACKLOG-002 (tabla `cfg_information_classification` debe existir)  

**Por qué es un gap:**  
Actualmente no existe etiquetado ejecutable — solo comentarios SQL. Las tablas con PII
no tienen columna `data_class` ni trigger que la aplique automáticamente.

**Diseño preliminar:**  
Trigger `BEFORE INSERT OR UPDATE` en tablas con PII que establece `data_class`
según las columnas presentes (si tiene `email` → CONFIDENTIAL, si es catálogo → PUBLIC).

**Artefactos a actualizar:**  
`DDLs/SBOS_db_V2_DDL.sql` (trigger) · `A.71` (A.5.13: EP(1/3) → C(3/3))

---

### T-BACKLOG-005 — Módulo de inteligencia de amenazas (A.5.7)

**Estado:** PENDIENTE  
**Prioridad:** P2 (MEDIO)  
**Control ISO:** A.5.7 — Inteligencia de amenazas  
**Gap confirmado por:** Usuario — 2026-08-01  

**Por qué es un gap real:**  
A.5.7 exige recopilar y analizar información sobre amenazas para producir inteligencia de
seguridad. bAuth ya *consume* señales de amenaza reactivas via CAEP (RFC 9493) — cuando un
proveedor externo notifica que una sesión específica tiene riesgo, bAuth actúa.

Lo que falta es la dimensión **proactiva**: IOCs (Indicators of Compromise) conocidos de
antemano — rangos IP de nodos Tor, dominios de phishing, listas de credenciales brecheadas —
que deben estar en el esquema para que bAuth los consulte en el momento de la autenticación
y aplique controles (block / step-up / monitor) antes de que el ataque ocurra.

bNotify es una herramienta de notificación (envía un mensaje por un medio determinado)
usada por bAuth y otros daemons — NO es el controlador de inteligencia de amenazas.
bAuth es el único daemon que ejecuta decisiones de acceso y por tanto es quien debe
administrar los IOCs y las correlaciones. Sin tabla de IOCs en el esquema de bAuth, los
indicadores de amenaza no pueden consultarse en el pipeline de autenticación.

**Diferencia CAEP vs Threat Intelligence:**

| CAEP (ya implementado) | IOC / Threat Intel (gap) |
|------------------------|--------------------------|
| Reactivo — evento de riesgo sobre sesión activa | Proactivo — indicador conocido antes del intento |
| Viene de proveedor de identidad externo | Viene de feeds CISA / STIX / TAXII / internos |
| Evento puntual sobre un usuario | Indicador que aplica a todo el sistema días/semanas |
| No necesita tabla propia | Necesita tabla de IOCs consultable en auth pipeline |

**Diseño propuesto — 2 tablas, prefijo `thi_`:**

```sql
-- TABLA 1: catálogo de IOCs (Indicators of Compromise)
bauth.thi_indicator
  indicator_id    UUID PK (uuidv7)
  indicator_type  TEXT NOT NULL    -- MC-THI-TYPE: IPv4 / IPv4_RANGE / DOMAIN / EMAIL_DOMAIN / HASH_SHA256 / USER_AGENT
  indicator_value TEXT NOT NULL    -- el valor: "185.220.101.0/24", "evil.com", etc.
  source          TEXT NOT NULL    -- MC-THI-SOURCE: CISA / STIX_TAXII / ISAC / INTERNAL / MANUAL
  confidence      TEXT NOT NULL    -- HIGH / MEDIUM / LOW  [MC-THI-CONFIDENCE]
  category        TEXT NOT NULL    -- MC-THI-CATEGORY: TOR_EXIT / CREDENTIAL_STUFFING / PHISHING / BOTNET / BRUTE_FORCE
  action          TEXT NOT NULL    -- MC-THI-ACTION: BLOCK / REQUIRE_STEP_UP / MONITOR / ALERT_ONLY
  valid_from      TIMESTAMPTZ NOT NULL DEFAULT now()
  valid_until     TIMESTAMPTZ      -- NULL = sin vencimiento; IOCs expiran
  is_active       BOOLEAN NOT NULL DEFAULT true
  notes           TEXT
  ctx_id          TEXT NOT NULL
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()

  CONSTRAINT uq_thi_indicator UNIQUE (indicator_type, indicator_value, source)

-- TABLA 2: log de correlaciones detectadas
bauth.thi_correlation_log
  corr_id          UUID PK (uuidv7)
  indicator_id     UUID FK → bauth.thi_indicator NOT NULL
  tenant_id        UUID FK → bauth.idn_tenant NOT NULL
  auth_attempt_ref UUID FK → bauth.auth_attempt_log  -- evidencia del intento (nullable)
  matched_value    TEXT NOT NULL     -- el valor exacto que coincidió con el IOC
  action_taken     TEXT NOT NULL     -- lo que bAuth hizo: BLOCKED / STEP_UP_FORCED / MONITORED
  entity_id        UUID FK → bauth.idn_identity_entity  -- usuario afectado (nullable si pre-auth)
  ctx_id           TEXT NOT NULL
  detected_at      TIMESTAMPTZ NOT NULL DEFAULT now()
```

**Flujo en el pipeline de autenticación:**

```
1. Intento de login desde IP 185.220.101.45
2. bAuth consulta: SELECT action FROM thi_indicator
   WHERE indicator_type = 'IPv4_RANGE'
     AND '185.220.101.45'::inet <<= indicator_value::inet
     AND is_active = true AND (valid_until IS NULL OR valid_until > now())
   → Encuentra: category='TOR_EXIT', action='REQUIRE_STEP_UP'
3. bAuth fuerza AAL3 antes de continuar
4. Registra correlación en thi_correlation_log con action_taken='STEP_UP_FORCED'
5. Si el usuario no cumple AAL3 → BLOCKED → entra a thi_correlation_log + aud_event_log
```

**Artefactos a actualizar al ejecutar:**

| Artefacto | Acción requerida |
|-----------|-----------------|
| `DDLs/SBOS_db_V2_DDL.sql` | Crear `thi_indicator` + `thi_correlation_log` |
| `DDLs/SBOS_db_V2_DDL_MANUAL.md` | Documentar las 2 tablas (HITL) |
| `A.65.02_ANEXO-NUEVA-DDL-v1.0.md` | T-codes nuevos para `thi_indicator` + `thi_correlation_log` |
| Seeds T060 | ENUMs: MC-THI-TYPE, MC-THI-SOURCE, MC-THI-CONFIDENCE, MC-THI-CATEGORY, MC-THI-ACTION |
| Seeds T061 | CHECK constraints para los 5 nuevos menús contextuales |
| `A.65.04_INVENTARIO-MENUS-CONTEXTUALES.md` | 5 MC-THI-* con Concepto + Valores válidos |
| `A.71_INFORME-CUMPLIMIENTO-ISO27001-2022-v1.0.md` | Actualizar A.5.7: P(2/3) → C(3/3) + §3.1.2 |

**Impacto en score A.71:**  
A.5.7: P(2/3) → C(3/3) = +1 punto → score acumulado +1

---

### T-BACKLOG-006 — Tabla de triaje de eventos de seguridad (A.5.25)

**Estado:** PENDIENTE  
**Prioridad:** P2 (MEDIO)  
**Control ISO:** A.5.25 — Evaluación y decisión de incidentes de seguridad  
**Gap confirmado por:** Usuario — 2026-08-01  
**Dependencia:** T-BACKLOG-001 (`inc_incident` debe existir — `incident_id` FK apunta a ella)

**Por qué es un gap real:**  
A.5.25 exige registrar la **decisión formal de triaje**: quién evaluó un evento sospechoso,
cuándo, y qué decidió (incidente confirmado / falso positivo / en monitoreo).

Las tablas existentes (`ses_caep_event_log`, `auth_attempt_log`, `aud_event_log`) capturan
eventos crudos y procesamiento automático, pero ninguna persiste el proceso de decisión
humana: *"un analista evaluó este evento y determinó que ES/NO ES un incidente de seguridad,
por estas razones"*. Sin eso, A.5.25 no está cubierto.

**Posición en el flujo de incidentes:**

```
[evento crudo]          [triaje — A.5.25]      [incidente — A.5.27]
auth_attempt_log   →    inc_security_event  →   inc_incident
ses_caep_event_log      (decision=CONFIRMED)     inc_root_cause
aud_event_log           (decision=FALSE_POS)     inc_corrective_action
reporte manual          (decision=MONITORING)    inc_effectiveness_review
```

**Diseño propuesto — 1 tabla:**

```sql
-- TABLA: triaje de eventos de seguridad (pre-incidente)
bauth.inc_security_event
  event_id      UUID PK (uuidv7)
  tenant_id     UUID FK → bauth.idn_tenant NOT NULL
  source_table  TEXT NOT NULL    -- MC-INCI-SOURCE-TABLE: ses_caep_event_log / auth_attempt_log /
                                 --   aud_event_log / thi_correlation_log / MANUAL
  source_ref    UUID             -- ID del registro origen (nullable si es reporte manual)
  description   TEXT NOT NULL    -- descripción del evento sospechoso
  assessed_by   UUID FK → bauth.idn_identity_entity   -- analista que evaluó
  assessed_at   TIMESTAMPTZ                            -- cuándo evaluó
  decision      TEXT             -- MC-INCI-DECISION: CONFIRMED / FALSE_POSITIVE /
                                 --   MONITORING / ESCALATED
  severity      TEXT             -- CRITICAL / HIGH / MEDIUM / LOW (si CONFIRMED)
  decision_notes TEXT            -- justificación de la decisión
  incident_id   UUID FK → bauth.inc_incident   -- enlace al incidente (solo si CONFIRMED)
  ctx_id        TEXT NOT NULL
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
```

**Artefactos a actualizar al ejecutar:**

| Artefacto | Acción requerida |
|-----------|-----------------|
| `DDLs/SBOS_db_V2_DDL.sql` | Crear `inc_security_event` |
| `DDLs/SBOS_db_V2_DDL_MANUAL.md` | Documentar (HITL) |
| `A.65.02_ANEXO-NUEVA-DDL-v1.0.md` | T-code nuevo para `inc_security_event` |
| Seeds T060 | ENUMs: MC-INCI-SOURCE-TABLE, MC-INCI-DECISION |
| Seeds T061 | CHECK constraints para los 2 nuevos menús |
| `A.65.04` | 2 MC nuevos con Concepto + Valores válidos |
| `A.71` | Actualizar A.5.25: P(2/3) → C(3/3) + §3.4 |

**Nota:** MC-INCI-DECISION es compartido con T-BACKLOG-001 si `inc_incident` también usa
un campo `decision` — revisar al momento de implementar para no duplicar ENUMs.

**Impacto en score A.71:**  
A.5.25: P(2/3) → C(3/3) = +1 punto → score acumulado +1

---

### T-BACKLOG-007 — Fases de respuesta activa en inc_corrective_action (A.5.26)

**Estado:** PENDIENTE  
**Prioridad:** P2 (MEDIO)  
**Control ISO:** A.5.26 — Respuesta a incidentes de seguridad  
**Gap confirmado por:** Usuario — 2026-08-01  
**Naturaleza:** Extensión de T-BACKLOG-001 — NO es una tabla nueva  
**Dependencia:** T-BACKLOG-001 (`inc_corrective_action` debe existir primero)

**Por qué es un gap real:**  
A.5.26 exige registrar las acciones de respuesta **durante** el incidente activo:
contención (bloquear al atacante), erradicación (eliminar la amenaza) y recuperación
(restaurar operación normal). Las acciones de respuesta en bAuth ya ocurren — revocaciones
en `idn_credencial_revocacion`, kills de sesión vía CAEP, bloqueos de IP en `thi_indicator`
— pero ninguna apunta al incidente que las originó. Sin ese vínculo, no se puede reconstruir
"todo lo que se hizo en respuesta al incidente X".

**Decisión de diseño — extensión, no tabla nueva:**  
`inc_corrective_action` (T-BACKLOG-001) ya captura acciones con responsable, fecha y
estado. Crear una tabla separada para respuesta activa duplicaría estructura idéntica.
La solución correcta es agregar `action_phase` que distingue las dos categorías de acción:

```
A.5.26 — Respuesta activa:     CONTAINMENT · ERADICATION · RECOVERY
A.5.27 — Post-incidente:       CORRECTIVE · TRAINING
```

**Cambio DDL en inc_corrective_action (T-BACKLOG-001):**

```sql
-- Agregar columna action_phase a inc_corrective_action:
action_phase TEXT NOT NULL DEFAULT 'CORRECTIVE'
  CHECK (action_phase IN (
    'CONTAINMENT',   -- detener el avance: revocar sesión, bloquear IP, suspender cuenta
    'ERADICATION',   -- eliminar la amenaza: purgar tokens, limpiar configuración comprometida
    'RECOVERY',      -- restaurar operación: reactivar servicios, validar integridad
    'CORRECTIVE',    -- post-incidente: cambio de política, refuerzo de control
    'TRAINING'       -- capacitación derivada del incidente
  ))
  -- [MC-INCI-ACTION-PHASE] → A.65.04

-- Además: agregar columna de referencia cruzada a acciones automáticas:
linked_revocation_id UUID FK → bauth.idn_credencial_revocacion  -- si CONTAINMENT vía revocación
linked_thi_id        UUID FK → bauth.thi_indicator               -- si CONTAINMENT vía IOC block
```

**Flujo completo del módulo de incidentes con esta extensión:**

```
inc_security_event (T-BACKLOG-006)
  → decision=CONFIRMED → crea inc_incident (T-BACKLOG-001)
       ├── inc_corrective_action phase=CONTAINMENT  → A.5.26 ✅
       ├── inc_corrective_action phase=ERADICATION  → A.5.26 ✅
       ├── inc_corrective_action phase=RECOVERY     → A.5.26 ✅
       ├── inc_root_cause                           → A.5.27 ✅
       ├── inc_corrective_action phase=CORRECTIVE   → A.5.27 ✅
       └── inc_effectiveness_review                 → A.5.27 ✅
```

**Artefactos a actualizar al ejecutar:**

| Artefacto | Acción requerida |
|-----------|-----------------|
| `DDLs/SBOS_db_V2_DDL.sql` | `ALTER TABLE inc_corrective_action ADD COLUMN action_phase TEXT ...` + CHECK |
| `DDLs/SBOS_db_V2_DDL_MANUAL.md` | Documentar `action_phase` + vínculos cruzados (HITL) |
| `A.65.02` | Actualizar entrada T-code de `inc_corrective_action` con nueva columna |
| Seeds T060 | Nuevo ENUM: MC-INCI-ACTION-PHASE (5 valores) |
| Seeds T061 | CHECK en `action_phase` — o ya queda en el DDL como inline CHECK |
| `A.65.04` | MC-INCI-ACTION-PHASE con Concepto + Valores válidos |
| `A.71` | Actualizar A.5.26: P(2/3) → C(3/3) + agregar §3.4.x |

**Impacto en score A.71:**  
A.5.26: P(2/3) → C(3/3) = +1 punto → score acumulado +1

---

### T-BACKLOG-008 — Columnas pii_category + legal_basis en idn_identity_attribute (A.5.34)

**Estado:** PENDIENTE  
**Prioridad:** P2 (MEDIO)  
**Control ISO:** A.5.34 — Privacidad y protección de PII  
**Gap confirmado por:** Usuario — 2026-08-01  
**Naturaleza:** Extensión de T-157 — NO es tabla nueva  

---

**Hallazgos de investigación — qué existe en D00 (evidencia DDL verificada)**

La evaluación inicial P(2/3) subestimó la cobertura real de D00. Investigación sobre el DDL
reveló la siguiente infraestructura de privacidad ya implementada:

| Tabla | T-code | Qué cubre de A.5.34 | WORM | Referencia normativa en DDL |
|-------|--------|---------------------|------|----------------------------|
| `idn_identity_attribute` | T-157 | Inventario de PII por entidad — EAV con namespaces (core, contact, professional, verification, security, fiscal) + campo `source` (employer/government/self/document/biometric) | No (mutable) | ISO 11179, ISO 24760-1, NIST SP 800-63A |
| `idn_identity_attribute_history` | T-158 | Historial WORM append-only de CADA cambio de atributo PII — INSERT/UPDATE/SOFT_DELETE — particionado mensual, hash-chain SHA-256 por (entity_id, attr_namespace, attr_key), as-of queries | ✅ REVOKE UPDATE/DELETE | **GDPR Art.30**, ISO 27001 A.8.15, PCI DSS 4.0.1 Req 10.3.2, NIST AU-9 |
| `idn_roles_ver_b01_retention_policy` | T-154 | Política de retención con `legal_basis TEXT NOT NULL`, `info_class` (C1/C2/C3/C4), `legal_hold BOOLEAN` (suspende purgas por medida cautelar) | No | ISO 27001 A.5.33, NIST AU-11, PCI DSS Req 10.5, SOX-404, **Ley 843 Bolivia Art.44** |
| `idn_roles_ver_b01_audit_log` | T-152 | Historial WORM de versiones de roles con `sys_period TSTZRANGE WITHOUT OVERLAPS` (PG18) | ✅ | ISO 27001 A.8.15 |
| `idn_roles_template_history` | T-163 | Historial WORM de cambios al árbol de políticas T-162 | ✅ REVOKE UPDATE/DELETE | ISO 27001 A.8.15 |
| `idn_roles_rol_lifecycle_event` | T-B02L | Log WORM de transiciones de estado de roles (7 estados), hash-chain | ✅ | ISO 27001 A.8.15 |
| `idn_roles_nhi_lifecycle_event` | T-187 | Log WORM de ciclo de vida de identidades NHI (máquinas/bots) | ✅ | NIST SP 800-53 IA-5(4), ISO 27001 A.8.2 |

**Conclusión de la investigación:**  
La trazabilidad y auditoría de cambios sobre roles, usuarios y entidades está completamente
cubierta por D00. T-158 referencia explícitamente GDPR Art.30 — el diseño ya contempla
obligaciones de privacidad. El campo `source` en T-157 actúa como proxy de base legal:
`employer` = contrato laboral · `government` = obligación legal · `self` = consentimiento ·
`document` = verificación legal.

**Lo que genuinamente falta — solo 2 columnas en T-157:**

`idn_identity_attribute` sabe que un atributo es `email` (por `attr_key`) pero no tiene:
1. **`pii_category`** — categoría formal de PII (EMAIL / PHONE / NID / BIOMETRIC / FINANCIAL / ADDRESS) para poder filtrar, auditar y aplicar masking sin depender de `attr_key` literales
2. **`legal_basis`** — base legal por atributo individual (T-154 ya la tiene para retención a nivel de tabla, pero no a nivel de atributo individual)

La tabla de derechos del titular (`prv_data_subject_request`) fue descartada — en el contexto
boliviano sin marco GDPR equivalente es sobredimensionada; los derechos de acceso y rectificación
están cubiertos por as-of queries sobre T-158.

**Cambio DDL — extensión de T-157:**

```sql
-- Agregar 2 columnas a bauth.idn_identity_attribute (T-157):
ALTER TABLE bauth.idn_identity_attribute
    ADD COLUMN IF NOT EXISTS pii_category TEXT
        CHECK (pii_category IN (
            'EMAIL','PHONE','NID','BIOMETRIC','FINANCIAL',
            'ADDRESS','NAME','DATE_OF_BIRTH','NONE'
        )),  -- [MC-PII-CATEGORY] → A.65.04; NULL = atributo no-PII
    ADD COLUMN IF NOT EXISTS legal_basis TEXT
        CHECK (legal_basis IN (
            'CONTRACT',           -- relación laboral / contractual
            'LEGAL_OBLIGATION',   -- obligación normativa (Ley 164, Ley 843, SIN)
            'LEGITIMATE_INTEREST',-- interés legítimo del responsable
            'CONSENT',            -- consentimiento expreso del titular
            'VITAL_INTEREST'      -- protección de intereses vitales
        ));  -- [MC-PII-LEGAL-BASIS] → A.65.04; NULL = atributo no-PII

-- Comentarios documentales:
COMMENT ON COLUMN bauth.idn_identity_attribute.pii_category IS
'[ISO 27001 A.5.34] Categoría formal de PII del atributo. NULL = no es dato personal.
Usado por bi18n para seleccionar mask_method y por el Motor de Identidad para
aplicar controles de privacidad diferenciados por categoría.';

COMMENT ON COLUMN bauth.idn_identity_attribute.legal_basis IS
'[ISO 27001 A.5.34] [GDPR Art.6] Base legal que justifica el procesamiento de este
atributo PII. CONTRACT = relación laboral. LEGAL_OBLIGATION = Ley 164/Ley 843/SIN.
CONSENT = consentimiento expreso registrado. NULL = atributo no-PII.
Complementa legal_basis de T-154 (retención a nivel de tabla) con granularidad por atributo.';
```

**Artefactos a actualizar al ejecutar:**

| Artefacto | Acción requerida |
|-----------|-----------------|
| `DDLs/SBOS_db_V2_DDL.sql` | `ALTER TABLE idn_identity_attribute ADD COLUMN pii_category + legal_basis` |
| `DDLs/SBOS_db_V2_DDL_MANUAL.md` | Documentar nuevas columnas en sección T-157 (HITL) |
| `A.65.02_ANEXO-NUEVA-DDL-v1.0.md` | Actualizar entrada T-157 con 2 columnas nuevas |
| Seeds T060 | ENUMs: MC-PII-CATEGORY (9 valores) + MC-PII-LEGAL-BASIS (5 valores) |
| Seeds T061 | CHECK constraints de los 2 nuevos menús (o ya quedan inline en el ALTER) |
| `A.65.04` | MC-PII-CATEGORY + MC-PII-LEGAL-BASIS con Concepto + Valores válidos |
| `A.71` | Actualizar A.5.34: P(2/3) → C(3/3) + §3.5 con hallazgos de investigación |

**Nota:** MC-PII-CATEGORY es compartido con el doble árbol de A.8.11
(`idn_identidad_atributo` en dominios D00+). Verificar al implementar si ya existe
un ENUM equivalente en las migrations para no duplicar.

**Impacto en score A.71:**  
A.5.34: P(2/3) → C(3/3) = +1 punto → score acumulado +1

---

### T-BACKLOG-009 — Inventario de componentes y evaluación de impacto CVE (A.8.8)

**Estado:** PENDIENTE  
**Prioridad:** P2 (MEDIO)  
**Control ISO:** A.8.8 — Gestión de vulnerabilidades técnicas  
**Gap confirmado por:** Usuario — 2026-08-01  
**Responsabilidad:** COMPARTIDA bos + bAuth (contrato bilateral)  
**Anexo bos:** `BosAgent/context/Documentacion/Anexos/A.18_ANEXO-GESTION-VULNERABILIDADES-BOS.md`

---

**Hallazgos de investigación — industria (fuentes verificadas 2026)**

| Fuente | Hallazgo clave |
|--------|---------------|
| ISO 27001:2022 A.8.8 + ISMS.online | Exige: inventario de activos software, rastreo de CVEs, SLAs por severidad (CRITICAL=24h / HIGH=7d / MEDIUM=30d / LOW=90d), trazabilidad de remediación |
| Konfirmity / HightTable 2026 | "Los programas de vulnerabilidad fallan cuando hallazgos, propiedad del activo y plazos de remediación viven en herramientas separadas" — la centralización es crítica |
| AWS Shared Responsibility + Wiz | Vulnerabilidades de infraestructura (OS, K8s) = proveedor/plano de control; vulnerabilidades de workload (crates, librerías auth) = equipo dueño del daemon |
| Open Security Architecture SP-038 | Modelo de seis fases: Discover → Prioritize → Assess → Report → Remediate → Verify — ciclo continuo |
| Wiz Academy CVE | "Una vulnerabilidad en un workload con permisos IAM amplios tiene mayor impacto que en un servicio de bajo privilegio" — bAuth, como IAM central, tiene el mayor radio de impacto del ecosistema |

**División de responsabilidades bos ↔ bAuth:**

bos es el plano de control soberano (día 0/1/2): tiene `observer/` (loop DAG topológico),
`reconcile/` (drift detection), `watchdog/` (watchdog daemon), `k8s/` (único dispatcher
kubectl). bos observa continuamente pods, eventos del SO y servidores — es el dueño natural
de vulnerabilidades de infraestructura (OS patches, K8s, PostgreSQL 18, Vault, Redis).

bAuth es dueño de su propio stack de autenticación (Rust 1.85+ crates, librerías OIDC/SAML/
JWT/WebAuthn/mTLS) y es el único daemon que puede evaluar el impacto de una CVE en los 18
métodos de autenticación y tomar acción inmediata (deshabilitar un método comprometido).

| Responsabilidad | Dueño | Tabla |
|----------------|-------|-------|
| Registro central de CVEs del ecosistema | **bos** | `bos.vul_cve_registry` (ver A.18 BosAgent) |
| Inventario de componentes de infraestructura | **bos** | `bos.vul_infra_component` (ver A.18 BosAgent) |
| Inventario de componentes del stack auth | **bAuth** | `bauth.vul_component` ← **este backlog** |
| Evaluación de impacto CVE en métodos auth | **bAuth** | `bauth.vul_auth_impact` ← **este backlog** |

**Flujo de colaboración bos → bAuth (via JSON-RPC):**

```
1. cargo-audit / Trivy detecta CVE en crate de bAuth
2. bos.observer ingresa CVE en bos.vul_cve_registry
3. bos notifica: bauth.vulnerability.notify(cve_id, component, severity)
4. bAuth evalúa impacto en 18 métodos auth
   → INSERT en bauth.vul_auth_impact
5. Si severity=CRITICAL/HIGH → bAuth desactiva método afectado
   → disabled_methods[] + aud_event_log (trazabilidad completa)
6. bAuth responde a bos con resultado de evaluación
7. bos cierra el loop en vul_cve_registry.status='MITIGATED'
```

**Diseño DDL — 2 tablas en schema `bauth`:**

```sql
-- TABLA 1: inventario de componentes del stack de autenticación
bauth.vul_component
  component_id   UUID PK (uuidv7)
  name           TEXT NOT NULL              -- "jsonwebtoken", "ring", "openssl", "rustls"
  component_type TEXT NOT NULL              -- MC-VUL-COMP-TYPE:
                                            -- RUST_CRATE / SYSTEM_LIB / BINARY / CONFIG / PROTOCOL
  version        TEXT NOT NULL              -- versión desplegada actual ("0.11.0")
  source         TEXT NOT NULL DEFAULT 'Cargo.toml'
  is_active      BOOLEAN NOT NULL DEFAULT true
  last_scanned   TIMESTAMPTZ                -- última ejecución de cargo-audit
  scan_tool      TEXT                       -- "cargo-audit" / "trivy" / "snyk"
  ctx_id         TEXT NOT NULL
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
  CONSTRAINT uq_vul_component UNIQUE (name, version)

-- TABLA 2: evaluación de impacto CVE en métodos de autenticación
bauth.vul_auth_impact
  impact_id        UUID PK (uuidv7)
  cve_id           TEXT NOT NULL            -- "CVE-2026-12345" — referencia a bos.vul_cve_registry
  component_id     UUID FK → bauth.vul_component NOT NULL
  affected_methods TEXT[] NOT NULL DEFAULT '{}'
                                            -- métodos auth comprometidos: ['OIDC','SAML','JWT','WEBAUTHN']
  severity         TEXT NOT NULL            -- MC-VUL-SEVERITY: CRITICAL/HIGH/MEDIUM/LOW/INFO
  cvss_score       NUMERIC(3,1)             -- 0.0-10.0 CVSS v3.1
  impact_desc      TEXT NOT NULL            -- descripción del impacto específico en autenticación
  mitigation       TEXT                     -- workaround mientras se parchea
  action_taken     TEXT                     -- MC-VUL-ACTION: DISABLED_METHOD/PATCHED/MITIGATED/ACCEPTED/PENDING
  disabled_methods TEXT[] NOT NULL DEFAULT '{}'
                                            -- métodos desactivados por bAuth como contención
  sla_deadline     TIMESTAMPTZ              -- calculado: detected_at + SLA por severity
  resolved_at      TIMESTAMPTZ
  ctx_id           TEXT NOT NULL
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()

-- SLAs por severidad (codificados como constraint):
-- CRITICAL → +1 día · HIGH → +7 días · MEDIUM → +30 días · LOW → +90 días
```

**SLAs de remediación (industria + ISO 27001 A.8.8):**

| Severidad | CVSS | SLA máximo | Acción automática bAuth |
|-----------|------|-----------|------------------------|
| CRITICAL | 9.0-10.0 | 24 horas | Deshabilitar método auth afectado inmediatamente |
| HIGH | 7.0-8.9 | 7 días | Alerta + step-up forzado en método afectado |
| MEDIUM | 4.0-6.9 | 30 días | Alerta + monitoreo reforzado |
| LOW | 0.1-3.9 | 90 días | Registrar + programar en próximo ciclo de parches |

**Artefactos a actualizar al ejecutar:**

| Artefacto | Acción requerida |
|-----------|-----------------|
| `DDLs/SBOS_db_V2_DDL.sql` | Crear `vul_component` + `vul_auth_impact` en schema `bauth` |
| `DDLs/SBOS_db_V2_DDL_MANUAL.md` | Documentar las 2 tablas (HITL) |
| `A.65.02_ANEXO-NUEVA-DDL-v1.0.md` | T-codes para las 2 tablas nuevas |
| Seeds T060 | ENUMs: MC-VUL-COMP-TYPE, MC-VUL-SEVERITY, MC-VUL-ACTION |
| Seeds T061 | CHECK constraints para los 3 nuevos menús |
| `A.65.04` | 3 MC-VUL-* con Concepto + Valores válidos |
| `A.71` | Actualizar A.8.8: P(2/3) → C(3/3) + §4.2.x con investigación |
| `BOS-BAUTH-CONTRATOS.md` | Formalizar contrato JSON-RPC `bauth.vulnerability.notify` |
| `BosAgent/context/Documentacion/Anexos/A.18_*` | Anexo bos — ya creado en esta sesión |

**Impacto en score A.71:**  
A.8.8: P(2/3) → C(3/3) = +1 punto → score acumulado +1

---

## DISCREPANCIAS PENDIENTES DE REVISIÓN CON EL USUARIO

Las siguientes discrepancias de A.71 NO han sido revisadas todavía.
Para cada una: revisar con el usuario si es gap real, falso positivo, o brecha de documentación.

| # | Control | Estado actual | Descripción breve |
|---|---------|--------------|------------------|
| ~~D-05~~ | ~~A.5.7 (P 2/3)~~ | **→ T-BACKLOG-005** | Gap confirmado — 2 tablas `thi_*`: IOC store + correlation log |
| ~~D-06~~ | ~~A.5.14 (P 2/3)~~ | **→ FALSO POSITIVO → C(3/3)** | Sistema cerrado: daemons en mismo host por Unix socket; biedata es el único punto de salida exterior. ctx_id + aud_event_log cubre lo interno. Actualizar A.71 §3.2.3. |
| ~~D-07~~ | ~~A.5.25 (P 2/3)~~ | **→ T-BACKLOG-006** | Gap confirmado — tabla `inc_security_event`: triaje previo al incidente confirmado (decisión formal CONFIRMED/FALSE_POSITIVE/ESCALATED) |
| ~~D-08~~ | ~~A.5.26 (P 2/3)~~ | **→ T-BACKLOG-007** | Gap confirmado — extensión de `inc_corrective_action` (T-BACKLOG-001): campo `action_phase` que distingue respuesta activa (CONTAINMENT/ERADICATION/RECOVERY) de post-incidente (CORRECTIVE/TRAINING) |
| ~~D-09~~ | ~~A.5.34 (P 2/3)~~ | **→ T-BACKLOG-008** | Gap parcial confirmado — NO es tabla nueva; extensión de T-157 con 2 columnas: `pii_category` + `legal_basis`. D00 ya cubre trazabilidad completa (T-158 WORM+hash-chain, T-154 legal_basis retención, T-163, T-152). |
| ~~D-10~~ | ~~A.8.8 (P 2/3)~~ | **→ T-BACKLOG-009** | Gap compartido bos+bAuth — bAuth: 2 tablas `vul_component` + `vul_auth_impact`; bos: registro central CVEs (ver A.18 BosAgent/Anexos). Ver investigación completa en T-BACKLOG-009. |
| ~~D-11~~ | ~~A.8.9 (P 2/3)~~ | **→ FALSO POSITIVO → C(3/3)** | T-162 ES la config de seguridad; T-163 WORM captura cada cambio con `change_reason` obligatorio + hash-chain SHA-256. Ver A.71 §4.2.3. |
| ~~D-12~~ | ~~A.8.17 (P 2/3)~~ | **→ FALSO POSITIVO → C(3/3)** | Arquitectura de 2 capas documentada en `i18n-orchestrator-rust.md` §10.6.1 (cita A.8.17 explícitamente): `CLOCK_REALTIME` (NTP/chrony UTC real, nunca enmascarado) + capa presentación bi18n (jiff/RegionalConfig/SET timezone per tenant). TIMESTAMPTZ 270+ cols = UTC instantes reales. Ver A.71 §4.3.3. |
| ~~D-13~~ | ~~A.8.25 (P 2/3)~~ | **→ DOCUMENTADO en A.72** | P(2/3) confirmado — 5 de 7 requisitos cubiertos. Gap P2: pipeline CI SAST/DAST/cargo-audit sin automatizar. Documentación SDL consolidada en A.72 (autosuficiente). Ver A.71 §4.6.0. |
| ~~D-14~~ | ~~A.8.28 (P 2/3)~~ | **→ FALSO POSITIVO → C(3/3)** | ISO 27002 A.8.28 exige "principios de codificación segura" (SHALL sobre principios, no herramientas). SAST es guía no normativa. NIST IR 8397: Rust compiler = análisis estático equivalente/superior. Revisor ORQUESTA = code review independiente en cada commit. Ver A.71 §4.6.3. |
| ~~D-15~~ | ~~A.6.5 (EP 1/3)~~ | **→ FALSO POSITIVO → C(3/3)** | Control = A.6.5 (responsabilidades tras cese). Sección faltaba en A.71. bAuth ES el mecanismo de revocación: `status=REVOKED`, revocación <30s, WORM history, CAEP termination, retención Ley 843. Añadido §3.6 + §3.6.1. Ver A.10 (offboarding). |

---

## COMPLETADAS

| Tarea | Control | Resultado | Commit | Fecha |
|-------|---------|-----------|--------|-------|
| A.8.3 RLS → re-evaluado CUMPLIDO | A.8.3 | C(3/3) — 3 capas: tenant_id FK + ctx_id + daemon | `d743494` | 2026-08-01 |
| A.8.11 masking → re-evaluado CUMPLIDO | A.8.11 | C(3/3) — doble árbol + bi18n 8 métodos | `ca47667` | 2026-08-01 |
| A.5.27 → gap CONFIRMADO, diseño propuesto | A.5.27 | En este backlog T-BACKLOG-001 | — | 2026-08-01 |
