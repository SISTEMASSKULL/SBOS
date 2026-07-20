// ============================================================
// bauth_desktop · main.dart
//
// Propósito: punto de entrada. Arranca la app dentro de un
//   ProviderScope (Riverpod). Sin window_manager — compatible
//   con Windows 11 sin Developer Mode.
// Dependencias: flutter, flutter_riverpod, app.dart.
// Estándar: desktop-first (win/mac/linux) · A.18 §3.1.
// ============================================================

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Entrada de la aplicación de escritorio.
void main() {
  runApp(const ProviderScope(child: BauthDesktopApp()));
}
