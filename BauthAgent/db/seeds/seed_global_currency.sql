-- seed_global_currency.sql — 43 monedas ISO 4217 + criptomonedas
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: ISO 4217:2015 (SIX Interbank Clearing)
-- PostgreSQL 18.4: uuidv7(), skip scan indexes, GIN sobre JSONB
-- ═══════════════════════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bglobal.global_currency RESTART IDENTITY CASCADE;
REINDEX TABLE bglobal.global_currency;

-- ═══════════════════════════════════════════════════════════════════════════
-- SEED: bglobal.global_currency
-- Orden: LATAM → Norteamérica → Europa → Asia → Oceanía → África → Cripto
-- ═══════════════════════════════════════════════════════════════════════════

INSERT INTO bglobal.global_currency (
    currency_code, iso_numeric, name, symbol, symbol_intl,
    decimal_places, minor_unit_name,
    issuer_country, country_id,
    is_active, is_cryptocurrency, exchange_rate_api
) VALUES

-- ═══════════════════════════════════════════════════════════════
-- LATAM
-- ═══════════════════════════════════════════════════════════════
('BOB',068,'{"es":{"singular":"Boliviano","plural":"Bolivianos"},"en":{"singular":"Bolivian Boliviano","plural":"Bolivian Bolivianos"}}',
 'Bs.','BOB',2,'centavo','BO',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='BO'),true,false,'https://www.bcb.gob.bo/'),

('ARS',032,'{"es":{"singular":"Peso argentino","plural":"Pesos argentinos"},"en":{"singular":"Argentine Peso","plural":"Argentine Pesos"}}',
 '$','ARS',2,'centavo','AR',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='AR'),true,false,'https://www.bcra.gob.ar/'),

('BRL',986,'{"es":{"singular":"Real brasileño","plural":"Reales brasileños"},"en":{"singular":"Brazilian Real","plural":"Brazilian Reais"}}',
 'R$','BRL',2,'centavo','BR',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='BR'),true,false,'https://www.bcb.gov.br/'),

('CLP',152,'{"es":{"singular":"Peso chileno","plural":"Pesos chilenos"},"en":{"singular":"Chilean Peso","plural":"Chilean Pesos"}}',
 '$','CLP',0,NULL,'CL',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='CL'),true,false,'https://www.bcentral.cl/'),

('PEN',604,'{"es":{"singular":"Sol peruano","plural":"Soles peruanos"},"en":{"singular":"Peruvian Sol","plural":"Peruvian Soles"}}',
 'S/','PEN',2,'céntimo','PE',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='PE'),true,false,'https://www.bcrp.gob.pe/'),

('COP',170,'{"es":{"singular":"Peso colombiano","plural":"Pesos colombianos"},"en":{"singular":"Colombian Peso","plural":"Colombian Pesos"}}',
 '$','COP',2,'centavo','CO',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='CO'),true,false,'https://www.banrep.gov.co/'),

('MXN',484,'{"es":{"singular":"Peso mexicano","plural":"Pesos mexicanos"},"en":{"singular":"Mexican Peso","plural":"Mexican Pesos"}}',
 '$','MXN',2,'centavo','MX',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='MX'),true,false,'https://www.banxico.org.mx/'),

('UYU',858,'{"es":{"singular":"Peso uruguayo","plural":"Pesos uruguayos"},"en":{"singular":"Uruguayan Peso","plural":"Uruguayan Pesos"}}',
 '$','UYU',2,'centésimo','UY',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='UY'),true,false,NULL),

('PYG',600,'{"es":{"singular":"Guaraní paraguayo","plural":"Guaraníes paraguayos"},"en":{"singular":"Paraguayan Guarani","plural":"Paraguayan Guaranies"}}',
 '₲','PYG',0,NULL,'PY',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='PY'),true,false,NULL),

