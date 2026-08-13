// ============================================================
// bauth_desktop · nucleo/api/modelos/arbol.dart
//
// Modelo del árbol de políticas: NodoRolTemplateBD.
// Part of bauth_api.dart — comparte librería y helpers _es/_esN/_en.
// ============================================================

part of '../bauth_api.dart';

/// Nodo del árbol de políticas desde bauth.idn_roles_template.
/// Campos i18n (clave, nombre, help) pueden llegar como texto plano
/// (SQL con ->>'es') o como JSONB completo — _es/_esN/_en manejan ambos.
class NodoRolTemplateBD {
  final String  id;
  final String? parentId;
  final String  path;
  final String  tipo;
  final String  clave;
  final String? claveEn;
  final String? alias;
  final String? blockCode;
  final String  nombre;
  final String? nombreEn;
  final String? valor;
  final String? help;
  final String? helpEn;
  final List<String> opciones;
  final bool    effect;
  final String? verbId;
  final int?    domainNumber;
  final int     depth;
  List<NodoRolTemplateBD> hijos;

  NodoRolTemplateBD.fromJson(Map<String, dynamic> j)
      : id           = j['id']?.toString()       ?? '?',
        parentId     = j['parent_id']?.toString(),
        path         = j['path']?.toString()     ?? '',
        tipo         = j['tipo']?.toString()     ?? 'objeto',
        clave        = _es(j['clave']),
        claveEn      = _en(j['clave']) ?? j['clave_en']?.toString(),
        alias        = j['alias']?.toString(),
        blockCode    = j['block_code']?.toString(),
        nombre       = _es(j['nombre'] ?? j['clave']),
        nombreEn     = _en(j['nombre'] ?? j['clave']) ?? j['nombre_en']?.toString(),
        valor        = j['valor']?.toString(),
        help         = _esN(j['help']),
        helpEn       = _en(j['help']) ?? j['help_en']?.toString(),
        opciones     = const [],
        effect       = j['effect'] as bool? ?? false,
        verbId       = j['verb_id']?.toString(),
        domainNumber = j['domain_number'] as int?,
        depth        = j['depth'] as int? ?? 0,
        hijos        = [];
}
