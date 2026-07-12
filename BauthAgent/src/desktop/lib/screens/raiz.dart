// ============================================================
// bauth_desktop · screens/raiz.dart
//
// Propósito: raíz de contenido — arma el viewport de 3 bloques.
// Dependencias: tf_shadcn_flutter, widgets/layout/estructura_desktop.
// Estándar: maqueta bAuth Desktop · DOC-SBOS-001 N3 (compositor delgado).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../widgets/layout/estructura_desktop.dart';

/// Viewport principal del Desktop (3 bloques).
class Raiz extends StatelessWidget {
  const Raiz({super.key});

  @override
  Widget build(BuildContext context) {
    return const EstructuraDesktop();
  }
}
