// ============================================================
// bauth_desktop · nucleo/conexion/tunel_ssh.dart
//
// Propósito: túnel SSH integrado — conecta al servidor vía SSH
//   y reenvía el Unix socket /tmp/bauth/bauth.sock a un puerto TCP
//   local aleatorio. Sin terminal extra: el túnel vive dentro
//   de la app usando dartssh2 (forwardLocalUnix).
//
// Flujo: SSH connect → autenticar → ServerSocket local (puerto 0)
//        → por cada TCP entrante, abrir SSHForwardChannel al socket
//        remoto → puente bidireccional de bytes.
//
// Dependencias: dart:io, dart:async, dartssh2.
// Estándar: ADR-020 (Interface Dual) · DOC-SBOS-001 N3.
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
  /// [usuario] — usuario SSH (ej. 'skull').
  /// [password] — contraseña SSH (nunca se persiste).
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
    // 1. Cerrar túnel previo si existía
    await cerrar();

    // 2. Conectar al servidor SSH
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

    // Espera a que la autenticación sea exitosa
    await _cliente!.authenticated;

    // 3. Servidor TCP local en puerto aleatorio (0 = asignado por OS)
    _servidor = await ServerSocket.bind('127.0.0.1', 0);
    _puertoLocal = _servidor!.port;

    // 4. Por cada conexión TCP entrante, abrir canal al socket Unix remoto
    _servidor!.listen(
      (local) => _puente(local, socketRemoto),
      onError: (_) {},
    );

    return _puertoLocal;
  }

  /// Crea un puente bidireccional entre [local] (TCP) y el socket Unix remoto.
  Future<void> _puente(Socket local, String socketRemoto) async {
    SSHForwardChannel? canal;
    StreamSubscription<Uint8List>? subRemoto;
    StreamSubscription<Uint8List>? subLocal;

    void limpiar() {
      subRemoto?.cancel();
      subLocal?.cancel();
      canal?.close();
      local.destroy();
    }

    try {
      // Abre canal directo al Unix socket usando direct-streamlocal@openssh.com
      canal = await _cliente!.forwardLocalUnix(socketRemoto);

      final done = Completer<void>();

      // Remote → local: datos del daemon al cliente RPC
      subRemoto = canal.stream.listen(
        local.add,
        onDone: () { if (!done.isCompleted) done.complete(); },
        onError: (_) { if (!done.isCompleted) done.complete(); },
        cancelOnError: true,
      );

      // Local → remote: datos del cliente RPC al daemon
      subLocal = local.listen(
        canal.sink.add,
        onDone: () { if (!done.isCompleted) done.complete(); },
        onError: (_) { if (!done.isCompleted) done.complete(); },
        cancelOnError: true,
      );

      await done.future;
    } catch (_) {
      // Conexión terminada o canal rechazado
    } finally {
      limpiar();
    }
  }

  /// Cierra el túnel y libera todos los recursos.
  Future<void> cerrar() async {
    await _servidor?.close();
    _cliente?.close();
    _servidor = null;
    _cliente = null;
    _puertoLocal = 0;
  }
}
