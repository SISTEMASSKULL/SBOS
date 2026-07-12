// ============================================================
// bauth_desktop · widgets/shell/barra_breadcrumb.dart
//
// Propósito: barra de contexto del bloque central — muestra «Control Plane /
//   {ruta activa}». Cambia con la navegación, sobre el outlet. `scaling`.
// Dependencias: flutter_riverpod, tf_shadcn_flutter, datos/menu_datos,
//   nucleo/sidenav_provider.
// Estándar: prototipo bAuth Desktop · SPA (shell) · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../datos/menu_datos.dart';
import '../../nucleo/sidenav_provider.dart';

/// Barra de breadcrumb (Control Plane / ruta activa).
class BarraBreadcrumb extends ConsumerWidget {
  const BarraBreadcrumb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final titulo = etiquetaDeRuta(ref.watch(layoutProvider).rutaActiva);
    final tenue = TextStyle(fontSize: 13 * s, color: cs.mutedForeground);
    return Container(
      height: 40 * s,
      padding: EdgeInsets.symmetric(horizontal: 18 * s),
      decoration: BoxDecoration(color: cs.background, border: Border(bottom: BorderSide(color: cs.border))),
      child: Row(
        children: [
          Text('Control Plane', style: tenue),
          SizedBox(width: 8 * s),
          Text('/', style: tenue),
          SizedBox(width: 8 * s),
          Flexible(
            child: Text(titulo,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.w600, color: cs.foreground)),
          ),
        ],
      ),
    );
  }
}
