// ============================================================
// bauth_desktop · widgets/comunes/panel_lateral.dart
//
// Propósito: sidenav colapsable — encabezado + área de contenido.
//   Expandido: ancho completo con título y contenido.
//   Colapsado: tira vertical con título rotado y botón de toggle.
//
// Rendimiento: usa Offstage para mantener AMBOS estados (expandido y
//   colapsado) siempre en el árbol. Evita el desmonte/remonte en cada
//   toggle, eliminando la reconstrucción costosa del contenido.
//   AnimatedContainer con clipBehavior para que el clip solo cambie
//   dimensión sin forzar relayout del contenido interior.
//
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

    // clipBehavior: el contenido a ancho fijo queda recortado durante
    // la animación sin necesidad de relayoutearlo en cada frame.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      width: _expandido ? widget.ancho * s : 32 * s,
      clipBehavior: Clip.hardEdge,
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
      // Stack con Offstage: AMBOS estados permanecen en el árbol.
      // Al hacer toggle solo cambia la visibilidad — nunca hay desmonte.
      child: Stack(
        children: [
          // ── Estado expandido ──────────────────────────────────
          Offstage(
            offstage: !_expandido,
            child: _PanelExpandido(
              titulo: widget.titulo,
              conteo: widget.conteo,
              lado: widget.lado,
              ancho: widget.ancho,
              onToggle: _toggle,
              child: widget.child,
            ),
          ),
          // ── Estado colapsado ──────────────────────────────────
          Offstage(
            offstage: _expandido,
            child: _PanelColapsado(
              titulo: widget.titulo,
              lado: widget.lado,
              onToggle: _toggle,
            ),
          ),
        ],
      ),
    );
  }

  void _toggle() => setState(() => _expandido = !_expandido);
}

// ════════════════════════════════════════════════════════════
// Sub-widgets internos (stateless — renderizan su estado)
// ════════════════════════════════════════════════════════════

class _PanelExpandido extends StatelessWidget {
  final String titulo;
  final String conteo;
  final LadoPanel lado;
  final double ancho;
  final VoidCallback onToggle;
  final Widget child;

  const _PanelExpandido({
    required this.titulo,
    required this.conteo,
    required this.lado,
    required this.ancho,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final esIzq = lado == LadoPanel.izquierdo;

    return SizedBox(
      width: ancho * s,
      child: Column(
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
                if (!esIzq) _BotonToggle(lado: lado, expandido: true, onToggle: onToggle, s: s, cs: cs),
                if (!esIzq) SizedBox(width: 4 * s),
                Expanded(
                  child: Text(
                    titulo.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9 * s,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5 * s,
                      color: cs.mutedForeground,
                    ),
                  ),
                ),
                if (conteo.isNotEmpty)
                  Text(
                    conteo,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9 * s,
                      color: cs.mutedForeground,
                    ),
                  ),
                if (esIzq) SizedBox(width: 4 * s),
                if (esIzq) _BotonToggle(lado: lado, expandido: true, onToggle: onToggle, s: s, cs: cs),
              ],
            ),
          ),
          // ── Contenido ────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 6 * s),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelColapsado extends StatelessWidget {
  final String titulo;
  final LadoPanel lado;
  final VoidCallback onToggle;

  const _PanelColapsado({
    required this.titulo,
    required this.lado,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;

    return SizedBox(
      width: 32 * s,
      child: Column(
        children: [
          SizedBox(
            width: 32 * s,
            height: 32 * s,
            child: _BotonToggle(lado: lado, expandido: false, onToggle: onToggle, s: s, cs: cs),
          ),
          Expanded(
            child: Center(
              child: RotatedBox(
                quarterTurns: lado == LadoPanel.izquierdo ? 1 : 3,
                child: Text(
                  titulo.toUpperCase(),
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
      ),
    );
  }
}

/// Botón de toggle reutilizable entre los dos estados del panel.
class _BotonToggle extends StatelessWidget {
  final LadoPanel lado;
  final bool expandido;
  final VoidCallback onToggle;
  final double s;
  final ColorScheme cs;

  const _BotonToggle({
    required this.lado,
    required this.expandido,
    required this.onToggle,
    required this.s,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final esIzq = lado == LadoPanel.izquierdo;
    final icono = expandido
        ? (esIzq ? LucideIcons.panelLeftClose : LucideIcons.panelRightClose)
        : (esIzq ? LucideIcons.panelLeftOpen : LucideIcons.panelRightOpen);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onToggle,
        child: Tooltip(
          tooltip: TooltipContainer(
            child: Text(expandido ? 'Colapsar' : 'Expandir'),
          ).call,
          child: Icon(icono, size: 14 * s, color: cs.mutedForeground),
        ),
      ),
    );
  }
}
