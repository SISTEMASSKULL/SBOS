// ============================================================
// bauth_desktop · nucleo/conexion/prueba_conexion.dart
//
// Propósito: el "hola mundo" — llama `bauth.health.check` al servidor y
//   expone el resultado (conectando / ok con versión / error) para la UI.
// Dependencias: flutter_riverpod, cliente_rpc, config_conexion.
// Estándar: bauth.health.check (verificado en la VPS: status/version).
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cliente_rpc.dart';
import 'config_conexion.dart';

/// Fase del intento de conexión.
enum FaseConexion { inicial, probando, exitosa, fallida }

/// Resultado del "hola mundo" con su mensaje para la UI.
class ResultadoConexion {
  final FaseConexion fase;
  final String mensaje;
  const ResultadoConexion(this.fase, this.mensaje);

  static const inicial =
      ResultadoConexion(FaseConexion.inicial, 'Sin probar todavía');
}

/// Ejecuta el health.check y publica el resultado.
class PruebaConexionNotifier extends Notifier<ResultadoConexion> {
  @override
  ResultadoConexion build() => ResultadoConexion.inicial;

  Future<void> probar() async {
    final cfg = ref.read(configConexionProvider);
    state = const ResultadoConexion(FaseConexion.probando, 'Conectando…');
    try {
      final r = await ClienteRpc()
          .llamar(cfg.host, cfg.puerto, 'bauth.health.check');
      final version = r['version'] ?? '?';
      final estado = r['status'] ?? '?';
      state = ResultadoConexion(
          FaseConexion.exitosa, 'bAuth v$version — $estado ✓');
    } catch (e) {
      state = ResultadoConexion(FaseConexion.fallida, e.toString());
    }
  }
}

/// Provider del resultado del "hola mundo".
final pruebaConexionProvider =
    NotifierProvider<PruebaConexionNotifier, ResultadoConexion>(
        PruebaConexionNotifier.new);
