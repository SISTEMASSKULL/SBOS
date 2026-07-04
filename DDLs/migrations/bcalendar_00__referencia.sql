-- ============================================================================
-- bcalendar — Calendario fiscal multi-nivel (RFC 5545/4791/7953)
-- REFERENCIA DE LECTURA — ESTE ARCHIVO NO CREA NADA (solo comentarios).
-- ============================================================================
-- Años fiscales, calendarios, eventos, alarmas, feriados, horarios, horas extra y descansos.
--
-- Las 9 tablas del schema 'bcalendar' NO se declaran aquí: están declaradas
-- en la DDL principal UNIDA  →  migrations/sbos_00__esquema_base.sql
--
-- ¿POR QUÉ no están separadas en este archivo?
-- Porque bglobal, bcalendar y bauth tienen CLAVES FORÁNEAS CIRCULARES entre sí:
--   · bcalendar.cal_*  y  bglobal.menu_*   →  REFERENCES bauth.idn_tenant
--   · bauth.*                              →  REFERENCES bglobal.global_country
-- No existe un orden 'un schema completo, luego el siguiente' que satisfaga el
-- ciclo: siempre queda una FK apuntando a un schema aún no creado. Separarlas
-- físicamente produjo 60 errores (verificado en BD auxiliar). Por eso la DDL
-- principal se mantiene UNIDA, con el orden entrelazado que sí resuelve las FK.
--
-- Este archivo cumple la convención (un archivo por servicio) como PUNTERO de
-- lectura: dónde está cada tabla, qué contiene, cuántos registros y un ejemplo
-- real. Cargarlo con inicializar_sbos_db.sh no ejecuta nada (todo es comentario).
-- ============================================================================

-- ── bcalendar.cal_alarm ────────────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 1745
--   Propósito:     [RFC 5545 VALARM] Disparador de notificación. Define CUÁNDO (trigger_seconds antes del evento) y CÓMO (channel). El motor de notificaciones (Novu) consulta alar…
--   Registros (BD real):  0   (aún sin datos)
--   Columnas (12): alarm_id, event_id, trigger_seconds, channel, template_ref, recipient_id, is_active, last_triggered_at, next_trigger_at, ctx_id, created_at, updated_at
--   Índices (1): idx_cal_next_trigger

-- ── bcalendar.cal_break_policy ─────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 4435
--   Propósito:     [D4 Temporal] Políticas de descansos: almuerzo, breaks cortos, auto-logout durante descanso.
--   Registros (BD real):  0   (aún sin datos)
--   Columnas (13): policy_id, tenant_id, lunch_required, lunch_duration_minutes, lunch_window_start, lunch_window_end, short_breaks_allowed, short_break_minutes, auto_logout_during_break, session_pause_during, is_active, ctx_id…

-- ── bcalendar.cal_calendar ─────────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 1677
--   Propósito:     [RFC 4791 VCALENDAR] Colección de calendarios. Tipos: WORK, FISCAL, PROCESS, COMPLIANCE, HOLIDAY, MAINTENANCE. Un tenant puede tener N calendarios. is_system=tr…
--   Registros (BD real):  0   (aún sin datos)
--   Columnas (13): calendar_id, tenant_id, name, calendar_type, description, color, timezone, is_system, is_active, metadata, ctx_id, created_at…
--   Índices (1): idx_ccal_tenant

-- ── bcalendar.cal_event ────────────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 1708
--   Propósito:     [RFC 5545 VEVENT] Evento maestro. rrule TEXT sin expandir (FREQ=WEEKLY;BYDAY=MO,WE,FR). Una serie completa = 1 registro. Las ocurrencias se materializan on-dema…
--   Registros (BD real):  0   (aún sin datos)
--   Columnas (19): event_id, calendar_id, title, description, dtstart, dtend, duration_minutes, is_all_day, rrule, exdate, until_date, count_occurrences…
--   Índices (3): idx_cev_calendar, idx_cev_dtstart, idx_cev_rrule

-- ── bcalendar.cal_fiscal_year ──────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 1556
--   Propósito:     [SIN Bolivia] [NIC 1/IAS 1] [NIC 8/IAS 8] [IAS 10] [ISO 27001 A.8.15] Gestión multigestión: años fiscales con 12 períodos contables mensuales. Permite operar en…
--   Registros (BD real):  0   (aún sin datos)
--   Columnas (17): fiscal_year_id, tenant_id, company_id, fiscal_year, name, status, start_date, end_date, closed_by, closed_at, periods, is_current…
--   Índices (4): idx_cfy_company, idx_cfy_current, idx_cfy_status, idx_cfy_tenant

-- ── bcalendar.cal_holiday ──────────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 1804
--   Propósito:     Feriados fijos (Navidad=12-25) y móviles (Pascua por fórmula de Gauss). Por país/región/tenant. is_recurring=true → se repite cada año.
--   Registros (BD real):  0   (aún sin datos)
--   Columnas (11): holiday_id, tenant_id, name, holiday_date, is_recurring, country_code, region, description, ctx_id, created_at, updated_at
--   Índices (1): idx_chol_tenant

-- ── bcalendar.cal_notification_log ─────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 1776
--   Propósito:     [ISO 27001 A.8.15] [WORM] Registro inmutable de notificaciones enviadas. Solo INSERT permitido. REVOKE UPDATE/DELETE. ctx_id obligatorio.
--   Registros (BD real):  0   (aún sin datos)
--   Columnas (10): notification_id, alarm_id, event_id, channel, recipient_id, template_used, outcome, error_message, sent_at, ctx_id
--   Índices (2): idx_cnl_alarm, idx_cnl_ctx

-- ── bcalendar.cal_overtime_policy ──────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 4416
--   Propósito:     [D4 Temporal] Políticas de horas extra: máximos diarios/semanales, tasas multiplicadoras, aprobación requerida. Ley General del Trabajo Bolivia.
--   Registros (BD real):  0   (aún sin datos)
--   Columnas (12): policy_id, tenant_id, max_daily_hours, max_weekly_hours, rate_multiplier, night_shift_rate, holiday_rate, requires_approval, approver_roles, is_active, ctx_id, created_at

-- ── bcalendar.cal_schedule ─────────────────────────────────────────────
--   Declarada en:  sbos_00__esquema_base.sql  ·  línea 1830
--   Propósito:     [RFC 7953 VAVAILABILITY] Horarios de trabajo y turnos. Reemplaza bos_schedule. Heredable: se asigna vía idn_calendar_assignment a tenant/empresa/sucursal. acces…
--   Registros (BD real):  0   (aún sin datos)
--   Columnas (13): schedule_id, tenant_id, name, days_of_week, start_time, end_time, schedule_type, shifts, access_outside_schedule, is_default, ctx_id, created_at…
--   Índices (1): idx_csch_tenant

