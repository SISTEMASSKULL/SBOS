WITH grupos AS (
    SELECT row_number() OVER (ORDER BY app_code, group_code) - 1 AS idx,
           app_code, group_code
    FROM bos_privilege.bos_group
),
atoms AS (
    SELECT
        100 + i AS atom_code,
        g.app_code,
        g.group_code,
        (i % 12) + 1 AS domain_code,
        ((i * 3) % 4) + 1 AS verb_code,
        1200 + i AS atom_position,
        CASE (i % 12) + 1
            WHEN 1 THEN 'Logico' WHEN 2 THEN 'Fisico' WHEN 3 THEN 'Financiero'
            WHEN 4 THEN 'Temporal' WHEN 5 THEN 'Biometrico' WHEN 6 THEN 'Geoespacial'
            WHEN 7 THEN 'Red' WHEN 8 THEN 'Contexto' WHEN 9 THEN 'Credencial'
            WHEN 10 THEN 'Delegacion' WHEN 11 THEN 'Auditoria' WHEN 12 THEN 'Blockchain'
        END || ' #' || (100 + i)::text AS atom_name,
        'atom-' || (100+i)::text || '.d' || ((i%12)+1)::text 
            || '.a' || g.app_code::text || '.g' || g.group_code::text 
            || '.v' || (((i*3)%4)+1)::text AS atom_slug,
        (((i % 12) + 1) << 8) | (g.app_code << 12) | (g.group_code << 21) AS contextual_mask,
        ((((i * 3) % 4) + 1) << 8) | (100 + i) AS logical_mask
    FROM generate_series(0, 499) AS i
    JOIN grupos g ON g.idx = (i % 34)
)
INSERT INTO bos_privilege.bos_atom_catalog
    (atom_code, app_code, group_code, domain_code, verb_code,
     atom_name, atom_slug, atom_position, contextual_mask, logical_mask, created_at)
SELECT atom_code, app_code, group_code, domain_code, verb_code,
       atom_name, atom_slug, atom_position, contextual_mask, logical_mask, now()
FROM atoms
ON CONFLICT DO NOTHING;
