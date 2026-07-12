// ============================================================
// bauth_desktop · widgets/config_tema.dart
//
// Propósito: contenido de Theme Options (sin contenedor propio) — se coloca
//   dentro del sidenav derecho (configuraciones). Modo, base, acento y radio
//   configurables en runtime.
// Dependencias: flutter_riverpod, tf_shadcn_flutter, core/theme, widgets.
// Estándar: DOC-SBOS-001 N3 · shadcn_flutter theme system.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../core/theme/sbos_tokens.dart';
import '../core/theme/theme_provider.dart';
import 'chip_opcion.dart';
import 'seccion_sbos.dart';

/// Panel de Theme Options — contenido para el sidenav derecho.
class ConfigTema extends ConsumerWidget {
  const ConfigTema({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(opcionesTemaProvider);
    final n = ref.read(opcionesTemaProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Opciones de Tema',
            style: TextStyle(color: cs.foreground, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        SeccionSbos(titulo: 'Modo', hijos: _chipsModo(o, n)),
        SeccionSbos(titulo: 'Color base', hijos: _chipsBase(o, n)),
        SeccionSbos(titulo: 'Acento', hijos: _chipsAcento(o, n)),
        SeccionSbos(titulo: 'Radio', hijos: _chipsRadio(o, n)),
      ],
    );
  }

  List<Widget> _chipsModo(OpcionesTema o, OpcionesTemaNotifier n) => [
        ChipOpcion(etiqueta: 'Oscuro', seleccionado: o.modo == ThemeMode.dark, alElegir: () => n.fijarModo(ThemeMode.dark)),
        ChipOpcion(etiqueta: 'Claro', seleccionado: o.modo == ThemeMode.light, alElegir: () => n.fijarModo(ThemeMode.light)),
        ChipOpcion(etiqueta: 'Sistema', seleccionado: o.modo == ThemeMode.system, alElegir: () => n.fijarModo(ThemeMode.system)),
      ];

  List<Widget> _chipsBase(OpcionesTema o, OpcionesTemaNotifier n) => [
        for (final b in TokensSbos.basesDisponibles)
          ChipOpcion(etiqueta: b, seleccionado: o.base == b, alElegir: () => n.fijarBase(b)),
      ];

  List<Widget> _chipsAcento(OpcionesTema o, OpcionesTemaNotifier n) => [
        for (final e in TokensSbos.acentosDisponibles.entries)
          ChipOpcion(etiqueta: e.key, muestra: e.value, seleccionado: o.acento == e.value, alElegir: () => n.fijarAcento(e.value)),
      ];

  List<Widget> _chipsRadio(OpcionesTema o, OpcionesTemaNotifier n) => [
        for (final r in const [0.0, 0.25, 0.5, 0.75, 1.0])
          ChipOpcion(etiqueta: r.toStringAsFixed(2), seleccionado: (o.radio - r).abs() < 0.01, alElegir: () => n.fijarRadio(r)),
      ];
}
