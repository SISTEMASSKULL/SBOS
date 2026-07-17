// ============================================================
// bauth_desktop · nucleo/conexion/prueba_conexion.dart
//
// Propósito: health check contra bAuth real usando el cliente
//   persistente. Expone el resultado para la UI de estado.
//
// Dependencias: flutter_riverpod, cliente_rpc, config_conexion.
// Estándar: bauth.health.check (verificado VPS 2026-07-15).
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cliente_rpc.dart';

/// Fase del intento de conexión.
enum FaseConexion { inicial, probando, exitosa, fallida }

/// Resultado del "hola mundo" con su mensaje para la UI.
class ResultadoConexion {
  final FaseConexion fase;
  final String mensaje;
  final String? version;
  final int? uptime;

  const ResultadoConexion(this.fase, this.mensaje,
      {this.version, this.uptime});

  static const inicial =
      ResultadoConexion(FaseConexion.inicial, 'Sin probar');

  bool get ok => fase == FaseConexion.exitosa;
}

/// Ejecuta el health.check y publica el resultado.
class PruebaConexionNotifier extends Notifier<ResultadoConexion> {
  @override
  ResultadoConexion build() => ResultadoConexion.inicial;

  Future<void> probar() async {
    state = const ResultadoConexion(FaseConexion.probando, 'Conectando…');

    // Usar el cliente persistente en vez de crear uno nuevo por test
    final cliente = ClienteRpc();
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
    } finally {
      cliente.desconectar();
    }
  }
}

/// Provider del resultado del health check.
final pruebaConexionProvider =
    NotifierProvider<PruebaConexionNotifier, ResultadoConexion>(
        PruebaConexionNotifier.new);
