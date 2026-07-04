-- ============================================================
-- B1 SEED MASIVO — 550+ registros para validación robusta
-- VPS: vmi3346550 · PostgreSQL 18.4 · bauth_db
-- ============================================================

-- Grupos adicionales para apps existentes (app_code 1=Tryton, 2=OrangeHRM, 3=Saleor, 4=CoreUI, 5=bSearch, 6=Sistema)
INSERT INTO bos_privilege.bos_group (app_code, group_code, group_name) VALUES
    (1, 5, 'Contabilidad'), (1, 6, 'Caja'), (1, 7, 'Bancos'), (1, 8, 'Reportes'),
    (2, 1, 'Empleados'), (2, 2, 'Nominas'), (2, 3, 'Reclutamiento'), (2, 4, 'Evaluaciones'),
    (3, 1, 'Productos'), (3, 2, 'Pedidos'), (3, 3, 'Clientes'), (3, 4, 'Descuentos'),
    (4, 1, 'Dashboard'), (4, 2, 'Usuarios'), (4, 3, 'Configuracion'), (4, 4, 'Temas'),
    (5, 1, 'Indices'), (5, 2, 'Consultas'), (5, 3, 'Federacion'),
    (6, 2, 'Configuracion'), (6, 3, 'Auditoria'), (6, 4, 'Mantenimiento')
ON CONFLICT DO NOTHING;

-- Función auxiliar para generar átomos masivamente (solo para grupos que existen)
DO $$
DECLARE
    r_group RECORD;
    atom INTEGER; pos INTEGER := 10;
    v_domain INTEGER; v_verb INTEGER; v_name TEXT; v_slug TEXT;
    v_ctx_mask INTEGER; v_log_mask INTEGER;
    v_action_idx INTEGER;
    verb_names TEXT[] := ARRAY['crear','editar','eliminar','ver','aprobar','importar','exportar','asignar','revocar','listar','validar','rechazar','archivar','restaurar','duplicar'];
BEGIN
    FOR r_group IN SELECT app_code, group_code, group_name FROM bos_privilege.bos_group LOOP
        FOR atom IN 1..5 LOOP
            v_domain := CASE WHEN r_group.group_code <= 2 THEN 3 ELSE 1 END;
            v_verb := ((atom - 1) % 4) + 1;
            v_action_idx := ((r_group.app_code * r_group.group_code * atom) % 15) + 1;
            v_name := initcap(r_group.group_name) || ' ' || verb_names[v_action_idx];
            v_slug := lower(r_group.group_name) || '.' || verb_names[v_action_idx];
            v_ctx_mask := (v_domain * 1000000 + r_group.app_code * 1000 + r_group.group_code * 100 + atom)::INTEGER;
            v_log_mask := (v_verb * 256 + atom * 16)::INTEGER;

            INSERT INTO bos_privilege.bos_atom_catalog
                (app_code, group_code, atom_code, domain_code, verb_code, atom_name, atom_slug, atom_position, contextual_mask, logical_mask)
            VALUES (r_group.app_code, r_group.group_code, atom, v_domain, v_verb, v_name, v_slug, pos, v_ctx_mask, v_log_mask)
            ON CONFLICT DO NOTHING;

            pos := pos + 1;
        END LOOP;
    END LOOP;
END $$;

