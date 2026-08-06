// ============================================================
// bauth_desktop · nucleo/conexion/prueba_conexion.dart
//
// Propósito: monitor de salud reactivo del daemon bAuth.
//   No hay polling. La UI reacciona al estado del BanexusTransporte:
//   - Transport → conectado  : ejecuta bauth.health.check automáticamente
//   - Transport → error/desc : muestra "Reconectando…" (backoff activo)
//   - Health check falla     : muestra el error + botón "Reconectar"
//   - Usuario pulsa botón    : llama.health.check (fuerza reintento inmediato)
//
// El BanexusTransporte gestiona heartbeat + watchdog + backoff internamente.
// Este notifier solo reacciona a los cambios de estado via estadoConexionProvider.
//
// Dependencias: flutter_riverpod, proveedor_conexion.
// Estándar: bauth.health.check · ADR-020 · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cliente_rpc.dart';
import 'proveedor_conexion.dart';

/// Fase del monitor de salud — refleja lo que la UI debe mostrar.
enum FaseConexion { probando, exitosa, fallida }

/// Resultado observable del monitor de salud.
class ResultadoConexion {
  final FaseConexion fase;
  final String mensaje;
  final String? version;
  final int? uptime;

  const ResultadoConexion(this.fase, this.mensaje,
      {this.version, this.uptime});

  bool get ok => fase == FaseConexion.exitosa;
}

/// Monitor de salud del daemon bAuth.
///
/// Reacciona a [estadoConexionProvider]:
///   - Cada vez que el transporte llega a [EstadoConexion.conectado]
///     (primera vez o tras reconexión automática), ejecuta el health check.
///   - Cuando el transporte cae, muestra "Reconectando…" y espera
///     que el ciclo de backoff del transporte reestablezca el canal.
class PruebaConexionNotifier extends Notifier<ResultadoConexion> {
  // Guard: evita dos health checks simultáneos si el listener y el botón
  // disparan probar() al mismo tiempo.
  bool _verificando = false;

  @override
  ResultadoConexion build() {
    // Suscribir al estado del transporte — reacciona a cada cambio.
    ref.listen<AsyncValue<EstadoConexion>>(
      estadoConexionProvider,
      (_, next) {
        next.whenData((estado) {
          switch (estado) {
            case EstadoConexion.conectado:
              // Canal TCP + handshake OK → verificar salud de bAuth
              probar();
            case EstadoConexion.desconectado:
            case EstadoConexion.error:
              // El transporte auto-reconecta con backoff — mostrar estado intermedio
              // solo si estábamos en "exitosa" (para no sobreescribir "Conectando…")
              if (state.fase == FaseConexion.exitosa) {
                state = const ResultadoConexion(
                    FaseConexion.probando, 'Reconectando…');
              }
            case EstadoConexion.conectando:
              break; // el transporte está trabajando, no cambiar el mensaje
          }
        });
      },
    );

    // Arrancar la conexión al inicializar el provider.
    // No se espera: el listener de arriba dispara probar() cuando conecte.
    Future.microtask(() => ref.read(banexusTransporteProvider).conectar());

    return const ResultadoConexion(FaseConexion.probando, 'Conectando…');
  }

  /// Ejecuta bauth.health.check contra el daemon.
  ///
  /// Llamado automáticamente cuando el transporte alcanza [EstadoConexion.conectado].
  /// También disponible para el botón "Reconectar" (fuerza reintento inmediato).
  Future<void> probar() async {
    if (_verificando) return;
    _verificando = true;
    state = const ResultadoConexion(FaseConexion.probando, 'Verificando…');
    try {
      // llamar() auto-conecta si el transporte cayó mientras esperábamos
      final r = await ref
          .read(clienteRpcActivoProvider)
          .llamar('bauth.health.check');
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
      _verificando = false;
    }
  }
}

/// Provider del monitor de salud de bAuth.
final pruebaConexionProvider =
    NotifierProvider<PruebaConexionNotifier, ResultadoConexion>(
        PruebaConexionNotifier.new);
