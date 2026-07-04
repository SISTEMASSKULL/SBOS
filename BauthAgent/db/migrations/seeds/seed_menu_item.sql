-- seed_menu_item.sql — ~40 ítems de menú jerárquico SBOS
-- IDEMPOTENCIA: TRUNCATE + RESTART IDENTITY CASCADE + REINDEX + INSERT
-- Fuente: BAUTH-090-MENU-SYSTEM-SPEC.md §3.1
-- ═══════════════════════════════════════════════════════════

SET lock_timeout = '5s';
TRUNCATE TABLE bglobal.menu_item RESTART IDENTITY CASCADE;
REINDEX TABLE bglobal.menu_item;

-- Nivel 0 — Raíces (7)
INSERT INTO bglobal.menu_item (tenant_id, parent_id, label, route, icon, sort_order, menu_type) VALUES
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), NULL, 'Dashboard',  '/dashboard',  'dashboard', 1, 'HIERARCHICAL'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), NULL, 'Finanzas',   '/finanzas',   'money',     2, 'HIERARCHICAL'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), NULL, 'Comercial',  '/comercial',  'shopping',  3, 'HIERARCHICAL'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), NULL, 'Inventario', '/inventario', 'package',   4, 'HIERARCHICAL'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), NULL, 'RRHH',       '/rrhh',       'users',     5, 'HIERARCHICAL'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), NULL, 'Admin',      '/admin',      'settings',  6, 'HIERARCHICAL'),
((SELECT tenant_id FROM bauth.idn_tenant WHERE tenant_slug='skull'), NULL, 'Auditoria',  '/auditoria',  'shield',    7, 'HIERARCHICAL');

-- Nivel 1 — Hijos de Finanzas (5)
INSERT INTO bglobal.menu_item (tenant_id, parent_id, label, route, icon, sort_order, menu_type)
SELECT tenant_id, p.id, label, route, icon, sort_order, 'HIERARCHICAL'
FROM bauth.idn_tenant, (SELECT id FROM bglobal.menu_item WHERE label='Finanzas' AND parent_id IS NULL) p,
(VALUES ('Transacciones','/finanzas/transacciones','exchange',1),
        ('Facturacion','/finanzas/facturacion','file-invoice',2),
        ('Tesorería','/finanzas/tesoreria','wallet',3),
        ('Contabilidad','/finanzas/contabilidad','calculator',4),
        ('Reportes','/finanzas/reportes','chart-bar',5)) AS v(label,route,icon,sort_order)
WHERE tenant_slug='skull';

-- Nivel 1 — Hijos de Comercial (3)
INSERT INTO bglobal.menu_item (tenant_id, parent_id, label, route, icon, sort_order, menu_type)
SELECT tenant_id, p.id, label, route, icon, sort_order, 'HIERARCHICAL'
FROM bauth.idn_tenant, (SELECT id FROM bglobal.menu_item WHERE label='Comercial' AND parent_id IS NULL) p,
(VALUES ('Ventas','/comercial/ventas','cart',1),
        ('Clientes','/comercial/clientes','contacts',2),
        ('Marketing','/comercial/marketing','megaphone',3)) AS v(label,route,icon,sort_order)
WHERE tenant_slug='skull';

-- Nivel 1 — Hijos de Inventario (3)
INSERT INTO bglobal.menu_item (tenant_id, parent_id, label, route, icon, sort_order, menu_type)
SELECT tenant_id, p.id, label, route, icon, sort_order, 'HIERARCHICAL'
FROM bauth.idn_tenant, (SELECT id FROM bglobal.menu_item WHERE label='Inventario' AND parent_id IS NULL) p,
(VALUES ('Almacen','/inventario/almacen','archive',1),
        ('Compras','/inventario/compras','truck',2),
        ('Proveedores','/inventario/proveedores','briefcase',3)) AS v(label,route,icon,sort_order)
WHERE tenant_slug='skull';

-- Nivel 1 — Hijos de RRHH (3)
INSERT INTO bglobal.menu_item (tenant_id, parent_id, label, route, icon, sort_order, menu_type)
SELECT tenant_id, p.id, label, route, icon, sort_order, 'HIERARCHICAL'
FROM bauth.idn_tenant, (SELECT id FROM bglobal.menu_item WHERE label='RRHH' AND parent_id IS NULL) p,
(VALUES ('Empleados','/rrhh/empleados','user',1),
        ('Nomina','/rrhh/nomina','money',2),
        ('Asistencia','/rrhh/asistencia','clock',3)) AS v(label,route,icon,sort_order)
WHERE tenant_slug='skull';

-- Nivel 1 — Hijos de Admin (7)
INSERT INTO bglobal.menu_item (tenant_id, parent_id, label, route, icon, sort_order, menu_type)
SELECT tenant_id, p.id, label, route, icon, sort_order, 'HIERARCHICAL'
FROM bauth.idn_tenant, (SELECT id FROM bglobal.menu_item WHERE label='Admin' AND parent_id IS NULL) p,
(VALUES ('Usuarios','/admin/usuarios','user-plus',1),
        ('Roles','/admin/roles','user-check',2),
        ('Empresas','/admin/empresas','building',3),
        ('Sucursales','/admin/sucursales','git-branch',4),
        ('POS','/admin/pos','monitor',5),
        ('Dominios','/admin/dominios','globe',6),
        ('Configuracion','/admin/config','sliders',7)) AS v(label,route,icon,sort_order)
WHERE tenant_slug='skull';

