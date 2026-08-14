// ============================================================
// bauth_desktop · nucleo/api/rutas/arbol_roles.dart
//
// Rutas: bauth.idn_roles_template.* · bauth.idn_policy_node_type.*
// Part of bauth_api.dart — usa _rpc (conexión banexus de BauthApi).
// ============================================================

part of '../bauth_api.dart';

extension BauthApiArbolRoles on BauthApi {
  // ── Árbol de políticas (idn_roles_template) ───────────────

  /// Carga TODOS los nodos de idn_roles_template vía JSON-RPC.
  /// Respuesta esperada: {"nodos": [{id, parent_id, tipo, …}]}.
  Future<List<NodoRolTemplateBD>> rolTemplateTodos({
    String tenantSlug = 'skull',
  }) async {
    final r = await _rpc
        .llamar('bauth.idn_roles_template.todos', {'tenant_slug': tenantSlug})
        .timeout(const Duration(seconds: 5));
    final lista = r['nodos'] as List<dynamic>? ?? [];
    return lista
        .cast<Map<String, dynamic>>()
        .map(NodoRolTemplateBD.fromJson)
        .toList();
  }

  // ── Catálogo de tipos de nodo ─────────────────────────────

  /// Carga todos los tipos de nodo desde bauth.idn_policy_node_type vía JSON-RPC.
  /// Retorna mapa vacío en caso de error (sin conexión, timeout).
  Future<Map<String, ConfigTipoNodo>> cargarCatalogoTipos() async {
    try {
      final r    = await _rpc.llamar('bauth.idn_policy_node_type.list', {});
      final lista = r['tipos'] as List<dynamic>? ?? [];
      return {
        for (final j in lista.cast<Map<String, dynamic>>())
          j['code'] as String: ConfigTipoNodo.fromJson(j),
      };
    } catch (_) {
      return const {};
    }
  }
}
