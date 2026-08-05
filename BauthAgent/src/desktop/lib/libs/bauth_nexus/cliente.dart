// ============================================================
// bauth_nexus · libs/bauth_nexus/cliente.dart
//
// Librería agnóstica — solo dart:ffi / dart:io / dart:async / dart:convert.
// No depende de Flutter, Riverpod ni ningún framework de UI.
//
// Propósito: cliente JSON-RPC 2.0 que llama a banexus.dll via dart:ffi.
//   No hay proceso separado ni puerto TCP local: la DLL se carga en el
//   mismo proceso Flutter y se comunica con bhnexus directamente.
//
// La DLL (banexus.dll / libbanexus.so) debe estar en el mismo directorio
// que el ejecutable del desktop. Flutter la encuentra automáticamente.
//
// Uso:
//   final c = BanexusCliente(bhnexusAddr: '13.140.128.230:9444');
//   await c.conectar();
//   final resp = await c.llamar('bauth.health.check', {});
//   c.dispose();
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

// ─── Tipos FFI ───────────────────────────────────────────────

typedef _InitNative  = Int32 Function(Pointer<Utf8>);
typedef _InitDart    = int   Function(Pointer<Utf8>);

typedef _LlamarNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _LlamarDart   = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef _LiberarNative = Void Function(Pointer<Utf8>);
typedef _LiberarDart   = void Function(Pointer<Utf8>);

// ─── Clases públicas ─────────────────────────────────────────

/// Error retornado por la DLL banexus (campo 'error' en JSON-RPC 2.0).
class BanexusError implements Exception {
  final int code;
  final String message;
  const BanexusError(this.code, this.message);
  @override
  String toString() => 'BanexusError($code): $message';
}

/// Estados de la conexión (mapeados desde banexus_estado()).
enum EstadoBanexus { desconectado, conectando, conectado, error }

/// Cliente JSON-RPC 2.0 via DLL banexus (dart:ffi).
///
/// Carga banexus.dll del mismo directorio del ejecutable y llama
/// a sus funciones C exportadas. La DLL mantiene la conexión TCP
/// persistente a bhnexus — este cliente solo encapsula las llamadas FFI.
class BanexusCliente {
  final String bhnexusAddr;
  final String nodeId;
  final bool devMode;
  final Duration timeout;

  /// host/puerto se ignoran en el cliente FFI — son para compatibilidad
  /// con la interfaz anterior (daemon TCP).
  // ignore: unused_field
  final String host;
  // ignore: unused_field
  final int puerto;

  EstadoBanexus _estado = EstadoBanexus.desconectado;
  final _estadoCtrl = StreamController<EstadoBanexus>.broadcast();

  /// Stream de cambios de estado.
  Stream<EstadoBanexus> get estadoStream => _estadoCtrl.stream;

  /// Estado actual.
  EstadoBanexus get estado => _estado;

  BanexusCliente({
    this.bhnexusAddr = '13.140.128.230:9444',
    this.nodeId = 'desktop-001',
    this.devMode = true,
    this.timeout = const Duration(seconds: 30),
    this.host = '127.0.0.1',
    this.puerto = 9446,
  });

  // ─── Conexión ─────────────────────────────────────────────

  /// Carga la DLL e inicializa la conexión a bhnexus.
  /// Bloquea ~100-500 ms durante el handshake (en un isolate separado).
  Future<void> conectar() async {
    if (_estado == EstadoBanexus.conectado) return;
    _setEstado(EstadoBanexus.conectando);

    final addr   = bhnexusAddr;
    final nid    = nodeId;
    final dev    = devMode;
    final dll    = _nombreDll();

    try {
      final code = await Isolate.run(() => _initDll(dll, addr, nid, dev));
      if (code == 0) {
        _setEstado(EstadoBanexus.conectado);
      } else {
        _setEstado(EstadoBanexus.error);
        throw BanexusError(code, 'banexus_init falló (código $code)');
      }
    } catch (e) {
      _setEstado(EstadoBanexus.error);
      rethrow;
    }
  }

