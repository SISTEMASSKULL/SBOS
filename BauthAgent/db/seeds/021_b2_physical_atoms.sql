-- B2: 17 átomos D2 × 3 verbos = 51 registros con grupos existentes
INSERT INTO bos_privilege.bos_atom_catalog
    (atom_code, app_code, group_code, domain_code, verb_code,
     atom_name, atom_slug, atom_position, contextual_mask, logical_mask, created_at)
VALUES
(11,2,1,2,1,'Puerta Zona A [nuevo]','d2.door.zone_a.nuevo',1701,(2<<8)|(2<<12)|(1<<21),(1<<8)|11,now()),
(12,2,1,2,2,'Puerta Zona A [editar]','d2.door.zone_a.editar',1702,(2<<8)|(2<<12)|(1<<21),(2<<8)|12,now()),
(14,2,1,2,4,'Puerta Zona A [ver]','d2.door.zone_a.ver',1703,(2<<8)|(2<<12)|(1<<21),(4<<8)|14,now()),
(21,2,2,2,1,'Puerta Zona B [nuevo]','d2.door.zone_b.nuevo',1704,(2<<8)|(2<<12)|(2<<21),(1<<8)|21,now()),
(22,2,2,2,2,'Puerta Zona B [editar]','d2.door.zone_b.editar',1705,(2<<8)|(2<<12)|(2<<21),(2<<8)|22,now()),
(24,2,2,2,4,'Puerta Zona B [ver]','d2.door.zone_b.ver',1706,(2<<8)|(2<<12)|(2<<21),(4<<8)|24,now()),
(31,5,1,2,1,'Acceso Nivel 1 [nuevo]','d2.phy_sec.level_1.nuevo',1707,(2<<8)|(5<<12)|(1<<21),(1<<8)|31,now()),
(32,5,1,2,2,'Acceso Nivel 1 [editar]','d2.phy_sec.level_1.editar',1708,(2<<8)|(5<<12)|(1<<21),(2<<8)|32,now()),
(34,5,1,2,4,'Acceso Nivel 1 [ver]','d2.phy_sec.level_1.ver',1709,(2<<8)|(5<<12)|(1<<21),(4<<8)|34,now()),
(41,5,2,2,1,'Acceso Nivel 2 [nuevo]','d2.phy_sec.level_2.nuevo',1710,(2<<8)|(5<<12)|(2<<21),(1<<8)|41,now()),
(42,5,2,2,2,'Acceso Nivel 2 [editar]','d2.phy_sec.level_2.editar',1711,(2<<8)|(5<<12)|(2<<21),(2<<8)|42,now()),
(44,5,2,2,4,'Acceso Nivel 2 [ver]','d2.phy_sec.level_2.ver',1712,(2<<8)|(5<<12)|(2<<21),(4<<8)|44,now()),
(51,3,1,2,1,'Shell Sistema [nuevo]','d2.shell.system.nuevo',1713,(2<<8)|(3<<12)|(1<<21),(1<<8)|51,now()),
(52,3,1,2,2,'Shell Sistema [editar]','d2.shell.system.editar',1714,(2<<8)|(3<<12)|(1<<21),(2<<8)|52,now()),
(54,3,1,2,4,'Shell Sistema [ver]','d2.shell.system.ver',1715,(2<<8)|(3<<12)|(1<<21),(4<<8)|54,now()),
(61,6,2,2,1,'Thunderbird Client [nuevo]','d2.device.thunderbird.nuevo',1716,(2<<8)|(6<<12)|(2<<21),(1<<8)|61,now()),
(62,6,2,2,2,'Thunderbird Client [editar]','d2.device.thunderbird.editar',1717,(2<<8)|(6<<12)|(2<<21),(2<<8)|62,now()),
(64,6,2,2,4,'Thunderbird Client [ver]','d2.device.thunderbird.ver',1718,(2<<8)|(6<<12)|(2<<21),(4<<8)|64,now()),
(71,6,3,2,1,'Terminal POS [nuevo]','d2.device.terminal_pos.nuevo',1719,(2<<8)|(6<<12)|(3<<21),(1<<8)|71,now()),
(72,6,3,2,2,'Terminal POS [editar]','d2.device.terminal_pos.editar',1720,(2<<8)|(6<<12)|(3<<21),(2<<8)|72,now()),
(74,6,3,2,4,'Terminal POS [ver]','d2.device.terminal_pos.ver',1721,(2<<8)|(6<<12)|(3<<21),(4<<8)|74,now())
ON CONFLICT DO NOTHING;
