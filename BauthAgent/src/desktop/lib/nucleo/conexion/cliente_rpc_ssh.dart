// ============================================================
// bauth_desktop · nucleo/conexion/cliente_rpc_ssh.dart
//
// Propósito: cliente JSON-RPC 2.0 persistente sobre SSH + socat.
//
//   PROTOCOLO CORRECTO (persistent channel):
//     1. conectar() abre UNA sesión SSH:
//          socat - UNIX-CONNECT:<socket>
//     2. llamar() escribe el JSON al stdin del canal — sin overhead SSH.
//     3. El canal vive mientras la sesión SSH esté activa.
//     4. Si el canal muere, reconectar() lo reabre.
//
//   LATENCIA resultante: RTT de red (~1-50 ms) en vez de
//   overhead de SSH exec por llamada (~300-2000 ms).
//
//   El canal acepta múltiples requests en vuelo simultáneamente
//   (multiplexado por JSON-RPC id) igual que ClienteRpc TCP.
//
// Dependencias: dart:async, dart:convert, dart:io, dartssh2, cliente_rpc.
// Estándar: JSON-RPC 2.0 · ADR-020 · DOC-SBOS-001 N3.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data' show BytesBuilder;

import 'package:dartssh2/dartssh2.dart';

import 'cliente_rpc.dart';

/// Cliente JSON-RPC 2.0 persistente sobre SSH + socat.
///
/// Abre una sola sesión SSH (`socat - UNIX-CONNECT:<socket>`) en [conectar] y
/// la reutiliza en todos los [llamar] posteriores. El canal stdin/stdout
/// actúa como un pipe directo al socket Unix del daemon bAuth, eliminando
/// el overhead de abrir una nueva sesión SSH por cada llamada.
///
/// Multiplexado: varios [llamar] pueden estar en vuelo a la vez; la
/// respuesta se despacha al Completer correcto usando el campo `id` de
/// JSON-RPC 2.0.
class ClienteRpcSsh implements IClienteRpc {
  final SSHClient _ssh;
  final String _socketRemoto;
  final Duration _timeout;

  // ── Canal persistente ─────────────────────────────────────────
  SSHSession? _canal;
  final StringBuffer _buf = StringBuffer();
  int _nextId = 1;

  // ── Requests en vuelo (id → Completer) ───────────────────────
  final Map<int, Completer<Map<String, dynamic>>> _pendientes = {};

  // ── Conexión concurrente: múltiples llamar() esperan el mismo conectar() ──
  Completer<void>? _conectandoCompleter;

  // ── Estado observable ─────────────────────────────────────────
  final _estadoCtrl = StreamController<EstadoConexion>.broadcast();
  EstadoConexion _estado = EstadoConexion.desconectado;

  @override
  Stream<EstadoConexion> get estado => _estadoCtrl.stream;

  ClienteRpcSsh(
    this._ssh,
    this._socketRemoto, {
    Duration timeout = const Duration(seconds: 15),
  }) : _timeout = timeout;

  // ═══════════════════════════════════════════════════════════
  // Conexión
  // ═══════════════════════════════════════════════════════════

  /// Abre el canal socat persistente. No-op si ya está conectado.
  ///
  /// Si múltiples llamar() llegan antes de que el canal esté listo,
  /// todos esperan el mismo Future de conexión — sin abrir canales duplicados.
  @override
  Future<void> conectar() async {
    if (_estado == EstadoConexion.conectado) return;

    // Si ya hay una conexión en curso, esperar a que termine (sin race condition).
    if (_conectandoCompleter != null) {
      return _conectandoCompleter!.future;
    }

    _conectandoCompleter = Completer<void>();
    _setEstado(EstadoConexion.conectando);
    try {
      _canal = await _ssh.execute('socat - UNIX-CONNECT:$_socketRemoto');
      _canal!.stdout.listen(
        _onDatos,
        onDone: _onCierre,
        onError: _onError,
        cancelOnError: false,
      );
      _setEstado(EstadoConexion.conectado);
      _conectandoCompleter!.complete();
    } catch (e) {
      _setEstado(EstadoConexion.error);
      _conectandoCompleter!.completeError(e);
      rethrow;
    } finally {
      _conectandoCompleter = null;
    }
  }

  /// Cierra el canal socat y rechaza requests pendientes.
  @override
  void desconectar() {
    try { _canal?.close(); } catch (_) {}
    _canal = null;
    _buf.clear();
    _rechazarPendientes('desconectado por el cliente');
    _setEstado(EstadoConexion.desconectado);
  }

