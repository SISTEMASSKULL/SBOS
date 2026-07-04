/// Cliente JSON-RPC 2.0 sobre WebSocket directo
/// Conexion al daemon bAuth (puerto 9450). Sin HTTP, sin SSH.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RpcClient extends ChangeNotifier {
  String host = '13.140.128.230';
  int port = 9450;
  bool _connected = false;
  String? _daemonVersion;
  int _requestId = 0;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  WebSocketChannel? _channel;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  final List<int> _backoffMs = [100, 500, 1000, 5000, 15000, 30000, 60000];
  int _backoffIndex = 0;

  bool get isConnected => _connected;
  String? get daemonVersion => _daemonVersion;

  Future<void> connect() async {
    try {
      final uri = Uri.parse('ws://$host:$port');
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _channel!.stream.listen(_onMessage, onError: _onError, onDone: _onDone, cancelOnError: false);
      _connected = true;
      _backoffIndex = 0;
      final health = await call('bauth.health.check');
      _daemonVersion = health['result']?['version'] as String?;
      _startPing();
      notifyListeners();
    } catch (_) {
      _scheduleReconnect();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> call(String method, [Map<String, dynamic>? params]) async {
    if (_channel == null) throw StateError('No conectado al daemon');
    final id = ++_requestId;
    final request = {'jsonrpc': '2.0', 'method': method, 'params': params ?? {}, 'id': id};
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _channel!.sink.add(jsonEncode(request));
    return completer.future.timeout(const Duration(seconds: 30), onTimeout: () {
      _pending.remove(id);
      throw TimeoutException('Timeout: $method');
    });
  }

  void _onMessage(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final id = msg['id'] as int?;
      if (id != null && _pending.containsKey(id)) {
        _pending.remove(id)!.complete(msg);
      }
    } catch (_) {}
  }

  void _onError(dynamic _) { _connected = false; _daemonVersion = null; notifyListeners(); _scheduleReconnect(); }
  void _onDone() { _connected = false; _daemonVersion = null; notifyListeners(); _scheduleReconnect(); }

  void _failAll(String reason) {
    for (final e in _pending.entries) { e.value.completeError(Exception(reason)); }
    _pending.clear();
  }

  void _scheduleReconnect() {
    _pingTimer?.cancel();
    final delay = _backoffMs[_backoffIndex.clamp(0, _backoffMs.length - 1)];
    if (_backoffIndex < _backoffMs.length - 1) _backoffIndex++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), () => connect().catchError((_) {}));
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) => call('bauth.health.check').catchError((_) {}));
  }

  @override
  void dispose() { _pingTimer?.cancel(); _reconnectTimer?.cancel(); _channel?.sink.close(); super.dispose(); }
}
