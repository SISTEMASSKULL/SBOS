// ============================================================
// bauth_desktop · widgets/shell/barra_estado.dart
//
// Propósito: STATUSBAR del bloque central (bajo el outlet) — conexión
//   WebSocket, reconcile de proyecciones (soberano, ADR-010), drift y métricas
//   en vivo. `scaling`.
// Dependencias: tf_shadcn_flutter.
// Estándar: prototipo bAuth Desktop · ADR-010 · SPA (shell) · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Barra de estado (bajo el outlet).
class BarraEstado extends StatelessWidget {
  const BarraEstado({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      height: 30 * s,
      padding: EdgeInsets.symmetric(horizontal: 14 * s),
      decoration: BoxDecoration(color: cs.background, border: Border(top: BorderSide(color: cs.border))),
      child: Row(
        children: [
          _Segmento(color: Colors.green.shade500, etiqueta: 'Conectado', fuerte: true, mono: 'WebSocket · ↕ 12 ms'),
          _Separador(),
          _Segmento(color: Colors.green.shade500, etiqueta: 'Reconcile · proyecciones', mono: 'hace 3m'),
          _Separador(),
          _Segmento(color: Colors.amber.shade500, etiqueta: '1 drift'),
          const Spacer(),
          const _Metricas(),
        ],
      ),
    );
  }
}

/// Un segmento: punto de estado + etiqueta (+ texto monospace).
class _Segmento extends StatelessWidget {
  final Color color;
  final String etiqueta;
  final bool fuerte;
  final String? mono;
  const _Segmento({required this.color, required this.etiqueta, this.fuerte = false, this.mono});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Row(
      children: [
        Container(width: 7 * s, height: 7 * s, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        SizedBox(width: 7 * s),
        Text(etiqueta,
            style: TextStyle(
                fontSize: 11.5 * s,
                fontWeight: fuerte ? FontWeight.w600 : FontWeight.w400,
                color: fuerte ? cs.foreground : cs.mutedForeground)),
        if (mono != null) ...[
          SizedBox(width: 7 * s),
          Text(mono!, style: TextStyle(fontFamily: 'monospace', fontSize: 11 * s, color: cs.mutedForeground)),
        ],
        SizedBox(width: 14 * s),
      ],
    );
  }
}

/// Separador vertical.
class _Separador extends StatelessWidget {
  const _Separador();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.scaling;
    return Container(width: 1, height: 14 * s, color: theme.colorScheme.border);
  }
}

/// Métricas en vivo (eval/s · sesiones · roles).
class _Metricas extends StatelessWidget {
  const _Metricas();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    Widget metrica(String valor, String rotulo) => Padding(
          padding: EdgeInsets.only(left: 18 * s),
          child: RichText(
            text: TextSpan(style: TextStyle(fontFamily: 'monospace', fontSize: 11.5 * s), children: [
              TextSpan(text: valor, style: TextStyle(color: cs.foreground)),
              TextSpan(text: ' $rotulo', style: TextStyle(color: cs.mutedForeground)),
            ]),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      metrica('142.857', 'eval/s'),
      metrica('89', 'sesiones'),
      metrica('366', 'roles'),
    ]);
  }
}
