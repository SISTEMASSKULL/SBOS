// ============================================================
// bauth_desktop · nucleo/api/bauth_api.dart
//
// Propósito: Router central de la API bAuth.
//   Define BauthApi — punto único de entrada que usa la conexión
//   banexus (IClienteRpc) inyectada desde el provider.
//
//   La conexión (BanexusTransporte) es independiente y se inyecta
//   desde proveedor_conexion.dart. Esta clase no crea ni posee la
//   conexión — la usa como canal hacia el daemon bAuth.
//
// Organización interna (part of):
//   modelos/ — tipos de datos por dominio
//     comun.dart      · HealthInfo · SyncStatusInfo
//     identidad.dart  · RolInfo · RolTemplate · UsuarioInfo · EntidadInfo
//     arbol.dart      · NodoRolTemplateBD
//     atomlang.dart   · AttrSchema · GrupoSchema · NodeTypeSchema · NodoSchema
//
//   rutas/ — métodos JSON-RPC activos
//     health.dart     · bauth.health.* / bauth.sync.*
//     roles.dart      · bauth.role.list
//     usuarios.dart   · bauth.user.list
//     entidades.dart  · bauth.entidad.tree
//     arbol_roles.dart· bauth.idn_roles_template.todos / idn_policy_node_type
//     atomlang.dart   · bauth.atomlang.schema.all
//
// Estándar: JSON-RPC 2.0 · ADR-020 · DOC-SBOS-001 N3.
// ============================================================

import '../conexion/cliente_rpc.dart';
import '../dominio/config_tipo_nodo.dart';

// ── Modelos de datos por dominio ──────────────────────────────
part 'modelos/comun.dart';
part 'modelos/identidad.dart';
part 'modelos/arbol.dart';
part 'modelos/atomlang.dart';

// ── Rutas (métodos JSON-RPC) por dominio ──────────────────────
part 'rutas/health.dart';
part 'rutas/roles.dart';
part 'rutas/usuarios.dart';
part 'rutas/entidades.dart';
part 'rutas/arbol_roles.dart';
part 'rutas/atomlang.dart';

// ── Helpers i18n compartidos por todos los modelos ────────────

/// Extrae español de un campo String plano o JSONB {"es","en"}.
String _es(dynamic v) {
  if (v is Map) return (v['es'] ?? v['en'] ?? '?').toString();
  return v?.toString() ?? '?';
}

/// Versión nullable — null si el campo es null o vacío.
String? _esN(dynamic v) {
  if (v == null) return null;
  if (v is Map) {
    final s = (v['es'] ?? v['en'])?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// Extrae inglés de un campo JSONB; null si es String plano.
String? _en(dynamic v) {
  if (v == null) return null;
  if (v is Map) return (v['en'] ?? v['es'])?.toString();
  return null;
}

// ── Router central ────────────────────────────────────────────

/// Punto de entrada de la API bAuth.
///
/// Usa la conexión [IClienteRpc] inyectada (banexus) para enrutar
/// llamadas JSON-RPC al daemon. Los métodos están organizados por
/// dominio como extensiones en rutas/ (part of esta librería).
///
/// La conexión es independiente — vive en BanexusTransporte y puede
/// usarse para otros fines además de esta API.
class BauthApi {
  final IClienteRpc _rpc;
  BauthApi(this._rpc);
}
