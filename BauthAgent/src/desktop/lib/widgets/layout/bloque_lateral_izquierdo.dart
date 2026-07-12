// ============================================================
// bauth_desktop · widgets/layout/bloque_lateral_izquierdo.dart
//
// Propósito: BLOQUE 1 del viewport — sidenav izquierdo con TOP (logo), BODY
//   (nav de grupos + Configuración) y BOTTOM (estado del daemon). La expansión
//   y la ruta activa viven en `layoutProvider`; al tocar un ítem se fija su
//   ruta (que el bloque central observa). Tamaños con `theme.scaling`.
// Dependencias: tf_shadcn_flutter, flutter_riverpod, datos/menu_datos,
//   widgets/menu/fila_menu, nucleo/sidenav_provider.
// Estándar: prototipo bAuth Desktop · responsive · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../datos/menu_datos.dart';
import '../../nucleo/sidenav_provider.dart';
import '../menu/fila_menu.dart';

/// Bloque lateral izquierdo, expandible/colapsable (estado en el provider).
class BloqueLateralIzquierdo extends ConsumerWidget {
  const BloqueLateralIzquierdo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final estado = ref.watch(layoutProvider);
    final nav = ref.read(layoutProvider.notifier);
    final expandido = estado.izqExpandido;
    final ruta = estado.rutaActiva;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: (expandido ? 248.0 : 76.0) * s,
      decoration: BoxDecoration(color: cs.card, border: Border(right: BorderSide(color: cs.border))),
      child: ClipRect(
        child: Column(
          children: [
            _Encabezado(expandido: expandido, alAlternar: nav.alternarIzq),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 12 * s),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final g in gruposMenu) ...[
                            if (expandido) _TituloGrupo(titulo: g.titulo) else SizedBox(height: 8 * s),
                            for (final it in g.items)
                              FilaMenu(
                                item: it,
                                expandido: expandido,
                                activo: it.ruta == ruta,
                                alTocar: () => nav.seleccionarRuta(it.ruta),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(10 * s, 4 * s, 10 * s, 8 * s),
                    child: FilaMenu(
                      item: itemConfiguracion,
                      expandido: expandido,
                      activo: itemConfiguracion.ruta == ruta,
                      alTocar: () => nav.seleccionarRuta(itemConfiguracion.ruta),
                    ),
                  ),
                ],
              ),
            ),
            _Pie(expandido: expandido),
          ],
        ),
      ),
    );
  }
}

/// TOP: logo bAuth (+ nombre y subtítulo cuando está extendido).
class _Encabezado extends StatelessWidget {
  final bool expandido;
  final VoidCallback alAlternar;
  const _Encabezado({required this.expandido, required this.alAlternar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return GestureDetector(
      onTap: alAlternar,
      child: Container(
        height: 56 * s,
        padding: EdgeInsets.symmetric(horizontal: 16 * s),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.border))),
        child: Row(
          children: [
            Container(
              width: 30 * s,
              height: 30 * s,
              decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8 * s)),
              child: Center(child: Icon(LucideIcons.shieldCheck, size: 18 * s, color: cs.primary)),
            ),
            if (expandido) ...[
              SizedBox(width: 11 * s),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('bAuth', style: TextStyle(fontSize: 15 * s, fontWeight: FontWeight.w700, color: cs.foreground)),
                    Text('Control Plane', style: TextStyle(fontSize: 10.5 * s, color: cs.mutedForeground)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// BOTTOM: estado del daemon (punto verde + textos cuando está extendido).
class _Pie extends StatelessWidget {
  final bool expandido;
  const _Pie({required this.expandido});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      height: 48 * s,
      padding: EdgeInsets.symmetric(horizontal: 14 * s),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.border))),
      child: Row(
        children: [
          Container(
              width: 8 * s,
              height: 8 * s,
              decoration: BoxDecoration(color: Colors.green.shade500, shape: BoxShape.circle)),
          if (expandido) ...[
            SizedBox(width: 10 * s),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daemon operativo',
                      style: TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w600, color: cs.foreground)),
                  Text('v0.9.0 · uptime 99.9%',
                      style: TextStyle(fontSize: 10.5 * s, fontFamily: 'monospace', color: cs.mutedForeground)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Título de grupo (uppercase, solo visible en modo extendido).
class _TituloGrupo extends StatelessWidget {
  final String titulo;
  const _TituloGrupo({required this.titulo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Padding(
      padding: EdgeInsets.fromLTRB(8 * s, 12 * s, 8 * s, 4 * s),
      child: Text(titulo,
          style: TextStyle(fontSize: 10 * s, fontWeight: FontWeight.w600, letterSpacing: 1.2 * s, color: cs.mutedForeground)),
    );
  }
}
