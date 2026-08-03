// ============================================================
// bauth_desktop · widgets/comunes/etiqueta_codigo.dart
//
// Propósito: sistema de referencia A.64.01 para el modo de desarrollo.
//   EtiquetaCodigo  — chip monospace que muestra el código de sección/objeto.
//   SeccionConCodigo — envuelve un widget con la etiqueta flotante en la
//   esquina superior izquierda, sin alterar el layout del hijo.
//   Ambos respetan mostrarCodigosProvider: invisibles cuando vale false.
// Dependencias: flutter_riverpod, tf_shadcn_flutter, nucleo/sidenav_provider.
// Estándar: A.64.01 · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../nucleo/sidenav_provider.dart';

/// Chip visual de código A.64.01 — widget puro, sin ConsumerWidget.
/// Se crea solo cuando los códigos están visibles (controlado por el padre).
class _ChipCodigo extends StatelessWidget {
  final String codigo;
  const _ChipCodigo(this.codigo);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4 * s, vertical: 1 * s),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(3 * s),
      ),
      child: Text(
        codigo,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9 * s,
          color: cs.primary.withValues(alpha: 0.75),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Chip de código A.64.01 para uso standalone (ej: dentro de una vista).
/// Retorna SizedBox.shrink cuando mostrarCodigosProvider = false.
class EtiquetaCodigo extends ConsumerWidget {
  final String codigo;
  const EtiquetaCodigo(this.codigo, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(mostrarCodigosProvider)) return const SizedBox.shrink();
    return _ChipCodigo(codigo);
  }
}

/// Envuelve [child] con una etiqueta de código A.64.01 flotante.
///
/// IMPORTANTE: devuelve SIEMPRE un Stack (nunca cambia de tipo).
/// Esto garantiza que el elemento hijo no se destruya cuando los
/// códigos se activan/desactivan — el estado de [child] se preserva.
/// La etiqueta se añade/quita como Positioned dentro del Stack existente.
class SeccionConCodigo extends ConsumerWidget {
  final String codigo;
  final Widget child;
  const SeccionConCodigo(this.codigo, {super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mostrar = ref.watch(mostrarCodigosProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (mostrar)
          Positioned(
            top: 3,
            left: 3,
            child: _ChipCodigo(codigo),
          ),
      ],
    );
  }
}
