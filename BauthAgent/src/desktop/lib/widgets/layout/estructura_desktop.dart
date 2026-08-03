// ============================================================
// bauth_desktop · widgets/layout/estructura_desktop.dart
//
// Propósito: el VIEWPORT como 3 BLOQUES en fila — izquierdo (sidenav
//   expandible G-SN), central (contenedor de datos G-BC) y derecho
//   (acciones/alertas G-BD). Cada bloque trae su propio top/body/bottom;
//   aquí solo se componen y se anotan con etiquetas A.64.01.
// Dependencias: tf_shadcn_flutter, widgets/layout/{bloque_lateral_izquierdo,
//   bloque_central, bloque_lateral_derecho}, widgets/comunes/etiqueta_codigo.
// Estándar: G-SH · A.64.01 · maqueta bAuth Desktop (3 bloques) · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../comunes/etiqueta_codigo.dart';
import '../shell/bloque_central.dart';
import 'bloque_lateral_derecho.dart';
import 'bloque_lateral_izquierdo.dart';

/// Viewport: G-SN (sidenav) · G-BC (central) · G-BD (panel derecho).
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
          // G-BC — bloque central (sus slots añaden etiquetas internas)
          Expanded(child: BloqueCentral()),
          // G-BD — bloque lateral derecho (panel conexión)
          SeccionConCodigo('G-BD', child: BloqueLateralDerecho()),
        ],
      ),
    );
  }
}
