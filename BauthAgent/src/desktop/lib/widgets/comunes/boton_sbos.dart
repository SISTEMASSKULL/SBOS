// ============================================================
// bauth_desktop · widgets/comunes/boton_sbos.dart
//
// Propósito: botón compacto reutilizable (neutro/primario/peligro), con icono
//   opcional. Colores del tema; `scaling`. Se usa en cualquier vista.
// Dependencias: tf_shadcn_flutter.
// Estándar: shadcn_flutter · DOC-SBOS-001 N3 (componente reutilizable).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Énfasis visual de un botón.
enum EnfasisBoton { neutro, primario, peligro }

/// Botón compacto reutilizable.
class BotonSbos extends StatelessWidget {
  final String texto;
  final EnfasisBoton enfasis;
  final IconData? icono;
  final VoidCallback? alTocar;
  const BotonSbos(this.texto, {super.key, this.enfasis = EnfasisBoton.neutro, this.icono, this.alTocar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final primario = enfasis == EnfasisBoton.primario;
    final peligro = enfasis == EnfasisBoton.peligro;
    final fondo = primario ? cs.primary : Colors.transparent;
    final borde = peligro ? cs.destructive : cs.border;
    final tinta = primario ? cs.primaryForeground : (peligro ? cs.destructive : cs.mutedForeground);
    return GestureDetector(
      onTap: alTocar,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 11 * s, vertical: 4 * s),
        decoration: BoxDecoration(
          color: fondo,
          border: primario ? null : Border.all(color: borde),
          borderRadius: BorderRadius.circular(4 * s),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[Icon(icono, size: 12 * s, color: tinta), SizedBox(width: 5 * s)],
            Text(texto, style: TextStyle(fontSize: 11 * s, fontWeight: FontWeight.w600, color: tinta)),
          ],
        ),
      ),
    );
  }
}
