// ============================================================
// bauth_desktop · widgets/shell/bloque_central.dart
//
// Propósito: BLOQUE G-BC (fijo) del viewport, compuesto en 5 slots:
//   G-BC:TOP (BarraSuperior) · G-BC:BB (breadcrumb) · G-BC:OUT (outlet)
//   · G-BC:SB (statusbar) · G-BC:BOT (barra inferior).
//   El OUTLET es lo único que cambia: monta la vista de la ruta activa.
// Dependencias: tf_shadcn_flutter, widgets/shell/{barra_superior,
//   barra_breadcrumb, outlet, barra_estado, barra_inferior},
//   widgets/comunes/etiqueta_codigo.
// Estándar: G-BC · A.64.01 · maqueta bAuth Desktop · SPA (shell) · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../comunes/etiqueta_codigo.dart';
import 'barra_breadcrumb.dart';
import 'barra_estado.dart';
import 'barra_inferior.dart';
import 'barra_superior.dart';
import 'outlet.dart';

/// Bloque central G-BC: G-BC:TOP · G-BC:BB · G-BC:OUT · G-BC:SB · G-BC:BOT.
class BloqueCentral extends StatelessWidget {
  const BloqueCentral({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.background,
      child: const Column(
        children: [
          SeccionConCodigo('G-BC:TOP', child: BarraSuperior()),
          Expanded(
            child: Column(
              children: [
                SeccionConCodigo('G-BC:BB', child: BarraBreadcrumb()),
                Expanded(child: SeccionConCodigo('G-BC:OUT', child: Outlet())),
                SeccionConCodigo('G-BC:SB', child: BarraEstado()),
              ],
            ),
          ),
          SeccionConCodigo('G-BC:BOT', child: BarraInferior()),
        ],
      ),
    );
  }
}
