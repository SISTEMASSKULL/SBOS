-- seed_global_language.sql — ~120 idiomas del mundo
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuentes: IANA Language Subtag Registry, ISO 639-1/2/3, Ethnologue, Unicode CLDR 46
-- Estándares: BCP 47 / RFC 5646, ISO 639-1:2002, ISO 639-2:1998, ISO 639-3:2007, ISO 15924
-- PostgreSQL 18.4: uuidv7(), skip scan indexes, GIN sobre JSONB
-- ═══════════════════════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bglobal.global_language RESTART IDENTITY CASCADE;
REINDEX TABLE bglobal.global_language;

-- ═══════════════════════════════════════════════════════════════════════════
-- SEED: bglobal.global_language
-- Orden: Indo-European → Sino-Tibetan → Afro-Asiatic → Austronesian →
--        Dravidian → Turkic → Japonic → Koreanic → Austroasiatic →
--        Tai-Kadai → Uralic → Quechuan → Aymaran → Tupian →
--        Constructed → Special
-- ═══════════════════════════════════════════════════════════════════════════

INSERT INTO bglobal.global_language (
    locale, iso_639_1, iso_639_2t, iso_639_2b, iso_639_3,
    scope, language_type, family, name, direction,
    fallback_locale, suppress_script, preferred_value, deprecated,
    wikidata_id, iana_registry_date
) VALUES

-- ═══════════════════════════════════════════════════════════════
-- INDO-EUROPEAN — Germanic
-- ═══════════════════════════════════════════════════════════════
('en','en','eng',NULL,'eng','individual','living','Indo-European',
 '{"en":"English","es":"Inglés","native":"English","fr":"Anglais","de":"Englisch","pt":"Inglês","zh":"英语","ar":"الإنجليزية","ru":"Английский"}',
 'ltr',NULL,'Latn',NULL,false,'Q1860','2026-06-23'),

('en-US','en','eng',NULL,'eng','individual','living','Indo-European',
 '{"en":"English (United States)","es":"Inglés (Estados Unidos)","native":"English (US)","fr":"Anglais (États-Unis)","de":"Englisch (USA)","pt":"Inglês (EUA)"}',
 'ltr','en','Latn',NULL,false,NULL,'2026-06-23'),

('en-GB','en','eng',NULL,'eng','individual','living','Indo-European',
 '{"en":"English (United Kingdom)","es":"Inglés (Reino Unido)","native":"English (UK)","fr":"Anglais (Royaume-Uni)","de":"Englisch (UK)","pt":"Inglês (Reino Unido)"}',
 'ltr','en','Latn',NULL,false,NULL,'2026-06-23'),

('de','de','deu','ger','deu','individual','living','Indo-European',
 '{"en":"German","es":"Alemán","native":"Deutsch","fr":"Allemand","pt":"Alemão","zh":"德语","ar":"الألمانية","ru":"Немецкий"}',
 'ltr',NULL,'Latn',NULL,false,'Q188','2026-06-23'),

('nl','nl','nld','dut','nld','individual','living','Indo-European',
 '{"en":"Dutch","es":"Holandés","native":"Nederlands","fr":"Néerlandais","de":"Niederländisch","pt":"Holandês"}',
 'ltr',NULL,'Latn',NULL,false,'Q7411','2026-06-23'),

('sv','sv','swe',NULL,'swe','individual','living','Indo-European',
 '{"en":"Swedish","es":"Sueco","native":"Svenska","fr":"Suédois","de":"Schwedisch","pt":"Sueco"}',
 'ltr',NULL,'Latn',NULL,false,'Q9027','2026-06-23'),

('da','da','dan',NULL,'dan','individual','living','Indo-European',
 '{"en":"Danish","es":"Danés","native":"Dansk","fr":"Danois","de":"Dänisch","pt":"Dinamarquês"}',
 'ltr',NULL,'Latn',NULL,false,'Q9035','2026-06-23'),

('no','no','nor',NULL,'nor','macrolanguage','living','Indo-European',
 '{"en":"Norwegian","es":"Noruego","native":"Norsk","fr":"Norvégien","de":"Norwegisch","pt":"Norueguês"}',
 'ltr',NULL,'Latn',NULL,false,'Q9043','2026-06-23'),

