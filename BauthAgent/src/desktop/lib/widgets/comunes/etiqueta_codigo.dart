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

/// Chip visual A.64.01 — widget puro (StatelessWidget, sin provider).
/// Solo se instancia cuando los códigos están activos.
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

/// Chip reactivo A.64.01: se muestra/oculta via Offstage según el toggle.
/// Al usar Offstage en vez de retornar tipos distintos, el elemento _ChipCodigo
/// nunca se destruye — solo cambia su visibilidad en el render tree.
class EtiquetaCodigo extends ConsumerWidget {
  final String codigo;
  const EtiquetaCodigo(this.codigo, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Offstage(
      offstage: !ref.watch(mostrarCodigosProvider),
      child: _ChipCodigo(codigo),
    );
  }
}

/// Envuelve [child] con una etiqueta A.64.01 flotante en la esquina.
///
/// Es un StatelessWidget PURO — no se suscribe a ningún provider.
/// Solo EtiquetaCodigo (el chip) escucha mostrarCodigosProvider.
/// Resultado: el toggle de códigos nunca reconstruye [child] ni a
/// SeccionConCodigo misma — solo actualiza el Offstage del chip.
class SeccionConCodigo extends StatelessWidget {
  final String codigo;
  final Widget child;
  const SeccionConCodigo(this.codigo, {super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: 3,
          left: 3,
          child: EtiquetaCodigo(codigo),
        ),
      ],
    );
  }
}
