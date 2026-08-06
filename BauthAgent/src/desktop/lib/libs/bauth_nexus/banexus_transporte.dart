// ============================================================
// bauth_desktop · libs/bauth_nexus/banexus_transporte.dart
//
// Propósito: banexus-implicit para Flutter/Dart con gestión de
//   conexión persistente al estándar de la industria.
//
// Mecanismos de resiliencia:
//   1. Heartbeat cada 30s: {"type":"heartbeat"} → espera pong
//   2. Watchdog 45s: si no llega pong → conexión declarada muerta
//   3. Reconexión automática con backoff exponencial: 500ms→1s→2s→...→30s
//   4. El ciclo es transparente para la app — solo llama a llamar()
//
// Patrón (WebSocket RFC 6455 / MQTT 5.0 / Socket.IO):
//   drop → backoff(500ms×2ⁿ, techo 30s) → TCP connect → handshake → listo
//
// Protocolo banexus-implicit (SSOT: 2.18_MANUAL-MOTOR-COMUNICACION v4.0):
//   TCP 9444 → {"type":"handshake",...} → handshake_ok
//              → rpc_call frames → rpc_response frames
//
// Dependencias: dart:io, dart:async, dart:convert, dart:math, rxdart.
// Estándar: ADR-020 · SBOS-NEXUS-CONCEPTUALIZACION §20 · 2.18 Motor de Comunicación.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:rxdart/rxdart.dart';

import '../../nucleo/conexion/cliente_rpc.dart';

/// Genera node_id UUID v4 único para esta sesión de banexus-implicit.
String _generarNodeId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // versión 4
  b[8] = (b[8] & 0x3f) | 0x80; // variante RFC 4122
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// banexus-implicit para Flutter/Dart — conexión persistente industrial.
///
/// La app solo invoca [llamar]. Todo lo demás (heartbeat, watchdog,
/// reconexión con backoff) es transparente y automático.
class BanexusTransporte implements IClienteRpc {
  // ── Config ────────────────────────────────────────────────────────────────
  final String _host;
  final int _puerto;
  final Duration _timeout;

  // ── Socket y handshake ────────────────────────────────────────────────────
  Socket? _socket;
  final StringBuffer _buffer = StringBuffer();
  int _seq = 0;
  bool _handshakeListo = false;
  Completer<void>? _handshakeCompleter;

  // ── Peticiones en vuelo (seq → Completer) ─────────────────────────────────
  final Map<int, Completer<Map<String, dynamic>>> _pendientes = {};

  // ── Reconexión automática ─────────────────────────────────────────────────
  bool _debeReconectar = false;
  int _intentos = 0;
  Timer? _reconectTimer;
  static const Duration _backoffBase = Duration(milliseconds: 500);
  static const Duration _backoffMax = Duration(seconds: 30);

  // ── Heartbeat + watchdog ──────────────────────────────────────────────────
  Timer? _heartbeatTimer;
  Timer? _pongWatchdog;
  static const Duration _heartbeatIntervalo = Duration(seconds: 30);
  static const Duration _pongTimeout = Duration(seconds: 45);

  // ── Estado observable ─────────────────────────────────────────────────────
  // BehaviorSubject: los nuevos suscriptores reciben el último valor emitido.
  // Necesario para que StreamProvider de Riverpod obtenga el estado actual
  // al suscribirse, sin esperar el próximo evento.
  final _estadoCtrl =
      BehaviorSubject<EstadoConexion>.seeded(EstadoConexion.desconectado);

  @override
  Stream<EstadoConexion> get estado => _estadoCtrl.stream;

  EstadoConexion get _estadoActual => _estadoCtrl.value;

  BanexusTransporte({
    String host = '13.140.128.230',
    int puerto = 9444,
    Duration timeout = const Duration(seconds: 15),
  })  : _host = host,
        _puerto = puerto,
        _timeout = timeout;

  // ══════════════════════════════════════════════════════════════════════════
  // API pública
  // ══════════════════════════════════════════════════════════════════════════

  /// Inicia la conexión y activa el ciclo de reconexión automática.
  @override
  Future<void> conectar() async {
    _debeReconectar = true;
    _intentos = 0;
    await _conectarInterno();
  }

  /// Cierra la conexión y desactiva la reconexión automática.
  @override
  void desconectar() {
    _debeReconectar = false;
    _intentos = 0;
    _detenerHeartbeat();
    _reconectTimer?.cancel();
    _reconectTimer = null;
    _rechazarPendientes('desconectado por el cliente');
    _socket?.destroy();
    _socket = null;
    _buffer.clear();
    _handshakeListo = false;
    _setEstado(EstadoConexion.desconectado);
  }

