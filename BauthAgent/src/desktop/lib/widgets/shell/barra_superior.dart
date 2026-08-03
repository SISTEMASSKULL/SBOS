// ============================================================
// bauth_desktop · widgets/shell/barra_superior.dart
//
// Propósito: TOP del bloque central (global, fijo) — conmutador del bloque
//   izquierdo (‹‹), buscador, chip de conexión, tema, toggle de códigos A.64.01,
//   notificaciones y perfil. No depende de la vista. `scaling`.
// Dependencias: flutter_riverpod, tf_shadcn_flutter, nucleo/sidenav_provider,
//   widgets/comunes/boton_icono.
// Estándar: G-BC:TOP · A.64.01 · SPA (shell) · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../nucleo/sidenav_provider.dart';
import '../comunes/boton_icono.dart';

/// Barra superior global (fija).
class BarraSuperior extends ConsumerWidget {
  const BarraSuperior({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final expandido = ref.watch(layoutProvider).izqExpandido;
    return Container(
      height: 48 * s,
      padding: EdgeInsets.symmetric(horizontal: 14 * s),
      decoration: BoxDecoration(color: cs.card, border: Border(bottom: BorderSide(color: cs.border))),
      child: Row(
        children: [
          BotonIcono(
            icono: expandido ? LucideIcons.chevronsLeft : LucideIcons.chevronsRight,
            alTocar: () => ref.read(layoutProvider.notifier).alternarIzq(),
          ),
          const Spacer(),
          const _Buscador(),
          SizedBox(width: 10 * s),
          const _ChipConexion(),
          SizedBox(width: 10 * s),
          const BotonIcono(icono: LucideIcons.sun),
          SizedBox(width: 10 * s),
          const _ToggleCodigos(),
          SizedBox(width: 10 * s),
          const BotonIcono(icono: LucideIcons.bell, insignia: _PuntoCritico()),
          SizedBox(width: 12 * s),
          const _Perfil(),
        ],
      ),
    );
  }
}

/// Toggle A.64.01 — muestra/oculta las etiquetas de código de sección.
/// Activo: fondo e ícono en color primario. Inactivo: fondo muted.
class _ToggleCodigos extends ConsumerWidget {
  const _ToggleCodigos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final activo = ref.watch(mostrarCodigosProvider);
    return GestureDetector(
      onTap: () => ref.read(mostrarCodigosProvider.notifier).alternar(),
      child: Container(
        width: 34 * s,
        height: 34 * s,
        decoration: BoxDecoration(
          color: activo ? cs.primary.withValues(alpha: 0.12) : cs.muted,
          border: Border.all(color: activo ? cs.primary : cs.border),
          borderRadius: BorderRadius.circular(8 * s),
        ),
        child: Center(
          child: Icon(LucideIcons.hash, size: 17 * s,
              color: activo ? cs.primary : cs.mutedForeground),
        ),
      ),
    );
  }
}

/// Campo de búsqueda con atajo ⌘K (presentacional).
class _Buscador extends StatelessWidget {
  const _Buscador();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      width: 320 * s,
      height: 36 * s,
      padding: EdgeInsets.symmetric(horizontal: 11 * s),
      decoration: BoxDecoration(color: cs.muted, border: Border.all(color: cs.border), borderRadius: BorderRadius.circular(9 * s)),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 15 * s, color: cs.mutedForeground),
          SizedBox(width: 8 * s),
          Expanded(
            child: Text('Buscar roles, usuarios, políticas…',
                overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13 * s, color: cs.mutedForeground)),
          ),
          SizedBox(width: 8 * s),
          _Tecla(texto: '⌘K'),
        ],
      ),
    );
  }
}

/// Tecla/atajo en recuadro monospace.
class _Tecla extends StatelessWidget {
  final String texto;
  const _Tecla({required this.texto});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 2 * s),
      decoration: BoxDecoration(border: Border.all(color: cs.border), borderRadius: BorderRadius.circular(6 * s)),
      child: Text(texto, style: TextStyle(fontFamily: 'monospace', fontSize: 11 * s, color: cs.mutedForeground)),
    );
  }
}

/// Chip de conexión al daemon.
class _ChipConexion extends StatelessWidget {
  const _ChipConexion();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      height: 34 * s,
      padding: EdgeInsets.symmetric(horizontal: 11 * s),
      decoration: BoxDecoration(color: cs.muted, border: Border.all(color: cs.border), borderRadius: BorderRadius.circular(9 * s)),
      child: Row(
        children: [
          Container(width: 7 * s, height: 7 * s, decoration: BoxDecoration(color: Colors.green.shade500, shape: BoxShape.circle)),
          SizedBox(width: 8 * s),
          Text('13.140.128.230:9450', style: TextStyle(fontFamily: 'monospace', fontSize: 12 * s, color: cs.mutedForeground)),
        ],
      ),
    );
  }
}

/// Punto rojo de notificación (insignia de la campana).
class _PuntoCritico extends StatelessWidget {
  const _PuntoCritico();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      width: 7 * s,
      height: 7 * s,
      decoration: BoxDecoration(color: cs.destructive, shape: BoxShape.circle, border: Border.all(color: cs.muted, width: 1.5 * s)),
    );
  }
}

/// Perfil del usuario (avatar + nombre/rol + chevron).
class _Perfil extends StatelessWidget {
  const _Perfil();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32 * s,
          height: 32 * s,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primary, Colors.blue.shade400]),
            borderRadius: BorderRadius.circular(8 * s),
          ),
          child: Center(
              child: Text('SA', style: TextStyle(fontSize: 12.5 * s, fontWeight: FontWeight.w700, color: cs.primaryForeground))),
        ),
        SizedBox(width: 9 * s),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('sbos-admin', style: TextStyle(fontSize: 12.5 * s, fontWeight: FontWeight.w600, color: cs.foreground)),
            Text('Administrador', style: TextStyle(fontSize: 10.5 * s, color: cs.mutedForeground)),
          ],
        ),
        SizedBox(width: 9 * s),
        Icon(LucideIcons.chevronDown, size: 15 * s, color: cs.mutedForeground),
      ],
    );
  }
}
