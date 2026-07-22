// ============================================================
// bauth_desktop · nucleo/conexion/prueba_conexion.dart
//
// Propósito: health check contra bAuth real usando el cliente activo.
//   Usa clienteRpcActivoProvider: SSH exec si hay túnel SSH activo,
//   TCP si está en modo directo. Expone el resultado para la UI.
//
// Dependencias: flutter_riverpod, proveedor_conexion.
// Estándar: bauth.health.check (verificado VPS 2026-07-15).
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'proveedor_conexion.dart';

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

  /// Publica un error sin ejecutar la prueba (usado por el túnel SSH).
  void establecerError(String mensaje) {
    state = ResultadoConexion(FaseConexion.fallida, mensaje);
  }

  /// Conecta usando el cliente activo y ejecuta bauth.health.check.
  /// Usa SSH exec si hay un ClienteRpcSsh activo; TCP si no.
  Future<void> probar() async {
    state = const ResultadoConexion(FaseConexion.probando, 'Conectando…');
    final cliente = ref.read(clienteRpcActivoProvider);
    try {
      await cliente.conectar(); // no-op para SSH
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
    // No desconectar: SSH exec no tiene estado persistente
    //                 TCP: el cliente compartido permanece conectado para reutilizar
  }
}

/// Provider del resultado del health check.
final pruebaConexionProvider =
    NotifierProvider<PruebaConexionNotifier, ResultadoConexion>(
        PruebaConexionNotifier.new);
