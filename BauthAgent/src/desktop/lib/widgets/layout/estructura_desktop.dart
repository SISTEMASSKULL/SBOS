// ============================================================
// bauth_desktop · widgets/layout/estructura_desktop.dart
//
// Propósito: el VIEWPORT como 3 BLOQUES en fila — izquierdo (sidenav
//   expandible G-SN), central (contenedor de datos G-BC) y derecho
//   (acciones/herramientas G-BD). Cada bloque gestiona sus slots internos.
// Dependencias: tf_shadcn_flutter, widgets/layout/{bloque_lateral_izquierdo,
//   bloque_central, bloque_lateral_derecho}, widgets/comunes/etiqueta_codigo.
// Estándar: G-SH · A.64.01 · maqueta bAuth Desktop · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../comunes/etiqueta_codigo.dart';
import '../shell/bloque_central.dart';
import 'bloque_lateral_derecho.dart';
import 'bloque_lateral_izquierdo.dart';

/// Viewport: G-SN (sidenav) · G-BC (central) · G-BD (acciones).
class EstructuraDesktop extends StatelessWidget {
  const EstructuraDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.background,
      child: const Row(
        children: [
          // G-SN — bloque lateral izquierdo (sidenav)
          SeccionConCodigo('G-SN', child: BloqueLateralIzquierdo()),
          // G-BC — bloque central (slots internos añaden etiquetas propias)
          Expanded(child: BloqueCentral()),
          // G-BD — bloque lateral derecho (acciones y herramientas)
          SeccionConCodigo('G-BD', child: BloqueLateralDerecho()),
        ],
      ),
    );
  }
}
