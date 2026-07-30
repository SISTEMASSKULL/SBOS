// ============================================================
// bauth_desktop · nucleo/api/bauth_api.dart
//
// Propósito: wrappers tipados para los métodos JSON-RPC de bAuth.
//   Cada método retorna un Future<T> con tipos Dart concretos.
//   Los providers de Riverpod consumen esta API.
//
// Métodos implementados (v3.0.0, registrados en main.rs):
//   Health, Roles, RoleTemplates, Users, Policy, Access,
//   Inheritance, SoD, Tokens, Saga, WebAuthn.
//
// Estándar: JSON-RPC 2.0 · Motor de Roles (2.17 §4) ·
//   Motor de Identidad (2.15 §5) · DOC-SBOS-001 N3.
// ============================================================

import 'dart:async';
import 'dart:convert';

import '../conexion/cliente_rpc.dart';
import '../dominio/config_tipo_nodo.dart';

// ═══════════════════════════════════════════════════════════
// Tipos de datos
// ═══════════════════════════════════════════════════════════

class HealthInfo {
  final String status;
  final String version;
  final int uptimeSeconds;
  final String socket;

  HealthInfo.fromJson(Map<String, dynamic> j)
      : status = j['status'] ?? '?',
        version = j['version'] ?? '?',
        uptimeSeconds = j['uptime_seconds'] ?? 0,
        socket = j['socket'] ?? '?';
}

class RolInfo {
  final String id;
  final String nombre;
  final String? tier;
  final String? status;
  final int atomCount;

  RolInfo.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? j['role_id'] ?? '?',
        nombre = j['name'] ?? j['nombre'] ?? '?',
        tier = j['tier'],
        status = j['status'],
        atomCount = j['atom_count'] ?? 0;
}

class RolTemplate {
  final String id;
  final String nombre;
  final String version;
  final String? dominio;
  final Map<String, dynamic>? metadata;

  RolTemplate.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '?',
        nombre = j['name'] ?? j['nombre'] ?? '?',
        version = j['version'] ?? '?',
        dominio = j['domain'] ?? j['dominio'],
        metadata = j['metadata'] as Map<String, dynamic>?;
}

class UsuarioInfo {
  final String uuid;
  final String username;
  final String? email;
  final String? accountType;
  final String? status;
  final List<String> roles;

