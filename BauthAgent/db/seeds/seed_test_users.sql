-- ============================================================================
-- SEED: Usuarios de prueba para validación de UserTemplates
-- Cubre todos los tiers: SU, SYS, BIZ_N1-N5, EXT_N0, M2M
-- ============================================================================

BEGIN;

DELETE FROM bauth.idn_user_template WHERE username LIKE 'test_%';

INSERT INTO bauth.idn_user_template (
    uuid, username, email, tenant_id, empresa_id, sucursal_id, pos_logico,
    status, rol_ids, rol_bitmask_base64, sync_status,
    kc_user_id, tryton_user_id, template_version
) VALUES
-- SU (AAL3, full audit)
(uuidv7(), 'test_superadmin', 'superadmin@sbos.bo',
 (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'),
 'NIT-1234567890', 'skull-central', 'POS-01',
 'ACTIVE', ARRAY['ROL-SYS-SUPERUSUARIO'], '', 'SYNCED',
 'kc-su-001', 2001, '0.0'),

-- SYS Admin Seguridad (AAL2)
(uuidv7(), 'test_admin_seguridad', 'seguridad@sbos.bo',
 (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'),
 'NIT-1234567890', 'skull-central', 'POS-01',
 'ACTIVE', ARRAY['ROL-SYS-ADMIN-SEGURIDAD'], '', 'SYNCED',
 'kc-sec-001', 2002, '0.0'),

-- BIZ_N1: Gerente General
(uuidv7(), 'test_gerente', 'gerente@acme.bo',
 (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'),
 'NIT-1234567890', 'skull-central', 'POS-01',
 'ACTIVE', ARRAY['ROL-ORG-CEO'], '', 'SYNCED',
 'kc-ger-001', 2003, '0.0'),

-- BIZ_N2: Contador Senior
(uuidv7(), 'test_contador', 'contador@acme.bo',
 (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'),
 'NIT-1234567890', 'skull-central', 'POS-01',
 'ACTIVE', ARRAY['ROL-ORG-CONT-SENIOR'], '', 'SYNCED',
 'kc-cont-001', 2004, '0.0'),

-- BIZ_N3: Cajero
(uuidv7(), 'test_cajero', 'cajero@acme.bo',
 (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'),
 'NIT-1234567890', 'skull-sucursal-sc', 'POS-03',
 'ACTIVE', ARRAY['ROL-ORG-VEND-JUNIOR'], '', 'SYNCED',
 'kc-caj-001', 2005, '0.0'),

-- BIZ_N4: Vendedor Senior
(uuidv7(), 'test_vendedor', 'vendedor@acme.bo',
 (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'),
 'NIT-1234567890', 'skull-sucursal-sc', 'POS-03',
 'ACTIVE', ARRAY['ROL-ORG-VEND-SENIOR'], '', 'SYNCED',
 'kc-ven-001', 2006, '0.0'),

-- EXT_N0: Cliente externo (sin roles)
(uuidv7(), 'test_cliente', 'cliente@externo.bo',
 (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'),
 'NIT-1234567890', 'skull-central', 'POS-01',
 'ACTIVE', ARRAY[]::text[], '', 'PENDING',
 NULL, NULL, '0.0'),

-- M2M: Service Account
(uuidv7(), 'test_m2m_daemon', 'daemon@sbos.bo',
 (SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'),
 'NIT-1234567890', 'skull-central', 'POS-01',
 'ACTIVE', ARRAY['ROL-SYS-M2M-BOOTSTRAP'], '', 'SYNCED',
 'kc-m2m-001', 2007, '0.0');

COMMIT;
