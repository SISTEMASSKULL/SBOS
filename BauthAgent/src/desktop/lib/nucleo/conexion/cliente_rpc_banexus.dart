// ============================================================
// bauth_desktop · nucleo/conexion/cliente_rpc_banexus.dart
//
// Propósito: adaptador IClienteRpc → BanexusCliente (libs/bauth_nexus/).
//   El protocolo de transporte es implementado por el binario banexus (Rust).
//   Este archivo no implementa ninguna lógica de transporte — solo adapta
//   la interfaz IClienteRpc al cliente TCP de la librería bauth_nexus.
//
// Dependencias: cliente_rpc (IClienteRpc), libs/bauth_nexus/cliente.dart.
// Estándar: JSON-RPC 2.0 · ADR-020 · SBOS-NEXUS-CONCEPTUALIZACION-v3_0 §24.3.
// ============================================================

import 'dart:async';

import '../../libs/bauth_nexus/cliente.dart';
import 'cliente_rpc.dart';

/// Adaptador IClienteRpc que delega al binario banexus (proceso Rust).
///
/// Toda la lógica de transporte (TCP a bhnexus, handshake, proxy a bAuth)
/// reside en el binario banexus. Este adaptador solo convierte BanexusCliente
/// al contrato IClienteRpc que el resto de la app utiliza.
class ClienteRpcBanexus implements IClienteRpc {
  final BanexusCliente _banexus;

  ClienteRpcBanexus({String host = '127.0.0.1', int puerto = 9446})
      : _banexus = BanexusCliente(host: host, puerto: puerto);

  @override
  Stream<EstadoConexion> get estado => _banexus.estadoStream.map(_mapearEstado);

  @override
  Future<void> conectar() => _banexus.conectar();

  @override
  void desconectar() => _banexus.cerrar();

  @override
  Future<Map<String, dynamic>> llamar(
    String metodo, [
    Map<String, dynamic>? params,
  ]) async {
    try {
      return await _banexus.llamar(metodo, params);
    } on BanexusError catch (e) {
      throw RpcError(e.code, e.message);
    }
  }

  /// No soportado en modo banexus — el shell es propio del servidor.
  @override
  Future<String> ejecutarCmd(String cmd) async {
    throw UnsupportedError(
        'ejecutarCmd no disponible vía banexus — usar CLI del servidor directamente');
  }

  @override
  void dispose() => _banexus.dispose();

  EstadoConexion _mapearEstado(EstadoBanexus s) {
    switch (s) {
      case EstadoBanexus.conectado:    return EstadoConexion.conectado;
      case EstadoBanexus.conectando:   return EstadoConexion.conectando;
      case EstadoBanexus.error:        return EstadoConexion.error;
      case EstadoBanexus.desconectado: return EstadoConexion.desconectado;
    }
  }
}