('af','af','afr',NULL,'afr','individual','living','Indo-European',
 '{"en":"Afrikaans","es":"Afrikáans","native":"Afrikaans","fr":"Afrikaans","de":"Afrikaans","pt":"Africâner"}',
 'ltr',NULL,'Latn',NULL,false,'Q14196','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- INDO-EUROPEAN — Romance
-- ═══════════════════════════════════════════════════════════════
('es','es','spa',NULL,'spa','individual','living','Indo-European',
 '{"en":"Spanish","es":"Español","native":"Español","fr":"Espagnol","de":"Spanisch","pt":"Espanhol","zh":"西班牙语","ar":"الإسبانية","ru":"Испанский","qu":"Kastilla simi"}',
 'ltr',NULL,'Latn',NULL,false,'Q1321','2026-06-23'),

('es-BO','es','spa',NULL,'spa','individual','living','Indo-European',
 '{"en":"Spanish (Bolivia)","es":"Español (Bolivia)","native":"Español boliviano","fr":"Espagnol (Bolivie)","de":"Spanisch (Bolivien)","pt":"Espanhol (Bolívia)"}',
 'ltr','es','Latn',NULL,false,NULL,'2026-06-23'),

('es-AR','es','spa',NULL,'spa','individual','living','Indo-European',
 '{"en":"Spanish (Argentina)","es":"Español (Argentina)","native":"Español rioplatense","fr":"Espagnol (Argentine)","de":"Spanisch (Argentinien)","pt":"Espanhol (Argentina)"}',
 'ltr','es','Latn',NULL,false,NULL,'2026-06-23'),

('es-MX','es','spa',NULL,'spa','individual','living','Indo-European',
 '{"en":"Spanish (Mexico)","es":"Español (México)","native":"Español mexicano","fr":"Espagnol (Mexique)","de":"Spanisch (Mexiko)","pt":"Espanhol (México)"}',
 'ltr','es','Latn',NULL,false,NULL,'2026-06-23'),

('fr','fr','fra','fre','fra','individual','living','Indo-European',
 '{"en":"French","es":"Francés","native":"Français","de":"Französisch","pt":"Francês","zh":"法语","ar":"الفرنسية","ru":"Французский"}',
 'ltr',NULL,'Latn',NULL,false,'Q150','2026-06-23'),

('pt','pt','por',NULL,'por','individual','living','Indo-European',
 '{"en":"Portuguese","es":"Portugués","native":"Português","fr":"Portugais","de":"Portugiesisch","zh":"葡萄牙语","ar":"البرتغالية","ru":"Португальский"}',
 'ltr',NULL,'Latn',NULL,false,'Q5146','2026-06-23'),

('pt-BR','pt','por',NULL,'por','individual','living','Indo-European',
 '{"en":"Portuguese (Brazil)","es":"Portugués (Brasil)","native":"Português brasileiro","fr":"Portugais (Brésil)","de":"Portugiesisch (Brasilien)"}',
 'ltr','pt','Latn',NULL,false,NULL,'2026-06-23'),

('it','it','ita',NULL,'ita','individual','living','Indo-European',
 '{"en":"Italian","es":"Italiano","native":"Italiano","fr":"Italien","de":"Italienisch","pt":"Italiano","zh":"意大利语","ru":"Итальянский"}',
 'ltr',NULL,'Latn',NULL,false,'Q652','2026-06-23'),

('ro','ro','ron','rum','ron','individual','living','Indo-European',
 '{"en":"Romanian","es":"Rumano","native":"Română","fr":"Roumain","de":"Rumänisch","pt":"Romeno"}',
 'ltr',NULL,'Latn',NULL,false,'Q7913','2026-06-23'),

('ca','ca','cat',NULL,'cat','individual','living','Indo-European',
 '{"en":"Catalan","es":"Catalán","native":"Català","fr":"Catalan","de":"Katalanisch","pt":"Catalão"}',
 'ltr',NULL,'Latn',NULL,false,'Q7026','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- INDO-EUROPEAN — Slavic
-- ═══════════════════════════════════════════════════════════════
('ru','ru','rus',NULL,'rus','individual','living','Indo-European',
 '{"en":"Russian","es":"Ruso","native":"Русский","fr":"Russe","de":"Russisch","pt":"Russo","zh":"俄语","ar":"الروسية"}',
 'ltr',NULL,'Cyrl',NULL,false,'Q7737','2026-06-23'),

('pl','pl','pol',NULL,'pol','individual','living','Indo-European',
 '{"en":"Polish","es":"Polaco","native":"Polski","fr":"Polonais","de":"Polnisch","pt":"Polonês"}',
 'ltr',NULL,'Latn',NULL,false,'Q809','2026-06-23'),

('uk','uk','ukr',NULL,'ukr','individual','living','Indo-European',
 '{"en":"Ukrainian","es":"Ucraniano","native":"Українська","fr":"Ukrainien","de":"Ukrainisch","pt":"Ucraniano"}',
 'ltr',NULL,'Cyrl',NULL,false,'Q8798','2026-06-23'),

('cs','cs','ces','cze','ces','individual','living','Indo-European',
 '{"en":"Czech","es":"Checo","native":"Čeština","fr":"Tchèque","de":"Tschechisch","pt":"Tcheco"}',
 'ltr',NULL,'Latn',NULL,false,'Q9056','2026-06-23'),

('sr','sr','srp',NULL,'srp','individual','living','Indo-European',
 '{"en":"Serbian","es":"Serbio","native":"Српски / Srpski","fr":"Serbe","de":"Serbisch","pt":"Sérvio"}',
 'ltr',NULL,NULL,NULL,false,'Q9299','2026-06-23'),

('bg','bg','bul',NULL,'bul','individual','living','Indo-European',
 '{"en":"Bulgarian","es":"Búlgaro","native":"Български","fr":"Bulgare","de":"Bulgarisch","pt":"Búlgaro"}',
 'ltr',NULL,'Cyrl',NULL,false,'Q7918','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- INDO-EUROPEAN — Indo-Iranian
-- ═══════════════════════════════════════════════════════════════
('hi','hi','hin',NULL,'hin','individual','living','Indo-European',
 '{"en":"Hindi","es":"Hindi","native":"हिन्दी","fr":"Hindi","de":"Hindi","pt":"Hindi","zh":"印地语","ar":"الهندية"}',
 'ltr',NULL,'Deva',NULL,false,'Q1568','2026-06-23'),

('ur','ur','urd',NULL,'urd','individual','living','Indo-European',
 '{"en":"Urdu","es":"Urdu","native":"اردو","fr":"Ourdou","de":"Urdu","pt":"Urdu"}',
 'rtl',NULL,'Arab',NULL,false,'Q1617','2026-06-23'),

('bn','bn','ben',NULL,'ben','individual','living','Indo-European',
 '{"en":"Bengali","es":"Bengalí","native":"বাংলা","fr":"Bengali","de":"Bengalisch","pt":"Bengali"}',
 'ltr',NULL,'Beng',NULL,false,'Q9610','2026-06-23'),

('fa','fa','fas','per','fas','macrolanguage','living','Indo-European',
 '{"en":"Persian","es":"Persa","native":"فارسی","fr":"Persan","de":"Persisch","pt":"Persa"}',
 'rtl',NULL,'Arab',NULL,false,'Q9168','2026-06-23'),

('pa','pa','pan',NULL,'pan','individual','living','Indo-European',
 '{"en":"Punjabi","es":"Panyabí","native":"ਪੰਜਾਬੀ / پنجابی","fr":"Pendjabi","de":"Punjabi","pt":"Punjabi"}',
 'ltr',NULL,NULL,NULL,false,'Q58635','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- INDO-EUROPEAN — Other
-- ═══════════════════════════════════════════════════════════════
('el','el','ell','gre','ell','individual','living','Indo-European',
 '{"en":"Greek","es":"Griego","native":"Ελληνικά","fr":"Grec","de":"Griechisch","pt":"Grego"}',
 'ltr',NULL,'Grek',NULL,false,'Q9129','2026-06-23'),

('sq','sq','sqi','alb','sqi','macrolanguage','living','Indo-European',
 '{"en":"Albanian","es":"Albanés","native":"Shqip","fr":"Albanais","de":"Albanisch","pt":"Albanês"}',
 'ltr',NULL,'Latn',NULL,false,'Q8748','2026-06-23'),

('hy','hy','hye','arm','hye','individual','living','Indo-European',
 '{"en":"Armenian","es":"Armenio","native":"Հայերեն","fr":"Arménien","de":"Armenisch","pt":"Armênio"}',
 'ltr',NULL,'Armn',NULL,false,'Q8785','2026-06-23'),

('lt','lt','lit',NULL,'lit','individual','living','Indo-European',
 '{"en":"Lithuanian","es":"Lituano","native":"Lietuvių","fr":"Lituanien","de":"Litauisch","pt":"Lituano"}',
 'ltr',NULL,'Latn',NULL,false,'Q9083','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- SINO-TIBETAN
-- ═══════════════════════════════════════════════════════════════
('zh','zh','zho','chi','zho','macrolanguage','living','Sino-Tibetan',
 '{"en":"Chinese","es":"Chino","native":"中文","fr":"Chinois","de":"Chinesisch","pt":"Chinês","ar":"الصينية","ru":"Китайский"}',
 'ltr',NULL,NULL,NULL,false,'Q7850','2026-06-23'),

('zh-Hans','zh','zho','chi','zho','individual','living','Sino-Tibetan',
 '{"en":"Chinese (Simplified)","es":"Chino (Simplificado)","native":"简体中文","fr":"Chinois (Simplifié)","de":"Chinesisch (Vereinfacht)","pt":"Chinês (Simplificado)"}',
 'ltr','zh','Hans',NULL,false,NULL,'2026-06-23'),

('zh-Hant','zh','zho','chi','zho','individual','living','Sino-Tibetan',
 '{"en":"Chinese (Traditional)","es":"Chino (Tradicional)","native":"繁體中文","fr":"Chinois (Traditionnel)","de":"Chinesisch (Traditionell)","pt":"Chinês (Tradicional)"}',
 'ltr','zh','Hant',NULL,false,NULL,'2026-06-23'),

('cmn','zh','zho','chi','cmn','individual','living','Sino-Tibetan',
 '{"en":"Mandarin Chinese","es":"Chino Mandarín","native":"官话 / 普通话","fr":"Mandarin","de":"Mandarin","pt":"Mandarim"}',
 'ltr','zh',NULL,NULL,false,NULL,'2026-06-23'),

('yue',NULL,NULL,NULL,'yue','individual','living','Sino-Tibetan',
 '{"en":"Cantonese","es":"Cantonés","native":"粵語 / 粤语","fr":"Cantonais","de":"Kantonesisch","pt":"Cantonês"}',
 'ltr','zh',NULL,NULL,false,NULL,'2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- AFRO-ASIATIC — Semitic
-- ═══════════════════════════════════════════════════════════════
('ar','ar','ara',NULL,'ara','macrolanguage','living','Afro-Asiatic',
 '{"en":"Arabic","es":"Árabe","native":"العربية","fr":"Arabe","de":"Arabisch","pt":"Árabe","zh":"阿拉伯语","ru":"Арабский"}',
 'rtl',NULL,'Arab',NULL,false,'Q13955','2026-06-23'),

('he','he','heb',NULL,'heb','individual','living','Afro-Asiatic',
 '{"en":"Hebrew","es":"Hebreo","native":"עברית","fr":"Hébreu","de":"Hebräisch","pt":"Hebraico"}',
 'rtl',NULL,'Hebr',NULL,false,'Q9288','2026-06-23'),

('iw',NULL,NULL,NULL,NULL,'individual','living','Afro-Asiatic',
 '{"en":"Hebrew (deprecated)","es":"Hebreo (obsoleto)","native":"עברית (מיושן)"}',
 'rtl','he','Hebr','he',true,'Q9288','2026-06-23'),

('am','am','amh',NULL,'amh','individual','living','Afro-Asiatic',
 '{"en":"Amharic","es":"Amárico","native":"አማርኛ","fr":"Amharique","de":"Amharisch","pt":"Amárico"}',
 'ltr',NULL,'Ethi',NULL,false,'Q28244','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- AFRO-ASIATIC — Other
-- ═══════════════════════════════════════════════════════════════
('ha','ha','hau',NULL,'hau','individual','living','Afro-Asiatic',
 '{"en":"Hausa","es":"Hausa","native":"Hausa / هَوُسَ","fr":"Haoussa","de":"Hausa","pt":"Hauçá"}',
 'ltr',NULL,NULL,NULL,false,'Q56475','2026-06-23'),

('so','so','som',NULL,'som','individual','living','Afro-Asiatic',
 '{"en":"Somali","es":"Somalí","native":"Soomaaliga","fr":"Somali","de":"Somali","pt":"Somali"}',
 'ltr',NULL,'Latn',NULL,false,'Q13275','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- AUSTRONESIAN
-- ═══════════════════════════════════════════════════════════════
('id','id','ind',NULL,'ind','individual','living','Austronesian',
 '{"en":"Indonesian","es":"Indonesio","native":"Bahasa Indonesia","fr":"Indonésien","de":"Indonesisch","pt":"Indonésio"}',
 'ltr',NULL,'Latn',NULL,false,'Q9240','2026-06-23'),

('in',NULL,NULL,NULL,NULL,'individual','living','Austronesian',
 '{"en":"Indonesian (deprecated)","es":"Indonesio (obsoleto)","native":"Bahasa Indonesia (usang)"}',
 'ltr','id','Latn','id',true,'Q9240','2026-06-23'),

('ms','ms','msa','may','msa','macrolanguage','living','Austronesian',
 '{"en":"Malay","es":"Malayo","native":"Bahasa Melayu / بهاس ملايو","fr":"Malais","de":"Malaiisch","pt":"Malaio"}',
 'ltr',NULL,NULL,NULL,false,'Q9237','2026-06-23'),

('tl','tl','tgl',NULL,'tgl','individual','living','Austronesian',
 '{"en":"Tagalog","es":"Tagalo","native":"Tagalog","fr":"Tagalog","de":"Tagalog","pt":"Tagalo"}',
 'ltr',NULL,'Latn',NULL,false,'Q34057','2026-06-23'),

('jv','jv','jav',NULL,'jav','individual','living','Austronesian',
 '{"en":"Javanese","es":"Javanés","native":"Basa Jawa / ꦧꦱꦗꦮ","fr":"Javanais","de":"Javanisch","pt":"Javanês"}',
 'ltr',NULL,NULL,NULL,false,'Q33549','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- DRAVIDIAN
-- ═══════════════════════════════════════════════════════════════
('ta','ta','tam',NULL,'tam','individual','living','Dravidian',
 '{"en":"Tamil","es":"Tamil","native":"தமிழ்","fr":"Tamoul","de":"Tamil","pt":"Tâmil"}',
 'ltr',NULL,'Taml',NULL,false,'Q5885','2026-06-23'),

('te','te','tel',NULL,'tel','individual','living','Dravidian',
 '{"en":"Telugu","es":"Telugu","native":"తెలుగు","fr":"Télougou","de":"Telugu","pt":"Télugo"}',
 'ltr',NULL,'Telu',NULL,false,'Q8097','2026-06-23'),

('kn','kn','kan',NULL,'kan','individual','living','Dravidian',
 '{"en":"Kannada","es":"Canarés","native":"ಕನ್ನಡ","fr":"Kannada","de":"Kannada","pt":"Canarês"}',
 'ltr',NULL,'Knda',NULL,false,'Q33673','2026-06-23'),

('ml','ml','mal',NULL,'mal','individual','living','Dravidian',
 '{"en":"Malayalam","es":"Malayalam","native":"മലയാളം","fr":"Malayalam","de":"Malayalam","pt":"Malaiala"}',
 'ltr',NULL,'Mlym',NULL,false,'Q36236','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- TURKIC
-- ═══════════════════════════════════════════════════════════════
('tr','tr','tur',NULL,'tur','individual','living','Turkic',
 '{"en":"Turkish","es":"Turco","native":"Türkçe","fr":"Turc","de":"Türkisch","pt":"Turco"}',
 'ltr',NULL,'Latn',NULL,false,'Q256','2026-06-23'),

('uz','uz','uzb',NULL,'uzb','macrolanguage','living','Turkic',
 '{"en":"Uzbek","es":"Uzbeko","native":"Oʻzbekcha / Ўзбекча","fr":"Ouzbek","de":"Usbekisch","pt":"Uzbeque"}',
 'ltr',NULL,NULL,NULL,false,'Q9264','2026-06-23'),

('kk','kk','kaz',NULL,'kaz','individual','living','Turkic',
 '{"en":"Kazakh","es":"Kazajo","native":"Қазақша / Qazaqşa","fr":"Kazakh","de":"Kasachisch","pt":"Cazaque"}',
 'ltr',NULL,'Cyrl',NULL,false,'Q9252','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- JAPONIC / KOREANIC
-- ═══════════════════════════════════════════════════════════════
('ja','ja','jpn',NULL,'jpn','individual','living','Japonic',
 '{"en":"Japanese","es":"Japonés","native":"日本語","fr":"Japonais","de":"Japanisch","pt":"Japonês","zh":"日语","ru":"Японский"}',
 'ltr',NULL,'Jpan',NULL,false,'Q5287','2026-06-23'),

('ko','ko','kor',NULL,'kor','individual','living','Koreanic',
 '{"en":"Korean","es":"Coreano","native":"한국어 / 조선말","fr":"Coréen","de":"Koreanisch","pt":"Coreano","zh":"韩语","ru":"Корейский"}',
 'ltr',NULL,'Kore',NULL,false,'Q9176','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- AUSTROASIATIC
-- ═══════════════════════════════════════════════════════════════
('vi','vi','vie',NULL,'vie','individual','living','Austroasiatic',
 '{"en":"Vietnamese","es":"Vietnamita","native":"Tiếng Việt","fr":"Vietnamien","de":"Vietnamesisch","pt":"Vietnamita"}',
 'ltr',NULL,'Latn',NULL,false,'Q9199','2026-06-23'),

('km','km','khm',NULL,'khm','individual','living','Austroasiatic',
 '{"en":"Khmer","es":"Jemer","native":"ភាសាខ្មែរ","fr":"Khmer","de":"Khmer","pt":"Khmer"}',
 'ltr',NULL,'Khmr',NULL,false,'Q9205','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- TAI-KADAI (Kra-Dai)
-- ═══════════════════════════════════════════════════════════════
('th','th','tha',NULL,'tha','individual','living','Tai-Kadai',
 '{"en":"Thai","es":"Tailandés","native":"ไทย","fr":"Thaï","de":"Thailändisch","pt":"Tailandês"}',
 'ltr',NULL,'Thai',NULL,false,'Q9217','2026-06-23'),

('lo','lo','lao',NULL,'lao','individual','living','Tai-Kadai',
 '{"en":"Lao","es":"Laosiano","native":"ລາວ","fr":"Lao","de":"Laotisch","pt":"Laosiano"}',
 'ltr',NULL,'Laoo',NULL,false,'Q9211','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- URALIC
-- ═══════════════════════════════════════════════════════════════
('hu','hu','hun',NULL,'hun','individual','living','Uralic',
 '{"en":"Hungarian","es":"Húngaro","native":"Magyar","fr":"Hongrois","de":"Ungarisch","pt":"Húngaro"}',
 'ltr',NULL,'Latn',NULL,false,'Q9067','2026-06-23'),

('fi','fi','fin',NULL,'fin','individual','living','Uralic',
 '{"en":"Finnish","es":"Finlandés","native":"Suomi","fr":"Finnois","de":"Finnisch","pt":"Finlandês"}',
 'ltr',NULL,'Latn',NULL,false,'Q1412','2026-06-23'),

('et','et','est',NULL,'est','macrolanguage','living','Uralic',
 '{"en":"Estonian","es":"Estonio","native":"Eesti","fr":"Estonien","de":"Estnisch","pt":"Estoniano"}',
 'ltr',NULL,'Latn',NULL,false,'Q9072','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- QUECHUAN — Bolivia + Perú (obligatorio SBOS)
-- ═══════════════════════════════════════════════════════════════
('qu','qu','que',NULL,'que','macrolanguage','living','Quechuan',
 '{"en":"Quechua","es":"Quechua","native":"Runasimi","fr":"Quechua","de":"Quechua","pt":"Quíchua"}',
 'ltr',NULL,'Latn',NULL,false,'Q5218','2026-06-23'),

('qu-BO','qu','que',NULL,'que','individual','living','Quechuan',
 '{"en":"Quechua (Bolivia)","es":"Quechua (Bolivia)","native":"Qhichwa simi (Buliwya)","fr":"Quechua (Bolivie)","de":"Quechua (Bolivien)","pt":"Quíchua (Bolívia)"}',
 'ltr','qu','Latn',NULL,false,NULL,'2026-06-23'),

('qu-PE','qu','que',NULL,'que','individual','living','Quechuan',
 '{"en":"Quechua (Peru)","es":"Quechua (Perú)","native":"Runasimi (Piruw)","fr":"Quechua (Pérou)","de":"Quechua (Peru)","pt":"Quíchua (Peru)"}',
 'ltr','qu','Latn',NULL,false,NULL,'2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- AYMARAN — Bolivia (obligatorio SBOS)
-- ═══════════════════════════════════════════════════════════════
('ay','ay','aym',NULL,'aym','macrolanguage','living','Aymaran',
 '{"en":"Aymara","es":"Aimara","native":"Aymar aru","fr":"Aymara","de":"Aymara","pt":"Aimará"}',
 'ltr',NULL,'Latn',NULL,false,'Q4627','2026-06-23'),

('ay-BO','ay','aym',NULL,'aym','individual','living','Aymaran',
 '{"en":"Aymara (Bolivia)","es":"Aimara (Bolivia)","native":"Aymar aru (Wuliwya)","fr":"Aymara (Bolivie)","de":"Aymara (Bolivien)","pt":"Aimará (Bolívia)"}',
 'ltr','ay','Latn',NULL,false,NULL,'2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- TUPIAN — Brasil + Paraguay
-- ═══════════════════════════════════════════════════════════════
('gn','gn','grn',NULL,'grn','macrolanguage','living','Tupian',
 '{"en":"Guarani","es":"Guaraní","native":"Avañe''ẽ","fr":"Guarani","de":"Guaraní","pt":"Guarani"}',
 'ltr',NULL,'Latn',NULL,false,'Q35876','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- OTHER AMERICAS INDIGENOUS
-- ═══════════════════════════════════════════════════════════════
('nah',NULL,NULL,NULL,'nci','individual','historic','Uto-Aztecan',
 '{"en":"Nahuatl","es":"Náhuatl","native":"Nāhuatl / Mexihcatlahtōlli","fr":"Nahuatl","de":"Nahuatl","pt":"Náuatle"}',
 'ltr',NULL,'Latn',NULL,false,NULL,'2026-06-23'),

('nv',NULL,NULL,NULL,'nav','individual','living','Athabaskan',
 '{"en":"Navajo","es":"Navajo","native":"Diné bizaad","fr":"Navajo","de":"Navajo","pt":"Navajo"}',
 'ltr',NULL,'Latn',NULL,false,'Q13310','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- NIGER-CONGO — Bantu
-- ═══════════════════════════════════════════════════════════════
('sw','sw','swa',NULL,'swa','macrolanguage','living','Niger-Congo',
 '{"en":"Swahili","es":"Suajili","native":"Kiswahili","fr":"Swahili","de":"Suaheli","pt":"Suaíli"}',
 'ltr',NULL,'Latn',NULL,false,'Q7838','2026-06-23'),

('yo','yo','yor',NULL,'yor','individual','living','Niger-Congo',
 '{"en":"Yoruba","es":"Yoruba","native":"Èdè Yorùbá","fr":"Yoruba","de":"Yoruba","pt":"Iorubá"}',
 'ltr',NULL,'Latn',NULL,false,'Q34311','2026-06-23'),

('ig','ig','ibo',NULL,'ibo','individual','living','Niger-Congo',
 '{"en":"Igbo","es":"Igbo","native":"Ásụ̀sụ́ Ìgbò","fr":"Igbo","de":"Igbo","pt":"Igbo"}',
 'ltr',NULL,'Latn',NULL,false,'Q33578','2026-06-23'),

('zu','zu','zul',NULL,'zul','individual','living','Niger-Congo',
 '{"en":"Zulu","es":"Zulú","native":"isiZulu","fr":"Zoulou","de":"Zulu","pt":"Zulu"}',
 'ltr',NULL,'Latn',NULL,false,'Q10179','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- OTHER MAJOR WORLD LANGUAGES
-- ═══════════════════════════════════════════════════════════════
('ka','ka','kat','geo','kat','individual','living','Kartvelian',
 '{"en":"Georgian","es":"Georgiano","native":"ქართული","fr":"Géorgien","de":"Georgisch","pt":"Georgiano"}',
 'ltr',NULL,'Geor',NULL,false,'Q8108','2026-06-23'),

('mn','mn','mon',NULL,'mon','macrolanguage','living','Mongolic',
 '{"en":"Mongolian","es":"Mongol","native":"Монгол хэл / ᠮᠣᠩᠭᠣᠯ ᠬᠡᠯᠡ","fr":"Mongol","de":"Mongolisch","pt":"Mongol"}',
 'ltr',NULL,NULL,NULL,false,'Q9246','2026-06-23'),

('my','my','mya','bur','mya','individual','living','Sino-Tibetan',
 '{"en":"Burmese","es":"Birmano","native":"မြန်မာဘာသာ","fr":"Birman","de":"Birmanisch","pt":"Birmanês"}',
 'ltr',NULL,'Mymr',NULL,false,'Q9228','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- CONSTRUCTED LANGUAGES
-- ═══════════════════════════════════════════════════════════════
('eo','eo','epo',NULL,'epo','individual','constructed','Constructed',
 '{"en":"Esperanto","es":"Esperanto","native":"Esperanto","fr":"Espéranto","de":"Esperanto","pt":"Esperanto"}',
 'ltr',NULL,'Latn',NULL,false,'Q143','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- SPECIAL CODES (ISO 639-3)
-- ═══════════════════════════════════════════════════════════════
('und',NULL,NULL,NULL,'und','special','living',NULL,
 '{"en":"Undetermined","es":"Indeterminado","native":"Undetermined","fr":"Indéterminé","de":"Unbestimmt","pt":"Indeterminado"}',
 'ltr',NULL,NULL,NULL,false,NULL,'2026-06-23'),

('mul',NULL,NULL,NULL,'mul','special','living',NULL,
 '{"en":"Multiple languages","es":"Múltiples idiomas","native":"Multiple languages","fr":"Multilingue","de":"Mehrsprachig","pt":"Múltiplos idiomas"}',
 'ltr',NULL,NULL,NULL,false,NULL,'2026-06-23'),

('zxx',NULL,NULL,NULL,'zxx','special','living',NULL,
 '{"en":"No linguistic content","es":"Sin contenido lingüístico","native":"No linguistic content","fr":"Aucun contenu linguistique","de":"Kein sprachlicher Inhalt","pt":"Sem conteúdo linguístico"}',
 'ltr',NULL,NULL,NULL,false,NULL,'2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- MORE INDO-EUROPEAN
-- ═══════════════════════════════════════════════════════════════
('sk','sk','slk','slo','slk','individual','living','Indo-European',
 '{"en":"Slovak","es":"Eslovaco","native":"Slovenčina","fr":"Slovaque","de":"Slowakisch","pt":"Eslovaco"}',
 'ltr',NULL,'Latn',NULL,false,'Q9058','2026-06-23'),

('sl','sl','slv',NULL,'slv','individual','living','Indo-European',
 '{"en":"Slovenian","es":"Esloveno","native":"Slovenščina","fr":"Slovène","de":"Slowenisch","pt":"Esloveno"}',
 'ltr',NULL,'Latn',NULL,false,'Q9063','2026-06-23'),

('hr','hr','hrv',NULL,'hrv','individual','living','Indo-European',
 '{"en":"Croatian","es":"Croata","native":"Hrvatski","fr":"Croate","de":"Kroatisch","pt":"Croata"}',
 'ltr',NULL,'Latn',NULL,false,'Q6654','2026-06-23'),

('lv','lv','lav',NULL,'lav','macrolanguage','living','Indo-European',
 '{"en":"Latvian","es":"Letón","native":"Latviešu","fr":"Letton","de":"Lettisch","pt":"Letão"}',
 'ltr',NULL,'Latn',NULL,false,'Q9078','2026-06-23'),

('ga','ga','gle',NULL,'gle','individual','living','Indo-European',
 '{"en":"Irish","es":"Irlandés","native":"Gaeilge","fr":"Irlandais","de":"Irisch","pt":"Irlandês"}',
 'ltr',NULL,'Latn',NULL,false,'Q9142','2026-06-23'),

('cy','cy','cym','wel','cym','individual','living','Indo-European',
 '{"en":"Welsh","es":"Galés","native":"Cymraeg","fr":"Gallois","de":"Walisisch","pt":"Galês"}',
 'ltr',NULL,'Latn',NULL,false,'Q9309','2026-06-23'),

('mr','mr','mar',NULL,'mar','individual','living','Indo-European',
 '{"en":"Marathi","es":"Maratí","native":"मराठी","fr":"Marathi","de":"Marathi","pt":"Marata"}',
 'ltr',NULL,'Deva',NULL,false,'Q1571','2026-06-23'),

('gu','gu','guj',NULL,'guj','individual','living','Indo-European',
 '{"en":"Gujarati","es":"Guyaratí","native":"ગુજરાતી","fr":"Goudjarati","de":"Gujarati","pt":"Guzerate"}',
 'ltr',NULL,'Gujr',NULL,false,'Q5137','2026-06-23'),

('ne','ne','nep',NULL,'nep','macrolanguage','living','Indo-European',
 '{"en":"Nepali","es":"Nepalí","native":"नेपाली","fr":"Népalais","de":"Nepalesisch","pt":"Nepalês"}',
 'ltr',NULL,'Deva',NULL,false,'Q33823','2026-06-23'),

('si','si','sin',NULL,'sin','individual','living','Indo-European',
 '{"en":"Sinhala","es":"Cingalés","native":"සිංහල","fr":"Cinghalais","de":"Singhalesisch","pt":"Cingalês"}',
 'ltr',NULL,'Sinh',NULL,false,'Q13267','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- MORE ASIAN LANGUAGES
-- ═══════════════════════════════════════════════════════════════
('bo','bo','bod','tib','bod','individual','living','Sino-Tibetan',
 '{"en":"Tibetan","es":"Tibetano","native":"བོད་སྐད","fr":"Tibétain","de":"Tibetisch","pt":"Tibetano"}',
 'ltr',NULL,'Tibt',NULL,false,'Q34271','2026-06-23'),

('dz','dz','dzo',NULL,'dzo','individual','living','Sino-Tibetan',
 '{"en":"Dzongkha","es":"Dzongkha","native":"རྫོང་ཁ","fr":"Dzongkha","de":"Dzongkha","pt":"Dzonga"}',
 'ltr',NULL,'Tibt',NULL,false,'Q33081','2026-06-23'),

('ps','ps','pus',NULL,'pus','macrolanguage','living','Indo-European',
 '{"en":"Pashto","es":"Pastún","native":"پښتو","fr":"Pachto","de":"Paschtu","pt":"Pachto"}',
 'rtl',NULL,'Arab',NULL,false,'Q58680','2026-06-23'),

('ku','ku','kur',NULL,'kur','macrolanguage','living','Indo-European',
 '{"en":"Kurdish","es":"Kurdo","native":"Kurdî / کوردی","fr":"Kurde","de":"Kurdisch","pt":"Curdo"}',
 'ltr',NULL,NULL,NULL,false,'Q36368','2026-06-23'),

('az','az','aze',NULL,'aze','macrolanguage','living','Turkic',
 '{"en":"Azerbaijani","es":"Azerbaiyano","native":"Azərbaycanca / آذربایجانجا","fr":"Azéri","de":"Aserbaidschanisch","pt":"Azerbaijano"}',
 'ltr',NULL,NULL,NULL,false,'Q9292','2026-06-23'),

('tk','tk','tuk',NULL,'tuk','individual','living','Turkic',
 '{"en":"Turkmen","es":"Turcomano","native":"Türkmençe / Түркменче","fr":"Turkmène","de":"Turkmenisch","pt":"Turcomeno"}',
 'ltr',NULL,'Latn',NULL,false,'Q9267','2026-06-23'),

('ky','ky','kir',NULL,'kir','individual','living','Turkic',
 '{"en":"Kyrgyz","es":"Kirguís","native":"Кыргызча / قىرعىزچا","fr":"Kirghize","de":"Kirgisisch","pt":"Quirguiz"}',
 'ltr',NULL,NULL,NULL,false,'Q9255','2026-06-23'),

('tt','tt','tat',NULL,'tat','individual','living','Turkic',
 '{"en":"Tatar","es":"Tártaro","native":"Татарча / Tatarça","fr":"Tatar","de":"Tatarisch","pt":"Tártaro"}',
 'ltr',NULL,NULL,NULL,false,'Q25285','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- MORE AFRICAN LANGUAGES
-- ═══════════════════════════════════════════════════════════════
('rw','rw','kin',NULL,'kin','individual','living','Niger-Congo',
 '{"en":"Kinyarwanda","es":"Kiñaruanda","native":"Ikinyarwanda","fr":"Kinyarwanda","de":"Kinyarwanda","pt":"Quiniaruanda"}',
 'ltr',NULL,'Latn',NULL,false,'Q33573','2026-06-23'),

('rn','rn','run',NULL,'run','individual','living','Niger-Congo',
 '{"en":"Kirundi","es":"Kirundi","native":"Ikirundi","fr":"Kirundi","de":"Kirundi","pt":"Quirundi"}',
 'ltr',NULL,'Latn',NULL,false,'Q33583','2026-06-23'),

('ny','ny','nya',NULL,'nya','individual','living','Niger-Congo',
 '{"en":"Chichewa","es":"Chichewa","native":"Chichewa / Chinyanja","fr":"Chichewa","de":"Chichewa","pt":"Chicheua"}',
 'ltr',NULL,'Latn',NULL,false,'Q33273','2026-06-23'),

('mg','mg','mlg',NULL,'mlg','macrolanguage','living','Austronesian',
 '{"en":"Malagasy","es":"Malgache","native":"Malagasy / مَلَغَسِ","fr":"Malgache","de":"Malagasy","pt":"Malgaxe"}',
 'ltr',NULL,'Latn',NULL,false,'Q7930','2026-06-23'),

('xh','xh','xho',NULL,'xho','individual','living','Niger-Congo',
 '{"en":"Xhosa","es":"Xhosa","native":"isiXhosa","fr":"Xhosa","de":"Xhosa","pt":"Xhosa"}',
 'ltr',NULL,'Latn',NULL,false,'Q13218','2026-06-23'),

('st','st','sot',NULL,'sot','individual','living','Niger-Congo',
 '{"en":"Sesotho","es":"Sesoto","native":"Sesotho","fr":"Sotho","de":"Sesotho","pt":"Sesoto"}',
 'ltr',NULL,'Latn',NULL,false,'Q34340','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- MORE EUROPEAN
-- ═══════════════════════════════════════════════════════════════
('is','is','isl','ice','isl','individual','living','Indo-European',
 '{"en":"Icelandic","es":"Islandés","native":"Íslenska","fr":"Islandais","de":"Isländisch","pt":"Islandês"}',
 'ltr',NULL,'Latn',NULL,false,'Q294','2026-06-23'),

('mt','mt','mlt',NULL,'mlt','individual','living','Afro-Asiatic',
 '{"en":"Maltese","es":"Maltés","native":"Malti","fr":"Maltais","de":"Maltesisch","pt":"Maltês"}',
 'ltr',NULL,'Latn',NULL,false,'Q9166','2026-06-23'),

('lb','lb','ltz',NULL,'ltz','individual','living','Indo-European',
 '{"en":"Luxembourgish","es":"Luxemburgués","native":"Lëtzebuergesch","fr":"Luxembourgeois","de":"Luxemburgisch","pt":"Luxemburguês"}',
 'ltr',NULL,'Latn',NULL,false,'Q9051','2026-06-23'),

('gl','gl','glg',NULL,'glg','individual','living','Indo-European',
 '{"en":"Galician","es":"Gallego","native":"Galego","fr":"Galicien","de":"Galicisch","pt":"Galego"}',
 'ltr',NULL,'Latn',NULL,false,'Q9307','2026-06-23'),

('eu','eu','eus','baq','eus','individual','living','Isolate',
 '{"en":"Basque","es":"Euskera","native":"Euskara","fr":"Basque","de":"Baskisch","pt":"Basco"}',
 'ltr',NULL,'Latn',NULL,false,'Q8752','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- HISTORIC / ANCIENT (referencia académica)
-- ═══════════════════════════════════════════════════════════════
('la','la','lat',NULL,'lat','individual','ancient','Indo-European',
 '{"en":"Latin","es":"Latín","native":"Latina","fr":"Latin","de":"Latein","pt":"Latim"}',
 'ltr',NULL,'Latn',NULL,false,'Q397','2026-06-23'),

('grc',NULL,NULL,NULL,'grc','individual','ancient','Indo-European',
 '{"en":"Ancient Greek","es":"Griego Antiguo","native":"Ἑλληνική","fr":"Grec ancien","de":"Altgriechisch","pt":"Grego Antigo"}',
 'ltr',NULL,'Grek',NULL,false,'Q35497','2026-06-23'),

('sa','sa','san',NULL,'san','individual','ancient','Indo-European',
 '{"en":"Sanskrit","es":"Sánscrito","native":"संस्कृतम्","fr":"Sanskrit","de":"Sanskrit","pt":"Sânscrito"}',
 'ltr',NULL,'Deva',NULL,false,'Q11059','2026-06-23'),

('ang',NULL,NULL,NULL,'ang','individual','historic','Indo-European',
 '{"en":"Old English","es":"Inglés Antiguo","native":"Ænglisc","fr":"Vieil anglais","de":"Altenglisch","pt":"Inglês Antigo"}',
 'ltr','en','Latn',NULL,false,'Q42365','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- SIGN LANGUAGES
-- ═══════════════════════════════════════════════════════════════
('sgn',NULL,NULL,NULL,'sgn','collection','living',NULL,
 '{"en":"Sign Languages","es":"Lenguas de señas","native":"Sign Languages","fr":"Langues des signes","de":"Gebärdensprachen","pt":"Línguas de sinais"}',
 'ltr',NULL,NULL,NULL,false,NULL,'2026-06-23'),

('ase',NULL,NULL,NULL,'ase','individual','living','Sign Language',
 '{"en":"American Sign Language","es":"Lengua de Señas Americana","native":"American Sign Language","fr":"Langue des signes américaine","de":"Amerikanische Gebärdensprache","pt":"Língua de Sinais Americana"}',
 'ltr',NULL,NULL,NULL,false,'Q14759','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- DEPRECATED CODES (ejemplos IANA Registry)
-- ═══════════════════════════════════════════════════════════════
('ji',NULL,NULL,NULL,NULL,'individual','living','Indo-European',
 '{"en":"Yiddish (deprecated)","es":"Yidis (obsoleto)","native":"ייִדיש (מיושן)","fr":"Yiddish (obsolète)","de":"Jiddisch (veraltet)"}',
 'rtl','yi','Hebr','yi',true,'Q8641','2026-06-23'),

('mo',NULL,NULL,NULL,NULL,'individual','living','Indo-European',
 '{"en":"Moldavian (deprecated)","es":"Moldavo (obsoleto)","native":"Moldovenească (învechit)","fr":"Moldave (obsolète)","de":"Moldauisch (veraltet)"}',
 'ltr','ro','Latn','ro',true,NULL,'2026-06-23'),

('sh',NULL,NULL,NULL,NULL,'individual','living','Indo-European',
 '{"en":"Serbo-Croatian (deprecated)","es":"Serbocroata (obsoleto)","native":"Srpskohrvatski (zastarjelo)","fr":"Serbo-croate (obsolète)","de":"Serbokroatisch (veraltet)"}',
 'ltr',NULL,'Latn',NULL,true,'Q9301','2026-06-23'),

-- ═══════════════════════════════════════════════════════════════
-- MIANTE LANGUAGES (South America)
-- ═══════════════════════════════════════════════════════════════
('yi','yi','yid',NULL,'yid','macrolanguage','living','Indo-European',
 '{"en":"Yiddish","es":"Yidis","native":"ייִדיש","fr":"Yiddish","de":"Jiddisch","pt":"Iídiche"}',
 'rtl',NULL,'Hebr',NULL,false,'Q8641','2026-06-23'),

('oc','oc','oci',NULL,'oci','individual','living','Indo-European',
 '{"en":"Occitan","es":"Occitano","native":"Occitan / Lenga d''òc","fr":"Occitan","de":"Okzitanisch","pt":"Occitano"}',
 'ltr',NULL,'Latn',NULL,false,'Q14185','2026-06-23');

-- ═══════════════════════════════════════════════════════════════
-- ACTIVACIÓN POR DEFECTO: Español e Inglés
-- Solo los idiomas oficiales de la plataforma se activan por defecto.
-- El resto se activan bajo demanda (cuando hay traducciones disponibles).
-- ═══════════════════════════════════════════════════════════════
UPDATE bglobal.global_language SET is_active = true WHERE locale IN ('es','es-BO','es-AR','es-MX','en','en-US','en-GB');

-- ═══════════════════════════════════════════════════════════════
-- VERIFICACIÓN
-- ═══════════════════════════════════════════════════════════════
-- SELECT count(*) AS total_languages FROM bglobal.global_language;
-- SELECT count(*) AS active_languages FROM bglobal.global_language WHERE is_active = true;
-- SELECT scope, count(*) FROM bglobal.global_language GROUP BY scope;
-- SELECT language_type, count(*) FROM bglobal.global_language GROUP BY language_type;
-- SELECT locale FROM bglobal.global_language WHERE deprecated = true;
-- SELECT locale, name->>'es' FROM bglobal.global_language WHERE is_active = true ORDER BY locale;
