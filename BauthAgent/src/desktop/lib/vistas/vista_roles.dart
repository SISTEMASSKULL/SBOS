// ============================================================
// bauth_desktop · vistas/vista_roles.dart
//
// Propósito: VISTA §7 — «Completitud de Roles».
//   Permite especializar cada rol: métodos, átomos y saga de autenticación.
//   El RolTemplate es ÚNICO — el OUTLET es una lente filtrada por rol.
//
// Layout: 2 bloques.
//   Bloque 1 (izq, fijo): árbol jerárquico de roles, solo lectura.
//     → CRUD de idn_role_template pertenece a §6 — no aquí.
//   Bloque 2 (der, flex): TOP (rol activo) + OUTLET (filtrado) + BOTTOM (acciones).
//
// Pendiente: contenido del OUTLET (Métodos / Átomos / Saga) — organización
//   no definida todavía; las secciones existen en A.64 §7 como tabs
//   marcados pendientes. El OUTLET se renderiza como marcador hasta su definición.
//
// Dependencias: flutter_riverpod, tf_shadcn_flutter, proveedor_conexion.
// Estándar: A.64 §7 · bauth.idn_role_template · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../nucleo/api/bauth_api.dart';
import '../nucleo/conexion/proveedor_conexion.dart';

/// Orden canónico de tiers — de mayor a menor privilegio.
const _ordenTiers = ['SU', 'SYS', 'BIZ_N5', 'BIZ_N4', 'BIZ_N3', 'BIZ_N2', 'BIZ_N1', 'EXT_N0', 'M2M', 'VISITANTE'];

/// Índice de nivel visual por tier (indentación del árbol).
const _nivelTier = {
  'SU': 0, 'SYS': 1,
  'BIZ_N5': 2, 'BIZ_N4': 2, 'BIZ_N3': 2, 'BIZ_N2': 2, 'BIZ_N1': 2,
  'EXT_N0': 3, 'M2M': 3, 'VISITANTE': 3,
};

/// Vista «Completitud de Roles» — §7 de la especificación bAuth Desktop.
class VistaRoles extends ConsumerStatefulWidget {
  const VistaRoles({super.key});
  @override
  ConsumerState<VistaRoles> createState() => _VistaRolesState();
}

class _VistaRolesState extends ConsumerState<VistaRoles> {
  RolInfo? _rolActivo;

  void _seleccionarRol(RolInfo rol) {
    setState(() => _rolActivo = rol);
  }

  void _publicar() {
    // Pendiente: lógica de publicar — agregar rol al SET del nodo equivalente
    // o crear nodo nuevo con SET({rol_activo}). Requiere OUTLET implementado.
  }

  void _cancelar() {
    // Pendiente: descartar cambios del OUTLET.
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _BloqueJerarquia(
          rolActivo: _rolActivo,
          alSeleccionar: _seleccionarRol,
          alAutoSeleccionar: _seleccionarRol,
        ),
        Container(width: 1, color: cs.border),
        Expanded(
          child: _BloqueEspecializacion(
            rolActivo: _rolActivo,
            alPublicar: _publicar,
            alCancelar: _cancelar,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Bloque 1 — Árbol jerárquico de roles (solo lectura)
// ═══════════════════════════════════════════════════════════════════════

/// Bloque izquierdo: jerarquía de roles agrupada por tier.
/// Proxy de la jerarquía real (parent_id) hasta que el API la exponga.
class _BloqueJerarquia extends ConsumerStatefulWidget {
  final RolInfo? rolActivo;
  final ValueChanged<RolInfo> alSeleccionar;
  final ValueChanged<RolInfo> alAutoSeleccionar;

  const _BloqueJerarquia({
    required this.rolActivo,
    required this.alSeleccionar,
    required this.alAutoSeleccionar,
  });

  @override
  ConsumerState<_BloqueJerarquia> createState() => _BloqueJerarquiaState();
}

class _BloqueJerarquiaState extends ConsumerState<_BloqueJerarquia> {
  bool _autoSeleccionado = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final async = ref.watch(rolesProvider);

    return SizedBox(
      width: 280 * s,
      child: Column(
        children: [
          _EncabezadoBloque(titulo: 'JERARQUÍA DE ROLES', subtitulo: 'idn_role_template'),
          Container(height: 1, color: cs.border),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorCarga(mensaje: '$e'),
              data: (roles) {
                _autoSeleccionarPrimero(roles);
                return _ArbolTiers(
                  roles: roles,
                  rolActivo: widget.rolActivo,
                  alSeleccionar: widget.alSeleccionar,
                );
              },
            ),
          ),
          _PieBloqueRoles(async: async, rolActivo: widget.rolActivo),
        ],
      ),
    );
  }

  void _autoSeleccionarPrimero(List<RolInfo> roles) {
    if (_autoSeleccionado || roles.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final primero = _primerRolEnOrden(roles);
      if (primero != null) widget.alAutoSeleccionar(primero);
    });
    _autoSeleccionado = true;
  }

