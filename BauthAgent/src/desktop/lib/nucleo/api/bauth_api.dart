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
      if (modo != null) 'mode': modo,
    });
  }

  Future<void> revocarRol(String userUuid, String roleId) async {
    await _rpc.llamar('bauth.user.revoke_role', {
      'user_uuid': userUuid,
      'role_id': roleId,
    });
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
      if (contexto != null) 'context': contexto,
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
}
