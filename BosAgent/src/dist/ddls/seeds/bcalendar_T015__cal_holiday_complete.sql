-- seed_cal_holiday_complete.sql — Calendario Bolivia 2026 por departamento
-- IDEMPOTENTE: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
SET lock_timeout = '5s';
TRUNCATE TABLE bcalendar.cal_holiday RESTART IDENTITY CASCADE;
REINDEX TABLE bcalendar.cal_holiday;

-- Usar tenant_id real desde idn_tenant
INSERT INTO bcalendar.cal_holiday (tenant_id, country_code, region, name, holiday_date, is_recurring, description)
SELECT t.tenant_id, v.country, v.region, v.name, v.hdate::date, v.recur, v.descr
FROM (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull' LIMIT 1) t,
(VALUES
  -- NACIONALES
  ('BO',NULL,'Año Nuevo','2026-01-01',true,'Feriado nacional. Ley 601.'),
  ('BO',NULL,'Día del Estado Plurinacional','2026-01-22',true,'Aniversario del Estado Plurinacional.'),
  ('BO',NULL,'Carnaval','2026-02-16',true,'Feriado de Carnaval.'),
  ('BO',NULL,'Carnaval','2026-02-17',true,'Feriado de Carnaval.'),
  ('BO',NULL,'Viernes Santo','2026-04-03',true,'Feriado religioso nacional.'),
  ('BO',NULL,'Día del Trabajo','2026-05-01',true,'Día Internacional del Trabajo.'),
  ('BO',NULL,'Corpus Christi','2026-06-04',true,'Feriado religioso nacional.'),
  ('BO',NULL,'Año Nuevo Andino','2026-06-21',true,'Willka Kuti. DS 173.'),
  ('BO',NULL,'Día de la Independencia','2026-08-06',true,'Independencia de Bolivia (1825).'),
  ('BO',NULL,'Todos los Santos','2026-11-02',true,'Feriado religioso nacional.'),
  ('BO',NULL,'Navidad','2026-12-25',true,'Feriado religioso nacional.'),
  -- DEPARTAMENTALES
  ('BO','LP','Aniversario de La Paz','2026-07-16',true,'Gesta libertaria de La Paz (1809).'),
  ('BO','LP','Día del Mar','2026-03-23',true,'Feriado departamental LP.'),
  ('BO','CB','Aniversario de Cochabamba','2026-09-14',true,'Gesta libertaria de Cochabamba (1810).'),
  ('BO','CB','Virgen de Urkupiña','2026-08-15',true,'Fiesta de la Virgen de Urkupiña.'),
  ('BO','SC','Aniversario de Santa Cruz','2026-09-24',true,'Gesta libertaria de Santa Cruz (1810).'),
  ('BO','SC','Tradición Cruceña','2026-11-25',true,'Feriado departamental SC.'),
  ('BO','OR','Aniversario de Oruro','2026-02-10',true,'Gesta libertaria de Oruro (1781).'),
  ('BO','OR','Sábado de Peregrinación','2026-02-14',true,'Peregrinación Virgen del Socavón.'),
  ('BO','PT','Aniversario de Potosí','2026-11-10',true,'Gesta libertaria de Potosí (1810).'),
  ('BO','TJ','Aniversario de Tarija','2026-04-15',true,'Gesta libertaria de Tarija (1817).'),
  ('BO','TJ','San Roque','2026-08-16',true,'Fiesta de San Roque.'),
  ('BO','CH','Aniversario de Chuquisaca','2026-05-25',true,'Primer Grito Libertario (1809).'),
  ('BO','CH','Virgen de Guadalupe','2026-09-08',true,'Fiesta de la Virgen de Guadalupe.'),
  ('BO','BE','Aniversario del Beni','2026-11-18',true,'Creación del Beni (1842).'),
  ('BO','PD','Aniversario de Pando','2026-09-24',true,'Creación de Pando (1938).'),
  -- NO LABORALES
  ('BO',NULL,'Jueves Santo','2026-04-02',true,'Medio día sector público.'),
  ('BO',NULL,'Sábado Santo','2026-04-04',true,'No laborable sector público.'),
  ('BO',NULL,'Navidad (víspera)','2026-12-24',true,'Medio día sector público.'),
  -- REGIONALES
  ('BO','LP','Señor de la Exaltación','2026-09-14',true,'Regional LP.'),
  ('BO','CB','San Lorenzo','2026-08-10',true,'Regional CB.'),
  ('BO','SC','San Juan','2026-06-24',true,'Regional SC.'),
  ('BO','OR','Virgen del Socavón','2026-02-15',true,'Entrada Folklórica. Oruro.'),
  ('BO','TJ','San Bernardo','2026-05-15',true,'Regional TJ.'),
  ('BO','PT','Virgen del Rosario','2026-10-07',true,'Regional PT.')
) AS v(country, region, name, hdate, recur, descr)
ON CONFLICT DO NOTHING;
