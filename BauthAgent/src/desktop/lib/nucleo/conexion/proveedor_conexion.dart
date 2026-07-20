// ============================================================
// bauth_desktop · nucleo/conexion/proveedor_conexion.dart
//
// Propósito: Riverpod providers que gestionan el ciclo de vida
//   de la conexión a bAuth: config → ClienteRpc → BauthApi.
//   La UI observa el estado y se actualiza automáticamente.
//
// Dependencias: flutter_riverpod, cliente_rpc, config_conexion, bauth_api.
// Estándar: JSON-RPC 2.0 · Riverpod 3.x · DOC-SBOS-001 N3.
// ============================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cliente_rpc.dart';
import 'config_conexion.dart';
import '../api/bauth_api.dart';

// ═══════════════════════════════════════════════════════════
// Cliente RPC (singleton gestionado por provider)
// ═══════════════════════════════════════════════════════════

/// Provider del cliente JSON-RPC. Se crea al leer la config
/// y persiste durante toda la vida de la app.
final clienteRpcProvider = Provider<ClienteRpc>((ref) {
  final cfg = ref.watch(configConexionProvider);
  final cliente = ClienteRpc(host: cfg.host, puerto: cfg.puerto);
  ref.onDispose(() => cliente.dispose());
  return cliente;
});

// ═══════════════════════════════════════════════════════════
// Estado de conexión (observable desde la UI)
// ═══════════════════════════════════════════════════════════

/// Stream del estado de conexión. La UI usa `ref.watch` para
/// mostrar el indicador ✅/🟡/🔴 en la barra de estado.
final estadoConexionProvider = StreamProvider<EstadoConexion>((ref) {
  final cliente = ref.watch(clienteRpcProvider);
  return cliente.estado;
});

/// Provider que controla la conexión: conectar/desconectar.
final controlConexionProvider = Provider<ControlConexion>((ref) {
  final cliente = ref.watch(clienteRpcProvider);
  return ControlConexion(cliente);
});

class ControlConexion {
  final ClienteRpc _cliente;
  ControlConexion(this._cliente);

  Future<void> conectar() => _cliente.conectar();
  void desconectar() => _cliente.desconectar();
}

// ═══════════════════════════════════════════════════════════
// API tipada (wrapper sobre ClienteRpc)
// ═══════════════════════════════════════════════════════════

final bauthApiProvider = Provider<BauthApi>((ref) {
  final cliente = ref.watch(clienteRpcProvider);
  return BauthApi(cliente);
});

// ═══════════════════════════════════════════════════════════
// Datos reales desde bAuth (providers Future)
// ═══════════════════════════════════════════════════════════

/// Health check — se refresca cada 30s.
final healthProvider = FutureProvider<HealthInfo>((ref) async {
  final api = ref.watch(bauthApiProvider);
  return api.healthCheck();
});

/// Lista de roles activos.
final rolesProvider = FutureProvider<List<RolInfo>>((ref) async {
  final api = ref.watch(bauthApiProvider);
  return api.listarRoles();
});

/// Lista de role templates.
final templatesProvider = FutureProvider<List<RolTemplate>>((ref) async {
  final api = ref.watch(bauthApiProvider);
  return api.listarTemplates();
});

/// Auto-conexión: conecta al iniciar la app.
final autoConexionProvider = FutureProvider<void>((ref) async {
  final control = ref.watch(controlConexionProvider);
  await control.conectar();
});

/// Lista de usuarios (recargable).
final usuariosProvider = FutureProvider.family<List<UsuarioInfo>, String>(
  (ref, busqueda) async {
    final api = ref.watch(bauthApiProvider);
    return api.listarUsuarios(busqueda: busqueda.isEmpty ? null : busqueda);
  },
);

/// Árbol completo de entidades (idn_identidad_entidad — 5 niveles).
/// Raíz: tenants → bdomain → bsubdomain → pos → actor.
final arbolEntidadesProvider = FutureProvider<List<EntidadInfo>>((ref) async {
  final api = ref.watch(bauthApiProvider);
  return api.arbolEntidades();
});
