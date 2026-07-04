-- Políticas masivas para todos los átomos existentes
-- Cada átomo recibe 1-2 políticas de su dominio correspondiente

-- D3 Financiero: 2 políticas por átomo (POL-D3-LIMITE + POL-D3-DUAL)
INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
SELECT app_code, group_code, atom_code, 3,
       'POL-D3-LIMITE-' || upper(atom_slug),
       jsonb_build_object(
           '$schema', 'bos_policy_v1', 'priority', 10, 'action', 'deny',
           'message', 'Monto excede el limite para ' || atom_slug,
           'evaluate', jsonb_build_object('logic', 'and', 'conditions', jsonb_build_array(
               jsonb_build_object('field', 'amount', 'op', 'gt', 'value', '${params.single_limit_bob}')
           )),
           'params', jsonb_build_object('single_limit_bob', 10000, 'daily_limit_bob', 50000)
       )
FROM bos_privilege.bos_atom_catalog
WHERE domain_code = 3
ON CONFLICT DO NOTHING;

INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
SELECT app_code, group_code, atom_code, 3,
       'POL-D3-DUAL-' || upper(atom_slug),
       jsonb_build_object(
           '$schema', 'bos_policy_v1', 'priority', 20, 'action', 'pending_approval',
           'message', 'Requiere segunda firma para ' || atom_slug,
           'evaluate', jsonb_build_object('logic', 'and', 'conditions', jsonb_build_array(
               jsonb_build_object('field', 'amount', 'op', 'gt', 'value', '${params.threshold}'),
               jsonb_build_object('field', 'is_approved', 'op', 'eq', 'value', false)
           )),
           'params', jsonb_build_object('threshold', 25000)
       )
FROM bos_privilege.bos_atom_catalog
WHERE domain_code = 3
ON CONFLICT DO NOTHING;

-- D4 Temporal: para átomos de Sesion
INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
SELECT app_code, group_code, atom_code, 4,
       'POL-D4-SHIFT-' || upper(atom_slug),
       jsonb_build_object(
           '$schema', 'bos_policy_v1', 'priority', 30, 'action', 'deny',
           'message', 'Fuera del horario laboral para ' || atom_slug,
           'evaluate', jsonb_build_object('logic', 'and', 'conditions', jsonb_build_array(
               jsonb_build_object('field', 'now_time', 'op', 'time_between',
                   'value', jsonb_build_object('start', '${params.shift_start}', 'end', '${params.shift_end}'))
           )),
           'params', jsonb_build_object('shift_start', '08:00', 'shift_end', '17:00')
       )
FROM bos_privilege.bos_atom_catalog
WHERE group_code = 4
ON CONFLICT DO NOTHING;

-- D6 Geoespacial: para átomos de Sesion
INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
SELECT app_code, group_code, atom_code, 6,
       'POL-D6-TRAVEL-' || upper(atom_slug),
       jsonb_build_object(
           '$schema', 'bos_policy_v1', 'priority', 20, 'action', 'deny',
           'message', 'Viaje imposible detectado para ' || atom_slug,
           'evaluate', jsonb_build_object('logic', 'and', 'conditions', jsonb_build_array(
               jsonb_build_object('field', 'distance_km', 'op', 'gt', 'value', '${params.max_km}'),
               jsonb_build_object('field', 'time_since_last_login_h', 'op', 'lt', 'value', '${params.max_hours}')
           )),
           'params', jsonb_build_object('max_km', 900, 'max_hours', 1)
       )
FROM bos_privilege.bos_atom_catalog
WHERE group_code = 4
ON CONFLICT DO NOTHING;

-- D7 Red: para 1/3 de átomos
INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
SELECT app_code, group_code, atom_code, 7,
       'POL-D7-CIDR-' || upper(atom_slug),
       jsonb_build_object(
           '$schema', 'bos_policy_v1', 'priority', 5, 'action', 'deny',
           'message', 'IP fuera del rango corporativo para ' || atom_slug,
           'evaluate', jsonb_build_object('logic', 'and', 'conditions', jsonb_build_array(
               jsonb_build_object('field', 'client_ip', 'op', 'cidr_match', 'value', '${params.allowed_cidr}')
           )),
           'params', jsonb_build_object('allowed_cidr', '10.0.0.0/8')
       )
FROM bos_privilege.bos_atom_catalog
WHERE atom_position % 3 = 0
ON CONFLICT DO NOTHING;

-- D10 Delegación: para átomos de dominio 1
INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
SELECT app_code, group_code, atom_code, 10,
       'POL-D10-DELEG-' || upper(atom_slug),
       jsonb_build_object(
           '$schema', 'bos_policy_v1', 'priority', 40, 'action', 'deny',
           'message', 'Delegacion excede duracion maxima para ' || atom_slug,
           'evaluate', jsonb_build_object('logic', 'and', 'conditions', jsonb_build_array(
               jsonb_build_object('field', 'delegation_days', 'op', 'gt', 'value', '${params.max_days}')
           )),
           'params', jsonb_build_object('max_days', 21)
       )
FROM bos_privilege.bos_atom_catalog
WHERE domain_code = 1 AND atom_position % 5 = 0
ON CONFLICT DO NOTHING;

-- Verificación
SELECT 'TOTAL' as metrica, count(*) as cantidad FROM (
    SELECT 'apps' as t FROM bos_privilege.bos_application
    UNION ALL SELECT 'grupos' FROM bos_privilege.bos_group
    UNION ALL SELECT 'atomos' FROM bos_privilege.bos_atom_catalog
    UNION ALL SELECT 'politicas' FROM bos_privilege.bos_atom_policy
) sub;
