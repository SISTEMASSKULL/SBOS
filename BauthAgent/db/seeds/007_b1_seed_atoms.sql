BEGIN;
INSERT INTO bos_privilege.bos_application (app_code, app_name, app_slug, tenant_id)
VALUES (1, 'Tryton ERP', 'tryton', '00000000-0000-0000-0000-000000000001'::uuid);
INSERT INTO bos_privilege.bos_group (app_code, group_code, group_name) VALUES
    (1, 1, 'Comprobantes'), (1, 2, 'Facturacion'), (1, 3, 'Inventario'), (1, 4, 'Sesion');
INSERT INTO bos_privilege.bos_atom_catalog (app_code, group_code, atom_code, domain_code, verb_code, atom_name, atom_slug, atom_position, contextual_mask, logical_mask) VALUES
    (1, 1, 1, 3, 1, 'Crear comprobante', 'comprobantes.nuevo', 0, 6295808, 256),
    (1, 1, 2, 3, 2, 'Editar comprobante', 'comprobantes.editar', 1, 6295808, 512),
    (1, 1, 3, 3, 3, 'Eliminar comprobante', 'comprobantes.eliminar', 2, 6295808, 1024),
    (1, 1, 4, 3, 4, 'Ver comprobante', 'comprobantes.ver', 3, 6295808, 2048),
    (1, 2, 1, 3, 1, 'Emitir factura', 'facturacion.nuevo', 4, 6295809, 256),
    (1, 2, 2, 3, 4, 'Ver factura', 'facturacion.ver', 5, 6295809, 2048),
    (1, 3, 1, 1, 1, 'Registrar entrada', 'inventario.nuevo', 6, 4196608, 256),
    (1, 3, 2, 1, 4, 'Ver inventario', 'inventario.ver', 7, 4196608, 2048),
    (1, 4, 1, 1, 1, 'Ingresar al sistema', 'sistema.sesion.ingresar', 8, 1, 256),
    (1, 4, 2, 1, 4, 'Cerrar sesion', 'sistema.sesion.cerrar', 9, 1, 2048);
COMMIT;
