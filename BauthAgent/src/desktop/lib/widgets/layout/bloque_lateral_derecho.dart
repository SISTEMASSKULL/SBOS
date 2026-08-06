// ============================================================
// bauth_desktop · widgets/layout/bloque_lateral_derecho.dart
//
// Propósito: BLOQUE G-BD — panel lateral derecho colapsable (300px ↔ 76px).
//   Slots: G-BD:TOP (SelectorContexto) · G-BD:BOD (paneles contextuales)
//          G-BD:BOT (EstadoSesion).
//   El colapso lo controla layoutProvider.derExpandido (AnimatedContainer).
//   El toggle está en G-BC-013 (BarraSuperior), simétrico a G-BC-002.
// Dependencias: flutter_riverpod, tf_shadcn_flutter, nucleo/sidenav_provider,
//   widgets/comunes/etiqueta_codigo.
// Estándar: G-BD · A.64.01 §4 · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../nucleo/sidenav_provider.dart';
import '../comunes/etiqueta_codigo.dart';

/// Bloque lateral derecho G-BD — colapsable (300px ↔ 76px).
/// El colapso anima con AnimatedContainer + ClipRect.
/// Contenido contextual pendiente: G-BD-001..G-BD-008 (A.64.01 §4).
class BloqueLateralDerecho extends ConsumerWidget {
  const BloqueLateralDerecho({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final expandido = ref.watch(layoutProvider).derExpandido;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      width: expandido ? 300 * s : 76 * s,
      decoration: BoxDecoration(
        color: cs.card,
        border: Border(left: BorderSide(color: cs.border)),
      ),
      child: ClipRect(
        child: SizedBox(
          width: 300 * s,
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
        ),
      ),
    );
  }
}
