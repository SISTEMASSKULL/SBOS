// ============================================================
// bauth_desktop · nucleo/conexion/proveedor_conexion.dart
//
// Propósito: Riverpod providers que gestionan el ciclo de vida
//   de la conexión a bAuth: config → ClienteRpc → BauthApi.
//   La UI observa el estado y se actualiza automáticamente.
//
//   Transporte primario:
//     banexus local API (127.0.0.1:9446) — TCP sin SSH.
//     Flutter → banexus → bhnexus Puerta 1 → bAuth socket.
//
//   Transporte secundario (solo si banexus no responde):
//     SSH exec — ClienteRpcSsh, activado desde PanelConexion.
//
// Dependencias: flutter_riverpod, cliente_rpc_banexus, cliente_rpc_ssh,
//               config_conexion, bauth_api.
// Estándar: JSON-RPC 2.0 · Riverpod 3.x · ADR-020 · DOC-SBOS-001 N3.
// ============================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cliente_rpc.dart';
import 'cliente_rpc_banexus.dart';
import 'cliente_rpc_ssh.dart';
import 'config_conexion.dart';
import '../api/bauth_api.dart';
import '../dominio/config_tipo_nodo.dart';

// ═══════════════════════════════════════════════════════════
// Transporte primario: banexus local API
// ═══════════════════════════════════════════════════════════

/// Provider del cliente JSON-RPC via banexus local API.
/// Transporte canónico: Flutter → banexus → bhnexus → bAuth.
final clienteRpcBanexusProvider = Provider<ClienteRpcBanexus>((ref) {
  final cliente = ClienteRpcBanexus();
  ref.onDispose(() => cliente.dispose());
  return cliente;
});

// ═══════════════════════════════════════════════════════════
// Transporte secundario: SSH exec (fallback manual)
// ═══════════════════════════════════════════════════════════

/// Notifier que sostiene el cliente SSH exec activo (fallback).
class ClienteRpcSshNotifier extends Notifier<ClienteRpcSsh?> {
  @override
  ClienteRpcSsh? build() => null;

  /// Establece o limpia el cliente SSH exec activo.
  void establecer(ClienteRpcSsh? cliente) => state = cliente;
}

/// Cliente SSH exec activo, o null si se usa banexus.
/// Se establece desde PanelConexion si banexus no está disponible.
final clienteRpcSshProvider =
    NotifierProvider<ClienteRpcSshNotifier, ClienteRpcSsh?>(
        ClienteRpcSshNotifier.new);

// ═══════════════════════════════════════════════════════════
// Cliente RPC activo (banexus primario, SSH fallback)
// ═══════════════════════════════════════════════════════════

/// Provee el cliente RPC activo:
///   1. ClienteRpcSsh si el fallback SSH está explícitamente activo.
///   2. ClienteRpcBanexus (banexus local API) — transporte por defecto.
final clienteRpcActivoProvider = Provider<IClienteRpc>((ref) {
  final ssh = ref.watch(clienteRpcSshProvider);
  if (ssh != null) return ssh;
  return ref.watch(clienteRpcBanexusProvider);
});

// ═══════════════════════════════════════════════════════════
// Cliente TCP legacy (mantenido para compatibilidad de providers)
// ═══════════════════════════════════════════════════════════

/// Provider del cliente JSON-RPC TCP directo.
/// En producción usar clienteRpcBanexusProvider — este es para pruebas.
final clienteRpcProvider = Provider<ClienteRpc>((ref) {
  final cfg = ref.watch(configConexionProvider);
  final cliente = ClienteRpc(host: cfg.host, puerto: cfg.puerto);
  ref.onDispose(() => cliente.dispose());
  return cliente;
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

/// BauthApi usa el cliente activo: SSH exec si disponible, TCP si no.
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

/// Auto-conexión TCP: conecta al iniciar la app (no-op en modo SSH).
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
