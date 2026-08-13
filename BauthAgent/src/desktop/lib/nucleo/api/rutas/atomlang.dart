// ============================================================
// bauth_desktop · nucleo/api/rutas/atomlang.dart
//
// Rutas: bauth.atomlang.schema.*
// Part of bauth_api.dart — usa _rpc (conexión banexus de BauthApi).
// ============================================================

part of '../bauth_api.dart';

extension BauthApiAtomLang on BauthApi {
  /// Schema de grupos y atributos para un tipo de nodo AtomLang específico.
  /// Llama a bauth.atomlang.schema.node_type (T-580 + T-581).
  Future<NodeTypeSchema> atomlangSchema(String nodeType) async {
    final r = await _rpc.llamar(
      'bauth.atomlang.schema.node_type',
      {'node_type': nodeType},
    );
    return NodeTypeSchema.fromJson(r);
  }

  /// Jerarquía completa del árbol AtomLang como lista plana padre-primero.
  /// Una sola llamada sin parámetros — el cliente reconstruye el árbol con parentId.
  /// Llama a bauth.atomlang.schema.all (T-580 + T-581).
  Future<List<NodoSchema>> atomlangSchemaAll() async {
    final r    = await _rpc.llamar('bauth.atomlang.schema.all', {});
    final nodos = r['nodos'] as List<dynamic>? ?? [];
    return nodos
        .map((n) => NodoSchema.fromJson(n as Map<String, dynamic>))
        .toList();
  }
}
