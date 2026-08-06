// ============================================================
// bauth_desktop · widgets/shell/barra_superior.dart
//
// Propósito: TOP del bloque central (global, fijo) — G-BC-001.
//   Todos los objetos internos marcados con SeccionConCodigo (A.64.01):
//   G-BC-002 ToggleSidenav · G-BC-003 BuscadorGlobal · G-BC-004 ChipConexion
//   G-BC-005 ToggleTema · G-BC-012 ToggleCodigos (dev) · G-BC-006 Campanilla
//   G-BC-007 AvatarMenu
//
// G-BC-004 ChipConexion: estado real de pruebaConexionProvider (banexus→bhnexus:9444).
// Dependencias: flutter_riverpod, tf_shadcn_flutter, nucleo/sidenav_provider,
//   nucleo/conexion/prueba_conexion, widgets/comunes/{boton_icono,etiqueta_codigo}.
// Estándar: G-BC:TOP · A.64.01 §4 · SPA (shell) · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../nucleo/conexion/prueba_conexion.dart';
import '../../nucleo/sidenav_provider.dart';
import '../comunes/boton_icono.dart';
import '../comunes/etiqueta_codigo.dart';

/// G-BC-001 — Barra superior global (fija, 48px).
/// Contiene G-BC-002 a G-BC-007 etiquetados con SeccionConCodigo.
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
      decoration: BoxDecoration(
          color: cs.card, border: Border(bottom: BorderSide(color: cs.border))),
      child: Row(
        children: [
          // G-BC-002 — ToggleSidenav: colapsa/expande G-SN
          SeccionConCodigo(
            'G-BC-002',
            child: BotonIcono(
              icono: expandido
                  ? LucideIcons.chevronsLeft
                  : LucideIcons.chevronsRight,
              alTocar: () => ref.read(layoutProvider.notifier).alternarIzq(),
            ),
          ),

          const Spacer(),

          // G-BC-003 — BuscadorGlobal: input fondo muted + atajo ⌘K
          SeccionConCodigo('G-BC-003', child: const _Buscador()),

          SizedBox(width: 10 * s),

          // G-BC-004 — ChipConexion: estado real de banexus→bhnexus:9444
          SeccionConCodigo('G-BC-004', child: const _ChipConexion()),

          SizedBox(width: 10 * s),

          // G-BC-005 — ToggleTema: alterna claro/oscuro (presentacional)
          SeccionConCodigo(
            'G-BC-005',
            child: const BotonIcono(icono: LucideIcons.sun),
          ),

          SizedBox(width: 10 * s),

          // G-BC-012 — ToggleCodigos: muestra/oculta etiquetas A.64.01 (dev)
          SeccionConCodigo('G-BC-012', child: const _ToggleCodigos()),

          SizedBox(width: 10 * s),

          // G-BC-006 — Campanilla: notificaciones con punto rojo si hay alerta
          SeccionConCodigo(
            'G-BC-006',
            child: const BotonIcono(
                icono: LucideIcons.bell, insignia: _PuntoCritico()),
          ),

          SizedBox(width: 12 * s),

          // G-BC-007 — AvatarMenu: avatar + nombre + rol + ▾ (abre G-BC-008)
          SeccionConCodigo('G-BC-007', child: const _Perfil()),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// G-BC-012 — ToggleCodigos
// ══════════════════════════════════════════════════════════════════════════════

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
          border:
              Border.all(color: activo ? cs.primary : cs.border),
          borderRadius: BorderRadius.circular(8 * s),
        ),
        child: Center(
          child: Icon(LucideIcons.hash,
              size: 17 * s,
              color: activo ? cs.primary : cs.mutedForeground),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// G-BC-003 — BuscadorGlobal
// ══════════════════════════════════════════════════════════════════════════════

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
      decoration: BoxDecoration(
          color: cs.muted,
          border: Border.all(color: cs.border),
          borderRadius: BorderRadius.circular(9 * s)),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 15 * s, color: cs.mutedForeground),
          SizedBox(width: 8 * s),
          Expanded(
            child: Text('Buscar roles, usuarios, políticas…',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13 * s, color: cs.mutedForeground)),
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
      decoration: BoxDecoration(
          border: Border.all(color: cs.border),
          borderRadius: BorderRadius.circular(6 * s)),
      child: Text(texto,
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11 * s,
              color: cs.mutedForeground)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// G-BC-004 — ChipConexion (control único de conexión)
// ══════════════════════════════════════════════════════════════════════════════

/// G-BC-004 — Control único del canal bAuth (banexus → bhnexus:9444).
///
/// Estados visuales:
///   exitosa  — verde · "bhnexus:9444"   (no interactivo)
///   probando — ámbar · mensaje dinámico (no interactivo — auto-reconecta)
///   fallida  — rojo  · "Error · Reconectar" (clic → probar())
class _ChipConexion extends ConsumerWidget {
  const _ChipConexion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final resultado = ref.watch(pruebaConexionProvider);
    final fallida = resultado.fase == FaseConexion.fallida;

    final Color dotColor = switch (resultado.fase) {
      FaseConexion.exitosa  => Colors.green.shade500,
      FaseConexion.fallida  => cs.destructive,
      FaseConexion.probando => Colors.amber.shade500,
    };

    final String etiqueta = switch (resultado.fase) {
      FaseConexion.exitosa  => 'bhnexus:9444',
      FaseConexion.probando => resultado.mensaje, // "Conectando…" / "Reconectando…"
      FaseConexion.fallida  => 'Error · Reconectar',
    };

    return MouseRegion(
      cursor: fallida ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: fallida
            ? () => ref.read(pruebaConexionProvider.notifier).probar()
            : null,
        child: Container(
          height: 34 * s,
          padding: EdgeInsets.symmetric(horizontal: 11 * s),
          decoration: BoxDecoration(
            color: fallida
                ? cs.destructive.withValues(alpha: 0.08)
                : cs.muted,
            border: Border.all(
                color: fallida ? cs.destructive.withValues(alpha: 0.4) : cs.border),
            borderRadius: BorderRadius.circular(9 * s),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7 * s,
                height: 7 * s,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              SizedBox(width: 8 * s),
              Text(etiqueta,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12 * s,
                      color: fallida ? cs.destructive : cs.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// G-BC-006 — Campanilla (insignia)
// ══════════════════════════════════════════════════════════════════════════════

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
      decoration: BoxDecoration(
          color: cs.destructive,
          shape: BoxShape.circle,
          border: Border.all(color: cs.muted, width: 1.5 * s)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// G-BC-007 — AvatarMenu
// ══════════════════════════════════════════════════════════════════════════════

/// Perfil del usuario (avatar + nombre/rol + chevron).
/// Al tocar abre G-BC-008 MenuUsuarioDesplegable (pendiente).
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cs.primary, Colors.blue.shade400]),
            borderRadius: BorderRadius.circular(8 * s),
          ),
          child: Center(
            child: Text('SA',
                style: TextStyle(
                    fontSize: 12.5 * s,
                    fontWeight: FontWeight.w700,
                    color: cs.primaryForeground)),
          ),
        ),
        SizedBox(width: 9 * s),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('sbos-admin',
                style: TextStyle(
                    fontSize: 12.5 * s,
                    fontWeight: FontWeight.w600,
                    color: cs.foreground)),
            Text('Administrador',
                style:
                    TextStyle(fontSize: 10.5 * s, color: cs.mutedForeground)),
          ],
        ),
        SizedBox(width: 9 * s),
        Icon(LucideIcons.chevronDown, size: 15 * s, color: cs.mutedForeground),
      ],
    );
  }
}
