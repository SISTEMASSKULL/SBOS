// ============================================================
// bauth_desktop · nucleo/conexion/cliente_rpc.dart
//
// Propósito: cliente JSON-RPC 2.0 persistente via TCP raw (Socket).
//   El daemon bAuth expone /tmp/bauth/bauth.sock con protocolo
//   JSON-RPC puro (una línea JSON por petición/respuesta, sin HTTP).
//   El túnel SSH reenvía ese socket a un puerto TCP local; este
//   cliente se conecta a ese puerto con Socket directo — sin
//   overhead de WebSocket (sin HTTP upgrade, sin frames).
//
// Protocolo:
//   Envío:   utf8(json + "\n")
//   Recepción: JSON objects delimitados por conteo de braces {}
//
// Dependencias: dart:io, dart:async, dart:convert.
// Estándar: JSON-RPC 2.0 · ADR-020 · DOC-SBOS-001 N3.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Error devuelto por el servidor JSON-RPC o por el cliente.
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

/// Interfaz mínima de cliente JSON-RPC 2.0.
/// Implementada por ClienteRpc (TCP) y ClienteRpcSsh (SSH exec).
abstract class IClienteRpc {
  Stream<EstadoConexion> get estado;
  Future<void> conectar();
  void desconectar();
  Future<Map<String, dynamic>> llamar(String metodo, [Map<String, dynamic>? params]);
  void dispose();
}

/// Cliente JSON-RPC 2.0 de baja latencia via Socket TCP.
/// Sin HTTP/WebSocket: petición → respuesta JSON directamente sobre TCP.
class ClienteRpc implements IClienteRpc {
  // ── Config ───────────────────────────────────────────────────
  final String _host;
  final int _puerto;
  final Duration _timeout;

  // ── Conexión ─────────────────────────────────────────────────
  Socket? _socket;
  final StringBuffer _buffer = StringBuffer();
  int _nextId = 1;

  // ── Pendientes ───────────────────────────────────────────────
  final Map<int, Completer<Map<String, dynamic>>> _pendientes = {};

  // ── Estado ───────────────────────────────────────────────────
  final _estadoCtrl = StreamController<EstadoConexion>.broadcast();
  @override
  Stream<EstadoConexion> get estado => _estadoCtrl.stream;
  EstadoConexion _estado = EstadoConexion.desconectado;

  // ── Reconexión ───────────────────────────────────────────────
  Timer? _reconectTimer;
  int _reintentos = 0;
  static const _maxReintentos = 10;
  static const _baseDelay = Duration(milliseconds: 500);

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

  /// Abre la conexión TCP al daemon (o al puerto local del túnel SSH).
  /// Lanza excepción si falla — el llamador ve el error real.
  @override
  Future<void> conectar() async {
    if (_estado == EstadoConexion.conectando ||
        _estado == EstadoConexion.conectado) {
      return;
    }
    _setEstado(EstadoConexion.conectando);
    try {
      _socket = await Socket.connect(_host, _puerto).timeout(_timeout);
      _socket!.listen(
        _onDatos,
        onError: _onError,
        onDone: _onCierre,
        cancelOnError: false,
      );
      _setEstado(EstadoConexion.conectado);
      _reintentos = 0;
    } catch (e) {
      _socket = null;
      _setEstado(EstadoConexion.error);
      _programarReconexion();
      rethrow; // el error real llega al llamador
    }
  }

  /// Cierra la conexión limpiamente.
  @override
  void desconectar() {
    _reconectTimer?.cancel();
    _reconectTimer = null;
    _rechazarPendientes('desconectado');
    _socket?.destroy();
    _socket = null;
    _buffer.clear();
    _setEstado(EstadoConexion.desconectado);
  }

  // ═══════════════════════════════════════════════════════════
  // JSON-RPC
  // ═══════════════════════════════════════════════════════════