  UsuarioInfo.fromJson(Map<String, dynamic> j)
      : uuid = j['uuid'] ?? '?',
        username = j['username'] ?? '?',
        email = j['email'],
        accountType = j['account_type'],
        status = j['status'],
        roles = (j['roles'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
}

/// Entidad del catálogo universal de identidad (idn_identity_entity).
/// Puede ser cualquier cosa: persona, empresa, vehículo, servidor, sensor, puerta.
/// Los 5 niveles: tenant → bdomain → bsubdomain → pos → actor.
class EntidadInfo {
  final String entidadId;
  final String? parentId;
  final String tenantId;
  final String nivel; // tenant | bdomain | bsubdomain | pos | actor
  final String tipo;  // empresa, HUMAN, caja, vehiculo, servidor, etc.
  final String nombre;
  final String slug;
  final bool? isInternal;
  final int sortOrder;
  final List<EntidadInfo> hijos;

  EntidadInfo.fromJson(Map<String, dynamic> j)
      : entidadId = j['entity_id'] ?? j['id'] ?? '?',
        parentId = j['parent_id'],
        tenantId = j['tenant_id'] ?? '?',
        nivel = j['level'] ?? j['nivel'] ?? '?',
        tipo = j['entity_type'] ?? j['tipo'] ?? '?',
        nombre = j['nombre'] ?? j['name'] ?? '?',
        slug = j['slug'] ?? '?',
        isInternal = j['is_internal'] as bool?,
        sortOrder = j['sort_order'] ?? 0,
        hijos = (j['hijos'] as List<dynamic>? ?? [])
            .map((e) => EntidadInfo.fromJson(e as Map<String, dynamic>))
            .toList();
}

class AccessResult {
  final bool permitido;
  final String? motivo;
  final Map<String, dynamic>? detalle;

  AccessResult.fromJson(Map<String, dynamic> j)
      : permitido = j['allowed'] == true || j['decision'] == 'Permit',
        motivo = j['reason'] ?? j['motivo'],
        detalle = j;
}

class SoDResult {
  final bool conflicto;
  final List<String> rolesConflictivos;
  final String? detalle;

  SoDResult.fromJson(Map<String, dynamic> j)
      : conflicto = j['conflict'] == true || j['conflicto'] == true,
        rolesConflictivos = (j['conflicting_roles'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        detalle = j['detail'] ?? j['detalle'];
}

// ═══════════════════════════════════════════════════════════
// Cliente API tipado
// ═══════════════════════════════════════════════════════════

class BauthApi {
  final IClienteRpc _rpc;

  BauthApi(this._rpc);

  // ── Health ───────────────────────────────────────────────

  Future<HealthInfo> healthCheck() async {
    final r = await _rpc.llamar('bauth.health.check');
    return HealthInfo.fromJson(r);
  }

  // ── Roles ────────────────────────────────────────────────

  /// Lista todos los roles activos.
  Future<List<RolInfo>> listarRoles({String? tier, String? status}) async {
    final params = <String, dynamic>{};
    if (tier != null) params['tier'] = tier;
    if (status != null) params['status'] = status;
    final r = await _rpc.llamar('bauth.role.list', params);
    final roles = r['roles'] as List<dynamic>? ?? [];
    return roles
        .map((e) => RolInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Combina dos o más roles (merge OR).
  Future<Map<String, dynamic>> mergeRoles(List<String> roleIds) async {
    return _rpc.llamar('bauth.role.merge', {'role_ids': roleIds});
  }

  // ── Role Templates ───────────────────────────────────────

  Future<List<RolTemplate>> listarTemplates() async {
    final r = await _rpc.llamar('bauth.role.template.list');
    final items = r['templates'] as List<dynamic>? ?? [];
    return items
        .map((e) => RolTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RolTemplate> obtenerTemplate(String id) async {
    final r = await _rpc.llamar('bauth.role.template.get', {'id': id});
    return RolTemplate.fromJson(r);
  }

  Future<Map<String, dynamic>> validarTemplate(
      Map<String, dynamic> template) async {
    return _rpc.llamar('bauth.role.template.validate', {'template': template});
  }

  Future<Map<String, dynamic>> crearTemplate(
      Map<String, dynamic> template) async {
    return _rpc.llamar('bauth.role.template.create', {'template': template});
  }

  // ── Usuarios ─────────────────────────────────────────────

  Future<UsuarioInfo> obtenerUsuario(String uuid) async {
    final r = await _rpc.llamar('bauth.user.get', {'uuid': uuid});
    return UsuarioInfo.fromJson(r);
  }

  Future<Map<String, dynamic>> crearUsuario(
      Map<String, dynamic> userData) async {
    return _rpc.llamar('bauth.user.create', {'user': userData});
  }

  Future<Map<String, dynamic>> actualizarUsuario(
      String uuid, Map<String, dynamic> cambios) async {
    return _rpc.llamar('bauth.user.update', {
      'uuid': uuid,
      'changes': cambios,
    });
  }

  Future<void> eliminarUsuario(String uuid) async {
    await _rpc.llamar('bauth.user.delete', {'uuid': uuid});
  }

  Future<Map<String, dynamic>> asignarRol(
      String userUuid, String roleId, {String? modo}) async {
    return _rpc.llamar('bauth.user.assign_role', {
      'user_uuid': userUuid,
      'role_id': roleId,
      'mode': ?modo,
    });
  }

  Future<void> revocarRol(String userUuid, String roleId) async {
    await _rpc.llamar('bauth.user.revoke_role', {
      'user_uuid': userUuid,
      'role_id': roleId,
    });
  }

  /// Lista usuarios con filtros opcionales.
  Future<List<UsuarioInfo>> listarUsuarios({
    String? busqueda,
    String? status,
    int limite = 100,
  }) async {
    final params = <String, dynamic>{'limit': limite};
    if (busqueda != null && busqueda.isNotEmpty) params['search'] = busqueda;
    if (status != null) params['status'] = status;
    final r = await _rpc.llamar('bauth.user.list', params);
    final items = r['users'] as List<dynamic>? ?? [];
    return items
        .map((e) => UsuarioInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Entidades (idn_identity_entity) ────────────────────
  // Modelo universal: cualquier cosa es una entidad con nivel y tipo.
  // 5 niveles: tenant → bdomain → bsubdomain → pos → actor.

  /// Árbol completo de entidades (estructura anidada con hijos).
  Future<List<EntidadInfo>> arbolEntidades({String? tenantId}) async {
    final params = <String, dynamic>{};
    if (tenantId != null) params['tenant_id'] = tenantId;
    final r = await _rpc.llamar('bauth.entidad.tree', params);
    final raices = r['raices'] as List<dynamic>? ?? [];
    return raices
        .map((e) => EntidadInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lista entidades con filtros opcionales (para queries específicas).
  Future<List<EntidadInfo>> listarEntidades({
    String? nivel,
    String? tipo,
    String? parentId,
    String? tenantId,
  }) async {
    final params = <String, dynamic>{};
    if (nivel != null) params['nivel'] = nivel;
    if (tipo != null) params['tipo'] = tipo;
    if (parentId != null) params['parent_id'] = parentId;
    if (tenantId != null) params['tenant_id'] = tenantId;
    final r = await _rpc.llamar('bauth.entidad.list', params);
    final items = r['entidades'] as List<dynamic>? ?? [];
    return items
        .map((e) => EntidadInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Crea una nueva entidad en la jerarquía.
  Future<EntidadInfo> crearEntidad({
    required String nivel,
    required String tipo,
    required String nombre,
    required String tenantId,
    String? parentId,
    bool? isInternal,
  }) async {
    final params = <String, dynamic>{
      'nivel': nivel,
      'tipo': tipo,
      'nombre': nombre,
      'tenant_id': tenantId,
    };
    if (parentId != null) params['parent_id'] = parentId;
    if (isInternal != null) params['is_internal'] = isInternal;
    final r = await _rpc.llamar('bauth.entidad.create', params);
    return EntidadInfo.fromJson(r);
  }

  // ── Access Control ───────────────────────────────────────

  Future<AccessResult> evaluarAcceso(
    String sujeto,
    String recurso,
    String verbo, {
    Map<String, dynamic>? contexto,
  }) async {
    final r = await _rpc.llamar('bauth.access.evaluate', {
      'subject': sujeto,
      'resource': recurso,
      'action': verbo,
      'context': ?contexto,
    });
    return AccessResult.fromJson(r);
  }

  // ── Policy ───────────────────────────────────────────────

  Future<AccessResult> evaluarPolitica(
    String policyId,
    Map<String, dynamic> contexto,
  ) async {
    final r = await _rpc.llamar('bauth.policy.evaluate', {
      'policy_id': policyId,
      'context': contexto,
    });
    return AccessResult.fromJson(r);
  }

  // ── Inheritance ──────────────────────────────────────────

  Future<Map<String, dynamic>> computarHerencia(String roleId) async {
    return _rpc.llamar('bauth.inheritance.compute', {'role_id': roleId});
  }

  Future<bool> verificarHerencia(String ancestro, String descendiente) async {
    final r =
        await _rpc.llamar('bauth.inheritance.check', {'ancestor': ancestro, 'descendant': descendiente});
    return r['inherits'] == true;
  }

  // ── SoD ──────────────────────────────────────────────────

  Future<SoDResult> verificarSoD(List<String> roleIds) async {
    final r =
        await _rpc.llamar('bauth.sod.check', {'role_ids': roleIds});
    return SoDResult.fromJson(r);
  }

  // ── Tokens ───────────────────────────────────────────────

  Future<Map<String, dynamic>> emitirToken(
      Map<String, dynamic> claims) async {
    return _rpc.llamar('bauth.token.issue', {'claims': claims});
  }

  Future<Map<String, dynamic>> validarToken(String token) async {
    return _rpc.llamar('bauth.token.validate', {'token': token});
  }

  // ── Árbol de políticas (idn_roles_template) ──────────────

  /// Hijos directos de [parentId] desde la BD — carga lazy nodo por nodo.
  /// Cada llamada ejecuta una query psql ordenada por sort_order.
  /// La BD es la única responsable del orden — Flutter solo presenta.
  Future<List<NodoRolTemplateBD>> rolTemplateHijos({
    String? parentId,
    String tenantSlug = 'skull',
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
    final b64 = base64Encode(utf8.encode(sql));
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

  // ── Catálogo de tipos de nodo (idn_policy_node_type) ─────────────

  /// Carga todos los tipos desde bauth.idn_policy_node_type.
  /// Devuelve Map<code, ConfigTipoNodo> listo para usar en widgets.
  /// Llamar una vez al conectar y cachear en el provider.
  Future<Map<String, ConfigTipoNodo>> cargarCatalogoTipos() async {
    const sql = 'SELECT json_agg(t) FROM ('
        'SELECT code, abbreviation, name_es, name_en,'
        ' color_key, color_key_valor, font_weight, font_size_token,'
        ' monospace, letter_spacing::float AS letter_spacing,'
        ' show_badge, expanded_default'
        ' FROM bauth.idn_policy_node_type WHERE is_active = true'
        ' ORDER BY sort_order) t';
    final b64 = base64Encode(utf8.encode(sql));
    final salida = await _rpc.ejecutarCmd(
      "echo $b64 | base64 -d | psql '$_dsnSbos' -t -A",
    );
    if (salida.isEmpty || salida == 'null') return const {};
    final decoded = jsonDecode(salida);
    if (decoded == null) return const {};
    final lista = (decoded as List<dynamic>).cast<Map<String, dynamic>>();
    return { for (final j in lista) j['code'] as String : ConfigTipoNodo.fromJson(j) };
  }
}

// ═══════════════════════════════════════════════════════════
// Helpers i18n
// ═══════════════════════════════════════════════════════════

/// Extrae español de un campo que puede ser String plano o JSONB {"es","en"}.
String _es(dynamic v) {
  if (v is Map) return (v['es'] ?? v['en'] ?? '?').toString();
  return v?.toString() ?? '?';
}

/// Versión nullable — retorna null si el campo es null o vacío.
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

// ═══════════════════════════════════════════════════════════
// Nodo BD y helpers de árbol
// ═══════════════════════════════════════════════════════════

/// Nodo del árbol de políticas desde bauth.idn_roles_template.
/// Campos i18n (clave, nombre, help) pueden llegar como texto plano
/// (SQL con ->>'es') o como JSONB completo — _es/_esN/_en manejan ambos.
class NodoRolTemplateBD {
  final String id;
  final String? parentId;
  final String path;
  final String tipo;
  final String clave;
  final String? claveEn;
  final String? alias;
  final String? blockCode;
  final String nombre;
  final String? nombreEn;
  final String? valor;
  final String? help;
  final String? helpEn;
  final List<String> opciones;
  final bool effect;
  final String? verbId;
  final int? domainNumber;
  final int depth;
  List<NodoRolTemplateBD> hijos;

  NodoRolTemplateBD.fromJson(Map<String, dynamic> j)
      : id = j['id']?.toString() ?? '?',
        parentId = j['parent_id']?.toString(),
        path = j['path']?.toString() ?? '',
        tipo = j['tipo']?.toString() ?? 'objeto',
        clave = _es(j['clave']),
        claveEn = _en(j['clave']) ?? j['clave_en']?.toString(),
        alias = j['alias']?.toString(),
        blockCode = j['block_code']?.toString(),
        nombre = _es(j['nombre'] ?? j['clave']),
        nombreEn = _en(j['nombre'] ?? j['clave']) ?? j['nombre_en']?.toString(),
        valor = j['valor']?.toString(),
        help = _esN(j['help']),
        helpEn = _en(j['help']) ?? j['help_en']?.toString(),
        opciones = const [],
        effect = j['effect'] as bool? ?? false,
        verbId = j['verb_id']?.toString(),
        domainNumber = j['domain_number'] as int?,
        depth = j['depth'] as int? ?? 0,
        hijos = [];
}

// DSN de la BD oficial SBOSDB
const _dsnSbos = 'postgres://postgres:postgres@localhost:15432/SBOSDB';