  RolInfo? _primerRolEnOrden(List<RolInfo> roles) {
    for (final tier in _ordenTiers) {
      final enTier = roles.where((r) => r.tier == tier).toList();
      if (enTier.isNotEmpty) return enTier.first;
    }
    return roles.first;
  }
}

/// Árbol de roles organizados por tier (proxy de jerarquía real).
class _ArbolTiers extends StatefulWidget {
  final List<RolInfo> roles;
  final RolInfo? rolActivo;
  final ValueChanged<RolInfo> alSeleccionar;

  const _ArbolTiers({required this.roles, required this.rolActivo, required this.alSeleccionar});

  @override
  State<_ArbolTiers> createState() => _ArbolTiersState();
}

class _ArbolTiersState extends State<_ArbolTiers> {
  final Set<String> _expandidos = {..._ordenTiers};

  void _toggleTier(String tier) {
    setState(() {
      if (_expandidos.contains(tier)) {
        _expandidos.remove(tier);
      } else {
        _expandidos.add(tier);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tiersConRoles = _ordenTiers
        .where((t) => widget.roles.any((r) => r.tier == t))
        .toList();

    return ListView(
      children: [
        for (final tier in tiersConRoles) ...[
          _CabeceraTier(
            tier: tier,
            nivel: _nivelTier[tier] ?? 0,
            expandido: _expandidos.contains(tier),
            alTogglear: () => _toggleTier(tier),
          ),
          if (_expandidos.contains(tier))
            ...widget.roles
                .where((r) => r.tier == tier)
                .map((r) => _FilaRolArbol(
                      rol: r,
                      activo: widget.rolActivo?.id == r.id,
                      nivel: (_nivelTier[tier] ?? 0) + 1,
                      alSeleccionar: () => widget.alSeleccionar(r),
                    )),
        ],
      ],
    );
  }
}

class _CabeceraTier extends StatelessWidget {
  final String tier;
  final int nivel;
  final bool expandido;
  final VoidCallback alTogglear;

  const _CabeceraTier({
    required this.tier,
    required this.nivel,
    required this.expandido,
    required this.alTogglear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return GestureDetector(
      onTap: alTogglear,
      child: Container(
        color: cs.muted.withValues(alpha: 0.4),
        padding: EdgeInsets.only(left: (12 + nivel * 12.0) * s, top: 5 * s, bottom: 5 * s, right: 8 * s),
        child: Row(
          children: [
            Icon(expandido ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                size: 11 * s, color: cs.mutedForeground),
            SizedBox(width: 6 * s),
            Text(tier,
                style: TextStyle(
                    fontSize: 10 * s,
                    fontWeight: FontWeight.w700,
                    color: cs.mutedForeground,
                    letterSpacing: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _FilaRolArbol extends StatelessWidget {
  final RolInfo rol;
  final bool activo;
  final int nivel;
  final VoidCallback alSeleccionar;

  const _FilaRolArbol({
    required this.rol,
    required this.activo,
    required this.nivel,
    required this.alSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return GestureDetector(
      onTap: alSeleccionar,
      child: Container(
        color: activo ? cs.primary.withValues(alpha: 0.12) : null,
        padding: EdgeInsets.only(
            left: (12 + nivel * 12.0) * s, top: 7 * s, bottom: 7 * s, right: 10 * s),
        child: Row(
          children: [
            Icon(
              activo ? LucideIcons.circle : LucideIcons.minus,
              size: 8 * s,
              color: activo ? cs.primary : cs.border,
            ),
            SizedBox(width: 7 * s),
            Expanded(
              child: Text(
                rol.nombre,
                style: TextStyle(
                    fontSize: 12 * s,
                    fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                    color: activo ? cs.primary : cs.foreground),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Bloque 2 — TOP / OUTLET / BOTTOM
// ═══════════════════════════════════════════════════════════════════════

/// Bloque derecho: TOP (rol activo) + OUTLET (filtrado) + BOTTOM (acciones).
class _BloqueEspecializacion extends StatelessWidget {
  final RolInfo? rolActivo;
  final VoidCallback alPublicar;
  final VoidCallback alCancelar;

  const _BloqueEspecializacion({
    required this.rolActivo,
    required this.alPublicar,
    required this.alCancelar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _TopRolActivo(rol: rolActivo),
        Container(height: 1, color: cs.border),
        Expanded(child: _OutletContenido(rolActivo: rolActivo)),
        Container(height: 1, color: cs.border),
        _BottomAcciones(alPublicar: alPublicar, alCancelar: alCancelar, habilitado: rolActivo != null),
      ],
    );
  }
}

/// TOP — muestra el id/nombre del rol seleccionado. Nunca vacío (auto-selección).
class _TopRolActivo extends StatelessWidget {
  final RolInfo? rol;
  const _TopRolActivo({required this.rol});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final etiqueta = rol == null ? '— sin selección —' : rol!.nombre;
    final id = rol?.id ?? '';
    return Container(
      height: 44 * s,
      color: cs.muted.withValues(alpha: 0.3),
      padding: EdgeInsets.symmetric(horizontal: 16 * s),
      child: Row(
        children: [
          if (rol?.tier != null) ...[
            _PillTier(tier: rol!.tier!),
            SizedBox(width: 10 * s),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta,
                    style: TextStyle(
                        fontSize: 13 * s,
                        fontWeight: FontWeight.w600,
                        color: rol == null ? cs.mutedForeground : cs.foreground)),
                if (id.isNotEmpty)
                  Text(id,
                      style: TextStyle(
                          fontSize: 10 * s,
                          color: cs.mutedForeground,
                          fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// OUTLET — vista filtrada del template único por rol seleccionado.
/// Contenido de secciones (Métodos / Átomos / Saga) pendiente de definición (A.64 §7).
class _OutletContenido extends StatelessWidget {
  final RolInfo? rolActivo;
  const _OutletContenido({required this.rolActivo});

  @override
  Widget build(BuildContext context) {
    if (rolActivo == null) return const _SinRolSeleccionado();
    return _PendienteDefinicion(rol: rolActivo!);
  }
}

/// Placeholder: rol seleccionado pero el contenido del OUTLET no está definido aún.
class _PendienteDefinicion extends StatelessWidget {
  final RolInfo rol;
  const _PendienteDefinicion({required this.rol});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.layoutList, size: 36 * s, color: cs.mutedForeground.withValues(alpha: 0.3)),
          SizedBox(height: 16 * s),
          Text('Especialización de ${rol.nombre}',
              style: TextStyle(fontSize: 14 * s, fontWeight: FontWeight.w600, color: cs.foreground)),
          SizedBox(height: 8 * s),
          Text('Secciones pendientes de definición',
              style: TextStyle(fontSize: 11 * s, color: cs.mutedForeground)),
          SizedBox(height: 20 * s),
          _ChipsPendientes(s: s, cs: cs),
          SizedBox(height: 16 * s),
          _NotaFiltro(s: s, cs: cs),
        ],
      ),
    );
  }
}

/// Chips que muestran qué secciones están pendientes de definición en OUTLET.
class _ChipsPendientes extends StatelessWidget {
  final double s;
  final ColorScheme cs;
  const _ChipsPendientes({required this.s, required this.cs});

  @override
  Widget build(BuildContext context) {
    const secciones = ['Métodos', 'Átomos', 'Saga de Autenticación'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: secciones
          .map((sec) => Container(
                margin: EdgeInsets.symmetric(horizontal: 4 * s),
                padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 5 * s),
                decoration: BoxDecoration(
                  border: Border.all(color: cs.border),
                  borderRadius: BorderRadius.circular(6 * s),
                  color: cs.muted.withValues(alpha: 0.3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.clock3, size: 10 * s, color: cs.mutedForeground),
                    SizedBox(width: 5 * s),
                    Text(sec,
                        style: TextStyle(
                            fontSize: 11 * s,
                            color: cs.mutedForeground,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

/// Nota explicativa del filtro que aplicará el OUTLET al estar implementado.
class _NotaFiltro extends StatelessWidget {
  final double s;
  final ColorScheme cs;
  const _NotaFiltro({required this.s, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380 * s,
      padding: EdgeInsets.all(12 * s),
      decoration: BoxDecoration(
        color: cs.muted.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6 * s),
        border: Border.all(color: cs.border),
      ),
      child: Text(
        'El OUTLET mostrará el RolTemplate global filtrado para este rol.\n'
        'Reglas: nodos sin SET (universales) siempre visibles · nodos con SET '
        'que incluya este rol visibles (●) · UNSET excluye explícitamente.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10.5 * s, height: 1.6, color: cs.mutedForeground),
      ),
    );
  }
}

/// Estado vacío: ningún rol seleccionado aún.
class _SinRolSeleccionado extends StatelessWidget {
  const _SinRolSeleccionado();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.shield, size: 28 * s, color: cs.mutedForeground),
          SizedBox(height: 8 * s),
          Text('Selecciona un rol en el árbol',
              style: TextStyle(fontSize: 13 * s, color: cs.mutedForeground)),
        ],
      ),
    );
  }
}

/// BOTTOM — botones de acción: [Publicar] y [Cancelar].
class _BottomAcciones extends StatelessWidget {
  final VoidCallback alPublicar;
  final VoidCallback alCancelar;
  final bool habilitado;

  const _BottomAcciones({
    required this.alPublicar,
    required this.alCancelar,
    required this.habilitado,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      height: 48 * s,
      color: cs.muted.withValues(alpha: 0.2),
      padding: EdgeInsets.symmetric(horizontal: 16 * s),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _BotonBottom(
            etiqueta: 'Cancelar',
            icono: LucideIcons.x,
            primario: false,
            habilitado: habilitado,
            alPresionar: alCancelar,
            cs: cs,
            s: s,
          ),
          SizedBox(width: 10 * s),
          _BotonBottom(
            etiqueta: 'Publicar',
            icono: LucideIcons.upload,
            primario: true,
            habilitado: habilitado,
            alPresionar: alPublicar,
            cs: cs,
            s: s,
          ),
        ],
      ),
    );
  }
}

class _BotonBottom extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  final bool primario;
  final bool habilitado;
  final VoidCallback alPresionar;
  final ColorScheme cs;
  final double s;

  const _BotonBottom({
    required this.etiqueta,
    required this.icono,
    required this.primario,
    required this.habilitado,
    required this.alPresionar,
    required this.cs,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final alpha = habilitado ? 1.0 : 0.4;
    return GestureDetector(
      onTap: habilitado ? alPresionar : null,
      child: MouseRegion(
        cursor: habilitado ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 7 * s),
          decoration: BoxDecoration(
            color: primario
                ? cs.primary.withValues(alpha: alpha)
                : cs.muted.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(6 * s),
            border: primario ? null : Border.all(color: cs.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono,
                  size: 12 * s,
                  color: primario
                      ? cs.primaryForeground.withValues(alpha: alpha)
                      : cs.foreground.withValues(alpha: alpha)),
              SizedBox(width: 6 * s),
              Text(etiqueta,
                  style: TextStyle(
                      fontSize: 12 * s,
                      fontWeight: FontWeight.w600,
                      color: primario
                          ? cs.primaryForeground.withValues(alpha: alpha)
                          : cs.foreground.withValues(alpha: alpha))),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Widgets auxiliares compartidos
// ═══════════════════════════════════════════════════════════════════════

class _EncabezadoBloque extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  const _EncabezadoBloque({required this.titulo, required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      height: 44 * s,
      color: cs.muted.withValues(alpha: 0.3),
      padding: EdgeInsets.symmetric(horizontal: 12 * s),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(
                  fontSize: 10 * s,
                  fontWeight: FontWeight.w700,
                  color: cs.mutedForeground,
                  letterSpacing: 0.6)),
          Text(subtitulo,
              style: TextStyle(
                  fontSize: 9.5 * s,
                  color: cs.mutedForeground.withValues(alpha: 0.6),
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

class _PieBloqueRoles extends StatelessWidget {
  final AsyncValue<List<RolInfo>> async;
  final RolInfo? rolActivo;
  const _PieBloqueRoles({required this.async, required this.rolActivo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      height: 32 * s,
      color: cs.muted.withValues(alpha: 0.2),
      padding: EdgeInsets.symmetric(horizontal: 12 * s),
      child: async.maybeWhen(
        data: (roles) => Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${roles.length} roles${rolActivo != null ? " · ${rolActivo!.tier ?? "?"}" : ""}',
            style: TextStyle(fontSize: 10 * s, color: cs.mutedForeground),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}

class _ErrorCarga extends StatelessWidget {
  final String mensaje;
  const _ErrorCarga({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Center(
      child: Text('Error: $mensaje',
          style: TextStyle(fontSize: 12 * s, color: cs.destructive)),
    );
  }
}

class _PillTier extends StatelessWidget {
  final String tier;
  const _PillTier({required this.tier});

  Color _bg(ColorScheme cs) => switch (tier) {
        'SU' || 'SYS' => cs.destructive.withValues(alpha: 0.15),
        'BIZ_N5' || 'BIZ_N4' => cs.primary.withValues(alpha: 0.12),
        _ => cs.muted,
      };

  Color _fg(ColorScheme cs) => switch (tier) {
        'SU' || 'SYS' => cs.destructive,
        'BIZ_N5' || 'BIZ_N4' => cs.primary,
        _ => cs.mutedForeground,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7 * s, vertical: 2 * s),
      decoration: BoxDecoration(
        color: _bg(cs),
        borderRadius: BorderRadius.circular(4 * s),
      ),
      child: Text(tier,
          style: TextStyle(
              fontSize: 10 * s, fontWeight: FontWeight.w700, color: _fg(cs))),
    );
  }
}
