// ============================================================
// bauth_desktop · widgets/comunes/tira_tabs.dart
//
// Propósito: tira de pestañas reutilizable, con subrayado de acento en la
//   activa y separador opcional. Se usa dentro de cualquier vista. `scaling`.
// Dependencias: tf_shadcn_flutter.
// Estándar: shadcn_flutter · DOC-SBOS-001 N3 (componente reutilizable).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Tira de pestañas: `activa` = índice seleccionado; `separadorTras` inserta un
/// separador vertical después de ese índice.
class TiraTabs extends StatelessWidget {
  final List<String> tabs;
  final int activa;
  final int? separadorTras;
  final ValueChanged<int>? alSeleccionar;
  const TiraTabs({super.key, required this.tabs, this.activa = 0, this.separadorTras, this.alSeleccionar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final hijos = <Widget>[];
    for (int i = 0; i < tabs.length; i++) {
      hijos.add(_Tab(texto: tabs[i], activa: i == activa, alTocar: () => alSeleccionar?.call(i)));
      if (separadorTras == i) {
        hijos.add(Container(width: 1, height: 18 * s, color: cs.border, margin: EdgeInsets.symmetric(horizontal: 8 * s)));
      }
    }
    return Container(
      decoration: BoxDecoration(color: cs.card, border: Border(bottom: BorderSide(color: cs.border))),
      padding: EdgeInsets.symmetric(horizontal: 16 * s),
      child: Row(children: hijos),
    );
  }
}

/// Una pestaña (subrayado de acento cuando activa).
class _Tab extends StatelessWidget {
  final String texto;
  final bool activa;
  final VoidCallback alTocar;
  const _Tab({required this.texto, required this.activa, required this.alTocar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return GestureDetector(
      onTap: alTocar,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 8 * s),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: activa ? cs.primary : Colors.transparent, width: 2 * s))),
        child: Text(texto,
            style: TextStyle(fontSize: 11 * s, fontWeight: FontWeight.w600, color: activa ? cs.primary : cs.mutedForeground)),
      ),
    );
  }
}
