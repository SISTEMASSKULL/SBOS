// ============================================================
// bauth_desktop · widgets/layout/estructura_desktop.dart
//
// Propósito: el VIEWPORT como 3 BLOQUES en fila — izquierdo (sidenav
//   expandible), central (contenedor de datos) y derecho (acciones/alertas).
//   Cada bloque trae su propio top/body/bottom; aquí solo se componen.
// Dependencias: tf_shadcn_flutter, widgets/layout/{bloque_lateral_izquierdo,
//   bloque_central, bloque_lateral_derecho}.
// Estándar: maqueta bAuth Desktop (3 bloques) · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../shell/bloque_central.dart';
import 'bloque_lateral_derecho.dart';
import 'bloque_lateral_izquierdo.dart';

/// Viewport: bloque izquierdo · bloque central · bloque derecho.
class EstructuraDesktop extends StatelessWidget {
  const EstructuraDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.background,
      child: const Row(
        children: [
          BloqueLateralIzquierdo(),
          Expanded(child: BloqueCentral()),
          BloqueLateralDerecho(),
        ],
      ),
    );
  }
}
