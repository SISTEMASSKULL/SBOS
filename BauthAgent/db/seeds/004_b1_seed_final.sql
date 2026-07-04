-- B1: Llevar total a 500+ registros
-- Actual: 6 apps + 26 grupos + 120 atomos + 209 politicas = 361

-- 7 grupos nuevos
INSERT INTO bos_privilege.bos_group (app_code, group_code, group_name) VALUES
    (5,4,'Notificaciones'),(5,5,'Exportaciones'),(5,6,'Scheduler'),
    (6,5,'Respaldos'),(6,6,'Monitoreo'),(6,7,'Notificaciones'),(6,8,'Integraciones')
ON CONFLICT DO NOTHING;

-- 35 atomos nuevos (5 por grupo nuevo)
DO $$
DECLARE
    r_group RECORD;
    atom INTEGER; pos INTEGER := 130;
    v_domain INTEGER; v_verb INTEGER; v_name TEXT; v_slug TEXT;
    verbs TEXT[] := ARRAY['crear','editar','eliminar','ver','listar','importar','exportar','asignar','revocar','validar','rechazar','archivar','restaurar','duplicar','aprobar'];
BEGIN
    FOR r_group IN SELECT * FROM bos_privilege.bos_group WHERE group_code >= 4 AND group_code <= 8 LOOP
        FOR atom IN 1..5 LOOP
            v_domain := CASE WHEN r_group.group_code <= 2 THEN 3 ELSE 1 END;
            v_verb := ((atom - 1) % 4) + 1;
            v_name := initcap(r_group.group_name) || ' ' || verbs[((r_group.app_code * r_group.group_code * atom) % 15) + 1];
            v_slug := lower(r_group.group_name) || '.' || verbs[((r_group.app_code * r_group.group_code * atom) % 15) + 1];
            INSERT INTO bos_privilege.bos_atom_catalog
                (app_code, group_code, atom_code, domain_code, verb_code, atom_name, atom_slug, atom_position, contextual_mask, logical_mask)
            VALUES (r_group.app_code, r_group.group_code, atom, v_domain, v_verb, v_name, v_slug, pos,
                    (v_domain * 1000000 + r_group.app_code * 1000 + r_group.group_code * 100 + atom)::INTEGER,
                    (v_verb * 256 + atom * 16)::INTEGER)
            ON CONFLICT DO NOTHING;
            pos := pos + 1;
        END LOOP;
    END LOOP;
END $$;

-- Politicas D3 para nuevos atomos de dominio 3
INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
SELECT app_code, group_code, atom_code, 3,
       'POL-D3-LIMITE-' || upper(atom_slug),
       jsonb_build_object(
           '$schema', 'bos_policy_v1', 'priority', 10, 'action', 'deny',
           'message', 'Monto excede limite para ' || atom_slug,
           'evaluate', jsonb_build_object('logic', 'and', 'conditions', jsonb_build_array(
               jsonb_build_object('field', 'amount', 'op', 'gt', 'value', '${params.limit}')
           )),
           'params', jsonb_build_object('limit', (random()*50000+5000)::INTEGER)
       )
FROM bos_privilege.bos_atom_catalog
WHERE domain_code = 3 AND atom_position >= 130
ON CONFLICT DO NOTHING;

-- Politicas D4 para nuevos atomos de sesion
INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
SELECT app_code, group_code, atom_code, 4,
       'POL-D4-SHIFT-' || upper(atom_slug),
       jsonb_build_object(
           '$schema', 'bos_policy_v1', 'priority', 30, 'action', 'deny',
           'message', 'Fuera de horario para ' || atom_slug,
           'evaluate', jsonb_build_object('logic', 'and', 'conditions', jsonb_build_array(
               jsonb_build_object('field', 'now_time', 'op', 'time_between',
                   'value', jsonb_build_object('start', '${params.start}', 'end', '${params.end}'))
           )),
           'params', jsonb_build_object('start', '08:00', 'end', '17:00')
       )
FROM bos_privilege.bos_atom_catalog
WHERE group_code = 4 AND atom_position >= 130
ON CONFLICT DO NOTHING;

-- Politicas D7 para 1/3 de nuevos atomos
INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
SELECT app_code, group_code, atom_code, 7,
       'POL-D7-CIDR-' || upper(atom_slug),
       jsonb_build_object(
           '$schema', 'bos_policy_v1', 'priority', 5, 'action', 'deny',
           'message', 'IP fuera de rango para ' || atom_slug,
           'evaluate', jsonb_build_object('logic', 'and', 'conditions', jsonb_build_array(
               jsonb_build_object('field', 'client_ip', 'op', 'cidr_match', 'value', '${params.cidr}')
           )),
           'params', jsonb_build_object('cidr', '10.0.0.0/8')
       )
FROM bos_privilege.bos_atom_catalog
WHERE atom_position >= 130 AND atom_position % 3 = 0
ON CONFLICT DO NOTHING;

-- Conteo final
SELECT 'APPS' as tipo, count(*) FROM bos_privilege.bos_application
UNION ALL SELECT 'GRUPOS', count(*) FROM bos_privilege.bos_group
UNION ALL SELECT 'ATOMOS', count(*) FROM bos_privilege.bos_atom_catalog
UNION ALL SELECT 'POLITICAS', count(*) FROM bos_privilege.bos_atom_policy
UNION ALL SELECT 'TOTAL', count(*) FROM (
    SELECT 1 FROM bos_privilege.bos_application
    UNION ALL SELECT 1 FROM bos_privilege.bos_group
    UNION ALL SELECT 1 FROM bos_privilege.bos_atom_catalog
    UNION ALL SELECT 1 FROM bos_privilege.bos_atom_policy
) sub
ORDER BY tipo;
