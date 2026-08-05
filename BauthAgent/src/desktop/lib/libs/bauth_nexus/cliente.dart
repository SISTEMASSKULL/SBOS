// ============================================================
// bauth_nexus · libs/bauth_nexus/cliente.dart
//
// Propósito: cliente FFI de banexus.dll para Flutter desktop.
//   Carga banexus.dll (dart:ffi) y expone la misma interfaz que
//   usaba el cliente TCP — sin proceso separado, sin puerto local.
//
// Cadena: Flutter → banexus.dll (FFI) → bhnexus (TCP 9444) → bAuth.
//
// Las llamadas bloqueantes de Rust se ejecutan en Isolate.run()
// para no bloquear el hilo de UI de Flutter.
//
// Dependencias: dart:ffi, dart:isolate, dart:convert, package:ffi.
// Estándar: SBOS-NEXUS §24.3 · ADR-020 · DOC-SBOS-001 N3.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

// ─── Tipos nativos FFI ────────────────────────────────────────

typedef _InitNative   = Int32         Function(Pointer<Utf8>);
typedef _InitDart     = int           Function(Pointer<Utf8>);
typedef _LlamarNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _LlamarDart   = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _LiberarNative = Void         Function(Pointer<Utf8>);
typedef _LiberarDart   = void         Function(Pointer<Utf8>);
typedef _CerrarNative = Void          Function();
typedef _CerrarDart   = void          Function();

// ─── Enlace a banexus.dll ─────────────────────────────────────

DynamicLibrary? _dll;
_InitDart?    _fInit;
_LlamarDart?  _fLlamar;
_LiberarDart? _fLiberar;
_CerrarDart?  _fCerrar;

/// Carga banexus.dll y enlaza las funciones exportadas. Idempotente.
void _enlazar() {
  if (_dll != null) return;
  _dll      = DynamicLibrary.open('banexus.dll');
  _fInit    = _dll!.lookupFunction<_InitNative,    _InitDart>   ('banexus_init');
  _fLlamar  = _dll!.lookupFunction<_LlamarNative,  _LlamarDart> ('banexus_llamar');
  _fLiberar = _dll!.lookupFunction<_LiberarNative, _LiberarDart>('banexus_liberar');
  _fCerrar  = _dll!.lookupFunction<_CerrarNative,  _CerrarDart> ('banexus_cerrar');
}

// ─── Helpers C-string ────────────────────────────────────────

T _conPtr<T>(String s, T Function(Pointer<Utf8>) fn) {
  final p = s.toNativeUtf8();
  try { return fn(p); }
  finally { malloc.free(p); }
}

// ─── Error y estado público ───────────────────────────────────

/// Error retornado por banexus.dll (código + mensaje JSON-RPC 2.0).
class BanexusError implements Exception {
  final int    code;
  final String message;
  const BanexusError(this.code, this.message);
  @override
  String toString() => 'BanexusError($code): $message';
}

/// Estado de la conexión de la DLL.
enum EstadoBanexus { desconectado, conectando, conectado, error }

// ─── Cliente público ──────────────────────────────────────────

/// Cliente FFI a banexus.dll.
/// Misma interfaz que el cliente TCP anterior — los providers no cambian.
///
/// La DLL maneja: conexión a bhnexus, handshake, pool TCP y proxy JSON-RPC.
/// Flutter solo llama conectar() → llamar() → dispose().
class BanexusCliente {
  /// host:puerto del servidor bhnexus (Puerta 1).
  final String bhnexusAddr;

  final _estadoCtrl = StreamController<EstadoBanexus>.broadcast();
  EstadoBanexus _estado = EstadoBanexus.desconectado;

  BanexusCliente({
    String? host,
    int?    puerto,
    this.bhnexusAddr = '13.140.128.230:9444',
  });

  Stream<EstadoBanexus> get estadoStream => _estadoCtrl.stream;
  EstadoBanexus get estado => _estado;

  // ─── Conexión ───────────────────────────────────────────────

  /// Inicializa la DLL y conecta a bhnexus. Idempotente.
  Future<void> conectar() async {
    if (_estado == EstadoBanexus.conectado) return;
    _setEstado(EstadoBanexus.conectando);
    final addr = bhnexusAddr;
    try {
      await Isolate.run(() {
        _enlazar();
        final cfg = jsonEncode({'bhnexus_addr': addr, 'node_id': 'desktop-bauth', 'dev_mode': true});
        final code = _conPtr(cfg, (p) => _fInit!(p));
        if (code != 0) throw BanexusError(code, 'banexus_init falló: código $code');
      });
      _setEstado(EstadoBanexus.conectado);
    } catch (e) {
      _setEstado(EstadoBanexus.error);
      rethrow;
    }
  }

  void cerrar() {
    try { _enlazar(); _fCerrar!(); } catch (_) {}
    _setEstado(EstadoBanexus.desconectado);
  }

  // ─── JSON-RPC 2.0 ───────────────────────────────────────────

  /// Llama a [metodo] con [params] y retorna el campo `result`.
  /// Lanza [BanexusError] si la DLL retorna error JSON-RPC.
  Future<Map<String, dynamic>> llamar(String metodo, [Map<String, dynamic>? params]) async {
    if (_estado != EstadoBanexus.conectado) await conectar();
    final m = metodo;
    final p = jsonEncode(params ?? {});
    return Isolate.run(() {
      _enlazar();
      // Las llamadas FFI bloquean el hilo del Isolate, no la UI
      late final Pointer<Utf8> resp;
      _conPtr(m, (mp) => _conPtr(p, (pp) { resp = _fLlamar!(mp, pp); }));
      try {
        final mapa = jsonDecode(resp.toDartString()) as Map<String, dynamic>;
        if (mapa.containsKey('error')) {
          final e = mapa['error'] as Map;
          throw BanexusError(e['code'] as int? ?? -1, e['message']?.toString() ?? '');
        }
        return (mapa['result'] as Map<String, dynamic>?) ?? {};
      } finally {
        _fLiberar!(resp);
      }
    });
  }

  void _setEstado(EstadoBanexus e) { _estado = e; _estadoCtrl.add(e); }

  void dispose() { cerrar(); _estadoCtrl.close(); }
}
