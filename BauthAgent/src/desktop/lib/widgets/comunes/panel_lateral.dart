// ============================================================
// bauth_desktop · widgets/comunes/panel_lateral.dart
//
// Propósito: panel lateral reutilizable — encabezado (título + conteo) sobre
//   un contenido desplazable, con borde del lado indicado. Se usa dentro de
//   cualquier vista (p. ej. paneles de átomos/políticas). `scaling`.
// Dependencias: tf_shadcn_flutter.
// Estándar: shadcn_flutter · DOC-SBOS-001 N3 (componente reutilizable).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Lado del borde de un panel lateral.
enum LadoPanel { izquierdo, derecho }

/// Panel lateral con encabezado y contenido desplazable.
class PanelLateral extends StatelessWidget {
  final String titulo;
  final String conteo;
  final LadoPanel lado;
  final Widget child;
  final double ancho;
  const PanelLateral({
    super.key,
    required this.titulo,
    this.conteo = '',
    required this.lado,
    required this.child,
    this.ancho = 252,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      width: ancho * s,
      decoration: BoxDecoration(
        color: cs.card,
        border: Border(
          right: lado == LadoPanel.izquierdo ? BorderSide(color: cs.border) : BorderSide.none,
          left: lado == LadoPanel.derecho ? BorderSide(color: cs.border) : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
            decoration: BoxDecoration(color: cs.muted, border: Border(bottom: BorderSide(color: cs.border))),
            child: Row(
              children: [
                Expanded(
                  child: Text(titulo.toUpperCase(),
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9 * s,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5 * s,
                          color: cs.mutedForeground)),
                ),
                if (conteo.isNotEmpty)
                  Text(conteo, style: TextStyle(fontFamily: 'monospace', fontSize: 9 * s, color: cs.mutedForeground)),
              ],
            ),
          ),
          Expanded(child: SingleChildScrollView(padding: EdgeInsets.symmetric(horizontal: 6 * s), child: child)),
        ],
      ),
    );
  }
}
