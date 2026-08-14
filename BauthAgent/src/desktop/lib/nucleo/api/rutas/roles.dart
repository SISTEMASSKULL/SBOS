// ============================================================
// bauth_desktop · nucleo/api/rutas/roles.dart
//
// Rutas: bauth.role.*
// Part of bauth_api.dart — usa _rpc (conexión banexus de BauthApi).
// ============================================================

part of '../bauth_api.dart';

extension BauthApiRoles on BauthApi {
  /// Lista roles activos, con filtros opcionales por tier y estado.
  Future<List<RolInfo>> listarRoles({String? tier, String? status}) async {
    final params = <String, dynamic>{};
    if (tier   != null) params['tier']   = tier;
    if (status != null) params['status'] = status;
    final r = await _rpc.llamar('bauth.role.list', params);
    final roles = r['roles'] as List<dynamic>? ?? [];
    return roles.map((e) => RolInfo.fromJson(e as Map<String, dynamic>)).toList();
  }
}
