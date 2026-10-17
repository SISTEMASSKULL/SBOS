-- seed_cal_schedule.sql — 2 horarios base (Ley General del Trabajo Bolivia)
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: Ley General del Trabajo Bolivia + RFC 7953 (VAVAILABILITY)
-- ═══════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bcalendar.cal_schedule RESTART IDENTITY CASCADE;
REINDEX TABLE bcalendar.cal_schedule;

INSERT INTO bcalendar.cal_schedule (tenant_id, name, days_of_week, start_time, end_time, schedule_type, is_default) VALUES
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'Horario Oficina', '{1,2,3,4,5}', '08:00', '18:00', 'REGULAR', true),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), 'Turnos Rotativos', '{1,2,3,4,5,6,7}', '06:00', '22:00', 'SHIFT', false);

-- SELECT count(*) FROM bcalendar.cal_schedule; -- 2