('VES',928,'{"es":{"singular":"Bolívar digital","plural":"Bolívares digitales"},"en":{"singular":"Digital Bolívar","plural":"Digital Bolívars"}}',
 'Bs.D','VES',2,'céntimo','VE',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='VE'),true,false,NULL),

('CRC',188,'{"es":{"singular":"Colón costarricense","plural":"Colones costarricenses"},"en":{"singular":"Costa Rican Colón","plural":"Costa Rican Colones"}}',
 '₡','CRC',2,'céntimo','CR',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='CR'),true,false,NULL),

('GTQ',320,'{"es":{"singular":"Quetzal guatemalteco","plural":"Quetzales guatemaltecos"},"en":{"singular":"Guatemalan Quetzal","plural":"Guatemalan Quetzales"}}',
 'Q','GTQ',2,'centavo','GT',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='GT'),true,false,NULL),

-- ═══════════════════════════════════════════════════════════════
-- NORTEAMÉRICA
-- ═══════════════════════════════════════════════════════════════
('USD',840,'{"es":{"singular":"Dólar estadounidense","plural":"Dólares estadounidenses"},"en":{"singular":"United States Dollar","plural":"United States Dollars"}}',
 '$','USD',2,'cent','US',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='US'),true,false,'https://www.federalreserve.gov/'),

('CAD',124,'{"es":{"singular":"Dólar canadiense","plural":"Dólares canadienses"},"en":{"singular":"Canadian Dollar","plural":"Canadian Dollars"}}',
 '$','CAD',2,'cent','CA',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='CA'),true,false,NULL),

-- ═══════════════════════════════════════════════════════════════
-- EUROPA
-- ═══════════════════════════════════════════════════════════════
('EUR',978,'{"es":{"singular":"Euro","plural":"Euros"},"en":{"singular":"Euro","plural":"Euros"}}',
 '€','EUR',2,'cent','EU',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='DE'),true,false,'https://www.ecb.europa.eu/'),

('GBP',826,'{"es":{"singular":"Libra esterlina","plural":"Libras esterlinas"},"en":{"singular":"Pound Sterling","plural":"Pounds Sterling"}}',
 '£','GBP',2,'penny','GB',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='GB'),true,false,'https://www.bankofengland.co.uk/'),

('CHF',756,'{"es":{"singular":"Franco suizo","plural":"Francos suizos"},"en":{"singular":"Swiss Franc","plural":"Swiss Francs"}}',
 'Fr','CHF',2,'rappen','CH',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='CH'),true,false,NULL),

('SEK',752,'{"es":{"singular":"Corona sueca","plural":"Coronas suecas"},"en":{"singular":"Swedish Krona","plural":"Swedish Kronor"}}',
 'kr','SEK',2,'öre','SE',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='SE'),true,false,NULL),

('NOK',578,'{"es":{"singular":"Corona noruega","plural":"Coronas noruegas"},"en":{"singular":"Norwegian Krone","plural":"Norwegian Kroner"}}',
 'kr','NOK',2,'øre','NO',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='NO'),true,false,NULL),

('DKK',208,'{"es":{"singular":"Corona danesa","plural":"Coronas danesas"},"en":{"singular":"Danish Krone","plural":"Danish Kroner"}}',
 'kr','DKK',2,'øre','DK',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='DK'),true,false,NULL),

('PLN',985,'{"es":{"singular":"Złoty polaco","plural":"Złotys polacos"},"en":{"singular":"Polish Zloty","plural":"Polish Zlotys"}}',
 'zł','PLN',2,'grosz','PL',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='PL'),true,false,NULL),

('RUB',643,'{"es":{"singular":"Rublo ruso","plural":"Rublos rusos"},"en":{"singular":"Russian Ruble","plural":"Russian Rubles"}}',
 '₽','RUB',2,'kopek','RU',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='RU'),true,false,NULL),

('TRY',949,'{"es":{"singular":"Lira turca","plural":"Liras turcas"},"en":{"singular":"Turkish Lira","plural":"Turkish Liras"}}',
 '₺','TRY',2,'kuruş','TR',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='TR'),true,false,NULL),

