// ============================================================
// bauth_desktop · nucleo/api/rutas/usuarios.dart
//
// Rutas: bauth.user.*
// Part of bauth_api.dart — usa _rpc (conexión banexus de BauthApi).
// ============================================================

part of '../bauth_api.dart';

extension BauthApiUsuarios on BauthApi {
  /// Obtiene un usuario por UUID.
  Future<UsuarioInfo> obtenerUsuario(String uuid) async {
    final r = await _rpc.llamar('bauth.user.get', {'uuid': uuid});
    return UsuarioInfo.fromJson(r);
  }

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

  /// Crea un nuevo usuario.
  Future<Map<String, dynamic>> crearUsuario(Map<String, dynamic> userData) async =>
      _rpc.llamar('bauth.user.create', {'user': userData});

  /// Actualiza campos de un usuario existente.
  Future<Map<String, dynamic>> actualizarUsuario(
    String uuid,
    Map<String, dynamic> cambios,
  ) async =>
      _rpc.llamar('bauth.user.update', {'uuid': uuid, 'changes': cambios});

  /// Elimina un usuario por UUID.
  Future<void> eliminarUsuario(String uuid) async =>
      _rpc.llamar('bauth.user.delete', {'uuid': uuid});

  /// Asigna un rol a un usuario.
  Future<Map<String, dynamic>> asignarRol(
    String userUuid,
    String roleId, {
    String? modo,
  }) async =>
      _rpc.llamar('bauth.user.assign_role', {
        'user_uuid': userUuid,
        'role_id':   roleId,
        'mode':      ?modo,
      });

  /// Revoca un rol de un usuario.
  Future<void> revocarRol(String userUuid, String roleId) async =>
      _rpc.llamar('bauth.user.revoke_role', {
        'user_uuid': userUuid,
        'role_id':   roleId,
      });
}
