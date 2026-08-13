// ============================================================
// bauth_desktop · widgets/comunes/panel_lateral.dart
//
// Propósito: sidenav colapsable con tres secciones de contenido:
//
//   ┌─────────────────────────────┐
//   │ encabezado (título + toggle)│  ← siempre presente, fijo
//   ├─────────────────────────────┤
//   │ top                         │  ← fijo, sin scroll (opcional)
//   ├─────────────────────────────┤
//   │ body  (Expanded + scroll)   │  ← flexible, scrolleable (opcional)
//   ├─────────────────────────────┤
//   │ bottom                      │  ← fijo, sin scroll (opcional)
//   └─────────────────────────────┘
//
//   Colapsado: tira vertical con título rotado y botón de toggle.
//
// Rendimiento: Offstage mantiene expandido y colapsado siempre en el
//   árbol — sin desmonte al hacer toggle. AnimatedContainer con
//   clipBehavior solo cambia el clip, no relayoutea el contenido.
//
// Dependencias: tf_shadcn_flutter.
// Estándar: shadcn_flutter · DOC-SBOS-001 N3 (componente reutilizable).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Lado del borde de un panel lateral.
enum LadoPanel { izquierdo, derecho }

/// Sidenav colapsable con tres secciones: [top], [body] y [bottom].
///
/// Todas las secciones son opcionales. [body] ocupa el espacio restante
/// con scroll; [top] y [bottom] son fijas (sin scroll).
class PanelLateral extends StatefulWidget {
  final String titulo;
  final String conteo;
  final LadoPanel lado;
  final double ancho;

  /// Sección superior fija (debajo del encabezado, sin scroll).
  final Widget? top;

  /// Sección central flexible con scroll vertical.
  final Widget? body;

  /// Sección central flexible SIN scroll — para layouts que necesitan
  /// altura fija (ej. splitters resizables). Tiene prioridad sobre [body].
  final Widget? bodyFlex;

  /// Sección inferior fija (encima del borde inferior, sin scroll).
  final Widget? bottom;

  const PanelLateral({
    super.key,
    required this.titulo,
    this.conteo = '',
    required this.lado,
    this.ancho = 252,
    this.top,
    this.body,
    this.bodyFlex,
    this.bottom,
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
      // Offstage: ambos estados permanecen en el árbol — sin desmonte.
      child: Stack(
        children: [
          Offstage(
            offstage: !_expandido,
            child: _PanelExpandido(
              titulo: widget.titulo,
              conteo: widget.conteo,
              lado: widget.lado,
              ancho: widget.ancho,
              onToggle: _toggle,
              top: widget.top,
              body: widget.body,
              bodyFlex: widget.bodyFlex,
              bottom: widget.bottom,
            ),
          ),
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
// Sub-widgets internos
// ════════════════════════════════════════════════════════════

class _PanelExpandido extends StatelessWidget {
  final String titulo;
  final String conteo;
  final LadoPanel lado;
  final double ancho;
  final VoidCallback onToggle;
  final Widget? top;
  final Widget? body;
  final Widget? bodyFlex;
  final Widget? bottom;

  const _PanelExpandido({
    required this.titulo,
    required this.conteo,
    required this.lado,
    required this.ancho,
    required this.onToggle,
    this.top,
    this.body,
    this.bodyFlex,
    this.bottom,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                if (!esIzq)
                  _BotonToggle(lado: lado, expandido: true, onToggle: onToggle, s: s, cs: cs),
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
                if (esIzq)
                  _BotonToggle(lado: lado, expandido: true, onToggle: onToggle, s: s, cs: cs),
              ],
            ),
          ),

          // ── Sección top (fija) ────────────────────────────────
          if (top != null) ...[
            top!,
            Divider(height: 1, thickness: 1, color: cs.border),
          ],

          // ── Sección body (flexible) ───────────────────────────
          // bodyFlex: sin scroll — para splitters y layouts de altura fija.
          // body: con scroll — para contenido de longitud variable.
          Expanded(
            child: bodyFlex != null
                ? bodyFlex!
                : body != null
                    ? SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 4 * s),
                        child: body,
                      )
                    : const SizedBox.shrink(),
          ),

          // ── Sección bottom (fija) ─────────────────────────────
          if (bottom != null) ...[
            Divider(height: 1, thickness: 1, color: cs.border),
            bottom!,
          ],
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
            child: _BotonToggle(
              lado: lado,
              expandido: false,
              onToggle: onToggle,
              s: s,
              cs: cs,
            ),
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

/// Botón de toggle compartido entre estado expandido y colapsado.
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
