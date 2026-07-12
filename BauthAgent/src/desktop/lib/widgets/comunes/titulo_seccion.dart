// ============================================================
// bauth_desktop · widgets/comunes/titulo_seccion.dart
//
// Propósito: título de sección reutilizable — rótulo en mayúsculas + línea de
//   relleno a la derecha. Se usa en cualquier vista. `scaling`.
// Dependencias: tf_shadcn_flutter.
// Estándar: shadcn_flutter · DOC-SBOS-001 N3 (componente reutilizable).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Título de sección: rótulo uppercase + línea de relleno.
class TituloSeccion extends StatelessWidget {
  final String texto;
  const TituloSeccion(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Row(
      children: [
        Text(texto.toUpperCase(),
            style: TextStyle(fontSize: 9 * s, fontWeight: FontWeight.w700, letterSpacing: 1 * s, color: cs.mutedForeground)),
        SizedBox(width: 8 * s),
        Expanded(child: Container(height: 1, color: cs.border)),
      ],
    );
  }
}
