// ============================================================
// bauth_desktop · nucleo/conexion/tunel_ssh.dart
//
// Propósito: gestor de autenticación SSH hacia el servidor bAuth.
//   Establece y mantiene la conexión SSH autenticada.
//   Expone crearClienteRpc() para obtener un ClienteRpcSsh
//   que hace RPC vía SSH exec (sin bridge TCP ni ServerSocket).
//
//   Flujo: SSH connect → autenticar → [listo para exec]
//   Cada llamada RPC ejecuta:
//     echo <b64_json> | base64 -d | socat STDIO UNIX-CONNECT:<socket>
//
// Dependencias: dart:async, dartssh2, cliente_rpc_ssh.
// Estándar: ADR-020 · DOC-SBOS-001 N3.
// ============================================================

import 'dart:async';

import 'package:dartssh2/dartssh2.dart';

import 'cliente_rpc_ssh.dart';

/// Gestiona la conexión SSH autenticada y provee clientes RPC vía exec.
class TunelSSH {
  SSHClient? _cliente;
  String _socketRemoto = '/tmp/bauth/bauth.sock';

  /// true si la conexión SSH está activa.
  bool get activo => _cliente != null;

  /// Establece la conexión SSH y autentica al usuario.
  ///
  /// [host]          — IP o hostname del servidor VPS (puerto SSH 22).
  /// [usuario]       — usuario SSH (ej. "root").
  /// [password]      — contraseña SSH (nunca se persiste ni se logea).
  /// [socketRemoto]  — ruta del Unix socket bAuth en el servidor.
  /// [puertoSSH]     — puerto SSH (default 22).
  Future<void> iniciar({
    required String host,
    required String usuario,
    required String password,
    String socketRemoto = '/tmp/bauth/bauth.sock',
    int puertoSSH = 22,
  }) async {
    await cerrar();
    _socketRemoto = socketRemoto;

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
  }

  /// Crea un cliente JSON-RPC que usa SSH exec por cada llamada.
  /// El SSH debe estar autenticado (llama a [iniciar] primero).
  ClienteRpcSsh crearClienteRpc() {
    final cliente = _cliente;
    if (cliente == null) {
      throw StateError('túnel SSH no conectado — llama a iniciar() primero');
    }
    return ClienteRpcSsh(cliente, _socketRemoto);
  }

  /// Cierra la conexión SSH y libera recursos.
  Future<void> cerrar() async {
    try { _cliente?.close(); } catch (_) {}
    _cliente = null;
  }
}
