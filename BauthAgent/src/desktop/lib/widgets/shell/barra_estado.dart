// ============================================================
// bauth_desktop · widgets/shell/barra_estado.dart
//
// Propósito: STATUSBAR global (G-BC:SB) — grid de indicadores de
//   estado del sistema + barra de progreso global de procesamiento.
//
//   Elementos codificados (A.64.01):
//     G-BC:SB-001 — indicador de conexión WebSocket / daemon
//     G-BC:SB-002 — indicador de reconcile de proyecciones (ADR-010)
//     G-BC:SB-003 — indicador de drift detectado
//     G-BC:SB-004 — métricas en vivo (eval/s · sesiones · roles)
//     G-BC:SB-005 — barra de progreso global (cualquier tarea async)
//
//   Layout: [SB-001 | SB-002 | SB-003] ── spacer ── [SB-005] | [SB-004]
//   SB-005 aparece solo cuando procesamientoProvider.activo == true.
//
// Dependencias: tf_shadcn_flutter, flutter_riverpod,
//   nucleo/procesamiento_provider, widgets/comunes/etiqueta_codigo.
// Estándar: G-BC:SB · A.64.01 · ADR-010 · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../nucleo/procesamiento_provider.dart';
import '../comunes/etiqueta_codigo.dart';

// ── Ancho de celda fija para los indicadores del lado izquierdo ─
const double _kAnchoConectado   = 180.0;
const double _kAnchoReconcile  = 210.0;
const double _kAnchoDrift      = 80.0;
const double _kAnchoProgreso   = 220.0;

/// Barra de estado global (G-BC:SB). ConsumerWidget — escucha
/// [procesamientoProvider] para mostrar/ocultar G-BC:SB-005.
class BarraEstado extends ConsumerWidget {
  const BarraEstado({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final s     = theme.scaling;
    final proc  = ref.watch(procesamientoProvider);

    return Container(
      height: 30 * s,
      padding: EdgeInsets.symmetric(horizontal: 14 * s),
      decoration: BoxDecoration(
        color: cs.background,
        border: Border(top: BorderSide(color: cs.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Lado izquierdo: indicadores de estado del sistema ──
          SeccionConCodigo(
            'G-BC:SB-001',
            child: _Celda(
              ancho: _kAnchoConectado,
              child: _Segmento(
                color: Colors.green.shade500,
                etiqueta: 'Conectado',
                fuerte: true,
                mono: 'WebSocket · ↕ 12 ms',
              ),
            ),
          ),
          _Separador(),
          SeccionConCodigo(
            'G-BC:SB-002',
            child: _Celda(
              ancho: _kAnchoReconcile,
              child: _Segmento(
                color: Colors.green.shade500,
                etiqueta: 'Reconcile · proyecciones',
                mono: 'hace 3m',
              ),
            ),
          ),
          _Separador(),
          SeccionConCodigo(
            'G-BC:SB-003',
            child: _Celda(
              ancho: _kAnchoDrift,
              child: _Segmento(
                color: Colors.amber.shade500,
                etiqueta: '1 drift',
              ),
            ),
          ),

          const Spacer(),

          // ── Lado derecho: progreso global + métricas ────────────
          if (proc.activo) ...[
            SeccionConCodigo(
              'G-BC:SB-005',
              child: _Celda(
                ancho: _kAnchoProgreso,
                child: _BarraProgreso(mensaje: proc.mensaje),
              ),
            ),
            _Separador(),
          ],
          SeccionConCodigo(
            'G-BC:SB-004',
            child: const _Metricas(),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Componentes internos
// ════════════════════════════════════════════════════════════

/// Celda de ancho fijo — garantiza alineación consistente en el grid.
class _Celda extends StatelessWidget {
  final double ancho;
  final Widget child;
  const _Celda({required this.ancho, required this.child});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).scaling;
    return SizedBox(width: ancho * s, child: child);
  }
}

/// Un segmento: punto de estado coloreado + etiqueta + texto monospace.
class _Segmento extends StatelessWidget {
  final Color color;
  final String etiqueta;
  final bool fuerte;
  final String? mono;
  const _Segmento({
    required this.color,
    required this.etiqueta,
    this.fuerte = false,
    this.mono,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s  = theme.scaling;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7 * s, height: 7 * s,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 7 * s),
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 11.5 * s,
            fontWeight: fuerte ? FontWeight.w600 : FontWeight.w400,
            color: fuerte ? cs.foreground : cs.mutedForeground,
          ),
        ),
        if (mono != null) ...[
          SizedBox(width: 7 * s),
          Text(
            mono!,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11 * s,
              color: cs.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }
}

/// Separador vertical entre celdas.
class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.scaling;
    return Container(
      width: 1,
      height: 14 * s,
      color: theme.colorScheme.border,
      margin: EdgeInsets.symmetric(horizontal: 10 * s),
    );
  }
}

/// G-BC:SB-005 — Barra de progreso global indeterminada.
/// Aparece cuando [procesamientoProvider].activo == true.
/// Usa [LinearProgressIndicator] de tf_shadcn_flutter con value=null (indeterminado).
class _BarraProgreso extends StatelessWidget {
  final String? mensaje;
  const _BarraProgreso({this.mensaje});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s  = theme.scaling;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Mensaje descriptivo de la tarea en curso.
        if (mensaje != null)
          Text(
            mensaje!,
            style: TextStyle(fontSize: 10.5 * s, color: cs.mutedForeground),
            overflow: TextOverflow.ellipsis,
          ),
        SizedBox(width: 10 * s),
        // Barra indeterminada del design system — value: null = animación automática.
        SizedBox(
          width: 100 * s,
          child: LinearProgressIndicator(
            value: null,
            minHeight: 3 * s,
            backgroundColor: cs.muted,
            color: cs.primary,
            borderRadius: BorderRadius.circular(2 * s),
          ),
        ),
      ],
    );
  }
}

/// G-BC:SB-004 — Métricas en vivo (eval/s · sesiones · roles).
class _Metricas extends StatelessWidget {
  const _Metricas();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s  = theme.scaling;

    Widget metrica(String valor, String rotulo) => Padding(
          padding: EdgeInsets.only(left: 16 * s),
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontFamily: 'monospace', fontSize: 11.5 * s),
              children: [
                TextSpan(text: valor, style: TextStyle(color: cs.foreground)),
                TextSpan(text: ' $rotulo',
                    style: TextStyle(color: cs.mutedForeground)),
              ],
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        metrica('142.857', 'eval/s'),
        metrica('89', 'sesiones'),
        metrica('366', 'roles'),
      ],
    );
  }
}
