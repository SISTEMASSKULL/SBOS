// ============================================================
// bauth_desktop · libs/bauth_nexus/banexus_transporte.dart
//
// Propósito: banexus-implicit para Flutter/Dart.
//   Transporte TCP nativo (dart:io Socket) hacia bhnexus:9444.
//   Protocolo newline-delimited JSON — handshake + rpc_call frames.
//   Cadena canónica: App → BanexusTransporte → bhnexus:9444 → bAuth socket.
//   Sin DLL. Sin FFI. Sin SSH. Solo socket nativo.
//
// Protocolo banexus-implicit (SSOT: 2.18_MANUAL-MOTOR-COMUNICACION v4.0):
//   1. Conectar TCP a bhnexus:9444
//   2. Enviar handshake: {"type":"handshake","node_id":"<uuid>","modo":"proxy","dev_mode":true}\n
//   3. Recibir:          {"type":"handshake_ok","granted":true,...}\n
//   4. Por cada llamada:
//      Enviar:  {"type":"rpc_call","payload":{json-rpc-2.0},"seq":N}\n
//      Recibir: {"type":"rpc_response","payload":{jsonrpc,result|error},"seq":N}\n
//
// Dependencias: dart:io, dart:async, dart:convert, dart:math.
// Estándar: ADR-020 · SBOS-NEXUS-CONCEPTUALIZACION-v3_0 §20 · 1.06 Formas banexus.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../nucleo/conexion/cliente_rpc.dart';

/// Genera un node_id único para esta sesión de banexus-implicit.
/// Formato UUID v4 (RFC 4122) usando Random.secure().
String _generarNodeId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // versión 4
  b[8] = (b[8] & 0x3f) | 0x80; // variante RFC 4122
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// banexus-implicit para Flutter/Dart — la forma base universal para apps de software.
/// Implementa [IClienteRpc] usando [dart:io Socket] directamente sobre TCP.
///
/// La app solo invoca [llamar] — el protocolo bhnexus (handshake, frames, seq)
/// es completamente transparente para el llamador.
///
/// Etapa 1 (actual): dev_mode=true, sin JWT. El handshake es aceptado por
/// bhnexus sin validación de token — bootstrap mientras bAuth aún no tiene usuarios.
/// Etapa 2: añadir jwt al handshake (cambio de una línea aquí).
class BanexusTransporte implements IClienteRpc {
  // ── Configuración ─────────────────────────────────────────────────────────
  final String _host;
  final int _puerto;
  final Duration _timeout;

  // ── Estado del socket ─────────────────────────────────────────────────────
  Socket? _socket;
  final StringBuffer _buffer = StringBuffer();
  int _seq = 0;
  bool _handshakeListo = false;
  Completer<void>? _handshakeCompleter;

  // ── Peticiones en vuelo: seq → Completer ──────────────────────────────────
  final Map<int, Completer<Map<String, dynamic>>> _pendientes = {};

  // ── Stream de estado ──────────────────────────────────────────────────────
  final _estadoCtrl = StreamController<EstadoConexion>.broadcast();
  EstadoConexion _estadoActual = EstadoConexion.desconectado;

  @override
  Stream<EstadoConexion> get estado => _estadoCtrl.stream;

  BanexusTransporte({
    String host = '13.140.128.230',
    int puerto = 9444,
    Duration timeout = const Duration(seconds: 15),
  })  : _host = host,
        _puerto = puerto,
        _timeout = timeout;

  // ══════════════════════════════════════════════════════════════════════════
  // Ciclo de vida
  // ══════════════════════════════════════════════════════════════════════════

  /// Abre la conexión TCP y completa el handshake banexus-implicit.
  /// Etapa 1: dev_mode=true (sin JWT). Idempotente si ya está conectado.
  @override
  Future<void> conectar() async {
    if (_estadoActual == EstadoConexion.conectado ||
        _estadoActual == EstadoConexion.conectando) return;

    _setEstado(EstadoConexion.conectando);
    final nodeId = '${_generarNodeId()}-flutter';

    try {
      _socket = await Socket.connect(_host, _puerto).timeout(_timeout);
      _socket!.listen(_onDatos, onError: _onError, onDone: _onCierre);

      // Handshake Etapa 1: dev_mode=true — bhnexus acepta sin JWT
      _handshakeCompleter = Completer<void>();
      _enviarLinea({
        'type': 'handshake',
        'node_id': nodeId,
        'modo': 'proxy',
        'dev_mode': true,
      });

      await _handshakeCompleter!.future.timeout(_timeout);
      _handshakeListo = true;
      _setEstado(EstadoConexion.conectado);
    } catch (e) {
      _socket?.destroy();
      _socket = null;
      _handshakeListo = false;
      _setEstado(EstadoConexion.error);
      rethrow;
    }
  }

