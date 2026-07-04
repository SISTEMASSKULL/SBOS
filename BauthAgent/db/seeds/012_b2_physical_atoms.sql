-- B2: Átomos del Dominio Físico (D2) — 17 átomos
-- SBOS-BAUTH-MOTORES-DOMINIO.md §D2
-- Puertas, zonas, hardware, dispositivos, red física

-- App 6 = Sistema (ya registrada). Grupo 5 = Físico.
INSERT INTO bos_privilege.bos_group (app_code, group_code, group_name) VALUES (6, 5, 'Fisico')
ON CONFLICT DO NOTHING;

INSERT INTO bos_privilege.bos_atom_catalog
    (app_code, group_code, atom_code, domain_code, verb_code, atom_name, atom_slug, atom_position, contextual_mask, logical_mask)
VALUES
    -- Sesión y Shell
    (6, 5, 1, 2, 1, 'Sesión física válida', 'fisico.sesion.valida', 300, 2099200, 256),
    (6, 5, 2, 2, 2, 'Desbloquear shell', 'fisico.shell.desbloquear', 301, 2099200, 512),

    -- Zonas de Acceso
    (6, 5, 3, 2, 1, 'Zona A — Acceso', 'fisico.zona.a', 302, 2099201, 256),
    (6, 5, 4, 2, 1, 'Zona B — Acceso', 'fisico.zona.b', 303, 2099201, 512),
    (6, 5, 5, 2, 1, 'Zona C — Acceso', 'fisico.zona.c', 304, 2099201, 1024),
    (6, 5, 6, 2, 1, 'Zona D — Acceso', 'fisico.zona.d', 305, 2099201, 2048),

    -- Niveles de Seguridad Física
    (6, 5, 7, 2, 1, 'Seguridad Nivel 1', 'fisico.seguridad.nivel1', 306, 2099202, 256),
    (6, 5, 8, 2, 1, 'Seguridad Nivel 2', 'fisico.seguridad.nivel2', 307, 2099202, 512),
    (6, 5, 9, 2, 1, 'Seguridad Nivel 3', 'fisico.seguridad.nivel3', 308, 2099202, 1024),
    (6, 5, 10, 2, 1, 'Seguridad Nivel 4', 'fisico.seguridad.nivel4', 309, 2099202, 2048),

    -- Control de Hardware
    (6, 5, 11, 2, 1, 'Impresora permitida', 'fisico.hardware.imprimir', 310, 2099203, 256),
    (6, 5, 12, 2, 1, 'USB Storage', 'fisico.hardware.usb', 311, 2099203, 512),
    (6, 5, 13, 2, 1, 'Red externa', 'fisico.red.externa', 312, 2099204, 256),
    (6, 5, 14, 2, 1, 'Acceso VPN', 'fisico.red.vpn', 313, 2099204, 512),

    -- Dispositivos
    (6, 5, 15, 2, 1, 'Terminal POS', 'fisico.dispositivo.pos', 314, 2099205, 256),
    (6, 5, 16, 2, 1, 'Panel de Administración', 'fisico.dispositivo.admin', 315, 2099205, 512),
    (6, 5, 17, 2, 1, 'Thunderbird Access', 'fisico.dispositivo.thunderbird', 316, 2099205, 1024)
ON CONFLICT DO NOTHING;

SELECT 'D2 atomos fisicos: ' || count(*) FROM bos_privilege.bos_atom_catalog WHERE domain_code = 2;
