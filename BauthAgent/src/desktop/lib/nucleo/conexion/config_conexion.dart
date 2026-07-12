// ============================================================
// bauth_desktop · nucleo/conexion/config_conexion.dart
//
// Propósito: configuración de conexión al daemon bAuth. El Desktop es un
//   cliente REMOTO: se conecta al **extremo local de un túnel SSH** que
//   reenvía el Unix socket del servidor (`/tmp/bauth/bauth.sock`) a un
//   host:puerto locales. Configurable en runtime (multiplataforma).
// Dependencias: flutter_riverpod.
// Estándar: ADR-020 (Interface Dual) · A.18 (cliente de administración).
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Datos de conexión al servidor (extremo local del túnel).
class ConfigConexion {
  final String host;
  final int puerto;

  const ConfigConexion({this.host = 'localhost', this.puerto = 9450});

  ConfigConexion copyWith({String? host, int? puerto}) =>
      ConfigConexion(host: host ?? this.host, puerto: puerto ?? this.puerto);
}

/// Estado editable de la configuración de conexión.
class ConfigConexionNotifier extends Notifier<ConfigConexion> {
  @override
  ConfigConexion build() => const ConfigConexion();

  void fijarHost(String h) => state = state.copyWith(host: h.trim());
  void fijarPuerto(int p) => state = state.copyWith(puerto: p);
}

/// Provider de la configuración de conexión.
final configConexionProvider =
    NotifierProvider<ConfigConexionNotifier, ConfigConexion>(
        ConfigConexionNotifier.new);
