/// JSON-RPC 2.0 Client — ADR-020 Interface Dual (Vía 1: WebSocket RPC)
///
/// TODA comunicación del Core UI con el daemon BOS usa JSON-RPC 2.0
/// sobre WebSocket. Convención: `bos.<modulo>.<operacion>`.
///
/// Transporte:
///   Desktop: WebSocket a Unix socket /run/bos/bos.sock (via ws://localhost:9443/ws)
///   Web:     WebSocket a wss://<host>:9443/ws
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Cliente JSON-RPC 2.0 para comunicación con el daemon BOS.
class JsonRpcClient {
  WebSocketChannel? _channel;
  final _controllers = <int, Completer<Map<String, dynamic>>>{};
  int _nextId = 1;
  bool _connected = false;
  StreamSubscription? _subscription;

  /// Estado de conexión observable.
  bool get isConnected => _connected;

  /// Conecta al daemon BOS vía WebSocket.
  ///
  /// Desktop: ws://localhost:9443/ws (el daemon proxy del Unix socket)
  /// Web:     wss://<host>:9443/ws
  Future<void> connect({String? host, int? port}) async {
    host ??= Platform.isAndroid || Platform.isIOS ? '10.0.2.2' : 'localhost';
    port ??= 9443;

    final uri = Uri.parse('ws://$host:$port/ws');
    _channel = WebSocketChannel.connect(uri);
    _connected = true;

    _subscription = _channel!.stream.listen(
      _handleMessage,
      onError: (error) {
        _connected = false;
        _rejectAllPending('WebSocket error: $error');
      },
      onDone: () {
        _connected = false;
        _rejectAllPending('WebSocket closed');
      },
    );
  }

  /// Envía una petición JSON-RPC 2.0 y espera la respuesta.
  ///
  /// [method] debe seguir la convención `bos.<modulo>.<operacion>`.
  /// [params] es un Map opcional con los parámetros.
  Future<Map<String, dynamic>> call(String method, [Map<String, dynamic>? params]) async {
    if (!_connected) {
      throw JsonRpcException(-32003, 'No conectado al daemon BOS');
    }

    final id = _nextId++;
    final request = {
      'jsonrpc': '2.0',
      'method': method,
      'params': params ?? {},
      'id': id,
    };

    final completer = Completer<Map<String, dynamic>>();
    _controllers[id] = completer;

    _channel!.sink.add(jsonEncode(request));

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _controllers.remove(id);
        throw JsonRpcException(-32002, 'Timeout: $method');
      },
    );
  }

  /// Notificación JSON-RPC 2.0 (sin respuesta esperada).
  void notify(String method, [Map<String, dynamic>? params]) {
    if (!_connected) return;
    _channel!.sink.add(jsonEncode({
      'jsonrpc': '2.0',
      'method': method,
      'params': params ?? {},
    }));
  }

  /// Reconecta al daemon BOS.
  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }

  /// Cierra la conexión.
  Future<void> disconnect() async {
    _connected = false;
    await _subscription?.cancel();
    await _channel?.sink.close();
  }

  // ── Manejo interno ─────────────────────────────────────────

  void _handleMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;

      // ¿Es una respuesta a una petición?
      if (data.containsKey('id') && data['id'] != null) {
        final id = data['id'] as int;
        final completer = _controllers.remove(id);
        if (completer == null) return;

        if (data.containsKey('error')) {
          final err = data['error'] as Map<String, dynamic>;
          completer.completeError(JsonRpcException(
            err['code'] as int? ?? -32603,
            err['message'] as String? ?? 'Unknown error',
            err['data'],
          ));
        } else {
          completer.complete(data);
        }
      }
      // Las notificaciones y eventos Centrifugo se manejan en WsService
    } catch (e) {
      // Ignorar frames malformados
    }
  }

  void _rejectAllPending(String reason) {
    for (final entry in _controllers.entries) {
      entry.value.completeError(JsonRpcException(-32003, reason));
    }
    _controllers.clear();
  }
}

/// Excepción JSON-RPC 2.0 tipada.
class JsonRpcException implements Exception {
  final int code;
  final String message;
  final dynamic data;

  const JsonRpcException(this.code, this.message, [this.data]);

  @override
  String toString() => 'JSON-RPC Error $code: $message';
}

/// Catálogo de métodos JSON-RPC 2.0 disponibles.
/// Convención: bos.<modulo>.<operacion> (ADR-020).
class BosMethods {
  static const fichaList = 'bos.ficha.list';
  static const fichaStatus = 'bos.ficha.status';
  static const fichaInstall = 'bos.ficha.install';
  static const fichaUpdate = 'bos.ficha.update';
  static const fichaRepair = 'bos.ficha.repair';
  static const fichaRemove = 'bos.ficha.remove';
  static const fichaProbe = 'bos.ficha.probe';

  static const bootstrapStart = 'bos.bootstrap.start';
  static const bootstrapVerify = 'bos.bootstrap.verify';
  static const bootstrapStatus = 'bos.bootstrap.status';
  static const bootstrapResume = 'bos.bootstrap.resume';

  static const stateRead = 'bos.state.read';
  static const healthCheck = 'bos.health.check';

  static const ctxCreate = 'bos.ctx.create';
  static const ctxValidate = 'bos.ctx.validate';

  static const releaseCheck = 'bos.release.check';
  static const releaseList = 'bos.release.list';

  static const pgAuxStart = 'bos.bootstrap.pg_auxiliar_start';
  static const pgAuxSync = 'bos.bootstrap.pg_auxiliar_sync';
  static const pgAuxStatus = 'bos.bootstrap.pg_auxiliar_status';
  static const pgAuxCleanup = 'bos.bootstrap.pg_auxiliar_cleanup';
}