-- ═══════════════════════════════════════════════════════════════
-- ASIA
-- ═══════════════════════════════════════════════════════════════
('CNY',156,'{"es":{"singular":"Yuan renminbi","plural":"Yuanes renminbi"},"en":{"singular":"Chinese Yuan","plural":"Chinese Yuan"}}',
 '¥','CNY',2,'jiao','CN',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='CN'),true,false,'https://www.pbc.gov.cn/'),

('JPY',392,'{"es":{"singular":"Yen japonés","plural":"Yenes japoneses"},"en":{"singular":"Japanese Yen","plural":"Japanese Yen"}}',
 '¥','JPY',0,NULL,'JP',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='JP'),true,false,'https://www.boj.or.jp/'),

('KRW',410,'{"es":{"singular":"Won surcoreano","plural":"Wones surcoreanos"},"en":{"singular":"South Korean Won","plural":"South Korean Won"}}',
 '₩','KRW',0,NULL,'KR',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='KR'),true,false,NULL),

('INR',356,'{"es":{"singular":"Rupia india","plural":"Rupias indias"},"en":{"singular":"Indian Rupee","plural":"Indian Rupees"}}',
 '₹','INR',2,'paisa','IN',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='IN'),true,false,'https://www.rbi.org.in/'),

('SGD',702,'{"es":{"singular":"Dólar de Singapur","plural":"Dólares de Singapur"},"en":{"singular":"Singapore Dollar","plural":"Singapore Dollars"}}',
 '$','SGD',2,'cent','SG',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='SG'),true,false,NULL),

('HKD',344,'{"es":{"singular":"Dólar de Hong Kong","plural":"Dólares de Hong Kong"},"en":{"singular":"Hong Kong Dollar","plural":"Hong Kong Dollars"}}',
 '$','HKD',2,'cent','HK',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='HK'),true,false,NULL),

('TWD',901,'{"es":{"singular":"Nuevo dólar taiwanés","plural":"Nuevos dólares taiwaneses"},"en":{"singular":"New Taiwan Dollar","plural":"New Taiwan Dollars"}}',
 '$','TWD',2,'cent','TW',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='TW'),true,false,NULL),

('AED',784,'{"es":{"singular":"Dírham de los EAU","plural":"Dírhams de los EAU"},"en":{"singular":"UAE Dirham","plural":"UAE Dirhams"}}',
 'د.إ','AED',2,'fils','AE',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='AE'),true,false,NULL),

('SAR',682,'{"es":{"singular":"Riyal saudí","plural":"Riyales saudíes"},"en":{"singular":"Saudi Riyal","plural":"Saudi Riyals"}}',
 '﷼','SAR',2,'halala','SA',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='SA'),true,false,NULL),

('THB',764,'{"es":{"singular":"Baht tailandés","plural":"Bahts tailandeses"},"en":{"singular":"Thai Baht","plural":"Thai Baht"}}',
 '฿','THB',2,'satang','TH',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='TH'),true,false,NULL),

('MYR',458,'{"es":{"singular":"Ringgit malayo","plural":"Ringgits malayos"},"en":{"singular":"Malaysian Ringgit","plural":"Malaysian Ringgits"}}',
 'RM','MYR',2,'sen','MY',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='MY'),true,false,NULL),

('IDR',360,'{"es":{"singular":"Rupia indonesia","plural":"Rupias indonesias"},"en":{"singular":"Indonesian Rupiah","plural":"Indonesian Rupiahs"}}',
 'Rp','IDR',2,'sen','ID',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='ID'),true,false,NULL),

('VND',704,'{"es":{"singular":"Dong vietnamita","plural":"Dongs vietnamitas"},"en":{"singular":"Vietnamese Dong","plural":"Vietnamese Dong"}}',
 '₫','VND',0,NULL,'VN',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='VN'),true,false,NULL),

