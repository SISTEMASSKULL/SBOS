// ============================================================
// bauth_desktop · nucleo/conexion/cliente_rpc_ssh.dart
//
// Propósito: cliente JSON-RPC 2.0 sobre SSH exec + socat.
//   Cada llamada abre una sesión SSH, ejecuta:
//     echo <base64_json> | base64 -d | socat STDIO UNIX-CONNECT:<socket>
//   y recolecta la respuesta de stdout.
//   No necesita bridge TCP ni ServerSocket — elimina toda la complejidad
//   del reenvío de puertos que fallaba en Windows con dartssh2.
//
//   Ventajas vs bridge:
//     • Cero race conditions — cada llamada es independiente
//     • Funciona confirmado: echo|socat sobre SSH vía terminal = respuesta OK
//     • Sin ServerSocket, sin puertoLocal, sin socat persistente
//     • base64 evita problemas de escaping bash con caracteres especiales
//
// Dependencias: dart:async, dart:convert, dart:io, dartssh2, cliente_rpc.
// Estándar: JSON-RPC 2.0 · ADR-020 · DOC-SBOS-001 N3.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data' show BytesBuilder;

import 'package:dartssh2/dartssh2.dart';

import 'cliente_rpc.dart';

/// Cliente JSON-RPC 2.0 que usa SSH exec por llamada.
/// No mantiene conexión persistente — cada [llamar] abre y cierra
/// una sesión SSH ejecutando el comando socat correspondiente.
class ClienteRpcSsh implements IClienteRpc {
  final SSHClient _ssh;
  final String _socketRemoto;

  ClienteRpcSsh(this._ssh, this._socketRemoto);

  // ── IClienteRpc (no-ops: SSH gestionado por TunelSSH) ────────

  @override
  Stream<EstadoConexion> get estado =>
      Stream.value(EstadoConexion.conectado);

  @override
  Future<void> conectar() async {}

  @override
  void desconectar() {}

  @override
  void dispose() {}

  // ── JSON-RPC vía SSH exec ─────────────────────────────────────

  /// Ejecuta un método JSON-RPC en bAuth mediante SSH exec + socat.
  ///
  /// Codifica la petición en base64 para evitar problemas de
  /// escaping bash, y la decodifica en el servidor antes de
  /// pasarla a socat. Timeout de 30 s.
  @override
  Future<Map<String, dynamic>> llamar(
    String metodo, [
    Map<String, dynamic>? params,
  ]) async {
    final req = <String, dynamic>{
      'jsonrpc': '2.0',
      'method': metodo,
      'id': 1,
    };
    if (params != null) req['params'] = params;

    // Codificar JSON + newline en base64 (A-Za-z0-9+/= — sin chars especiales bash)
    final jsonBytes = utf8.encode('${jsonEncode(req)}\n');
    final b64 = base64Encode(jsonBytes);

    final cmd =
        'echo $b64 | base64 -d | socat STDIO UNIX-CONNECT:$_socketRemoto';

    return _ejecutar(cmd).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw RpcError(-32000,
          'Timeout: bAuth no respondió en 30 s — verifica que el daemon esté activo'),
    );
  }

  Future<Map<String, dynamic>> _ejecutar(String cmd) async {
    final SSHSession session;
    try {
      session = await _ssh.execute(cmd);
    } catch (e) {
      throw RpcError(-32000, 'Error al abrir sesión SSH exec: $e');
    }

    // Recolectar stdout y stderr en paralelo
    final stdoutB = BytesBuilder();
    final stderrB = BytesBuilder();
    await Future.wait([
      session.stdout.forEach(stdoutB.add),
      session.stderr.forEach(stderrB.add),
    ]);

    try { session.close(); } catch (_) {}

    final texto = utf8.decode(stdoutB.toBytes(), allowMalformed: true).trim();
    if (texto.isEmpty) {
      final err = utf8.decode(stderrB.toBytes(), allowMalformed: true).trim();
      throw RpcError(
        -32000,
        'Respuesta vacía del daemon bAuth.'
        '${err.isEmpty ? '' : ' stderr: $err'}',
      );
    }

    final Map<String, dynamic> resp;
    try {
      resp = jsonDecode(texto) as Map<String, dynamic>;
    } catch (_) {
      throw RpcError(-32700,
          'JSON inválido recibido del daemon: ${texto.length > 200 ? texto.substring(0, 200) : texto}');
    }

    if (resp.containsKey('error')) {
      final e = resp['error'] as Map<String, dynamic>;
      throw RpcError(
        e['code'] as int? ?? -1,
        e['message']?.toString() ?? 'error RPC desconocido',
        e['data'],
      );
    }

    return (resp['result'] as Map<String, dynamic>?) ?? const {};
  }
}
