-- seed_ath_policy_d11.sql — Políticas D11 Auditoría
SET lock_timeout = '5s'; TRUNCATE TABLE bauth.ath_policy_d11 RESTART IDENTITY CASCADE; REINDEX TABLE bauth.ath_policy_d11;
INSERT INTO bauth.ath_policy_d11 (policy_code, policy_name, description, standard_ref, config) VALUES
('AUDIT_RETENTION_7Y','Retención 7 años','Registros de auditoría financiera: 2555 días. SOX §404 + PCI DSS.','{SOX §404,PCI DSS 10.3.2,ISO 27001 A.8.15}','{"rule":"retention","days":2555,"applies_to":["FINANCIAL","ACCESS","AUTH"]}'),
('AUDIT_RETENTION_90D','Retención 90 días','Registros operativos: 90 días online, 7 años offline.','{ISO 27001 A.8.15}','{"rule":"retention","days":90,"archive_after_days":90,"archive_retention_years":7}'),
('HASH_CHAIN_SHA256','Hash-chain SHA-256','Cada evento de auditoría encadenado criptográficamente. WORM inmutable.','{PCI DSS 10.3.2,NIST SP 800-53 AU-3}','{"rule":"hash_chain","algorithm":"SHA-256","worm":true}'),
('REVIEW_QUARTERLY','Revisión trimestral de accesos','Recertificación de accesos cada 3 meses. Alerta 7 días antes.','{ISO 27001 A.9.2.5,NIST SP 800-53 AC-2}','{"rule":"access_review","frequency":"QUARTERLY","alert_days_before":7}');