  /// Cierra la conexión (no descarga la DLL — el proceso la retiene).
  void cerrar() {
    _setEstado(EstadoBanexus.desconectado);
  }

  // ─── JSON-RPC 2.0 ─────────────────────────────────────────

  /// Llama a [metodo] con [params] opcionales.
  /// La llamada FFI bloquea en un isolate secundario — no congela la UI.
  /// Lanza [BanexusError] si la DLL retorna un error JSON-RPC.
  Future<Map<String, dynamic>> llamar(
    String metodo, [
    Map<String, dynamic>? params,
  ]) async {
    if (_estado != EstadoBanexus.conectado) await conectar();

    final dll    = _nombreDll();
    final m      = metodo;
    final p      = jsonEncode(params ?? {});

    final respJson = await Isolate.run(
      () => _llamarDll(dll, m, p),
    ).timeout(timeout, onTimeout: () =>
        jsonEncode({'jsonrpc':'2.0','error':{'code':-32001,'message':'timeout'},'id':null}));

    final resp = jsonDecode(respJson) as Map<String, dynamic>;
    final error = resp['error'];
    if (error is Map) {
      throw BanexusError(
        error['code'] as int? ?? -1,
        error['message']?.toString() ?? 'error desconocido',
      );
    }
    return (resp['result'] as Map<String, dynamic>?) ?? const {};
  }

  // ─── Compatibilidad IClienteRpc ───────────────────────────

  void desconectar() => cerrar();

  void dispose() {
    cerrar();
    _estadoCtrl.close();
  }

  // ─── Internos ─────────────────────────────────────────────

  void _setEstado(EstadoBanexus e) {
    _estado = e;
    _estadoCtrl.add(e);
  }

  /// Nombre de la DLL según la plataforma.
  static String _nombreDll() {
    if (Platform.isWindows) return 'banexus.dll';
    if (Platform.isMacOS)   return 'libbanexus.dylib';
    return 'libbanexus.so';
  }
}

// ─── Funciones top-level (ejecutadas en isolates) ────────────

/// Carga la DLL y llama a banexus_init.
/// Ejecutado en un isolate secundario — no bloquea la UI.
int _initDll(String dll, String bhnexusAddr, String nodeId, bool devMode) {
  final lib = DynamicLibrary.open(dll);
  final fn  = lib.lookupFunction<_InitNative, _InitDart>('banexus_init');

  final config = jsonEncode({
    'bhnexus_addr': bhnexusAddr,
    'node_id':      nodeId,
    'dev_mode':     devMode,
  });
  final ptr = config.toNativeUtf8();
  try {
    return fn(ptr.cast());
  } finally {
    calloc.free(ptr);
  }
}

/// Carga la DLL y llama a banexus_llamar.
/// Ejecutado en un isolate secundario — no bloquea la UI.
String _llamarDll(String dll, String metodo, String paramsJson) {
  final lib     = DynamicLibrary.open(dll);
  final llamar  = lib.lookupFunction<_LlamarNative,  _LlamarDart> ('banexus_llamar');
  final liberar = lib.lookupFunction<_LiberarNative, _LiberarDart>('banexus_liberar');

  final mPtr = metodo.toNativeUtf8();
  final pPtr = paramsJson.toNativeUtf8();
  try {
    final respPtr = llamar(mPtr.cast(), pPtr.cast());
    if (respPtr == nullptr) {
      return jsonEncode({'jsonrpc':'2.0','error':{'code':-32000,'message':'DLL retornó null'},'id':null});
    }
    final respStr = respPtr.cast<Utf8>().toDartString();
    liberar(respPtr.cast());
    return respStr;
  } finally {
    calloc.free(mPtr);
    calloc.free(pPtr);
  }
}
