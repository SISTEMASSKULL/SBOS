// ============================================================
// bauth_desktop · nucleo/conexion/cliente_rpc.dart
//
// Propósito: cliente **JSON-RPC 2.0** sobre socket TCP hacia bAuth. El
//   servidor (Interface Dual, ADR-020) enruta como JSON-RPC cuando el primer
//   byte es '{'. Verificado contra el daemon real: `bauth.health.check` →
//   {status, version, uptime_seconds}. Funciona en Windows/Mac/Linux.
// Dependencias: dart:io (Socket), dart:convert.
// Estándar: JSON-RPC 2.0 · ADR-020.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Error devuelto por el servidor en el campo `error` de JSON-RPC.
class RpcError implements Exception {
  final int codigo;
  final String mensaje;
  RpcError(this.codigo, this.mensaje);
  @override
  String toString() => 'RPC $codigo: $mensaje';
}

/// Cliente que abre el socket, llama un método y devuelve su `result`.
class ClienteRpc {
  static const Duration _limite = Duration(seconds: 8);

  /// Llama [metodo] en `host:puerto` y devuelve el objeto `result`.
  Future<Map<String, dynamic>> llamar(
    String host,
    int puerto,
    String metodo, [
    Map<String, dynamic>? params,
  ]) async {
    final socket = await Socket.connect(host, puerto, timeout: _limite);
    try {
      final cuerpo = <String, dynamic>{
        'jsonrpc': '2.0',
        'method': metodo,
        'id': 1,
      };
      if (params != null) cuerpo['params'] = params;
      socket.add(utf8.encode('${jsonEncode(cuerpo)}\n'));
      final crudo = await _leerRespuesta(socket);
      final resp = jsonDecode(crudo) as Map<String, dynamic>;
      final error = resp['error'];
      if (error is Map) {
        throw RpcError(error['code'] as int? ?? -1,
            error['message'] as String? ?? 'error desconocido');
      }
      return (resp['result'] as Map<String, dynamic>?) ?? const {};
    } finally {
      socket.destroy();
    }
  }

  /// Acumula bytes hasta obtener una respuesta JSON parseable.
  Future<String> _leerRespuesta(Socket socket) {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    late StreamSubscription<List<int>> sub;
    sub = socket.listen(
      (datos) {
        buffer.write(utf8.decode(datos));
        final texto = buffer.toString().trim();
        if (_jsonCompleto(texto) && !completer.isCompleted) {
          completer.complete(texto);
          sub.cancel();
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (completer.isCompleted) return;
        final t = buffer.toString().trim();
        _jsonCompleto(t)
            ? completer.complete(t)
            : completer.completeError('conexión cerrada sin respuesta válida');
      },
    );
    return completer.future.timeout(_limite);
  }

  bool _jsonCompleto(String s) {
    if (s.isEmpty) return false;
    try {
      jsonDecode(s);
      return true;
    } catch (_) {
      return false;
    }
  }
}
