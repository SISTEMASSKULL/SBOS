// ============================================================
// bauth_desktop · nucleo/conexion/proveedor_conexion.dart
//
// Propósito: Riverpod providers que gestionan el ciclo de vida
//   de la conexión a bAuth: config → ClienteRpc → BauthApi.
//   La UI observa el estado y se actualiza automáticamente.
//
//   Modos de conexión:
//     SSH exec   — clienteRpcSshProvider != null: cada RPC usa SSH exec.
//     TCP directo — fallback: ClienteRpc con host:puerto convencional.
//
// Dependencias: flutter_riverpod, cliente_rpc, cliente_rpc_ssh,
//               config_conexion, bauth_api.
// Estándar: JSON-RPC 2.0 · Riverpod 3.x · DOC-SBOS-001 N3.
// ============================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cliente_rpc.dart';
import 'cliente_rpc_ssh.dart';
import 'config_conexion.dart';
import '../api/bauth_api.dart';

// ═══════════════════════════════════════════════════════════
// Modo SSH exec (prioridad sobre TCP cuando está activo)
// ═══════════════════════════════════════════════════════════

/// Notifier que sostiene el cliente SSH exec activo.
class ClienteRpcSshNotifier extends Notifier<ClienteRpcSsh?> {
  @override
  ClienteRpcSsh? build() => null;

  /// Establece o limpia el cliente SSH exec activo.
  void establecer(ClienteRpcSsh? cliente) => state = cliente;
}

/// Cliente SSH exec activo, o null si se usa modo TCP.
/// Se establece desde PanelConexion tras autenticar SSH con éxito.
final clienteRpcSshProvider =
    NotifierProvider<ClienteRpcSshNotifier, ClienteRpcSsh?>(
        ClienteRpcSshNotifier.new);

// ═══════════════════════════════════════════════════════════
// Cliente RPC activo (SSH exec o TCP, según disponibilidad)
// ═══════════════════════════════════════════════════════════

/// Provee el mejor cliente RPC disponible:
///   1. ClienteRpcSsh si el modo SSH está activo.
///   2. ClienteRpc TCP si el modo directo está configurado.
final clienteRpcActivoProvider = Provider<IClienteRpc>((ref) {
  final ssh = ref.watch(clienteRpcSshProvider);
  if (ssh != null) return ssh;
  return ref.watch(clienteRpcProvider);
});

// ═══════════════════════════════════════════════════════════
// Cliente TCP (singleton gestionado por provider)
// ═══════════════════════════════════════════════════════════

/// Provider del cliente JSON-RPC TCP. Se crea al leer la config
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

/// Stream del estado de conexión del cliente TCP.
final estadoConexionProvider = StreamProvider<EstadoConexion>((ref) {
  final cliente = ref.watch(clienteRpcProvider);
  return cliente.estado;
});

/// Provider que controla la conexión TCP: conectar/desconectar.
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

/// Árbol completo de entidades (idn_identidad_entidad — 5 niveles).
/// Raíz: tenants → bdomain → bsubdomain → pos → actor.
final arbolEntidadesProvider = FutureProvider<List<EntidadInfo>>((ref) async {
  final api = ref.watch(bauthApiProvider);
  return api.arbolEntidades();
});