-- Nivel 1 — Hijos de Auditoria (4)
INSERT INTO bglobal.menu_item (tenant_id, parent_id, label, route, icon, sort_order, menu_type)
SELECT tenant_id, p.id, label, route, icon, sort_order, 'HIERARCHICAL'
FROM bauth.idn_tenant, (SELECT id FROM bglobal.menu_item WHERE label='Auditoria' AND parent_id IS NULL) p,
(VALUES ('Eventos','/auditoria/eventos','list',1),
        ('Accesos','/auditoria/accesos','lock',2),
        ('Sesiones','/auditoria/sesiones','activity',3),
        ('Blockchain','/auditoria/blockchain','link',4)) AS v(label,route,icon,sort_order)
WHERE tenant_slug='skull';

-- Nivel 2 — Hijos de Transacciones (3)
INSERT INTO bglobal.menu_item (tenant_id, parent_id, label, route, icon, sort_order, menu_type)
SELECT tenant_id, p.id, label, route, icon, sort_order, 'HIERARCHICAL'
FROM bauth.idn_tenant, (SELECT id FROM bglobal.menu_item WHERE label='Transacciones' AND parent_id IS NOT NULL) p,
(VALUES ('Nueva Transferencia','/finanzas/transacciones/nueva','plus-circle',1),
        ('Historial','/finanzas/transacciones/historial','history',2),
        ('Pendientes','/finanzas/transacciones/pendientes','clock',3)) AS v(label,route,icon,sort_order)
WHERE tenant_slug='skull';

-- Nivel 2 — Hijos de Usuarios (3)
INSERT INTO bglobal.menu_item (tenant_id, parent_id, label, route, icon, sort_order, menu_type)
SELECT tenant_id, p.id, label, route, icon, sort_order, 'HIERARCHICAL'
FROM bauth.idn_tenant, (SELECT id FROM bglobal.menu_item WHERE label='Usuarios' AND parent_id IS NOT NULL) p,
(VALUES ('Crear Usuario','/admin/usuarios/crear','user-plus',1),
        ('Lista','/admin/usuarios/lista','list',2),
        ('Revocar Acceso','/admin/usuarios/revocar','shield-off',3)) AS v(label,route,icon,sort_order)
WHERE tenant_slug='skull';

-- Nivel 2 — Hijos de Roles (3)
INSERT INTO bglobal.menu_item (tenant_id, parent_id, label, route, icon, sort_order, menu_type)
SELECT tenant_id, p.id, label, route, icon, sort_order, 'HIERARCHICAL'
FROM bauth.idn_tenant, (SELECT id FROM bglobal.menu_item WHERE label='Roles' AND parent_id IS NOT NULL) p,
(VALUES ('Crear Rol','/admin/roles/crear','plus-circle',1),
        ('Catalogo','/admin/roles/catalogo','book',2),
        ('Asignar','/admin/roles/asignar','user-check',3)) AS v(label,route,icon,sort_order)
WHERE tenant_slug='skull';

-- Nivel 1 — Admin: Config Sistema (acceso a semillas del framework)
INSERT INTO bglobal.menu_item (tenant_id, parent_id, label, route, icon, sort_order, menu_type)
SELECT tenant_id, p.id, 'Config Sistema', '/admin/config-sistema', 'sliders', 1, 'HIERARCHICAL'
FROM bauth.idn_tenant, (SELECT id FROM bglobal.menu_item WHERE label='Admin' AND parent_id IS NULL) p
WHERE tenant_slug='skull';

-- Nivel 2 — Config Sistema: submenús por área de seed
INSERT INTO bglobal.menu_item (tenant_id, parent_id, label, route, icon, sort_order, menu_type)
SELECT t.tenant_id, c.id, v.label, v.route, v.icon, v.sort_order, 'HIERARCHICAL'
FROM bauth.idn_tenant t,
     (SELECT id FROM bglobal.menu_item WHERE label='Config Sistema' AND parent_id IS NOT NULL) c,
     (VALUES ('Dominios (D1-D12)','/admin/config-sistema/dominios','grid',1),
             ('Autenticacion','/admin/config-sistema/autenticacion','key',2),
             ('Framework','/admin/config-sistema/framework','database',3),
             ('Cumplimiento','/admin/config-sistema/cumplimiento','shield-check',4),
             ('Organizacion','/admin/config-sistema/organizacion','building',5),
             ('Menus','/admin/config-sistema/menus','menu',6)) AS v(label,route,icon,sort_order)
WHERE t.tenant_slug='skull';

-- ═══════════════════════════════════════════════════════════
-- Items CONTEXTUALES — un ítem por cada context_key en menu_context
-- Estos alimentan los dropdowns/selección del frontend
-- ═══════════════════════════════════════════════════════════
INSERT INTO bglobal.menu_item (tenant_id, parent_id, label, menu_type, context_key, sort_order, is_visible)
SELECT t.tenant_id, (SELECT id FROM bglobal.menu_item WHERE label='Config Sistema' AND parent_id IS NOT NULL LIMIT 1),
       mc.entity_type || ': ' || mc.description,
       'CONTEXTUAL', mc.context_key,
       row_number() OVER (ORDER BY mc.context_key)::int, false
FROM bauth.idn_tenant t,
     bglobal.menu_context mc
WHERE t.tenant_slug='skull' AND mc.tenant_id = t.tenant_id
ON CONFLICT DO NOTHING;

-- SELECT count(*) FROM bglobal.menu_item WHERE menu_type = 'CONTEXTUAL'; -- 43
