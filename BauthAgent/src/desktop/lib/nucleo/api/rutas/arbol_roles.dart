// ============================================================
// bauth_desktop · nucleo/api/rutas/arbol_roles.dart
//
// Rutas: bauth.idn_roles_template.* · idn_policy_node_type
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

  /// Hijos directos de [parentId] — carga lazy nodo por nodo vía SQL directo.
  /// Usa ejecutarCmd con SQL codificado en base64.
  Future<List<NodoRolTemplateBD>> rolTemplateHijos({
    String? parentId,
    String  tenantSlug = 'skull',
  }) async {
    final condicion = parentId == null
        ? 'irt.parent_id IS NULL'
        : "irt.parent_id = '$parentId'";
    final sql = "SELECT json_agg(t ORDER BY t.sort_order) FROM ("
        "SELECT irt.id::text, irt.parent_id::text, irt.path, irt.node_type AS tipo,"
        " irt.label->>'es' AS clave, irt.label->>'en' AS clave_en,"
        " irt.name->>'es' AS nombre, irt.name->>'en' AS nombre_en,"
        " irt.value AS valor,"
        " irt.help->>'es' AS help, irt.help->>'en' AS help_en,"
        " irt.effect, irt.verb_id, irt.domain_number, irt.depth, irt.sort_order,"
        " irt.alias, irt.block_code"
        " FROM bauth.idn_roles_template irt"
        " WHERE $condicion"
        " AND irt.tenant_id = ("
        "  SELECT tenant_id FROM bauth.idn_tenant"
        "  WHERE tenant_slug = '$tenantSlug' LIMIT 1)"
        ") t";
    final b64    = base64Encode(utf8.encode(sql));
    final salida = await _rpc.ejecutarCmd(
      "echo $b64 | base64 -d | psql '$_dsnSbos' -t -A",
    );
    if (salida.isEmpty || salida == 'null') return const [];
    final decoded = jsonDecode(salida);
    if (decoded == null) return const [];
    return (decoded as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(NodoRolTemplateBD.fromJson)
        .toList();
  }

  /// Sin caché — cada llamada va directo a la BD.
  void invalidarCacheArbol() {}

  // ── Catálogo de tipos de nodo ─────────────────────────────

  /// Carga todos los tipos de nodo desde bauth.idn_policy_node_type.
  /// Retorna mapa vacío en caso de error (sin conexión, timeout, SQL).
  Future<Map<String, ConfigTipoNodo>> cargarCatalogoTipos() async {
    try {
      const sql = 'SELECT json_agg(t) FROM ('
          'SELECT code, abbreviation, name_es, name_en,'
          ' color_key, color_key_valor, font_weight, font_size_token,'
          ' monospace, letter_spacing::float AS letter_spacing,'
          ' show_badge, expanded_default'
          ' FROM bauth.idn_policy_node_type WHERE is_active = true'
          ' ORDER BY sort_order) t';
      final b64    = base64Encode(utf8.encode(sql));
      final salida = await _rpc.ejecutarCmd(
        "echo $b64 | base64 -d | psql '$_dsnSbos' -t -A",
      );
      if (salida.isEmpty || salida == 'null') return const {};
      final decoded = jsonDecode(salida);
      if (decoded == null) return const {};
      final lista = (decoded as List<dynamic>).cast<Map<String, dynamic>>();
      return {for (final j in lista) j['code'] as String: ConfigTipoNodo.fromJson(j)};
    } catch (_) {
      return const {};
    }
  }
}
