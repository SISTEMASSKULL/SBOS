// ============================================================
// bauth_desktop · nucleo/conexion/tunel_ssh.dart
//
// Propósito: túnel SSH integrado — conecta al servidor vía SSH
//   y reenvía /tmp/bauth/bauth.sock a un puerto TCP local aleatorio.
//   Usa SSH execute + socat (más portable que direct-streamlocal).
//
// Flujo: SSH connect → autenticar → ServerSocket local (puerto 0)
//   → por cada TCP entrante, ejecutar "socat STDIO UNIX-CONNECT:socket"
//   → puente bidireccional stdin/stdout ↔ TCP local.
//
// Dependencias: dart:io, dart:async, dart:typed_data, dartssh2.
// Estándar: ADR-020 · DOC-SBOS-001 N3.
// ============================================================

import 'dart:async';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

/// Gestiona el ciclo de vida del túnel SSH hacia /tmp/bauth/bauth.sock.
class TunelSSH {
  SSHClient? _cliente;
  ServerSocket? _servidor;
  int _puertoLocal = 0;

  /// Puerto TCP local donde escucha el puente (0 si el túnel no está activo).
  int get puertoLocal => _puertoLocal;

  /// true si el túnel está activo y el cliente SSH conectado.
  bool get activo => _cliente != null && _servidor != null;

  /// Establece la conexión SSH y abre el servidor TCP local.
  ///
  /// [host] — IP o hostname del servidor VPS (puerto SSH 22).
  /// [usuario] — usuario SSH.
  /// [password] — contraseña SSH (nunca se persiste ni se logea).
  /// [socketRemoto] — ruta del Unix socket en el servidor.
  ///
  /// Retorna el puerto TCP local al que debe conectarse ClienteRpc.
  Future<int> iniciar({
    required String host,
    required String usuario,
    required String password,
    String socketRemoto = '/tmp/bauth/bauth.sock',
    int puertoSSH = 22,
  }) async {
    await cerrar();

    // Conectar y autenticar SSH
    final sock = await SSHSocket.connect(
      host,
      puertoSSH,
      timeout: const Duration(seconds: 15),
    );
    _cliente = SSHClient(
      sock,
      username: usuario,
      onPasswordRequest: () => password,
    );
    await _cliente!.authenticated;

    // ServerSocket local en puerto aleatorio
    _servidor = await ServerSocket.bind('127.0.0.1', 0);
    _puertoLocal = _servidor!.port;

    // Cada conexión TCP local → una sesión SSH con socat
    _servidor!.listen(
      (local) => _puente(local, socketRemoto),
      onError: (_) {},
    );

    return _puertoLocal;
  }

  /// Puente bidireccional: TCP local ↔ SSH exec socat ↔ Unix socket remoto.
  /// socat es más portable que direct-streamlocal@openssh.com en Windows.
  Future<void> _puente(Socket local, String socketRemoto) async {
    SSHSession? session;

    void limpiar() {
      try { session?.close(); } catch (_) {}
      try { local.destroy(); } catch (_) {}
    }

    try {
      // socat en el servidor hace de bridge stdin/stdout ↔ Unix socket
      session = await _cliente!.execute(
        'socat STDIO UNIX-CONNECT:$socketRemoto',
      );

      final done = Completer<void>();

      // Daemon → cliente local
      session.stdout.listen(
        local.add,
        onDone: () { if (!done.isCompleted) done.complete(); },
        onError: (_) { if (!done.isCompleted) done.complete(); },
        cancelOnError: true,
      );

      // Cliente local → daemon (convierte List<int> → Uint8List para stdin)
      local.listen(
        session.stdin.add,
        onDone: () { if (!done.isCompleted) done.complete(); },
        onError: (_) { if (!done.isCompleted) done.complete(); },
        cancelOnError: true,
      );

      await done.future;
    } catch (_) {
      // Canal rechazado, socat no disponible, o conexión terminada
    } finally {
      limpiar();
    }
  }

  /// Cierra el túnel y libera todos los recursos.
  Future<void> cerrar() async {
    try { await _servidor?.close(); } catch (_) {}
    try { _cliente?.close(); } catch (_) {}
    _servidor = null;
    _cliente = null;
    _puertoLocal = 0;
  }
}
