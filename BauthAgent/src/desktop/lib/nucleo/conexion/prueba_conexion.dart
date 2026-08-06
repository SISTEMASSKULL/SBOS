// ============================================================
// bauth_desktop · nucleo/conexion/prueba_conexion.dart
//
// Propósito: health check automático contra bAuth al iniciar la app.
//   Al crear el provider ejecuta bauth.health.check inmediatamente.
//   El botón de reconexión solo aparece cuando la conexión falla.
//
// Dependencias: flutter_riverpod, proveedor_conexion.
// Estándar: bauth.health.check · ADR-020 · DOC-SBOS-001 N3.
// ============================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'proveedor_conexion.dart';

/// Fase del intento de conexión.
enum FaseConexion { probando, exitosa, fallida }

/// Resultado del health check con el mensaje para la UI.
class ResultadoConexion {
  final FaseConexion fase;
  final String mensaje;
  final String? version;
  final int? uptime;

  const ResultadoConexion(this.fase, this.mensaje,
      {this.version, this.uptime});

  bool get ok => fase == FaseConexion.exitosa;
}

/// Ejecuta bauth.health.check y publica el resultado.
/// Al inicializarse dispara la conexión automáticamente.
class PruebaConexionNotifier extends Notifier<ResultadoConexion> {
  @override
  ResultadoConexion build() {
    // Conectar automáticamente al arrancar la app
    Future.microtask(probar);
    return const ResultadoConexion(FaseConexion.probando, 'Conectando…');
  }

  /// Conecta via BanexusTransporte y verifica bauth.health.check.
  /// Llamado automáticamente al iniciar y manualmente al reconectar.
  Future<void> probar() async {
    state = const ResultadoConexion(FaseConexion.probando, 'Conectando…');
    final cliente = ref.read(clienteRpcActivoProvider);
    try {
      await cliente.conectar();
      final r = await cliente.llamar('bauth.health.check');
      final version = r['version'] ?? '?';
      final status = r['status'] ?? '?';
      final uptime = r['uptime_seconds'] as int? ?? 0;
      state = ResultadoConexion(
        FaseConexion.exitosa,
        'bAuth v$version — $status ✓',
        version: version.toString(),
        uptime: uptime,
      );
    } catch (e) {
      state = ResultadoConexion(FaseConexion.fallida, e.toString());
    }
  }
}

/// Provider del resultado del health check.
final pruebaConexionProvider =
    NotifierProvider<PruebaConexionNotifier, ResultadoConexion>(
        PruebaConexionNotifier.new);
