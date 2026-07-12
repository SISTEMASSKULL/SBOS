// ============================================================
// bauth_desktop · widgets/tarjeta_sbos.dart
//
// Propósito: componente GLOBAL reutilizable — la tarjeta contenedora del
//   Design System (superficie `card` + borde + radio del tema activo).
//   Recibe cualquier contenido. Reacciona a las Theme Options (color/radio).
// Dependencias: tf_shadcn_flutter.
// Estándar: DOC-SBOS-001 N3 (contenedor genérico, sin lógica de negocio).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Tarjeta contenedora reutilizable. `ancho` null = se ajusta al contenido.
class TarjetaSbos extends StatelessWidget {
  final Widget child;
  final double? ancho;
  final EdgeInsetsGeometry padding;

  const TarjetaSbos({
    super.key,
    required this.child,
    this.ancho,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: ancho,
      padding: padding,
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      child: child,
    );
  }
}