  // ═══════════════════════════════════════════════════════════
  // JSON-RPC
  // ═══════════════════════════════════════════════════════════

  /// Envía un request JSON-RPC al canal persistente y aguarda la respuesta.
  ///
  /// Puede haber múltiples llamadas en vuelo a la vez — cada una se
  /// identifica por su `id` y se despacha individualmente al completarse.
  @override
  Future<Map<String, dynamic>> llamar(
    String metodo, [
    Map<String, dynamic>? params,
  ]) async {
    if (_estado != EstadoConexion.conectado) await conectar();
    if (_canal == null) {
      throw RpcError(-32000, 'canal SSH no disponible — verifica la conexión');
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

    // Escritura directa al stdin del canal socat — sin overhead SSH
    _canal!.stdin.add(utf8.encode('${jsonEncode(msg)}\n'));

    return completer.future.timeout(_timeout).whenComplete(() {
      _pendientes.remove(id);
    });
  }

  // ═══════════════════════════════════════════════════════════
  // Parser de respuestas (misma lógica que ClienteRpc TCP)
  // ═══════════════════════════════════════════════════════════

  void _onDatos(List<int> datos) {
    _buf.write(utf8.decode(datos, allowMalformed: true));
    _extraerMensajes();
  }

  /// Extrae objetos JSON completos del buffer por conteo de llaves.
  /// Robusto ante fragmentación de paquetes TCP/SSH.
  void _extraerMensajes() {
    final s = _buf.toString();
    int nivel = 0;
    int inicio = 0;
    bool enCadena = false;
    bool escapeNext = false;

    for (int i = 0; i < s.length; i++) {
      final c = s[i];
      if (escapeNext) { escapeNext = false; continue; }
      if (c == '\\' && enCadena) { escapeNext = true; continue; }
      if (c == '"') { enCadena = !enCadena; continue; }
      if (enCadena) continue;

      if (c == '{') {
        nivel++;
      } else if (c == '}') {
        nivel--;
        if (nivel == 0) {
          try {
            _procesarRespuesta(
                jsonDecode(s.substring(inicio, i + 1)) as Map<String, dynamic>);
          } catch (_) {}
          inicio = i + 1;
        }
      }
    }

    _buf.clear();
    if (inicio < s.length) _buf.write(s.substring(inicio));
  }

  void _procesarRespuesta(Map<String, dynamic> resp) {
    final id = resp['id'] as int?;
    if (id == null || !_pendientes.containsKey(id)) return;

    final error = resp['error'];
    if (error is Map) {
      _pendientes[id]!.completeError(RpcError(
        error['code'] as int? ?? -1,
        error['message']?.toString() ?? 'error RPC desconocido',
        error['data'],
      ));
    } else {
      _pendientes[id]!.complete(
        (resp['result'] as Map<String, dynamic>?) ?? const {},
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Eventos del canal
  // ═══════════════════════════════════════════════════════════

  void _onCierre() {
    _canal = null;
    _buf.clear();
    _rechazarPendientes('canal SSH cerrado inesperadamente');
    _setEstado(EstadoConexion.desconectado);
  }

  void _onError(Object err) {
    _rechazarPendientes(err.toString());
    _setEstado(EstadoConexion.error);
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

  // ═══════════════════════════════════════════════════════════
  // Comandos de shell (exec separado — no usa el canal socat)
  // ═══════════════════════════════════════════════════════════

  /// Ejecuta un comando de shell arbitrario en el servidor.
  /// Abre una sesión SSH separada para no interferir con el canal socat.
  @override
  /// Ejecuta un comando remoto y retorna stdout completo.
  /// Lanza [TimeoutException] si el comando no responde en [_timeout].
  Future<String> ejecutarCmd(String cmd) async {
    final session = await _ssh.execute(cmd);
    final b = BytesBuilder();
    try {
      await Future.wait([
        session.stdout.forEach(b.add),
        session.stderr.drain<void>(),
      ]).timeout(_timeout, onTimeout: () {
        session.close();
        throw TimeoutException(
          'Comando SSH superó ${_timeout.inSeconds}s sin respuesta',
        );
      });
    } finally {
      try { session.close(); } catch (_) {}
    }
    return utf8.decode(b.toBytes(), allowMalformed: true).trim();
  }

  @override
  void dispose() {
    desconectar();
    _estadoCtrl.close();
  }
}
