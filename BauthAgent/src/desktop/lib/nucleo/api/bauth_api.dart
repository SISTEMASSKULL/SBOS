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

import '../conexion/cliente_rpc.dart';

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

/// Entidad del catálogo universal de identidad (idn_identidad_entidad).
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
      : entidadId = j['entidad_id'] ?? j['id'] ?? '?',
        parentId = j['parent_id'],
        tenantId = j['tenant_id'] ?? '?',
        nivel = j['nivel'] ?? '?',
        tipo = j['tipo'] ?? '?',
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
  final ClienteRpc _rpc;

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

  // ── Entidades (idn_identidad_entidad) ────────────────────
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

  /// Árbol completo de políticas para el tenant indicado.
  /// Llama a bauth.rol_template.tree y construye la estructura anidada.
  Future<List<NodoRolTemplateBD>> rolTemplateArbol({
    String tenantSlug = 'skull',
  }) async {
    final r = await _rpc.llamar(
      'bauth.rol_template.tree',
      {'tenant_slug': tenantSlug},
    );
    final items = r['nodos'] as List<dynamic>? ?? [];
    final planos = items
        .map((e) => NodoRolTemplateBD.fromJson(e as Map<String, dynamic>))
        .toList();
    return _construirArbolBD(planos);
  }

  /// Hijos directos de [parentId] — carga lazy con caché local.
  ///
  /// Primera llamada (parentId=null): obtiene TODOS los nodos de
  /// bauth.rol_template.tree y construye un índice en memoria por parent_id.
  /// Llamadas siguientes: sirven del índice sin más RPCs.
  /// Así la UI siente carga nodo a nodo pero solo hay UN llamado al daemon.
  Future<List<NodoRolTemplateBD>> rolTemplateHijos({
    String? parentId,
    String tenantSlug = 'skull',
  }) async {
    _cacheArbol ??= _CacheArbolBD();
    await _cacheArbol!.cargar(_rpc, tenantSlug);
    return _cacheArbol!.hijos(parentId);
  }

  /// Descarta el caché del árbol — la siguiente llamada recarga desde el daemon.
  void invalidarCacheArbol() => _cacheArbol = null;

  // Caché del árbol (un solo RPC, índice local por parent_id)
  _CacheArbolBD? _cacheArbol;
}

// ═══════════════════════════════════════════════════════════
// Nodo BD y helpers de árbol
// ═══════════════════════════════════════════════════════════

/// Nodo del árbol de políticas almacenado en bauth.idn_roles_template.
/// La estructura anidada se construye del resultado plano devuelto por la API.
class NodoRolTemplateBD {
  final String id;
  final String? parentId;
  final String path;
  final String tipo;
  final String clave;
  final String nombre;
  final String? valor;
  final String? help;
  final List<String> opciones;
  final bool effect;
  final String? verbId;
  final int? domainNumber;
  final int depth;
  List<NodoRolTemplateBD> hijos;

  NodoRolTemplateBD.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '?',
        parentId = j['parent_id'],
        path = j['path'] ?? '',
        tipo = j['tipo'] ?? '?',
        clave = j['clave'] ?? '?',
        nombre = _nombreEs(j['name']),
        valor = j['valor'],
        help = j['help'],
        opciones = (j['opciones'] as List<dynamic>?)?.cast<String>() ?? [],
        effect = j['effect'] == true,
        verbId = j['verb_id'],
        domainNumber = j['domain_number'] as int?,
        depth = j['depth'] ?? 0,
        hijos = [];

  /// Extrae el nombre en español del JSONB name (ej. {"es": "Acceso Lógico"}).
  static String _nombreEs(dynamic name) {
    if (name is Map<String, dynamic>) {
      final es = name['es'];
      if (es != null) return es.toString();
      if (name.isNotEmpty) return name.values.first.toString();
      return '?';
    }
    return name?.toString() ?? '?';
  }
}

/// Construye árbol anidado desde lista plana usando parent_id.
List<NodoRolTemplateBD> _construirArbolBD(List<NodoRolTemplateBD> planos) {
  final mapa = {for (final n in planos) n.id: n};
  final raices = <NodoRolTemplateBD>[];
  for (final n in planos) {
    if (n.parentId == null) {
      raices.add(n);
    } else {
      mapa[n.parentId]?.hijos.add(n);
    }
  }
  _ordenarBD(raices);
  return raices;
}

/// Ordena nodos por path para comparación visual estable con el árbol fuente.
void _ordenarBD(List<NodoRolTemplateBD> nodos) {
  nodos.sort((a, b) => a.path.compareTo(b.path));
  for (final n in nodos) { _ordenarBD(n.hijos); }
}

// ═══════════════════════════════════════════════════════════
// Caché del árbol RolTemplate (índice local lazy)
// ═══════════════════════════════════════════════════════════

/// Caché de un solo RPC: carga bauth.rol_template.tree una vez
/// y sirve los hijos por parent_id desde un índice en memoria.
class _CacheArbolBD {
  final Map<String?, List<NodoRolTemplateBD>> _indice = {};
  // Completer compartido para serializar peticiones concurrentes
  Completer<void>? _enCurso;
  bool _cargado = false;

  bool get cargado => _cargado;

  /// Carga el árbol completo si aún no fue cargado.
  /// Llamadas concurrentes esperan a la misma petición en vuelo.
  Future<void> cargar(ClienteRpc rpc, String tenantSlug) async {
    if (_cargado) return;
    if (_enCurso != null) {
      await _enCurso!.future;
      return;
    }
    _enCurso = Completer<void>();
    try {
      final r = await rpc.llamar(
          'bauth.rol_template.tree', {'tenant_slug': tenantSlug});
      final items = r['nodos'] as List<dynamic>? ?? [];
      _indice.clear();
      for (final raw in items) {
        final n = NodoRolTemplateBD.fromJson(raw as Map<String, dynamic>);
        (_indice[n.parentId] ??= []).add(n);
      }
      for (final lista in _indice.values) {
        lista.sort((a, b) => a.path.compareTo(b.path));
      }
      _cargado = true;
      _enCurso!.complete();
    } catch (e) {
      final c = _enCurso!;
      _enCurso = null; // permite reintento en próxima llamada
      c.completeError(e);
      rethrow;
    }
  }

  /// Devuelve los hijos directos de [parentId] ([] si no hay ninguno).
  List<NodoRolTemplateBD> hijos(String? parentId) =>
      _indice[parentId] ?? const [];
}
