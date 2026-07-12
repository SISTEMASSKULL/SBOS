// ============================================================
// bauth_desktop · widgets/shell/bloque_central.dart
//
// Propósito: BLOQUE 2 (fijo) del viewport, compuesto en 5 capas —
//   top (BarraSuperior) · [ breadcrumb · OUTLET · statusbar ] · bottom.
//   El OUTLET es lo único que cambia: monta la vista de la ruta activa.
// Dependencias: tf_shadcn_flutter, widgets/shell/{barra_superior,
//   barra_breadcrumb, outlet, barra_estado, barra_inferior}.
// Estándar: maqueta bAuth Desktop · SPA (shell) · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import 'barra_breadcrumb.dart';
import 'barra_estado.dart';
import 'barra_inferior.dart';
import 'barra_superior.dart';
import 'outlet.dart';

/// Bloque central: top + (breadcrumb + outlet + statusbar) + bottom.
class BloqueCentral extends StatelessWidget {
  const BloqueCentral({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.background,
      child: const Column(
        children: [
          BarraSuperior(), // TOP (fijo)
          Expanded(
            child: Column(
              children: [
                BarraBreadcrumb(), // breadcrumb
                Expanded(child: Outlet()), // ★ vistas ★
                BarraEstado(), // statusbar
              ],
            ),
          ),
          BarraInferior(), // BOTTOM (fijo)
        ],
      ),
    );
  }
}
