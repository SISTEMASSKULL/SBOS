// ============================================================
// bauth_desktop · widgets/seccion_sbos.dart
//
// Propósito: componente GLOBAL reutilizable — una sección con título en
//   mayúsculas + un `Wrap` de hijos. Se usa en el panel de Theme Options y
//   en cualquier panel de opciones agrupadas.
// Dependencias: tf_shadcn_flutter.
// Estándar: DOC-SBOS-001 N3 (agrupador genérico reutilizable).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Sección titulada con un envoltorio flexible de hijos.
class SeccionSbos extends StatelessWidget {
  final String titulo;
  final List<Widget> hijos;

  const SeccionSbos({super.key, required this.titulo, required this.hijos});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo.toUpperCase(),
          style: TextStyle(
            color: cs.mutedForeground,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: hijos),
        const SizedBox(height: 20),
      ],
    );
  }
}
