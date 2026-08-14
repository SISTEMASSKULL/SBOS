// ============================================================
// bauth_desktop · nucleo/api/rutas/usuarios.dart
//
// Rutas: bauth.user.*
// Part of bauth_api.dart — usa _rpc (conexión banexus de BauthApi).
// ============================================================

part of '../bauth_api.dart';

extension BauthApiUsuarios on BauthApi {
  /// Lista usuarios con búsqueda y filtros opcionales.
  Future<List<UsuarioInfo>> listarUsuarios({
    String? busqueda,
    String? status,
    int     limite = 100,
  }) async {
    final params = <String, dynamic>{'limit': limite};
    if (busqueda != null && busqueda.isNotEmpty) params['search'] = busqueda;
    if (status   != null) params['status'] = status;
    final r     = await _rpc.llamar('bauth.user.list', params);
    final items = r['users'] as List<dynamic>? ?? [];
    return items.map((e) => UsuarioInfo.fromJson(e as Map<String, dynamic>)).toList();
  }
}
