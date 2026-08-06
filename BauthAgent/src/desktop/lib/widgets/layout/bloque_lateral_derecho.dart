// ============================================================
// bauth_desktop · widgets/layout/bloque_lateral_derecho.dart
//
// Propósito: BLOQUE G-BD (300px fijo) — panel lateral derecho de acciones.
//   Slots: G-BD:TOP (SelectorContexto) · G-BD:BOD (paneles contextuales)
//          G-BD:BOT (EstadoSesion).
//   El estado de conexión fue consolidado en G-BC-004 — este bloque
//   está reservado para: Config · Herramientas · AtomLang · Uso · Ayuda.
// Dependencias: tf_shadcn_flutter, widgets/comunes/etiqueta_codigo.
// Estándar: G-BD · A.64.01 §4 · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../comunes/etiqueta_codigo.dart';

/// Bloque lateral derecho G-BD (300px).
/// Contenido contextual pendiente: G-BD-001..G-BD-008 (A.64.01 §4).
class BloqueLateralDerecho extends StatelessWidget {
  const BloqueLateralDerecho({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      width: 300 * s,
      decoration: BoxDecoration(
        color: cs.card,
        border: Border(left: BorderSide(color: cs.border)),
      ),
      child: Column(
        children: [
          // G-BD:TOP — SelectorContexto (pendiente G-BD-001)
          SeccionConCodigo(
            'G-BD:TOP',
            child: Container(
              height: 48 * s,
              padding: EdgeInsets.symmetric(horizontal: 14 * s),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: cs.border))),
              child: Row(
                children: [
                  Icon(LucideIcons.settings2,
                      size: 15 * s, color: cs.mutedForeground),
                  SizedBox(width: 8 * s),
                  Text('Acciones',
                      style: TextStyle(
                          fontSize: 13 * s,
                          fontWeight: FontWeight.w600,
                          color: cs.foreground)),
                  const Spacer(),
                  Icon(LucideIcons.chevronDown,
                      size: 14 * s, color: cs.mutedForeground),
                ],
              ),
            ),
          ),

          // G-BD:BOD — contenido contextual (pendiente G-BD-002..007)
          Expanded(
            child: SeccionConCodigo(
              'G-BD:BOD',
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.layoutTemplate,
                        size: 28 * s,
                        color: cs.mutedForeground.withValues(alpha: 0.4)),
                    SizedBox(height: 10 * s),
                    Text('Paneles en desarrollo',
                        style: TextStyle(
                            fontSize: 12 * s,
                            color: cs.mutedForeground
                                .withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ),
          ),

          // G-BD:BOT — EstadoSesion (pendiente G-BD-008)
          SeccionConCodigo(
            'G-BD:BOT',
            child: Container(
              height: 36 * s,
              padding: EdgeInsets.symmetric(horizontal: 14 * s),
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: cs.border))),
              child: Row(
                children: [
                  Container(
                    width: 7 * s,
                    height: 7 * s,
                    decoration: BoxDecoration(
                        color: cs.mutedForeground.withValues(alpha: 0.3),
                        shape: BoxShape.circle),
                  ),
                  SizedBox(width: 8 * s),
                  Text('Sesión',
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11 * s,
                          color: cs.mutedForeground)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
