// ============================================================
// bauth_desktop · datos/arbol_datos.dart
//
// Propósito: modelo genérico de árbol (NodoArbol) y datos REPRESENTATIVOS de
//   los árboles del builder de Rol Template — átomos (App→Módulo→Grupo→Verbo),
//   dominios (12) y políticas. Los nombres/conteos definitivos vienen del
//   catálogo real; aquí van datos de maqueta. Solo datos.
// Dependencias: tf_shadcn_flutter (IconData/LucideIcons).
// Estándar: prototipo bAuth Desktop · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Nodo genérico de árbol: etiqueta + icono/badge opcionales + hijos.
class NodoArbol {
  final String etiqueta;
  final IconData? icono;
  final String? badge;
  final List<NodoArbol> hijos;
  const NodoArbol(this.etiqueta, {this.icono, this.badge, this.hijos = const []});
}

/// Árbol de ÁTOMOS (App → Módulo → Grupo → Verbo) del dominio activo.
const List<NodoArbol> arbolAtomos = [
  NodoArbol('bAuth', icono: LucideIcons.appWindow, badge: '48', hijos: [
    NodoArbol('Identidad', icono: LucideIcons.layoutGrid, badge: '18', hijos: [
      NodoArbol('Usuarios', badge: '10', hijos: [
        NodoArbol('usuario.crear', icono: LucideIcons.zap),
        NodoArbol('usuario.leer', icono: LucideIcons.zap),
        NodoArbol('usuario.actualizar', icono: LucideIcons.zap),
        NodoArbol('usuario.eliminar', icono: LucideIcons.zap),
      ]),
      NodoArbol('Roles', badge: '8', hijos: [
        NodoArbol('rol.crear', icono: LucideIcons.zap),
        NodoArbol('rol.asignar', icono: LucideIcons.zap),
      ]),
    ]),
    NodoArbol('Sesiones', icono: LucideIcons.layoutGrid, badge: '6', hijos: [
      NodoArbol('sesion.abrir', icono: LucideIcons.zap),
      NodoArbol('sesion.revocar', icono: LucideIcons.zap),
    ]),
  ]),
];

/// Árbol de los 12 DOMINIOS de control (con átomos de muestra en algunos).
const List<NodoArbol> arbolDominios = [
  NodoArbol('D1 · Lógico', icono: LucideIcons.settings2, badge: '12', hijos: [
    NodoArbol('rol.crear', icono: LucideIcons.zap),
    NodoArbol('rol.asignar', icono: LucideIcons.zap),
  ]),
  NodoArbol('D2 · Temporal', icono: LucideIcons.settings2, badge: '8', hijos: [
    NodoArbol('horario.definir', icono: LucideIcons.zap),
  ]),
  NodoArbol('D3 · Geoespacial', icono: LucideIcons.settings2, badge: '6'),
  NodoArbol('D4 · Jerárquico', icono: LucideIcons.settings2, badge: '9'),
  NodoArbol('D5 · Delegación', icono: LucideIcons.settings2, badge: '5'),
  NodoArbol('D6 · Financiero', icono: LucideIcons.settings2, badge: '11'),
  NodoArbol('D7 · Riesgo', icono: LucideIcons.settings2, badge: '7'),
  NodoArbol('D8 · Sesión', icono: LucideIcons.settings2, badge: '6'),
  NodoArbol('D9 · Dispositivo', icono: LucideIcons.settings2, badge: '4'),
  NodoArbol('D10 · Red', icono: LucideIcons.settings2, badge: '5'),
  NodoArbol('D11 · Datos', icono: LucideIcons.settings2, badge: '8'),
  NodoArbol('D12 · Cumplimiento', icono: LucideIcons.settings2, badge: '10'),
];

/// Árbol de POLÍTICAS por dominio (muestra).
const List<NodoArbol> arbolPoliticas = [
  NodoArbol('D1 · Lógico', hijos: [
    NodoArbol('pol.rol_vigente', icono: LucideIcons.clipboardCheck),
    NodoArbol('pol.sod_estatico', icono: LucideIcons.clipboardCheck),
  ]),
  NodoArbol('D2 · Temporal', hijos: [
    NodoArbol('pol.horario_laboral', icono: LucideIcons.clipboardCheck),
  ]),
  NodoArbol('D7 · Riesgo', hijos: [
    NodoArbol('pol.step_up_aal3', icono: LucideIcons.clipboardCheck),
  ]),
];
