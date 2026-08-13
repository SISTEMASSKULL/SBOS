// ============================================================
// bauth_desktop · nucleo/api/rutas/roles.dart
//
// Rutas: bauth.role.* · bauth.role.template.*
// Part of bauth_api.dart — usa _rpc (conexión banexus de BauthApi).
// ============================================================

part of '../bauth_api.dart';

extension BauthApiRoles on BauthApi {
  // ── Roles ─────────────────────────────────────────────────

  /// Lista roles activos, con filtros opcionales por tier y estado.
  Future<List<RolInfo>> listarRoles({String? tier, String? status}) async {
    final params = <String, dynamic>{};
    if (tier   != null) params['tier']   = tier;
    if (status != null) params['status'] = status;
    final r = await _rpc.llamar('bauth.role.list', params);
    final roles = r['roles'] as List<dynamic>? ?? [];
    return roles.map((e) => RolInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Combina dos o más roles (merge OR) y devuelve el bitmask resultante.
  Future<Map<String, dynamic>> mergeRoles(List<String> roleIds) async =>
      _rpc.llamar('bauth.role.merge', {'role_ids': roleIds});

  // ── Role Templates ────────────────────────────────────────

  /// Lista todas las plantillas de rol disponibles.
  Future<List<RolTemplate>> listarTemplates() async {
    final r = await _rpc.llamar('bauth.role.template.list');
    final items = r['templates'] as List<dynamic>? ?? [];
    return items.map((e) => RolTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Obtiene una plantilla de rol por ID.
  Future<RolTemplate> obtenerTemplate(String id) async {
    final r = await _rpc.llamar('bauth.role.template.get', {'id': id});
    return RolTemplate.fromJson(r);
  }

  /// Valida una plantilla antes de crearla o actualizarla.
  Future<Map<String, dynamic>> validarTemplate(Map<String, dynamic> template) async =>
      _rpc.llamar('bauth.role.template.validate', {'template': template});

  /// Crea una nueva plantilla de rol.
  Future<Map<String, dynamic>> crearTemplate(Map<String, dynamic> template) async =>
      _rpc.llamar('bauth.role.template.create', {'template': template});
}