  /// Llama un método JSON-RPC y retorna el `result`.
  /// Auto-conecta si el socket no está listo.
  @override
  Future<Map<String, dynamic>> llamar(
    String metodo, [
    Map<String, dynamic>? params,
  ]) async {
    if (_estado != EstadoConexion.conectado) {
      await conectar(); // rethrow si falla
    }
    if (_socket == null || _estado != EstadoConexion.conectado) {
      throw RpcError(-32000, 'no conectado a bAuth — verifica el túnel SSH');
    }

    final id = _nextId++;
    final msg = <String, dynamic>{
      'jsonrpc': '2.0',
      'method': metodo,
      'id': id,
    };
    if (params != null) msg['params'] = params;

    final completer = Completer<Map<String, dynamic>>();
    _pendientes[id] = completer;

    // Envío: JSON + salto de línea (sin overhead HTTP)
    _socket!.add(utf8.encode('${jsonEncode(msg)}\n'));

    return completer.future.timeout(_timeout).whenComplete(() {
      _pendientes.remove(id);
    });
  }

  // ═══════════════════════════════════════════════════════════
  // Manejadores de socket
  // ═══════════════════════════════════════════════════════════

  /// Acumula bytes y extrae objetos JSON completos por conteo de braces.
  void _onDatos(List<int> datos) {
    _buffer.write(utf8.decode(datos, allowMalformed: true));
    _extraerMensajes();
  }

  /// Parsea objetos JSON del buffer usando conteo de braces {}.
  /// Robusto ante mensajes partidos en múltiples fragmentos TCP.
  void _extraerMensajes() {
    final s = _buffer.toString();
    int nivel = 0;
    int inicio = 0;
    bool enCadena = false;
    bool escapeNext = false;

    for (int i = 0; i < s.length; i++) {
      final c = s[i];
      if (escapeNext) {
        escapeNext = false;
        continue;
      }
      if (c == '\\' && enCadena) {
        escapeNext = true;
        continue;
      }
      if (c == '"') {
        enCadena = !enCadena;
        continue;
      }
      if (enCadena) continue;

      if (c == '{') {
        nivel++;
      } else if (c == '}') {
        nivel--;
        if (nivel == 0) {
          final fragmento = s.substring(inicio, i + 1);
          try {
            _procesarRespuesta(jsonDecode(fragmento) as Map<String, dynamic>);
          } catch (_) {}
          inicio = i + 1;
        }
      }
    }

    // Retener fragmento incompleto para el siguiente evento de datos
    _buffer.clear();
    if (inicio < s.length) {
      _buffer.write(s.substring(inicio));
    }
  }

  void _procesarRespuesta(Map<String, dynamic> resp) {
    final id = resp['id'] as int?;
    if (id == null || !_pendientes.containsKey(id)) return;

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

  void _onError(Object error) {
    _setEstado(EstadoConexion.error);
    _rechazarPendientes(error.toString());
    _programarReconexion();
  }

  void _onCierre() {
    _socket = null;
    _buffer.clear();
    if (_estado == EstadoConexion.conectado) {
      _setEstado(EstadoConexion.desconectado);
      _rechazarPendientes('conexión cerrada');
      _programarReconexion();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Reconexión exponencial
  // ═══════════════════════════════════════════════════════════

  void _programarReconexion() {
    if (_reintentos >= _maxReintentos) return;
    _reconectTimer?.cancel();
    final delay = _baseDelay * (_reintentos + 1);
    _reconectTimer = Timer(delay, () {
      _reintentos++;
      conectar().catchError((_) {}); // el catch interno de conectar() ya maneja el error
    });
  }

  void _rechazarPendientes(String motivo) {
    final err = RpcError(-32000, motivo);
    for (final c in _pendientes.values) {
      if (!c.isCompleted) c.completeError(err);
    }
    _pendientes.clear();
  }

  void _setEstado(EstadoConexion e) {
    _estado = e;
    _estadoCtrl.add(e);
  }

  /// Libera todos los recursos.
  @override
  void dispose() {
    desconectar();
    _estadoCtrl.close();
  }
}