  /// Cierra la conexión TCP limpiamente y rechaza peticiones pendientes.
  @override
  void desconectar() {
    _rechazarPendientes('desconectado por el cliente');
    _socket?.destroy();
    _socket = null;
    _buffer.clear();
    _handshakeListo = false;
    _setEstado(EstadoConexion.desconectado);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Llamada JSON-RPC 2.0 vía frame rpc_call
  // ══════════════════════════════════════════════════════════════════════════

  /// Envuelve la llamada JSON-RPC en un frame rpc_call y espera rpc_response.
  /// Auto-conecta si el socket no está listo.
  @override
  Future<Map<String, dynamic>> llamar(
    String metodo, [
    Map<String, dynamic>? params,
  ]) async {
    if (_estadoActual != EstadoConexion.conectado) await conectar();

    final seq = ++_seq;
    final payload = <String, dynamic>{
      'jsonrpc': '2.0',
      'method': metodo,
      'id': seq,
    };
    if (params != null) payload['params'] = params;

    final completer = Completer<Map<String, dynamic>>();
    _pendientes[seq] = completer;

    _enviarLinea({'type': 'rpc_call', 'payload': payload, 'seq': seq});

    return completer.future.timeout(_timeout).whenComplete(() {
      _pendientes.remove(seq);
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Procesamiento de mensajes entrantes (newline-delimited JSON)
  // ══════════════════════════════════════════════════════════════════════════

  void _onDatos(List<int> datos) {
    _buffer.write(utf8.decode(datos, allowMalformed: true));
    _extraerLineas();
  }

  /// Extrae mensajes completos separados por '\n'.
  /// Retiene el fragmento final incompleto para el siguiente evento.
  void _extraerLineas() {
    final s = _buffer.toString();
    final lineas = s.split('\n');
    _buffer.clear();

    for (int i = 0; i < lineas.length - 1; i++) {
      final linea = lineas[i].trim();
      if (linea.isEmpty) continue;
      try {
        _procesarMensaje(jsonDecode(linea) as Map<String, dynamic>);
      } catch (_) {}
    }

    // Fragmento incompleto al final — retener para el próximo evento
    if (lineas.last.isNotEmpty) _buffer.write(lineas.last);
  }

  void _procesarMensaje(Map<String, dynamic> msg) {
    switch (msg['type'] as String?) {
      case 'handshake_ok':
        if (!(_handshakeCompleter?.isCompleted ?? true)) {
          _handshakeCompleter!.complete();
        }

      case 'rpc_response':
        final seq = msg['seq'] as int?;
        final payload = msg['payload'] as Map<String, dynamic>?;
        if (seq == null || payload == null) break;
        final c = _pendientes[seq];
        if (c == null || c.isCompleted) break;
        final error = payload['error'];
        if (error is Map) {
          c.completeError(RpcError(
            error['code'] as int? ?? -1,
            error['message'] as String? ?? 'error RPC',
          ));
        } else {
          c.complete(payload['result'] as Map<String, dynamic>? ?? {});
        }

      case 'rpc_error':
        final seq = msg['seq'] as int?;
        if (seq == null) break;
        _pendientes[seq]?.completeError(
          RpcError(-32000, msg['error'] as String? ?? 'error bhnexus'),
        );

      case 'pong':
        break; // heartbeat confirmado — sin acción necesaria
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Manejo de errores y cierre de socket
  // ══════════════════════════════════════════════════════════════════════════

  void _onError(Object e) {
    _rechazarPendientes(e.toString());
    _setEstado(EstadoConexion.error);
  }

  void _onCierre() {
    _socket = null;
    _handshakeListo = false;
    if (_estadoActual == EstadoConexion.conectado) {
      _rechazarPendientes('conexión cerrada por bhnexus');
      _setEstado(EstadoConexion.desconectado);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Utilidades
  // ══════════════════════════════════════════════════════════════════════════

  /// Serializa [msg] a JSON y lo envía como línea terminada en '\n'.
  void _enviarLinea(Map<String, dynamic> msg) {
    _socket?.add(utf8.encode('${jsonEncode(msg)}\n'));
  }

  /// Rechaza todas las peticiones pendientes con el motivo dado.
  void _rechazarPendientes(String motivo) {
    final err = RpcError(-32000, motivo);
    for (final c in _pendientes.values) {
      if (!c.isCompleted) c.completeError(err);
    }
    _pendientes.clear();
    if (!(_handshakeCompleter?.isCompleted ?? true)) {
      _handshakeCompleter!.completeError(err);
    }
  }

  void _setEstado(EstadoConexion e) {
    _estadoActual = e;
    if (!_estadoCtrl.isClosed) _estadoCtrl.add(e);
  }

  /// ejecutarCmd no aplica a banexus-implicit — solo existía en el cliente SSH (eliminado).
  @override
  Future<String> ejecutarCmd(String cmd) =>
      Future.error(UnsupportedError('ejecutarCmd no aplica en banexus-implicit'));

  @override
  void dispose() {
    desconectar();
    _estadoCtrl.close();
  }
}
