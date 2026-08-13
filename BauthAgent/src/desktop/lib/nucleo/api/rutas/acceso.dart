// ============================================================
// bauth_desktop · nucleo/api/rutas/acceso.dart
//
// Rutas: bauth.access.* · bauth.policy.* · bauth.inheritance.* · bauth.sod.*
// Part of bauth_api.dart — usa _rpc (conexión banexus de BauthApi).
// ============================================================

part of '../bauth_api.dart';

extension BauthApiAcceso on BauthApi {
  // ── Evaluación de acceso ──────────────────────────────────

  /// Evalúa si [sujeto] puede ejecutar [verbo] sobre [recurso].
  Future<AccessResult> evaluarAcceso(
    String sujeto,
    String recurso,
    String verbo, {
    Map<String, dynamic>? contexto,
  }) async {
    final r = await _rpc.llamar('bauth.access.evaluate', {
      'subject':  sujeto,
      'resource': recurso,
      'action':   verbo,
      'context':  ?contexto,
    });
    return AccessResult.fromJson(r);
  }

  // ── Políticas ─────────────────────────────────────────────

  /// Evalúa una política XACML por ID con el contexto dado.
  Future<AccessResult> evaluarPolitica(
    String                policyId,
    Map<String, dynamic>  contexto,
  ) async {
    final r = await _rpc.llamar('bauth.policy.evaluate', {
      'policy_id': policyId,
      'context':   contexto,
    });
    return AccessResult.fromJson(r);
  }

  // ── Herencia DAG ──────────────────────────────────────────

  /// Calcula el conjunto de átomos heredados para un rol (cierre transitivo).
  Future<Map<String, dynamic>> computarHerencia(String roleId) async =>
      _rpc.llamar('bauth.inheritance.compute', {'role_id': roleId});

  /// Verifica si [descendiente] hereda de [ancestro] en el DAG de roles.
  Future<bool> verificarHerencia(String ancestro, String descendiente) async {
    final r = await _rpc.llamar('bauth.inheritance.check', {
      'ancestor':   ancestro,
      'descendant': descendiente,
    });
    return r['inherits'] == true;
  }

  // ── Separación de Deberes ─────────────────────────────────

  /// Verifica conflictos SoD entre los roles indicados.
  Future<SoDResult> verificarSoD(List<String> roleIds) async {
    final r = await _rpc.llamar('bauth.sod.check', {'role_ids': roleIds});
    return SoDResult.fromJson(r);
  }
}
