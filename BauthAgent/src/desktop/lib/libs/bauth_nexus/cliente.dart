// ============================================================
// bauth_nexus · libs/bauth_nexus/cliente.dart
//
// Librería agnóstica — solo dart:io / dart:async / dart:convert.
// No depende de Flutter, Riverpod ni ningún framework de UI.
//
// Propósito: cliente TCP al binario banexus (Rust).
//   banexus-daemon escucha en 127.0.0.1:9446 (local_api).
//   Protocolo: JSON-RPC 2.0 newline-delimited → banexus → bhnexus → bAuth.
//
//   La lógica de transporte (handshake, reconexión, bhnexus, bAuth)
//   está íntegramente en el binario banexus (Rust). Este cliente
//   solo abre un socket TCP y envía/recibe JSON estándar.
//
// Uso:
//   final c = BanexusCliente();
//   await c.conectar();
//   final resp = await c.llamar('bauth.health', {});
//   c.cerrar();
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Error retornado por el binario banexus (campo 'error' en JSON-RPC 2.0).
class BanexusError implements Exception {
  final int code;
  final String message;
  const BanexusError(this.code, this.message);
  @override
  String toString() => 'BanexusError($code): $message';
}

/// Estados de la conexión TCP al binario banexus.
enum EstadoBanexus { desconectado, conectando, conectado, error }

/// Cliente TCP al binario banexus (proceso Rust independiente).
///
/// banexus-daemon corre en la misma máquina (o puede ser arrancado por
/// [BanexusLauncher]) y expone su local_api en 127.0.0.1:9446.
/// Este cliente envía llamadas JSON-RPC 2.0 al daemon y recibe respuestas.
///
/// Toda la lógica de transporte (conexión a bhnexus, handshake, proxy
/// a bAuth) está en el binario Rust — este cliente no implementa nada
/// del protocolo banexus.
class BanexusCliente {
  final String host;
  final int puerto;
  final Duration timeout;

  Socket? _socket;
  final StringBuffer _buf = StringBuffer();
  int _nextId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pendientes = {};

  final _estadoCtrl = StreamController<EstadoBanexus>.broadcast();
  EstadoBanexus _estado = EstadoBanexus.desconectado;

  Completer<void>? _conectandoCompleter;

  /// Stream de cambios de estado de la conexión TCP.
  Stream<EstadoBanexus> get estadoStream => _estadoCtrl.stream;

  /// Estado actual de la conexión.
  EstadoBanexus get estado => _estado;

  BanexusCliente({
    this.host = '127.0.0.1',
    this.puerto = 9446,
    this.timeout = const Duration(seconds: 15),
  });

  // ─── Conexión ───────────────────────────────────────────────

  /// Abre el socket TCP al binario banexus. Idempotente.
  Future<void> conectar() async {
    if (_estado == EstadoBanexus.conectado) return;
    if (_conectandoCompleter != null) return _conectandoCompleter!.future;

    _conectandoCompleter = Completer<void>();
    _setEstado(EstadoBanexus.conectando);
    try {
      _socket = await Socket.connect(host, puerto, timeout: timeout);
      _socket!
        ..setOption(SocketOption.tcpNoDelay, true)
        ..listen(_onDatos, onDone: _onCierre, onError: _onError, cancelOnError: false);
      _setEstado(EstadoBanexus.conectado);
      _conectandoCompleter!.complete();
    } catch (e) {
      _setEstado(EstadoBanexus.error);
      _conectandoCompleter!.completeError(e);
      rethrow;
    } finally {
      _conectandoCompleter = null;
    }
  }

  /// Cierra el socket y rechaza todas las llamadas pendientes.
  void cerrar() {
    try { _socket?.destroy(); } catch (_) {}
    _socket = null;
    _buf.clear();
    _rechazarPendientes('socket cerrado');
    _setEstado(EstadoBanexus.desconectado);
  }

  // ─── JSON-RPC 2.0 ───────────────────────────────────────────

  /// Llama a [metodo] con [params] opcionales y retorna el campo `result`.
  /// Lanza [BanexusError] si el binario retorna un error JSON-RPC.
  Future<Map<String, dynamic>> llamar(
    String metodo, [
    Map<String, dynamic>? params,
  ]) async {
    if (_estado != EstadoBanexus.conectado) await conectar();
    if (_socket == null) throw BanexusError(-32000, 'socket banexus no disponible');

    final id = _nextId++;
    final msg = <String, dynamic>{'jsonrpc': '2.0', 'method': metodo, 'id': id};
    if (params != null) msg['params'] = params;

    final completer = Completer<Map<String, dynamic>>();
    _pendientes[id] = completer;

    // Enviar JSON + '\n' (protocolo newline-delimited de banexus local_api)
    _socket!.write('${jsonEncode(msg)}\n');

    return completer.future.timeout(timeout, onTimeout: () {
      _pendientes.remove(id);
      throw BanexusError(-32001, 'timeout en llamada $metodo');
    }).whenComplete(() => _pendientes.remove(id));
  }

  // ─── Parser interno ─────────────────────────────────────────

  void _onDatos(List<int> datos) {
    _buf.write(utf8.decode(datos, allowMalformed: true));
    _extraerMensajes();
  }

  void _extraerMensajes() {
    final s = _buf.toString();
    int nivel = 0, inicio = 0;
    bool enCadena = false, escape = false;

    for (int i = 0; i < s.length; i++) {
      final c = s[i];
      if (escape) { escape = false; continue; }
      if (c == '\\' && enCadena) { escape = true; continue; }
      if (c == '"') { enCadena = !enCadena; continue; }
      if (enCadena) continue;
      if (c == '{') nivel++;
      else if (c == '}') {
        nivel--;
        if (nivel == 0) {
          try { _despachar(jsonDecode(s.substring(inicio, i + 1)) as Map<String, dynamic>); }
          catch (_) {}
          inicio = i + 1;
        }
      }
    }
    _buf.clear();
    if (inicio < s.length) _buf.write(s.substring(inicio));
  }

  void _despachar(Map<String, dynamic> resp) {
    final id = resp['id'] as int?;
    if (id == null || !_pendientes.containsKey(id)) return;

    final error = resp['error'];
    if (error is Map) {
      _pendientes[id]!.completeError(BanexusError(
        error['code'] as int? ?? -1,
        error['message']?.toString() ?? 'error desconocido',
      ));
    } else {
      _pendientes[id]!.complete(
        (resp['result'] as Map<String, dynamic>?) ?? const {},
      );
    }
  }

  void _onCierre() {
    _socket = null;
    _buf.clear();
    _rechazarPendientes('banexus cerró la conexión');
    _setEstado(EstadoBanexus.desconectado);
  }

  void _onError(Object err) {
    _rechazarPendientes(err.toString());
    _setEstado(EstadoBanexus.error);
  }

  void _rechazarPendientes(String motivo) {
    final err = BanexusError(-32000, motivo);
    for (final c in _pendientes.values) {
      if (!c.isCompleted) c.completeError(err);
    }
    _pendientes.clear();
  }

  void _setEstado(EstadoBanexus e) {
    _estado = e;
    _estadoCtrl.add(e);
  }

  void dispose() {
    cerrar();
    _estadoCtrl.close();
  }
}
