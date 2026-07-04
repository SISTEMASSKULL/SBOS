-- Atomos extra dominio 3
DO $$
DECLARE
    r_group RECORD;
    atom INTEGER; pos INTEGER := 200;
    verbs TEXT[] := ARRAY['crear','editar','eliminar','ver','listar','importar','exportar','conciliar','revertir','auditar'];
BEGIN
    FOR r_group IN SELECT * FROM bos_privilege.bos_group WHERE group_code <= 2 LOOP
        FOR atom IN 6..10 LOOP
            INSERT INTO bos_privilege.bos_atom_catalog
                (app_code, group_code, atom_code, domain_code, verb_code, atom_name, atom_slug, atom_position, contextual_mask, logical_mask)
            VALUES (r_group.app_code, r_group.group_code, atom, 3, ((atom-1)%4)+1,
                    initcap(r_group.group_name) || ' ' || verbs[atom],
                    lower(r_group.group_name) || '.' || verbs[atom],
                    pos,
                    (3*1000000 + r_group.app_code*1000 + r_group.group_code*100 + atom)::INTEGER,
                    ((((atom-1)%4)+1)*256 + atom*16)::INTEGER)
            ON CONFLICT DO NOTHING;
            pos := pos + 1;
        END LOOP;
    END LOOP;
END $$;

-- D3-LIMITE para todos los de dominio 3
INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
SELECT app_code, group_code, atom_code, 3,
       'POL-D3-LIMITE-' || upper(atom_slug),
       jsonb_build_object(
           '$schema', 'bos_policy_v1', 'priority', 10, 'action', 'deny',
           'message', 'Monto excede limite',
           'evaluate', jsonb_build_object('logic', 'and', 'conditions', jsonb_build_array(
               jsonb_build_object('field', 'amount', 'op', 'gt', 'value', '${params.limit}')
           )),
           'params', jsonb_build_object('limit', (random()*50000+5000)::INTEGER)
       )
FROM bos_privilege.bos_atom_catalog WHERE domain_code = 3
ON CONFLICT DO NOTHING;

-- D3-DUAL para todos
INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
SELECT app_code, group_code, atom_code, 3,
       'POL-D3-DUAL-' || upper(atom_slug),
       jsonb_build_object(
           '$schema', 'bos_policy_v1', 'priority', 20, 'action', 'pending_approval',
           'message', 'Requiere segunda firma',
           'evaluate', jsonb_build_object('logic', 'and', 'conditions', jsonb_build_array(
               jsonb_build_object('field', 'amount', 'op', 'gt', 'value', '${params.threshold}')
           )),
           'params', jsonb_build_object('threshold', 25000)
       )
FROM bos_privilege.bos_atom_catalog WHERE domain_code = 3
ON CONFLICT DO NOTHING;

-- D7 para todos los atom_position % 3 = 0
INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
SELECT app_code, group_code, atom_code, 7,
       'POL-D7-CIDR-' || upper(atom_slug),
       jsonb_build_object(
           '$schema', 'bos_policy_v1', 'priority', 5, 'action', 'deny',
           'message', 'IP fuera de rango',
           'evaluate', jsonb_build_object('logic', 'and', 'conditions', jsonb_build_array(
               jsonb_build_object('field', 'client_ip', 'op', 'cidr_match', 'value', '${params.cidr}')
           )),
           'params', jsonb_build_object('cidr', '10.0.0.0/8')
       )
FROM bos_privilege.bos_atom_catalog WHERE atom_position % 3 = 0
ON CONFLICT DO NOTHING;

-- Verificacion
SELECT 'apps' t, count(*) FROM bos_privilege.bos_application
UNION ALL SELECT 'grupos', count(*) FROM bos_privilege.bos_group
UNION ALL SELECT 'atomos', count(*) FROM bos_privilege.bos_atom_catalog
UNION ALL SELECT 'politicas', count(*) FROM bos_privilege.bos_atom_policy
ORDER BY t;