-- Políticas financieras (D3) para átomos de dominio 3
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT app_code, group_code, atom_code, atom_slug
             FROM bos_privilege.bos_atom_catalog
             WHERE domain_code = 3
    LOOP
        -- POL-D3-LIMITE: deny si excede límite
        INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
        VALUES (r.app_code, r.group_code, r.atom_code, 3, 'POL-D3-LIMITE-' || upper(r.atom_slug),
            jsonb_build_object(
                '$schema', 'bos_policy_v1',
                'priority', 10,
                'action', 'deny',
                'message', 'Monto excede el limite permitido para ' || r.atom_slug,
                'evaluate', jsonb_build_object(
                    'logic', 'and',
                    'conditions', jsonb_build_array(
                        jsonb_build_object('field', 'amount', 'op', 'gt', 'value', '${params.single_limit_bob}')
                    )
                ),
                'params', jsonb_build_object(
                    'single_limit_bob', (random()*50000 + 5000)::INTEGER,
                    'daily_limit_bob', (random()*200000 + 20000)::INTEGER
                )
            )
        ON CONFLICT DO NOTHING;

        -- POL-D3-DUAL-APPROVAL: requiere doble firma
        INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
        VALUES (r.app_code, r.group_code, r.atom_code, 3, 'POL-D3-DUAL-' || upper(r.atom_slug),
            jsonb_build_object(
                '$schema', 'bos_policy_v1',
                'priority', 20,
                'action', 'pending_approval',
                'message', 'Requiere segunda firma para ' || r.atom_slug,
                'evaluate', jsonb_build_object(
                    'logic', 'and',
                    'conditions', jsonb_build_array(
                        jsonb_build_object('field', 'amount', 'op', 'gt', 'value', '${params.threshold}'),
                        jsonb_build_object('field', 'is_approved', 'op', 'eq', 'value', false)
                    )
                ),
                'params', jsonb_build_object('threshold', 25000)
            )
        ON CONFLICT DO NOTHING;
    END LOOP;
END $$;

-- Políticas temporales (D4) para átomos de sesión (app=6, group=4)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT app_code, group_code, atom_code, atom_slug
             FROM bos_privilege.bos_atom_catalog
             WHERE app_code = 6 AND group_code = 4
    LOOP
        INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
        VALUES (r.app_code, r.group_code, r.atom_code, 4, 'POL-D4-SHIFT-' || upper(r.atom_slug),
            jsonb_build_object(
                '$schema', 'bos_policy_v1',
                'priority', 30,
                'action', 'deny',
                'message', 'Fuera del horario laboral para ' || r.atom_slug,
                'evaluate', jsonb_build_object(
                    'logic', 'and',
                    'conditions', jsonb_build_array(
                        jsonb_build_object('field', 'now_time', 'op', 'time_between',
                            'value', jsonb_build_object('start', '${params.shift_start}', 'end', '${params.shift_end}'))
                    )
                ),
                'params', jsonb_build_object('shift_start', '08:00', 'shift_end', '17:00')
            )
        ON CONFLICT DO NOTHING;
    END LOOP;
END $$;

-- Políticas geoespaciales (D6) para átomos de sesión
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT app_code, group_code, atom_code, atom_slug
             FROM bos_privilege.bos_atom_catalog
             WHERE app_code = 6 AND group_code = 4
    LOOP
        INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
        VALUES (r.app_code, r.group_code, r.atom_code, 6, 'POL-D6-TRAVEL-' || upper(r.atom_slug),
            jsonb_build_object(
                '$schema', 'bos_policy_v1',
                'priority', 20,
                'action', 'deny',
                'message', 'Viaje imposible detectado para ' || r.atom_slug,
                'evaluate', jsonb_build_object(
                    'logic', 'and',
                    'conditions', jsonb_build_array(
                        jsonb_build_object('field', 'distance_km', 'op', 'gt', 'value', '${params.max_km}'),
                        jsonb_build_object('field', 'time_since_last_login_h', 'op', 'lt', 'value', '${params.max_hours}')
                    )
                ),
                'params', jsonb_build_object('max_km', 900, 'max_hours', 1)
            )
        ON CONFLICT DO NOTHING;
    END LOOP;
END $$;

-- Políticas de red (D7) para todos los átomos
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT app_code, group_code, atom_code, atom_slug
             FROM bos_privilege.bos_atom_catalog
             WHERE atom_position % 3 = 0  -- ~1/3 de átomos
    LOOP
        INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
        VALUES (r.app_code, r.group_code, r.atom_code, 7, 'POL-D7-CIDR-' || upper(r.atom_slug),
            jsonb_build_object(
                '$schema', 'bos_policy_v1',
                'priority', 5,
                'action', 'deny',
                'message', 'IP fuera del rango corporativo para ' || r.atom_slug,
                'evaluate', jsonb_build_object(
                    'logic', 'and',
                    'conditions', jsonb_build_array(
                        jsonb_build_object('field', 'client_ip', 'op', 'cidr_match', 'value', '${params.allowed_cidr}')
                    )
                ),
                'params', jsonb_build_object('allowed_cidr', '10.0.0.0/8')
            )
        ON CONFLICT DO NOTHING;
    END LOOP;
END $$;

-- Políticas de delegación (D10) para átomos de dominio 1
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT app_code, group_code, atom_code, atom_slug
             FROM bos_privilege.bos_atom_catalog
             WHERE domain_code = 1 AND atom_position % 5 = 0
    LOOP
        INSERT INTO bos_privilege.bos_atom_policy (app_code, group_code, atom_code, policy_domain, policy_slug, policy_data)
        VALUES (r.app_code, r.group_code, r.atom_code, 10, 'POL-D10-DELEG-' || upper(r.atom_slug),
            jsonb_build_object(
                '$schema', 'bos_policy_v1',
                'priority', 40,
                'action', 'deny',
                'message', 'Delegacion excede duracion maxima para ' || r.atom_slug,
                'evaluate', jsonb_build_object(
                    'logic', 'and',
                    'conditions', jsonb_build_array(
                        jsonb_build_object('field', 'delegation_days', 'op', 'gt', 'value', '${params.max_days}')
                    )
                ),
                'params', jsonb_build_object('max_days', 21)
            )
        ON CONFLICT DO NOTHING;
    END LOOP;
END $$;

-- Verificación final
SELECT 'APPS' as tipo, count(*) FROM bos_privilege.bos_application
UNION ALL SELECT 'GRUPOS', count(*) FROM bos_privilege.bos_group
UNION ALL SELECT 'ATOMOS', count(*) FROM bos_privilege.bos_atom_catalog
UNION ALL SELECT 'POLITICAS', count(*) FROM bos_privilege.bos_atom_policy
ORDER BY tipo;