-- ═══════════════════════════════════════════════════════════════
-- OCEANÍA
-- ═══════════════════════════════════════════════════════════════
('AUD',036,'{"es":{"singular":"Dólar australiano","plural":"Dólares australianos"},"en":{"singular":"Australian Dollar","plural":"Australian Dollars"}}',
 '$','AUD',2,'cent','AU',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='AU'),true,false,'https://www.rba.gov.au/'),

('NZD',554,'{"es":{"singular":"Dólar neozelandés","plural":"Dólares neozelandeses"},"en":{"singular":"New Zealand Dollar","plural":"New Zealand Dollars"}}',
 '$','NZD',2,'cent','NZ',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='NZ'),true,false,NULL),

-- ═══════════════════════════════════════════════════════════════
-- ÁFRICA
-- ═══════════════════════════════════════════════════════════════
('ZAR',710,'{"es":{"singular":"Rand sudafricano","plural":"Rands sudafricanos"},"en":{"singular":"South African Rand","plural":"South African Rands"}}',
 'R','ZAR',2,'cent','ZA',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='ZA'),true,false,NULL),

('NGN',566,'{"es":{"singular":"Naira nigeriana","plural":"Nairas nigerianas"},"en":{"singular":"Nigerian Naira","plural":"Nigerian Nairas"}}',
 '₦','NGN',2,'kobo','NG',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='NG'),true,false,NULL),

('EGP',818,'{"es":{"singular":"Libra egipcia","plural":"Libras egipcias"},"en":{"singular":"Egyptian Pound","plural":"Egyptian Pounds"}}',
 '£','EGP',2,'piastre','EG',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='EG'),true,false,NULL),

('KES',404,'{"es":{"singular":"Chelín keniano","plural":"Chelines kenianos"},"en":{"singular":"Kenyan Shilling","plural":"Kenyan Shillings"}}',
 'KSh','KES',2,'cent','KE',(SELECT country_id FROM bglobal.global_country WHERE iso_alpha2='KE'),true,false,NULL),

-- ═══════════════════════════════════════════════════════════════
-- CRIPTOMONEDAS (iso_numeric negativo = sin asignación ISO 4217)
-- ═══════════════════════════════════════════════════════════════
('BTC',-1,'{"es":{"singular":"Bitcoin","plural":"Bitcoins"},"en":{"singular":"Bitcoin","plural":"Bitcoins"}}',
 '₿','BTC',8,'satoshi','XX',NULL,true,true,'https://api.coindesk.com/v1/bpi/currentprice.json'),

('ETH',-2,'{"es":{"singular":"Ethereum","plural":"Ethereums"},"en":{"singular":"Ethereum","plural":"Ethereums"}}',
 'Ξ','ETH',18,'wei','XX',NULL,true,true,'https://api.coindesk.com/v1/bpi/currentprice.json'),

('UST',-3,'{"es":{"singular":"Tether USD","plural":"Tether USD"},"en":{"singular":"Tether USD","plural":"Tether USD"}}',
 '₮','UST',6,NULL,'XX',NULL,true,true,'https://api.coindesk.com/v1/bpi/currentprice.json');

-- ═══════════════════════════════════════════════════════════════
-- VERIFICACIÓN
-- ═══════════════════════════════════════════════════════════════
-- SELECT count(*) AS total_currencies FROM bglobal.global_currency;
-- SELECT count(*) AS crypto_currencies FROM bglobal.global_currency WHERE is_cryptocurrency = true;
-- SELECT count(*) AS fiat_currencies FROM bglobal.global_currency WHERE is_cryptocurrency = false;
-- SELECT currency_code, name->>'es' AS name_es, symbol FROM bglobal.global_currency WHERE is_active = true ORDER BY issuer_country, currency_code;
-- SELECT currency_code, name->>'en' AS name_en, is_cryptocurrency FROM bglobal.global_currency WHERE is_cryptocurrency = true;
