// ============================================================
// bauth_desktop · nucleo/conexion/proveedor_conexion.dart
//
// Propósito: providers Riverpod para el ciclo de vida de conexión a bAuth.
//   Transporte único: BanexusTransporte (dart:io Socket → bhnexus:9444).
//   Cadena canónica: Flutter → BanexusTransporte → bhnexus:9444 → bAuth socket.
//   Sin SSH. Sin DLL. Sin TCP directo a bAuth.
//
// Dependencias: flutter_riverpod, banexus_transporte, bauth_api.
// Estándar: JSON-RPC 2.0 · Riverpod 3.x · ADR-020 · 2.18 Motor de Comunicación.
// ============================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cliente_rpc.dart';
import '../../libs/bauth_nexus/banexus_transporte.dart';
import '../api/bauth_api.dart';
import '../dominio/config_tipo_nodo.dart';

// ═══════════════════════════════════════════════════════════
// Transporte: banexus-implicit (único — cadena canónica)
// ═══════════════════════════════════════════════════════════

/// Transporte banexus-implicit — el único canal permitido para el desktop.
/// Flutter → BanexusTransporte → bhnexus:9444 → bAuth.
final banexusTransporteProvider = Provider<BanexusTransporte>((ref) {
  final t = BanexusTransporte(host: '13.140.128.230', puerto: 9444);
  ref.onDispose(() => t.dispose());
  return t;
});

/// IClienteRpc activo — siempre BanexusTransporte en la cadena canónica.
final clienteRpcActivoProvider = Provider<IClienteRpc>((ref) {
  return ref.watch(banexusTransporteProvider);
});

// ═══════════════════════════════════════════════════════════
// Estado de conexión (observable desde la UI)
// ═══════════════════════════════════════════════════════════

/// Stream del estado de conexión TCP banexus.
final estadoConexionProvider = StreamProvider<EstadoConexion>((ref) {
  return ref.watch(banexusTransporteProvider).estado;
});

/// Control de conexión: conectar/desconectar desde la UI.
final controlConexionProvider = Provider<ControlConexion>((ref) {
  return ControlConexion(ref.watch(banexusTransporteProvider));
});

class ControlConexion {
  final IClienteRpc _cliente;
  ControlConexion(this._cliente);
  Future<void> conectar() => _cliente.conectar();
  void desconectar() => _cliente.desconectar();
}

// ═══════════════════════════════════════════════════════════
// API tipada y providers de datos
// ═══════════════════════════════════════════════════════════

/// BauthApi usa el cliente activo — siempre BanexusTransporte.
final bauthApiProvider = Provider<BauthApi>((ref) {
  return BauthApi(ref.watch(clienteRpcActivoProvider));
});

/// Health check del daemon bAuth.
final healthProvider = FutureProvider<HealthInfo>((ref) async {
  return ref.watch(bauthApiProvider).healthCheck();
});

/// Lista de roles activos.
final rolesProvider = FutureProvider<List<RolInfo>>((ref) async {
  return ref.watch(bauthApiProvider).listarRoles();
});

/// Lista de role templates.
final templatesProvider = FutureProvider<List<RolTemplate>>((ref) async {
  return ref.watch(bauthApiProvider).listarTemplates();
});

/// Auto-conexión al iniciar la app: llama conectar() en BanexusTransporte.
final autoConexionProvider = FutureProvider<void>((ref) async {
  await ref.watch(controlConexionProvider).conectar();
});

/// Lista de usuarios con filtro de búsqueda.
final usuariosProvider = FutureProvider.family<List<UsuarioInfo>, String>(
  (ref, busqueda) async {
    return ref.watch(bauthApiProvider).listarUsuarios(
      busqueda: busqueda.isEmpty ? null : busqueda,
    );
  },
);

/// Árbol completo de entidades organizacionales.
final arbolEntidadesProvider = FutureProvider<List<EntidadInfo>>((ref) async {
  return ref.watch(bauthApiProvider).arbolEntidades();
});

/// Catálogo de tipos de nodo (idn_policy_node_type).
final catalogoTiposProvider =
    FutureProvider<Map<String, ConfigTipoNodo>>((ref) async {
  return ref.watch(bauthApiProvider).cargarCatalogoTipos();
});

/// Métricas del daemon bAuth — refresco automático cada 30 s.
final syncStatusProvider =
    FutureProvider.autoDispose<SyncStatusInfo>((ref) async {
  ref.keepAlive();
  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  return ref.watch(bauthApiProvider).syncStatus();
});
