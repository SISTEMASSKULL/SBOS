// ============================================================
// bauth_desktop · nucleo/conexion/cliente_rpc.dart
//
// Propósito: cliente JSON-RPC 2.0 persistente vía WebSocket/TCP
//   hacia bAuth. Mantiene UNA conexión, reconecta automáticamente,
//   y expone estado de conexión para la UI.
//
//   El desktop se conecta al extremo local de un túnel SSH que
//   reenvía el Unix socket del servidor a TCP localhost:9450.
//
// Dependencias: dart:io (WebSocket/Socket), dart:convert.
// Estándar: JSON-RPC 2.0 · ADR-020 (Interface Dual).
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Error devuelto por el servidor JSON-RPC.
class RpcError implements Exception {
  final int codigo;
  final String mensaje;
  final dynamic data;
  RpcError(this.codigo, this.mensaje, [this.data]);

  @override
  String toString() => 'RPC $codigo: $mensaje';
}

/// Estados de la conexión al daemon.
enum EstadoConexion {
  desconectado,
  conectando,
  conectado,
  error,
}

/// Cliente JSON-RPC persistente con reconexión automática.
/// Usa WebSocket para mantener una conexión de larga duración.
class ClienteRpc {
  // ── Conexión ──
  final String _host;
  final int _puerto;
  final Duration _timeout;

  WebSocket? _ws;
  int _nextId = 1;

  // ── Callbacks pendientes ──
  final Map<int, Completer<Map<String, dynamic>>> _pendientes = {};

  // ── Stream de estado ──
  final _estadoController = StreamController<EstadoConexion>.broadcast();
  Stream<EstadoConexion> get estado => _estadoController.stream;
  EstadoConexion _estado = EstadoConexion.desconectado;

  // ── Reconexión ──
  Timer? _reconectTimer;
  int _reintentos = 0;
  static const _maxReintentos = 10;
  static const _reconectBase = Duration(milliseconds: 500);

  ClienteRpc({
    String host = 'localhost',
    int puerto = 9450,
    Duration timeout = const Duration(seconds: 15),
  })  : _host = host,
        _puerto = puerto,
        _timeout = timeout;

  // ═══════════════════════════════════════════════════════════
  // Conexión
  // ═══════════════════════════════════════════════════════════

  /// Inicia la conexión WebSocket al daemon.
  Future<void> conectar() async {
    if (_estado == EstadoConexion.conectando ||
        _estado == EstadoConexion.conectado) return;

    _setEstado(EstadoConexion.conectando);

    try {
      final uri = Uri.parse('ws://$_host:$_puerto/');
      _ws = await WebSocket.connect(uri).timeout(_timeout);

      _ws!.listen(
        _onMensaje,
        onError: _onError,
        onDone: _onCierre,
        cancelOnError: false,
      );

      _setEstado(EstadoConexion.conectado);
      _reintentos = 0;
    } catch (e) {
      _setEstado(EstadoConexion.error);
      _programarReconexion();
    }
  }

  /// Cierra la conexión limpiamente.
  void desconectar() {
    _reconectTimer?.cancel();
    _reconectTimer = null;
    _rechazarPendientes('desconectado');
    _ws?.close();
    _ws = null;
    _setEstado(EstadoConexion.desconectado);
  }

  // ═══════════════════════════════════════════════════════════
  // JSON-RPC
  // ═══════════════════════════════════════════════════════════

  /// Llama un método JSON-RPC y devuelve el `result`.
  Future<Map<String, dynamic>> llamar(
    String metodo, [
    Map<String, dynamic>? params,
  ]) async {
    if (_ws == null || _estado != EstadoConexion.conectado) {
      throw RpcError(-32000, 'no conectado a bAuth');
    }

    final id = _nextId++;
    final cuerpo = <String, dynamic>{
      'jsonrpc': '2.0',
      'method': metodo,
      'id': id,
    };
    if (params != null) cuerpo['params'] = params;

    final completer = Completer<Map<String, dynamic>>();
    _pendientes[id] = completer;

    _ws!.add(utf8.encode('${jsonEncode(cuerpo)}\n'));

    return completer.future.timeout(_timeout).whenComplete(() {
      _pendientes.remove(id);
    });
  }

  /// Notificación JSON-RPC (sin respuesta esperada).
  void notificar(String metodo, [Map<String, dynamic>? params]) {
    if (_ws == null || _estado != EstadoConexion.conectado) return;

    final cuerpo = <String, dynamic>{
      'jsonrpc': '2.0',
      'method': metodo,
    };
    if (params != null) cuerpo['params'] = params;

    _ws!.add(utf8.encode('${jsonEncode(cuerpo)}\n'));
  }

  // ═══════════════════════════════════════════════════════════
  // Manejadores WebSocket
  // ═══════════════════════════════════════════════════════════

  void _onMensaje(dynamic datos) {
    try {
      final texto = utf8.decode(datos is List<int> ? datos : []);
      final resp = jsonDecode(texto) as Map<String, dynamic>;
      final id = resp['id'] as int?;

      if (id != null && _pendientes.containsKey(id)) {
        final error = resp['error'];
        if (error is Map) {
          _pendientes[id]!.completeError(RpcError(
            error['code'] as int? ?? -1,
            error['message'] as String? ?? 'error desconocido',
            error['data'],
          ));
        } else {
          _pendientes[id]!.complete(
            (resp['result'] as Map<String, dynamic>?) ?? const {},
          );
        }
      }
      // Notificaciones sin id se ignoran (futuro: push events)
    } catch (_) {
      // Ignorar frames no-JSON (WebSocket ping/pong, etc.)
    }
  }

  void _onError(Object error) {
    _setEstado(EstadoConexion.error);
    _rechazarPendientes(error.toString());
    _programarReconexion();
  }

  void _onCierre() {
    _ws = null;
    if (_estado == EstadoConexion.conectado) {
      _setEstado(EstadoConexion.desconectado);
      _rechazarPendientes('conexión cerrada');
      _programarReconexion();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Reconexión
  // ═══════════════════════════════════════════════════════════

  void _programarReconexion() {
    if (_reintentos >= _maxReintentos) return;
    _reconectTimer?.cancel();
    final delay = _reconectBase * (_reintentos + 1);
    _reconectTimer = Timer(delay, () {
      _reintentos++;
      conectar();
    });
  }

  void _rechazarPendientes(String motivo) {
    final error = RpcError(-32000, motivo);
    for (final c in _pendientes.values) {
      if (!c.isCompleted) c.completeError(error);
    }
    _pendientes.clear();
  }

  void _setEstado(EstadoConexion e) {
    _estado = e;
    _estadoController.add(e);
  }

  /// Libera recursos.
  void dispose() {
    desconectar();
    _estadoController.close();
  }
}
