-- B5: D5 Biométrico — 6 tipos (grupo 8)
INSERT INTO bos_privilege.bos_group (app_code, group_code, group_name) VALUES (6, 8, 'Biometrico')
ON CONFLICT DO NOTHING;

INSERT INTO bos_privilege.bos_atom_catalog (app_code, group_code, atom_code, domain_code, verb_code, atom_name, atom_slug, atom_position, contextual_mask, logical_mask) VALUES
    (6, 8, 1, 5, 1, 'Huella dactilar', 'biometrico.huella', 350, 5248000, 256),
    (6, 8, 2, 5, 1, 'Rostro', 'biometrico.rostro', 351, 5248000, 512),
    (6, 8, 3, 5, 1, 'Iris', 'biometrico.iris', 352, 5248000, 1024),
    (6, 8, 4, 5, 1, 'Voz', 'biometrico.voz', 353, 5248000, 2048),
    (6, 8, 5, 5, 1, 'Palma', 'biometrico.palma', 354, 5248000, 4096),
    (6, 8, 6, 5, 1, 'Comportamiento', 'biometrico.comportamiento', 355, 5248000, 8192)
ON CONFLICT DO NOTHING;

-- B8: D7 Red — 5 zonas (grupo 9)
INSERT INTO bos_privilege.bos_group (app_code, group_code, group_name) VALUES (6, 9, 'Red')
ON CONFLICT DO NOTHING;

INSERT INTO bos_privilege.bos_atom_catalog (app_code, group_code, atom_code, domain_code, verb_code, atom_name, atom_slug, atom_position, contextual_mask, logical_mask) VALUES
    (6, 9, 1, 7, 1, 'Zona DMZ', 'red.zona.dmz', 360, 7344000, 256),
    (6, 9, 2, 7, 1, 'Zona Interna', 'red.zona.interna', 361, 7344000, 512),
    (6, 9, 3, 7, 1, 'Zona Management', 'red.zona.management', 362, 7344000, 1024),
    (6, 9, 4, 7, 1, 'Zona Aislada', 'red.zona.aislada', 363, 7344000, 2048),
    (6, 9, 5, 7, 1, 'Acceso VPN', 'red.vpn.acceso', 364, 7344000, 4096)
ON CONFLICT DO NOTHING;

SELECT 'D5:' || count(*) FROM bos_privilege.bos_atom_catalog WHERE domain_code = 5;
SELECT 'D7:' || count(*) FROM bos_privilege.bos_atom_catalog WHERE domain_code = 7;
