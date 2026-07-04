-- ============================================================
-- SEED 050: Datos geográficos ISO
-- Tablas: bos_pais (ISO 3166-1), bos_moneda (ISO 4217),
--         bos_idioma (ISO 639), bos_timezone (IANA TZ)
-- IDEMPOTENTE: ON CONFLICT DO NOTHING
-- ============================================================

INSERT INTO bauth.bos_pais (codice_iso_alfa2, codice_iso_alfa3, codice_iso_num, nombre_es, nombre_en, continente, region, flag_emoji, codigo_telefonico) VALUES
('BO','BOL',068,'Bolivia','Bolivia','América del Sur','LATAM','🇧🇴','+591'),
('AR','ARG',032,'Argentina','Argentina','América del Sur','LATAM','🇦🇷','+54'),
('BR','BRA',076,'Brasil','Brazil','América del Sur','LATAM','🇧🇷','+55'),
('CL','CHL',152,'Chile','Chile','América del Sur','LATAM','🇨🇱','+56'),
('PE','PER',604,'Perú','Peru','América del Sur','LATAM','🇵🇪','+51'),
('CO','COL',170,'Colombia','Colombia','América del Sur','LATAM','🇨🇴','+57'),
('MX','MEX',484,'México','Mexico','América del Norte','LATAM','🇲🇽','+52'),
('US','USA',840,'Estados Unidos','United States','América del Norte','NA','🇺🇸','+1'),
('CN','CHN',156,'China','China','Asia','APAC','🇨🇳','+86'),
('ES','ESP',724,'España','Spain','Europa','EMEA','🇪🇸','+34'),
('PT','PRT',620,'Portugal','Portugal','Europa','EMEA','🇵🇹','+351'),
('DE','DEU',276,'Alemania','Germany','Europa','EMEA','🇩🇪','+49'),
('JP','JPN',392,'Japón','Japan','Asia','APAC','🇯🇵','+81'),
('KR','KOR',410,'Corea del Sur','South Korea','Asia','APAC','🇰🇷','+82'),
('IN','IND',356,'India','India','Asia','APAC','🇮🇳','+91')
ON CONFLICT DO NOTHING;

-- Monedas (ISO 4217)

INSERT INTO bauth.bos_moneda (codice_iso, codice_num, nombre_es, nombre_en, simbolo, simbolo_int, precision, pais_emisor) VALUES
('BOB',068,'Boliviano','Bolivian Boliviano','Bs.','BOB',2,'BO'),
('USD',840,'Dólar estadounidense','US Dollar','$','USD',2,'US'),
('EUR',978,'Euro','Euro','€','EUR',2,'DE'),
('CNY',156,'Yuan chino','Chinese Yuan','¥','CNY',2,'CN'),
('BRL',986,'Real brasileño','Brazilian Real','R$','BRL',2,'BR'),
('ARS',032,'Peso argentino','Argentine Peso','ARS$','ARS',2,'AR'),
('CLP',152,'Peso chileno','Chilean Peso','CLP$','CLP',0,'CL'),
('PEN',604,'Sol peruano','Peruvian Sol','S/.','PEN',2,'PE'),
('COP',170,'Peso colombiano','Colombian Peso','COL$','COP',0,'CO'),
('MXN',484,'Peso mexicano','Mexican Peso','MEX$','MXN',2,'MX'),
('JPY',392,'Yen japonés','Japanese Yen','¥','JPY',0,'JP'),
('INR',356,'Rupia india','Indian Rupee','₹','INR',2,'IN')
ON CONFLICT DO NOTHING;

-- Idiomas (BCP 47)

INSERT INTO bauth.bos_idioma (locale, codice_iso_639_1, codice_iso_639_2, nombre_nativo, nombre_es, direccion_texto, flag_emoji) VALUES
('es-BO','es','spa','Español (Bolivia)','Español (Bolivia)','LTR','🇧🇴'),
('es-AR','es','spa','Español (Argentina)','Español (Argentina)','LTR','🇦🇷'),
('es-MX','es','spa','Español (México)','Español (México)','LTR','🇲🇽'),
('en-US','en','eng','English (US)','Inglés (EEUU)','LTR','🇺🇸'),
('pt-BR','pt','por','Português (Brasil)','Portugués (Brasil)','LTR','🇧🇷'),
('zh-CN','zh','zho','中文 (简体)','Chino (Simplificado)','LTR','🇨🇳'),
('qu-BO','qu','que','Quechua (Bolivia)','Quechua (Bolivia)','LTR','🇧🇴'),
('ay-BO','ay','aym','Aymara (Bolivia)','Aymara (Bolivia)','LTR','🇧🇴'),
('ja-JP','ja','jpn','日本語','Japonés','LTR','🇯🇵'),
('de-DE','de','deu','Deutsch','Alemán','LTR','🇩🇪'),
('ar-SA','ar','ara','العربية','Árabe','RTL','🇸🇦')
ON CONFLICT DO NOTHING;

-- Zonas Horarias (IANA TZ)

INSERT INTO bauth.bos_timezone (timezone_id, nombre_es, utc_offset, utc_offset_min, observa_dst, pais, ciudad_principal) VALUES
('America/La_Paz','Bolivia (La Paz)','-04:00',-240,false,'BO','La Paz'),
('America/Argentina/Buenos_Aires','Argentina (Buenos Aires)','-03:00',-180,false,'AR','Buenos Aires'),
('America/Santiago','Chile (Santiago)','-04:00',-240,true,'CL','Santiago'),
('America/Lima','Perú (Lima)','-05:00',-300,false,'PE','Lima'),
('America/Bogota','Colombia (Bogotá)','-05:00',-300,false,'CO','Bogotá'),
('America/Mexico_City','México (Ciudad de México)','-06:00',-360,true,'MX','Ciudad de México'),
('America/New_York','EEUU (Nueva York)','-05:00',-300,true,'US','Nueva York'),
('America/Sao_Paulo','Brasil (São Paulo)','-03:00',-180,true,'BR','São Paulo'),
('Asia/Shanghai','China (Shanghái)','+08:00',480,false,'CN','Shanghái'),
('Europe/Madrid','España (Madrid)','+01:00',60,true,'ES','Madrid'),
('Europe/Berlin','Alemania (Berlín)','+01:00',60,true,'DE','Berlín'),
('Asia/Tokyo','Japón (Tokio)','+09:00',540,false,'JP','Tokio'),
('Asia/Kolkata','India (Kolkata)','+05:30',330,false,'IN','Kolkata')
ON CONFLICT DO NOTHING;

-- Tipos de transacciones financieras
