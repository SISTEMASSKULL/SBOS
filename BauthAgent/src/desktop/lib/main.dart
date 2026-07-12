// ============================================================
// bauth_desktop · main.dart
//
// Propósito: punto de entrada. Inicializa la ventana de escritorio
//   (window_manager) y arranca la app dentro de un ProviderScope (Riverpod).
// Dependencias: flutter, flutter_riverpod, window_manager, app.dart.
// Estándar: desktop-first (win/mac/linux) · A.18 §3.1.
// ============================================================

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

/// Entrada de la aplicación de escritorio.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const opciones = WindowOptions(
    size: Size(1360, 860),
    minimumSize: Size(1024, 680),
    center: true,
    title: 'bAuth Desktop',
  );
  await windowManager.waitUntilReadyToShow(opciones, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: BauthDesktopApp()));
}
