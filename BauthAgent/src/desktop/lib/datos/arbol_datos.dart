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

/// Árbol de los dominios de control canónicos del RolTemplate v6.0.
/// D0..D13 = dominios funcionales (entran al BitMask 64-bit).
/// D98 = Registro Estructural (Sets de roles — no entra al BitMask, no produce Decision).
/// D99 = Administrativo Global (garante, Control Plane Policies — no entra al BitMask funcional).
const List<NodoArbol> arbolDominios = [
  NodoArbol('D98 · Registro Estructural', icono: LucideIcons.library, badge: 'REG',
      hijos: [NodoArbol('SET: tier_descuento_alto', icono: LucideIcons.users)]),
  NodoArbol('D0 · Identidad Organizacional', icono: LucideIcons.settings2, badge: '8', hijos: [
    NodoArbol('B1 · Identificación', icono: LucideIcons.layoutGrid),
    NodoArbol('B3 · Flujo de aprobación', icono: LucideIcons.layoutGrid),
  ]),
  NodoArbol('D1 · Acceso Lógico', icono: LucideIcons.settings2, badge: '24', hijos: [
    NodoArbol('B4 · Autenticación (metodos)', icono: LucideIcons.layoutGrid),
    NodoArbol('B6 · Zonas de negocio', icono: LucideIcons.layoutGrid),
    NodoArbol('B7 · Privilegios de Aplicaciones', icono: LucideIcons.layoutGrid),
  ]),
  NodoArbol('D2 · Acceso Físico', icono: LucideIcons.settings2, badge: '12', hijos: [
    NodoArbol('B5 · Dominio físico', icono: LucideIcons.layoutGrid),
  ]),
  NodoArbol('D3 · Financiero', icono: LucideIcons.settings2, badge: '11'),
  NodoArbol('D4 · Temporal', icono: LucideIcons.settings2, badge: '6'),
  NodoArbol('D5 · Biométrico', icono: LucideIcons.settings2, badge: '5'),
  NodoArbol('D6 · Geoespacial', icono: LucideIcons.settings2, badge: '7'),
  NodoArbol('D7 · Red', icono: LucideIcons.settings2, badge: '6'),
  NodoArbol('D8 · Contexto / Sesión', icono: LucideIcons.settings2, badge: '8'),
  NodoArbol('D9 · Credenciales', icono: LucideIcons.settings2, badge: '9'),
  NodoArbol('D10 · Delegación', icono: LucideIcons.settings2, badge: '6'),
  NodoArbol('D11 · Auditoría', icono: LucideIcons.settings2, badge: '7'),
  NodoArbol('D12 · Blockchain / Anclaje', icono: LucideIcons.settings2, badge: '5'),
  NodoArbol('D13 · Firma Digital Externa', icono: LucideIcons.settings2, badge: '4'),
  NodoArbol('D99 · Administrativo Global', icono: LucideIcons.shieldAlert, badge: 'GLB'),
];

/// Árbol de POLÍTICAS por dominio (muestra representativa de D1 y D3).
const List<NodoArbol> arbolPoliticas = [
  NodoArbol('D1 · Acceso Lógico', hijos: [
    NodoArbol('step_up_triggers', icono: LucideIcons.clipboardCheck),
    NodoArbol('account_lockout_policy', icono: LucideIcons.clipboardCheck),
    NodoArbol('session_management', icono: LucideIcons.clipboardCheck),
    NodoArbol('session_binding', icono: LucideIcons.clipboardCheck),
    NodoArbol('zona_logical_ventas', icono: LucideIcons.clipboardCheck),
    NodoArbol('zona_financial_ventas', icono: LucideIcons.clipboardCheck),
    NodoArbol('button_rules', icono: LucideIcons.clipboardCheck),
    NodoArbol('b7_crm_acceso', icono: LucideIcons.clipboardCheck),
    NodoArbol('b7_rrhh_acceso', icono: LucideIcons.clipboardCheck),
    NodoArbol('b7_bnotify_acceso', icono: LucideIcons.clipboardCheck),
  ]),
  NodoArbol('D3 · Financiero', hijos: [
    NodoArbol('requiredMethods_financial', icono: LucideIcons.clipboardCheck),
    NodoArbol('transaction_schedule', icono: LucideIcons.clipboardCheck),
    NodoArbol('sod_rules', icono: LucideIcons.clipboardCheck),
  ]),
  NodoArbol('D8 · Contexto / Sesión', hijos: [
    NodoArbol('risk_engine', icono: LucideIcons.clipboardCheck),
    NodoArbol('adaptive_policies', icono: LucideIcons.clipboardCheck),
    NodoArbol('emergency_access', icono: LucideIcons.clipboardCheck),
  ]),
];
