// ============================================================
// bauth_desktop · datos/menu_datos.dart
//
// Propósito: catálogo del MENÚ del bloque izquierdo, transcrito del prototipo
//   bAuth Desktop (grupos, ítems, iconos Lucide, badges, puntos y RUTA). La
//   ruta identifica el contenido que el bloque central mostrará. Solo datos.
// Dependencias: tf_shadcn_flutter (IconData/LucideIcons).
// Estándar: prototipo bAuth Desktop · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Estado semántico de un punto indicador junto a un ítem.
enum EstadoPunto { ok, advertencia }

/// Un ítem del menú: icono + etiqueta + ruta, con badge y/o punto opcionales.
class ItemMenu {
  final IconData icono;
  final String etiqueta;
  final String ruta;
  final String? badge;
  final EstadoPunto? punto;
  const ItemMenu(this.icono, this.etiqueta, this.ruta, {this.badge, this.punto});
}

/// Un grupo del menú: título de sección + sus ítems.
class GrupoMenu {
  final String titulo;
  final List<ItemMenu> items;
  const GrupoMenu(this.titulo, this.items);
}

/// Grupos del menú, en el orden y con el contenido del prototipo.
const List<GrupoMenu> gruposMenu = [
  GrupoMenu('GENERAL', [
    ItemMenu(LucideIcons.layoutDashboard, 'Dashboard de Salud', 'dashboard'),
    ItemMenu(LucideIcons.users, 'Usuarios Conectados', 'conectados', badge: '89'),
  ]),
  GrupoMenu('TEMPLATES', [
    ItemMenu(LucideIcons.idCard, 'Identidad', 'rtpl_identidad'),
    ItemMenu(LucideIcons.shield, 'Rol', 'rtpl'),
    ItemMenu(LucideIcons.user, 'User', 'utpl'),
    ItemMenu(LucideIcons.package, 'Aplicacion', 'appcat'),
  ]),
  GrupoMenu('CRUD', [
    ItemMenu(LucideIcons.settings, 'Métodos', 'metodos'),
    ItemMenu(LucideIcons.globe, 'Dominios', 'dominios'),
    ItemMenu(LucideIcons.boxes, 'Bloques', 'bloques'),
    ItemMenu(LucideIcons.tag, 'Atributos', 'atributos'),
    ItemMenu(LucideIcons.zap, 'Verbos', 'verbos'),
    ItemMenu(LucideIcons.shield, 'Roles', 'roles', badge: '366'),
    ItemMenu(LucideIcons.users, 'Usuarios', 'usuarios', badge: '1.2k'),
    ItemMenu(LucideIcons.package, 'Aplicaciones', 'aplicaciones'),
    ItemMenu(LucideIcons.component, 'Módulos', 'modulos'),
    ItemMenu(LucideIcons.group, 'Grupos', 'grupos'),
    ItemMenu(LucideIcons.fileText, 'Reglas', 'reglas'),
  ]),
  GrupoMenu('IDENTIDAD', [
    ItemMenu(LucideIcons.gitBranch, 'Árbol de Entidades', 'identidad'),
    ItemMenu(LucideIcons.activity, 'Uso del Sistema', 'uso', punto: EstadoPunto.advertencia),
  ]),
  GrupoMenu('SISTEMA', [
    ItemMenu(LucideIcons.refreshCw, 'Sincronización', 'sync', punto: EstadoPunto.ok),
    ItemMenu(LucideIcons.fileCheck, 'Auditoría', 'auditoria', punto: EstadoPunto.advertencia),
    ItemMenu(LucideIcons.shieldCheck, 'Visión BOS', 'bos', punto: EstadoPunto.advertencia),
    ItemMenu(LucideIcons.link, 'Blockchain', 'blockchain'),
  ]),
  GrupoMenu('CUENTA', [
    ItemMenu(LucideIcons.creditCard, 'Mi Cuenta', 'cuenta'),
    ItemMenu(LucideIcons.headphones, 'Soporte SBOS', 'soporte'),
  ]),
];

/// Ítem de configuración, fijo al pie del nav (tras el espaciador).
const ItemMenu itemConfiguracion = ItemMenu(LucideIcons.slidersHorizontal, 'Configuración', 'config');

/// Etiqueta del ítem cuya ruta coincide (para el breadcrumb del bloque central).
String etiquetaDeRuta(String ruta) {
  for (final g in gruposMenu) {
    for (final it in g.items) {
      if (it.ruta == ruta) return it.etiqueta;
    }
  }
  return itemConfiguracion.ruta == ruta ? itemConfiguracion.etiqueta : 'Panel';
}
