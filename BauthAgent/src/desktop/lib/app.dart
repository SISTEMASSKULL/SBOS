// ============================================================
// bauth_desktop · app.dart
//
// Propósito: raíz de la aplicación. Monta `ShadcnApp` reconstruyendo los
//   temas claro y oscuro DINÁMICAMENTE desde las Theme Options (base, acento,
//   radio, modo) — de modo que cualquier cambio se refleja en tiempo real.
// Dependencias: flutter_riverpod, tf_shadcn_flutter, core/theme, screens.
// Estándar: ADR-013 · A.18 §3.1 · shadcn_flutter theme system.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import 'core/theme/sbos_theme.dart';
import 'core/theme/theme_provider.dart';
import 'screens/raiz.dart';

/// Aplicación bAuth Desktop — Dashboard producto (ADR-013).
class BauthDesktopApp extends ConsumerWidget {
  const BauthDesktopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opciones = ref.watch(opcionesTemaProvider);
    return ShadcnApp(
      title: 'bAuth Desktop',
      theme: construirTema(opciones, Brightness.light),
      darkTheme: construirTema(opciones, Brightness.dark),
      themeMode: opciones.modo,
      debugShowCheckedModeBanner: false,
      home: const Raiz(),
    );
  }
}
