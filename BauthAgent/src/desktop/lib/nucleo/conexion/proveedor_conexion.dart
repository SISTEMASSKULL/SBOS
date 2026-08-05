// ============================================================
// bauth_desktop · nucleo/conexion/proveedor_conexion.dart
//
// Propósito: Riverpod providers que gestionan el ciclo de vida
//   de la conexión a bAuth: config → ClienteRpcBanexus → BauthApi.
//   La UI observa el estado y se actualiza automáticamente.
//
//   Transporte único: DLL banexus (dart:ffi).
//     Flutter → banexus.dll → bhnexus Puerta 1 → bAuth Unix socket.
//     No existe modo SSH ni proceso externo (ADR-020, SBOS-NEXUS §24.3).
//
// Dependencias: flutter_riverpod, cliente_rpc_banexus, config_conexion, bauth_api.
// Estándar: JSON-RPC 2.0 · Riverpod 3.x · ADR-020 · DOC-SBOS-001 N3.
// ============================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cliente_rpc.dart';
import 'cliente_rpc_banexus.dart';
import 'config_conexion.dart';
import '../api/bauth_api.dart';
import '../dominio/config_tipo_nodo.dart';

// ═══════════════════════════════════════════════════════════
// Transporte único: banexus local API
// ═══════════════════════════════════════════════════════════

/// Provider del cliente JSON-RPC via DLL banexus (FFI).
/// Transporte canónico: Flutter → banexus.dll → bhnexus → bAuth.
final clienteRpcBanexusProvider = Provider<ClienteRpcBanexus>((ref) {
  final cfg    = ref.watch(configConexionProvider);
  final addr   = '${cfg.banexusHost}:${cfg.banexusPuerto}';
  final cliente = ClienteRpcBanexus(bhnexusAddr: addr);
  ref.onDispose(() => cliente.dispose());
  return cliente;
});

// ═══════════════════════════════════════════════════════════
// Cliente RPC activo — siempre banexus
// ═══════════════════════════════════════════════════════════

/// Provee el cliente RPC activo: siempre banexus local API.
final clienteRpcActivoProvider = Provider<IClienteRpc>((ref) {
  return ref.watch(clienteRpcBanexusProvider);
});

// ═══════════════════════════════════════════════════════════
// Estado de conexión (observable desde la UI)
// ═══════════════════════════════════════════════════════════

/// Stream del estado de conexión — sigue a banexus local API.
final estadoConexionProvider = StreamProvider<EstadoConexion>((ref) {
  final cliente = ref.watch(clienteRpcBanexusProvider);
  return cliente.estado;
});

/// Provider que controla la conexión banexus: conectar/desconectar.
final controlConexionProvider = Provider<ControlConexion>((ref) {
  final cliente = ref.watch(clienteRpcBanexusProvider);
  return ControlConexion(cliente);
});

class ControlConexion {
  final IClienteRpc _cliente;
  ControlConexion(this._cliente);

  Future<void> conectar() => _cliente.conectar();
  void desconectar() => _cliente.desconectar();
}

// ═══════════════════════════════════════════════════════════
// API tipada (wrapper sobre el cliente activo)
// ═══════════════════════════════════════════════════════════

/// BauthApi usa el cliente activo (siempre banexus).
final bauthApiProvider = Provider<BauthApi>((ref) {
  final cliente = ref.watch(clienteRpcActivoProvider);
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

/// Inicialización de la DLL banexus y conexión al arrancar la app.
/// El usuario solo ejecuta el .exe — la DLL se carga automáticamente.
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

/// Árbol completo de entidades (idn_identity_entity — 5 niveles).
/// Raíz: tenants → bdomain → bsubdomain → pos → actor.
final arbolEntidadesProvider = FutureProvider<List<EntidadInfo>>((ref) async {
  final api = ref.watch(bauthApiProvider);
  return api.arbolEntidades();
});

/// Catálogo de tipos de nodo desde bauth.idn_policy_node_type.
/// Cargado una vez al conectar. Provee `Map<codigo, ConfigTipoNodo>`.
/// Los widgets leen de aquí — cero switch de presentación por tipo en la UI.
final catalogoTiposProvider = FutureProvider<Map<String, ConfigTipoNodo>>((ref) async {
  final api = ref.watch(bauthApiProvider);
  return api.cargarCatalogoTipos();
});

/// Métricas operacionales del daemon bAuth — se refresca cada 30 s.
/// Consume bauth.sync.status (7 COUNTs en paralelo, < 5 ms).
final syncStatusProvider = FutureProvider.autoDispose<SyncStatusInfo>((ref) async {
  ref.keepAlive();
  final api = ref.watch(bauthApiProvider);
  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    // ignore: invalid_use_of_visible_for_testing_member
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  return api.syncStatus();
});
