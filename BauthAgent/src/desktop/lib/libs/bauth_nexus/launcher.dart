// ============================================================
// bauth_nexus · libs/bauth_nexus/launcher.dart
//
// Librería agnóstica — solo dart:io / dart:async.
// No depende de Flutter, Riverpod ni ningún framework de UI.
//
// Propósito: detecta y lanza el binario banexus automáticamente.
//   1. Intenta conectar a 127.0.0.1:9446 (la local_api del daemon).
//   2. Si no hay respuesta, busca banexus.exe junto al ejecutable de la app
//      y lo lanza como proceso hijo independiente (detached).
//   3. Espera hasta que la local_api responda (max [maxEspera]).
//
// El usuario final solo ejecuta el exe del desktop — banexus arranca solo.
// ============================================================

import 'dart:async';
import 'dart:io';

/// Resultado del intento de arranque de banexus.
enum EstadoLauncher { corriendo, arrancado, fallo }

/// Detecta y arranca el binario banexus si no está disponible.
class BanexusLauncher {
  final String host;
  final int puerto;
  final Duration maxEspera;

  Process? _proceso;

  BanexusLauncher({
    this.host = '127.0.0.1',
    this.puerto = 9446,
    this.maxEspera = const Duration(seconds: 15),
  });

  // ─── API pública ─────────────────────────────────────────────

  /// Asegura que banexus está corriendo.
  /// Si ya responde → [EstadoLauncher.corriendo].
  /// Si no, lo busca junto al exe de la app y lo lanza.
  Future<EstadoLauncher> asegurarCorriendo() async {
    if (await _estaRespondiendo()) return EstadoLauncher.corriendo;

    final info = _encontrarBinario();
    if (info == null) return EstadoLauncher.fallo;

    try {
      // workingDirectory = directorio del binario para que encuentre banexus.toml
      _proceso = await Process.start(
        info.ruta,
        [],
        workingDirectory: info.directorio,
        mode: ProcessStartMode.detached,
      );
    } catch (_) {
      return EstadoLauncher.fallo;
    }

    // Esperar hasta que la local_api responda
    final deadline = DateTime.now().add(maxEspera);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (await _estaRespondiendo()) return EstadoLauncher.arrancado;
    }

    return EstadoLauncher.fallo;
  }

  /// Detiene el proceso hijo si fue arrancado por este launcher.
  void detener() {
    _proceso?.kill();
    _proceso = null;
  }

  // ─── Internos ────────────────────────────────────────────────

  /// Comprueba si banexus local_api responde a una conexión TCP.
  Future<bool> _estaRespondiendo() async {
    try {
      final s = await Socket.connect(
        host, puerto,
        timeout: const Duration(seconds: 1),
      );
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Busca banexus en el directorio del ejecutable de la app (prioritario)
  /// y en candidatos alternativos. Retorna ruta + directorio de trabajo.
  _InfoBinario? _encontrarBinario() {
    for (final ruta in _candidatos()) {
      final f = File(ruta);
      if (f.existsSync()) {
        return _InfoBinario(
          ruta: f.absolute.path,
          directorio: f.absolute.parent.path,
        );
      }
    }
    return null;
  }

  /// Rutas candidatas en orden de preferencia.
  /// El directorio del ejecutable de la app es el primer candidato —
  /// ahí es donde el usuario despliega banexus.exe junto al desktop.
  List<String> _candidatos() {
    final exeDir = _directorioEjecutable();
    final nombre = Platform.isWindows ? 'banexus.exe' : 'banexus';

    return [
      if (exeDir != null) '$exeDir${Platform.pathSeparator}$nombre',
      nombre,
      '.${Platform.pathSeparator}$nombre',
      if (!Platform.isWindows) '/usr/local/bin/banexus',
    ];
  }

  /// Directorio del ejecutable de la app en tiempo de ejecución.
  String? _directorioEjecutable() {
    try {
      final exe = Platform.resolvedExecutable;
      final sep = Platform.pathSeparator;
      final idx = exe.lastIndexOf(sep);
      if (idx < 0) return null;
      return exe.substring(0, idx);
    } catch (_) {
      return null;
    }
  }
}

/// Ruta y directorio de trabajo del binario encontrado.
class _InfoBinario {
  final String ruta;
  final String directorio;
  const _InfoBinario({required this.ruta, required this.directorio});
}
