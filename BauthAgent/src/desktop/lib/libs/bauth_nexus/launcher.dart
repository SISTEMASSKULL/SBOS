// ============================================================
// bauth_nexus · libs/bauth_nexus/launcher.dart
//
// Librería agnóstica — solo dart:io / dart:async.
// No depende de Flutter, Riverpod ni ningún framework de UI.
//
// Propósito: detecta y lanza el binario banexus (Rust) si no está corriendo.
//   1. Intenta conectar a 127.0.0.1:9446 (la local_api del daemon).
//   2. Si no hay respuesta, busca banexus.exe en los paths configurados
//      y lo lanza como proceso hijo.
//   3. Espera hasta que la local_api responda (max [maxEspera]).
//
// El binario banexus maneja su propio archivo de configuración (banexus.toml).
// Este launcher no configura nada del protocolo — solo arranca el proceso.
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
  final List<String> candidatos;

  Process? _proceso;

  BanexusLauncher({
    this.host = '127.0.0.1',
    this.puerto = 9446,
    this.maxEspera = const Duration(seconds: 10),
    List<String>? candidatos,
  }) : candidatos = candidatos ?? _candidatosDefecto();

  // ─── API pública ─────────────────────────────────────────────

  /// Asegura que banexus está corriendo.
  /// Si ya responde → [EstadoLauncher.corriendo].
  /// Si no, lo arranca → [EstadoLauncher.arrancado] o [EstadoLauncher.fallo].
  Future<EstadoLauncher> asegurarCorriendo() async {
    if (await _estaRespondiendo()) return EstadoLauncher.corriendo;

    final binario = _encontrarBinario();
    if (binario == null) return EstadoLauncher.fallo;

    try {
      _proceso = await Process.start(
        binario, [],
        mode: ProcessStartMode.detached,
      );
    } catch (_) {
      return EstadoLauncher.fallo;
    }

    // Esperar hasta que la local_api responda
    final deadline = DateTime.now().add(maxEspera);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 300));
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
      final s = await Socket.connect(host, puerto,
          timeout: const Duration(seconds: 1));
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Busca el binario banexus en los candidatos (primer match que existe).
  String? _encontrarBinario() {
    for (final ruta in candidatos) {
      if (File(ruta).existsSync()) return ruta;
    }
    return null;
  }

  /// Rutas por defecto del binario banexus según plataforma.
  static List<String> _candidatosDefecto() {
    if (Platform.isWindows) {
      return [
        r'banexus.exe',
        r'.\banexus.exe',
        r'..\banexus\banexus.exe',
      ];
    }
    return [
      'banexus',
      './banexus',
      '/usr/local/bin/banexus',
    ];
  }
}
