// ============================================================
// bauth_desktop · nucleo/api/modelos/comun.dart
//
// Modelos de datos transversales: métricas, acceso, SoD.
// Part of bauth_api.dart — comparte librería y helpers _es/_esN.
// ============================================================

part of '../bauth_api.dart';

/// Respuesta de bauth.health.check.
class HealthInfo {
  final String status;
  final String version;
  final int    uptimeSeconds;
  final String socket;

  HealthInfo.fromJson(Map<String, dynamic> j)
      : status        = j['status']         ?? '?',
        version       = j['version']        ?? '?',
        uptimeSeconds = j['uptime_seconds'] ?? 0,
        socket        = j['socket']         ?? '?';
}

/// Métricas operacionales del daemon — respuesta de bauth.sync.status.
class SyncStatusInfo {
  final String status;
  final String timestamp;
  final int rolesTotal;
  final int atomosActivos;
  final int atomosConPosicion;
  final int usuariosActivos;
  final int sesionesActivas;
  final int credencialesActivas;
  final int intentosUltimaHora;
  final int algoritmosAprobados;

  SyncStatusInfo.fromJson(Map<String, dynamic> j)
      : status              = j['status']    ?? 'UNKNOWN',
        timestamp           = j['timestamp'] ?? '',
        rolesTotal          = (j['identidad']     as Map?)?['roles_total']           ?? 0,
        atomosActivos       = (j['identidad']     as Map?)?['atomos_activos']        ?? 0,
        atomosConPosicion   = (j['identidad']     as Map?)?['atomos_con_posicion']   ?? 0,
        usuariosActivos     = (j['identidad']     as Map?)?['usuarios_activos']      ?? 0,
        sesionesActivas     = (j['sesiones']      as Map?)?['activas']               ?? 0,
        credencialesActivas = (j['sesiones']      as Map?)?['credenciales_activas']  ?? 0,
        intentosUltimaHora  = (j['sesiones']      as Map?)?['intentos_ultima_hora']  ?? 0,
        algoritmosAprobados = (j['criptografia']  as Map?)?['algoritmos_aprobados']  ?? 0;

  factory SyncStatusInfo.vacio() => SyncStatusInfo.fromJson(const {});
}

/// Resultado de evaluación de acceso — bauth.access.evaluate / bauth.policy.evaluate.
class AccessResult {
  final bool                permitido;
  final String?             motivo;
  final Map<String, dynamic>? detalle;

  AccessResult.fromJson(Map<String, dynamic> j)
      : permitido = j['allowed'] == true || j['decision'] == 'Permit',
        motivo    = j['reason'] ?? j['motivo'],
        detalle   = j;
}

/// Resultado de verificación de Separación de Deberes — bauth.sod.check.
class SoDResult {
  final bool         conflicto;
  final List<String> rolesConflictivos;
  final String?      detalle;

  SoDResult.fromJson(Map<String, dynamic> j)
      : conflicto         = j['conflict'] == true || j['conflicto'] == true,
        rolesConflictivos = (j['conflicting_roles'] as List<dynamic>?)
                                ?.map((e) => e.toString()).toList() ?? [],
        detalle = j['detail'] ?? j['detalle'];
}
