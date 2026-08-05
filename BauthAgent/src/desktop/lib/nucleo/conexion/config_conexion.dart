// ============================================================
// bauth_desktop · nucleo/conexion/config_conexion.dart
//
// Propósito: configuración de conexión al daemon bAuth.
//   Transporte primario: DLL banexus (dart:ffi).
//     Flutter → banexus.dll → bhnexus Puerta 1 → bAuth socket.
//   banexusHost:banexusPuerto = dirección del servidor bhnexus Puerta 1.
// Dependencias: flutter_riverpod.
// Estándar: ADR-020 (Interface Dual) · SBOS-NEXUS §24.3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Datos de conexión al servidor bAuth.
class ConfigConexion {
  /// Host del servidor bhnexus Puerta 1 (Rust, TCP).
  final String banexusHost;

  /// Puerto del servidor bhnexus Puerta 1 (SBOS-050: rango 9400-9499).
  final int banexusPuerto;

  /// Host TCP directo (solo fallback / pruebas).
  final String host;

  /// Puerto TCP directo (solo fallback / pruebas).
  final int puerto;

  const ConfigConexion({
    this.banexusHost = '13.140.128.230',
    this.banexusPuerto = 9444,
    this.host = 'localhost',
    this.puerto = 9450,
  });

  ConfigConexion copyWith({
    String? banexusHost,
    int? banexusPuerto,
    String? host,
    int? puerto,
  }) =>
      ConfigConexion(
        banexusHost: banexusHost ?? this.banexusHost,
        banexusPuerto: banexusPuerto ?? this.banexusPuerto,
        host: host ?? this.host,
        puerto: puerto ?? this.puerto,
      );
}

/// Estado editable de la configuración de conexión.
class ConfigConexionNotifier extends Notifier<ConfigConexion> {
  @override
  ConfigConexion build() => const ConfigConexion();

  void fijarBanexusHost(String h) =>
      state = state.copyWith(banexusHost: h.trim());
  void fijarBanexusPuerto(int p) =>
      state = state.copyWith(banexusPuerto: p);
  void fijarHost(String h) => state = state.copyWith(host: h.trim());
  void fijarPuerto(int p) => state = state.copyWith(puerto: p);
}

/// Provider de la configuración de conexión.
final configConexionProvider =
    NotifierProvider<ConfigConexionNotifier, ConfigConexion>(
        ConfigConexionNotifier.new);