  /// Envuelve la llamada JSON-RPC en un frame rpc_call y espera rpc_response.
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
  // Conexión interna (también usada por el ciclo de reconexión)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _conectarInterno() async {
    if (_estadoActual == EstadoConexion.conectado ||
        _estadoActual == EstadoConexion.conectando) return;

    _setEstado(EstadoConexion.conectando);
    final nodeId = '${_generarNodeId()}-flutter';

    try {
      _socket = await Socket.connect(_host, _puerto).timeout(_timeout);
      _socket!.listen(_onDatos, onError: _onError, onDone: _onCierre);

      // Handshake Etapa 1 — dev_mode:true (sin JWT)
      _handshakeCompleter = Completer<void>();
      _enviarLinea({
        'type': 'handshake',
        'node_id': nodeId,
        'modo': 'proxy',
        'dev_mode': true,
      });

      await _handshakeCompleter!.future.timeout(_timeout);
      _handshakeListo = true;
      _intentos = 0; // reset backoff en conexión exitosa
      _setEstado(EstadoConexion.conectado);
      _iniciarHeartbeat();
    } catch (_) {
      _socket?.destroy();
      _socket = null;
      _handshakeListo = false;
      _setEstado(EstadoConexion.error);
      if (_debeReconectar) _programarReconexion();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Heartbeat + watchdog de pong (detección rápida de canal muerto)
  // ══════════════════════════════════════════════════════════════════════════

  void _iniciarHeartbeat() {
    _detenerHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatIntervalo, (_) {
      if (_estadoActual != EstadoConexion.conectado) return;
      _enviarLinea({'type': 'heartbeat'});
      // Watchdog: si no llega pong en _pongTimeout → canal muerto
      _pongWatchdog?.cancel();
      _pongWatchdog = Timer(_pongTimeout, _onCanalMuerto);
    });
  }

  void _detenerHeartbeat() {
    _heartbeatTimer?.cancel();
    _pongWatchdog?.cancel();
    _heartbeatTimer = null;
    _pongWatchdog = null;
  }

  /// Watchdog expiró — bhnexus no respondió el pong en 45s.
  void _onCanalMuerto() {
    _socket?.destroy();
    _socket = null;
    _handshakeListo = false;
    _detenerHeartbeat();
    _setEstado(EstadoConexion.error);
    if (_debeReconectar) _programarReconexion();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Backoff exponencial: 500ms → 1s → 2s → 4s → 8s → 16s → 30s → 30s…
  // ══════════════════════════════════════════════════════════════════════════

  void _programarReconexion() {
    _reconectTimer?.cancel();
    final exp = _intentos.clamp(0, 6); // 2⁶ = 64 → techo 30s
    final ms = _backoffBase.inMilliseconds * (1 << exp);
    final delay = Duration(milliseconds: ms.clamp(0, _backoffMax.inMilliseconds));
    _intentos++;
    _reconectTimer = Timer(delay, () async {
      if (_debeReconectar) await _conectarInterno();
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Procesamiento de mensajes entrantes (newline-delimited JSON)
  // ══════════════════════════════════════════════════════════════════════════

  void _onDatos(List<int> datos) {
    _buffer.write(utf8.decode(datos, allowMalformed: true));
    _extraerLineas();
  }

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
        // Pong recibido → canal vivo, cancelar watchdog
        _pongWatchdog?.cancel();
        _pongWatchdog = null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Manejo de caída del socket
  // ══════════════════════════════════════════════════════════════════════════

  void _onError(Object _) {
    _detenerHeartbeat();
    _rechazarPendientes('error de socket');
    _setEstado(EstadoConexion.error);
    if (_debeReconectar) _programarReconexion();
  }

  void _onCierre() {
    _socket = null;
    _handshakeListo = false;
    _detenerHeartbeat();
    if (_estadoActual == EstadoConexion.conectado ||
        _estadoActual == EstadoConexion.conectando) {
      _rechazarPendientes('conexión cerrada por bhnexus');
      _setEstado(EstadoConexion.desconectado);
      if (_debeReconectar) _programarReconexion();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Utilidades
  // ══════════════════════════════════════════════════════════════════════════

  void _enviarLinea(Map<String, dynamic> msg) {
    _socket?.add(utf8.encode('${jsonEncode(msg)}\n'));
  }

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
    if (!_estadoCtrl.isClosed) _estadoCtrl.add(e);
  }

  @override
  Future<String> ejecutarCmd(String cmd) =>
      Future.error(UnsupportedError('ejecutarCmd no aplica en banexus-implicit'));

  @override
  void dispose() {
    desconectar();
    _estadoCtrl.close();
  }
}
