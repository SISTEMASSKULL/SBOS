// ============================================================
// bauth_desktop · widgets/central/boton_icono.dart
//
// Propósito: botón cuadrado de icono (34×34) del header central — borde, fondo
//   elevado e icono neutro, con insignia opcional (punto de notificación).
//   Reutilizable. Tamaños calculados con `theme.scaling`.
// Dependencias: tf_shadcn_flutter.
// Estándar: prototipo bAuth Desktop · shadcn_flutter · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Botón de icono del header (34×34) con insignia opcional.
class BotonIcono extends StatelessWidget {
  final IconData icono;
  final VoidCallback? alTocar;
  final Widget? insignia;

  const BotonIcono({super.key, required this.icono, this.alTocar, this.insignia});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return GestureDetector(
      onTap: alTocar,
      child: Container(
        width: 34 * s,
        height: 34 * s,
        decoration: BoxDecoration(
          color: cs.muted,
          border: Border.all(color: cs.border),
          borderRadius: BorderRadius.circular(8 * s),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icono, size: 17 * s, color: cs.mutedForeground),
            if (insignia != null) Positioned(top: 6 * s, right: 7 * s, child: insignia!),
          ],
        ),
      ),
    );
  }
}
