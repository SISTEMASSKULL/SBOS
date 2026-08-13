// ============================================================
// bauth_desktop · nucleo/api/rutas/health.dart
//
// Rutas: bauth.health.* · bauth.sync.*
// Part of bauth_api.dart — usa _rpc (conexión banexus de BauthApi).
// ============================================================

part of '../bauth_api.dart';

extension BauthApiHealth on BauthApi {
  /// Estado del daemon: versión, uptime, socket.
  Future<HealthInfo> healthCheck() async {
    final r = await _rpc.llamar('bauth.health.check');
    return HealthInfo.fromJson(r);
  }

  /// Métricas operacionales: roles, átomos, usuarios, sesiones, cripto.
  Future<SyncStatusInfo> syncStatus() async {
    final r = await _rpc.llamar('bauth.sync.status');
    return SyncStatusInfo.fromJson(r);
  }
}
