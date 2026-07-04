-- seed_ath_policy_d4.sql — Políticas D4 Temporal
SET lock_timeout = '5s'; TRUNCATE TABLE bauth.ath_policy_d4 RESTART IDENTITY CASCADE; REINDEX TABLE bauth.ath_policy_d4;
INSERT INTO bauth.ath_policy_d4 (policy_code, policy_name, description, standard_ref, config) VALUES
('SCHEDULE_OFFICE_HOURS','Horario de oficina Lun-Vie 8-18','Acceso solo en días laborales con horario de oficina estándar. Feriados: bloqueado.','{RFC 5545,ISO 8601}','{"rule":"schedule","type":"SPECIFIC_DAYS","days":["MON-FRI"],"hours":"08:00-18:00","holidays":"BLOCKED"}'),
('SCHEDULE_24X7','Acceso 24x7','Acceso sin restricción horaria. Para guardias y administradores.','{RFC 5545}','{"rule":"schedule","type":"FULL_WEEK","holidays":"ALLOWED"}'),
('OVERTIME_MAX_4H','Horas extra máx 4h/día','Máximo 4 horas extra por día, 20 por semana. Tasa 1.5x. Requiere aprobación.','{Ley General del Trabajo Bolivia}','{"rule":"overtime","max_daily_hours":4,"max_weekly_hours":20,"rate_multiplier":1.5,"requires_approval":true}'),
('BREAK_LUNCH_60MIN','Almuerzo 60 minutos','Almuerzo obligatorio de 60min entre 12:00-14:00. 2 breaks cortos de 15min.','{Ley General del Trabajo Bolivia}','{"rule":"breaks","lunch_required":true,"lunch_duration":60,"lunch_window":"12:00-14:00","short_breaks":2,"short_break_duration":15}'),
('SESSION_TIMEOUT_8H','Sesión máxima 8 horas','Duración máxima de sesión laboral. Force logout al fin del turno.','{NIST SP 800-63B-4 §7}','{"rule":"session_timeout","max_seconds":28800,"force_logout_end_shift":true}');
