// ============================================================
// bauth_desktop · nucleo/api/rutas/entidades.dart
//
// Rutas: bauth.entidad.*
// Entidades del catálogo universal de identidad (idn_identity_entity).
// Part of bauth_api.dart — usa _rpc (conexión banexus de BauthApi).
// ============================================================

part of '../bauth_api.dart';

extension BauthApiEntidades on BauthApi {
  /// Árbol completo de entidades (estructura anidada con hijos).
  Future<List<EntidadInfo>> arbolEntidades({String? tenantId}) async {
    final params = <String, dynamic>{};
    if (tenantId != null) params['tenant_id'] = tenantId;
    final r      = await _rpc.llamar('bauth.entidad.tree', params);
    final raices = r['raices'] as List<dynamic>? ?? [];
    return raices.map((e) => EntidadInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Lista entidades con filtros opcionales.
  Future<List<EntidadInfo>> listarEntidades({
    String? nivel,
    String? tipo,
    String? parentId,
    String? tenantId,
  }) async {
    final params = <String, dynamic>{};
    if (nivel    != null) params['nivel']     = nivel;
    if (tipo     != null) params['tipo']      = tipo;
    if (parentId != null) params['parent_id'] = parentId;
    if (tenantId != null) params['tenant_id'] = tenantId;
    final r     = await _rpc.llamar('bauth.entidad.list', params);
    final items = r['entidades'] as List<dynamic>? ?? [];
    return items.map((e) => EntidadInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Crea una nueva entidad en la jerarquía organizacional.
  Future<EntidadInfo> crearEntidad({
    required String nivel,
    required String tipo,
    required String nombre,
    required String tenantId,
    String? parentId,
    bool?   isInternal,
  }) async {
    final params = <String, dynamic>{
      'nivel':     nivel,
      'tipo':      tipo,
      'nombre':    nombre,
      'tenant_id': tenantId,
    };
    if (parentId   != null) params['parent_id']   = parentId;
    if (isInternal != null) params['is_internal']  = isInternal;
    final r = await _rpc.llamar('bauth.entidad.create', params);
    return EntidadInfo.fromJson(r);
  }
}
