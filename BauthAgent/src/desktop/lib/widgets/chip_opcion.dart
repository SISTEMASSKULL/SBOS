// ============================================================
// bauth_desktop · widgets/chip_opcion.dart
//
// Propósito: chip de opción **reutilizable y parametrizado** — se usa para
//   elegir modo, base, acento y radio en el panel de Theme Options. Si
//   [muestra] no es null, pinta un punto del color (para elegir acentos).
// Dependencias: tf_shadcn_flutter (widgets, tema).
// Estándar: DOC-SBOS-001 N3 (componente reutilizable, parámetros tipados).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Chip seleccionable genérico. Un solo componente para todas las opciones.
class ChipOpcion extends StatelessWidget {
  final String etiqueta;
  final bool seleccionado;
  final VoidCallback alElegir;
  final Color? muestra;

  const ChipOpcion({
    super.key,
    required this.etiqueta,
    required this.seleccionado,
    required this.alElegir,
    this.muestra,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: alElegir,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: seleccionado ? cs.primary : cs.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: seleccionado ? cs.primary : cs.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (muestra != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: muestra, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              etiqueta,
              style: TextStyle(
                color: seleccionado ? cs.primaryForeground : cs.foreground,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
