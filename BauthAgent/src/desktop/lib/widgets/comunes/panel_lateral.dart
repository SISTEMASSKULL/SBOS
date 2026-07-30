// ============================================================
// bauth_desktop · widgets/comunes/panel_lateral.dart
//
// Propósito: sidenav colapsable — encabezado + contenido desplazable.
//   Expandido: ancho completo con título y contenido.
//   Colapsado: tira vertical con título rotado y botón de toggle.
//   El estado es interno — no requiere gestión externa.
// Dependencias: tf_shadcn_flutter.
// Estándar: shadcn_flutter · DOC-SBOS-001 N3 (componente reutilizable).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Lado del borde de un panel lateral.
enum LadoPanel { izquierdo, derecho }

/// Sidenav colapsable con encabezado y contenido desplazable.
class PanelLateral extends StatefulWidget {
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
  State<PanelLateral> createState() => _PanelLateralState();
}

class _PanelLateralState extends State<PanelLateral> {
  bool _expandido = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      width: _expandido ? widget.ancho * s : 32 * s,
      decoration: BoxDecoration(
        color: cs.card,
        border: Border(
          right: widget.lado == LadoPanel.izquierdo
              ? BorderSide(color: cs.border)
              : BorderSide.none,
          left: widget.lado == LadoPanel.derecho
              ? BorderSide(color: cs.border)
              : BorderSide.none,
        ),
      ),
      child: _expandido ? _panelExpandido(cs, s) : _panelColapsado(cs, s),
    );
  }

  Widget _panelExpandido(ColorScheme cs, double s) {
    final esIzq = widget.lado == LadoPanel.izquierdo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Encabezado ───────────────────────────────────────
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 6 * s),
          decoration: BoxDecoration(
            color: cs.muted,
            border: Border(bottom: BorderSide(color: cs.border)),
          ),
          child: Row(
            children: [
              if (!esIzq) _botonToggle(cs, s),
              if (!esIzq) SizedBox(width: 4 * s),
              Expanded(
                child: Text(
                  widget.titulo.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9 * s,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5 * s,
                    color: cs.mutedForeground,
                  ),
                ),
              ),
              if (widget.conteo.isNotEmpty)
                Text(
                  widget.conteo,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9 * s,
                    color: cs.mutedForeground,
                  ),
                ),
              if (esIzq) SizedBox(width: 4 * s),
              if (esIzq) _botonToggle(cs, s),
            ],
          ),
        ),
        // ── Contenido ────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 6 * s),
            child: widget.child,
          ),
        ),
      ],
    );
  }

  Widget _panelColapsado(ColorScheme cs, double s) {
    return Column(
      children: [
        // ── Botón de expandir ────────────────────────────────
        SizedBox(
          width: 32 * s,
          height: 32 * s,
          child: _botonToggle(cs, s),
        ),
        // ── Título rotado ────────────────────────────────────
        Expanded(
          child: Center(
            child: RotatedBox(
              quarterTurns: widget.lado == LadoPanel.izquierdo ? 1 : 3,
              child: Text(
                widget.titulo.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9 * s,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8 * s,
                  color: cs.mutedForeground,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _botonToggle(ColorScheme cs, double s) {
    final esIzq = widget.lado == LadoPanel.izquierdo;
    final icono = _expandido
        ? (esIzq ? LucideIcons.panelLeftClose : LucideIcons.panelRightClose)
        : (esIzq ? LucideIcons.panelLeftOpen : LucideIcons.panelRightOpen);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _expandido = !_expandido),
        child: Tooltip(
          tooltip: TooltipContainer(
            child: Text(_expandido ? 'Colapsar' : 'Expandir'),
          ),
          child: Icon(icono, size: 14 * s, color: cs.mutedForeground),
        ),
      ),
    );
  }
}
