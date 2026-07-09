-- ============================================================================
-- bauth_62__idn_role_closure.sql — Cierre transitivo DAG de herencia RBAC
-- IDEMPOTENTE: DELETE total + INSERT derivado del árbol parent_id + WITH RECURSIVE
-- Prerequisito: bauth_48 debe haber corrido primero (roles + parent_id wiring completo)
-- Convención: ancestro_id = padre en árbol · descendiente_id = hijo en árbol
-- Árbol: raíz única ROL-SYS-SUPERUSUARIO · 548 nodos · 547 aristas directas
-- ============================================================================
-- La closure es DATOS DERIVADOS del árbol parent_id en idn_role_template.
-- DELETE + rebuild es safe: no hay datos que no se puedan reconstruir.
-- G-B01-04: hierarchy_level se recalcula aquí desde el árbol real.
-- ============================================================================

SET lock_timeout = '10s';
BEGIN;

-- ═══ Limpiar closure anterior (datos derivados, reconstruibles) ═══
DELETE FROM bauth.idn_role_closure;

-- ═══ PASE 1: Aristas directas derivadas del árbol parent_id ═══
-- Lee TODOS los vínculos padre→hijo directamente de idn_role_template.parent_id.
-- No hardcodeamos pares: el árbol es la única fuente de verdad.
-- Resultado esperado: 547 aristas (548 roles − 1 raíz sin parent_id)
INSERT INTO bauth.idn_role_closure (closure_id, ancestro_id, descendiente_id, profundidad, ctx_id)
SELECT
    gen_random_uuid(),
    parent_id,          -- padre = ancestro
    id,                 -- hijo  = descendiente
    1,
    'seed'
FROM bauth.idn_role_template
WHERE parent_id IS NOT NULL
ON CONFLICT (ancestro_id, descendiente_id) DO NOTHING;

-- ═══ PASE 2: Cierre transitivo vía WITH RECURSIVE ═══
-- Propaga las aristas directas hacia todos los ancestros alcanzables.
-- Esto genera las rutas abuelo→nieto, bisabuelo→bisnieto, etc.
INSERT INTO bauth.idn_role_closure (closure_id, ancestro_id, descendiente_id, profundidad, ctx_id)
WITH RECURSIVE tc(anc, desc_, prof) AS (
    -- Base: todas las aristas directas ya insertadas
    SELECT ancestro_id, descendiente_id, profundidad
    FROM   bauth.idn_role_closure
    WHERE  ctx_id = 'seed'
    UNION ALL
    -- Paso: extender cada camino un nivel más abajo
    SELECT t.anc, c.descendiente_id, t.prof + c.profundidad
    FROM   tc t
    JOIN   bauth.idn_role_closure c ON t.desc_ = c.ancestro_id
    WHERE  c.ctx_id = 'seed'
)
SELECT
    gen_random_uuid(),
    anc,
    desc_,
    MIN(prof),
    'seed-transitivo'
FROM tc
WHERE (anc, desc_) NOT IN (
    SELECT ancestro_id, descendiente_id FROM bauth.idn_role_closure
)
GROUP BY anc, desc_
ON CONFLICT (ancestro_id, descendiente_id) DO NOTHING;

-- ═══ PASE 3: Recalcular hierarchy_level desde el árbol real ═══
-- hierarchy_level = profundidad del nodo en el árbol padre-hijo.
-- Raíz (ROL-SYS-SUPERUSUARIO) = nivel 0.
-- Resuelve G-B01-04: antes era un campo con valor fijo incorrecto.
WITH RECURSIVE profundidad(id, nivel) AS (
    -- Raíz: nodos sin parent_id
    SELECT id, 0
    FROM   bauth.idn_role_template
    WHERE  parent_id IS NULL
    UNION ALL
    -- Hijos: nivel del padre + 1
    SELECT c.id, d.nivel + 1
    FROM   bauth.idn_role_template c
    JOIN   profundidad d ON c.parent_id = d.id
)
UPDATE bauth.idn_role_template t
SET    hierarchy_level = d.nivel
FROM   profundidad d
WHERE  t.id = d.id;

COMMIT;

-- ═══ Verificación post-ejecución ═══
SELECT 'aristas directas'       AS metrica, COUNT(*)::text AS valor
FROM   bauth.idn_role_closure WHERE profundidad = 1;

SELECT 'closure total'          AS metrica, COUNT(*)::text AS valor
FROM   bauth.idn_role_closure;

SELECT 'max profundidad'        AS metrica, MAX(profundidad)::text AS valor
FROM   bauth.idn_role_closure;

SELECT 'roles con ancestros'    AS metrica, COUNT(DISTINCT descendiente_id)::text AS valor
FROM   bauth.idn_role_closure;

SELECT 'raices sueltas (debe=1)' AS metrica, COUNT(*)::text AS valor
FROM   bauth.idn_role_template WHERE parent_id IS NULL;

SELECT 'distribucion por nivel' AS metrica, hierarchy_level::text || ' → ' || COUNT(*)::text AS valor
FROM   bauth.idn_role_template
GROUP  BY hierarchy_level
ORDER  BY hierarchy_level;
