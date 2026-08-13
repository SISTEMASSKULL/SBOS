// ============================================================
// bauth_desktop · nucleo/api/modelos/atomlang.dart
//
// Modelos del schema AtomLang (T-580/T-581):
//   AttrSchema, GrupoSchema, NodeTypeSchema, NodoSchema.
// Part of bauth_api.dart — comparte librería y helpers _es/_esN.
// ============================================================

part of '../bauth_api.dart';

/// Atributo hoja de un grupo del schema AtomLang (T-581).
class AttrSchema {
  final String       attrId;
  final String       key;
  final String       labelEs;
  final String       descEs;
  final String       tipo;
  final List<String> enumValores;
  final int          sortOrder;
  final bool         readonly;
  final bool         nullable;
  final bool         obligatorio;

  AttrSchema.fromJson(Map<String, dynamic> j)
      : attrId      = j['attr_id']?.toString() ?? '?',
        key         = j['key']?.toString()     ?? '?',
        labelEs     = _es(j['label']),
        descEs      = _esN(j['desc'])          ?? '',
        tipo        = j['tipo']?.toString()    ?? 'text',
        enumValores = (j['enum_valores'] as List<dynamic>?)
                          ?.map((e) => e.toString()).toList() ?? const [],
        sortOrder   = j['sort_order'] as int? ?? 0,
        readonly    = j['readonly']  == true,
        nullable    = j['nullable']  != false,
        obligatorio = j['obligatorio'] == true;
}

/// Grupo del schema AtomLang (T-580) con sus atributos hoja.
/// Usado por bauth.atomlang.schema.node_type.
class GrupoSchema {
  final String       schemaId;
  final String       slug;
  final String?      parentId;
  final String?      parentSlug;
  final String       labelEs;
  final String       descEs;
  final int          sortOrder;
  final bool         readonly;
  final bool         reactivo;
  final List<AttrSchema> atributos;

  GrupoSchema.fromJson(Map<String, dynamic> j)
      : schemaId   = j['schema_id']?.toString()  ?? '?',
        slug       = j['slug']?.toString()        ?? '?',
        parentId   = j['parent_id']?.toString(),
        parentSlug = j['parent_slug']?.toString(),
        labelEs    = _es(j['label']),
        descEs     = _esN(j['desc'])              ?? '',
        sortOrder  = j['sort_order'] as int?      ?? 0,
        readonly   = j['readonly']  == true,
        reactivo   = j['reactivo']  == true,
        atributos  = (j['atributos'] as List<dynamic>? ?? [])
                         .map((e) => AttrSchema.fromJson(e as Map<String, dynamic>))
                         .toList();

  bool get esSubgrupo => parentId != null;
}

/// Schema completo de un tipo de nodo AtomLang — respuesta de
/// bauth.atomlang.schema.node_type.
class NodeTypeSchema {
  final String           nodeType;
  final List<GrupoSchema> grupos;

  NodeTypeSchema.fromJson(Map<String, dynamic> j)
      : nodeType = j['node_type']?.toString() ?? '?',
        grupos   = (j['grupos'] as List<dynamic>? ?? [])
                       .map((e) => GrupoSchema.fromJson(e as Map<String, dynamic>))
                       .toList();

  static NodeTypeSchema vacio(String tipo) =>
      NodeTypeSchema.fromJson({'node_type': tipo, 'grupos': <dynamic>[]});
}

/// Nodo del árbol jerárquico AtomLang — respuesta de bauth.atomlang.schema.all.
/// Lista plana ordenada padre-primero; el cliente reconstruye el árbol con parentId.
///
/// esTipo=true  → fila "self" del tipo. Si tiene atributos es seleccionable.
/// esTipo=false → grupo especializado, siempre seleccionable.
class NodoSchema {
  final String       schemaId;
  final String       nodeType;
  final String       slug;
  final String?      parentId;
  final bool         esTipo;
  final String       labelEs;
  final String       descEs;
  final String?      icono;
  final String?      color;
  final int          sortOrder;
  final bool         readonly;
  final bool         reactivo;
  final List<AttrSchema> atributos;

  NodoSchema.fromJson(Map<String, dynamic> j)
      : schemaId  = j['schema_id']?.toString() ?? '?',
        nodeType  = j['node_type']?.toString() ?? '?',
        slug      = j['slug']?.toString()      ?? '?',
        parentId  = j['parent_id']?.toString(),
        esTipo    = j['es_tipo'] == true,
        labelEs   = _es(j['label']),
        descEs    = _esN(j['desc'])            ?? '',
        icono     = j['icono']?.toString(),
        color     = j['color']?.toString(),
        sortOrder = j['sort_order'] as int?    ?? 0,
        readonly  = j['readonly']  == true,
        reactivo  = j['reactivo']  == true,
        atributos = (j['atributos'] as List<dynamic>? ?? [])
                        .map((e) => AttrSchema.fromJson(e as Map<String, dynamic>))
                        .toList();

  /// Seleccionable si es un grupo especializado, o si es un tipo con atributos propios.
  bool get esSeleccionable => !esTipo || atributos.isNotEmpty;
}
