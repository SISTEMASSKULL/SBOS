-- seed_cal_calendar.sql — 6 calendarios del sistema por tenant
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: BAUTH-CALENDAR-SUBSYSTEM.md · RFC 4791 (VCALENDAR)
-- ═══════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bcalendar.cal_calendar RESTART IDENTITY CASCADE;
REINDEX TABLE bcalendar.cal_calendar;

INSERT INTO bcalendar.cal_calendar (tenant_id, name, calendar_type, description, color, timezone, is_system, is_active) VALUES
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), 'Laboral',    'WORK',        'Calendario laboral estándar. Lunes a Viernes.', '#1a73e8', 'America/La_Paz', true, true),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), 'Fiscal',     'FISCAL',      'Calendario fiscal SIN Bolivia. Cierres, declaraciones.', '#34a853', 'America/La_Paz', true, true),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), 'Procesos',   'PROCESS',     'Calendario de procesos internos y flujos de trabajo.', '#fbbc04', 'America/La_Paz', true, true),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), 'Cumplimiento','COMPLIANCE',  'Auditorías, certificaciones, revisiones ISO 27001.', '#ea4335', 'America/La_Paz', true, true),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), 'Feriados',   'HOLIDAY',     'Feriados nacionales Bolivia + regionales.', '#9c27b0', 'America/La_Paz', true, true),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1), 'Mantenimiento','MAINTENANCE','Ventanas de mantenimiento programado.', '#ff6d01', 'America/La_Paz', true, true);

-- SELECT count(*) FROM bcalendar.cal_calendar; -- debe ser 6
