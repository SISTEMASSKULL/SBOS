-- seed_org_empresa.sql — Empresa SKULL bootstrap
SET lock_timeout = '5s'; TRUNCATE TABLE bauth.org_empresa RESTART IDENTITY CASCADE; REINDEX TABLE bauth.org_empresa;
INSERT INTO bauth.org_empresa (empresa_id, tenant_id, razon_social, nit, regimen_fiscal, es_operador, locale_default, timezone_default, moneda_default, currency_symbol, status) VALUES
('skull','skull','Sistemas SKULL SRL','1234567890','GENERAL',true,'es-BO','America/La_Paz','BOB','Bs.','ACTIVE');
