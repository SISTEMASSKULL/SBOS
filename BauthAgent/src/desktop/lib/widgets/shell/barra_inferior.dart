// ============================================================
// bauth_desktop · widgets/shell/barra_inferior.dart
//
// Propósito: BOTTOM del bloque central (global, fijo) — atajos de teclado y
//   sello de cumplimiento + fecha. No depende de la vista. `scaling`.
// Dependencias: tf_shadcn_flutter.
// Estándar: prototipo bAuth Desktop · SPA (shell) · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Barra inferior global (fija).
class BarraInferior extends StatelessWidget {
  const BarraInferior({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      height: 30 * s,
      padding: EdgeInsets.symmetric(horizontal: 14 * s),
      decoration: BoxDecoration(color: cs.card, border: Border(top: BorderSide(color: cs.border))),
      child: Row(
        children: [
          const _Atajo(tecla: '⌘K', rotulo: 'Buscar'),
          SizedBox(width: 14 * s),
          const _Atajo(tecla: 'Ctrl 1–8', rotulo: 'Navegar'),
          const Spacer(),
          Text('ISO 27001 ✓', style: TextStyle(fontSize: 11 * s, color: Colors.green.shade500)),
          SizedBox(width: 8 * s),
          Text('·', style: TextStyle(fontSize: 11 * s, color: cs.mutedForeground)),
          SizedBox(width: 8 * s),
          Text('27 jun 2026 · 14:32 GMT-5',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11 * s, color: cs.mutedForeground)),
        ],
      ),
    );
  }
}

/// Un atajo de teclado (tecla en recuadro + rótulo).
class _Atajo extends StatelessWidget {
  final String tecla;
  final String rotulo;
  const _Atajo({required this.tecla, required this.rotulo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 1 * s),
          decoration: BoxDecoration(border: Border.all(color: cs.border), borderRadius: BorderRadius.circular(5 * s)),
          child: Text(tecla, style: TextStyle(fontFamily: 'monospace', fontSize: 10 * s, color: cs.mutedForeground)),
        ),
        SizedBox(width: 5 * s),
        Text(rotulo, style: TextStyle(fontSize: 11 * s, color: cs.mutedForeground)),
      ],
    );
  }
}
