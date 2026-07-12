// ============================================================
// bauth_desktop · widgets/punto_estado.dart
//
// Propósito: componente GLOBAL reutilizable — un punto circular de color.
//   Indicador de estado usado en barra lateral, tarjetas, listas, etc.
// Dependencias: tf_shadcn_flutter (Color, Widget).
// Estándar: DOC-SBOS-001 N3 (widget global reutilizable, parámetros tipados).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Punto circular de color. Tamaño configurable (por defecto 8 px).
class PuntoEstado extends StatelessWidget {
  final Color color;
  final double tamano;

  const PuntoEstado({super.key, required this.color, this.tamano = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
