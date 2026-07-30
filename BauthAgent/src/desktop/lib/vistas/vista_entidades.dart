// ============================================================
// bauth_desktop · vistas/vista_entidades.dart
//
// Propósito: VISTA «Árbol de Entidades» — jerarquía universal de
//   identidad D00: tenant → bdomain → bsubdomain → pos → actor.
//   Todo es una entidad; el tipo y nivel diferencian qué es.
//   Panel izquierdo: árbol expandible con badges de nivel.
//   Panel derecho: detalle de la entidad seleccionada.
//
// Dependencias: tf_shadcn_flutter, flutter_riverpod,
//   proveedor_conexion, bauth_api.
// Estándar: D00 Identidad Organizacional (1.06 v2.0) ·
//   idn_identity_entity (5 niveles) · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../nucleo/api/bauth_api.dart';
import '../nucleo/conexion/proveedor_conexion.dart';

// ═══════════════════════════════════════════════════════════
// Vista principal
// ═══════════════════════════════════════════════════════════

/// Vista del árbol universal de entidades D00.
class VistaEntidades extends ConsumerStatefulWidget {
  const VistaEntidades({super.key});
  @override
  ConsumerState<VistaEntidades> createState() => _VistaEntidadesState();
}

class _VistaEntidadesState extends ConsumerState<VistaEntidades> {
  EntidadInfo? _seleccionada;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).scaling;
    return Row(
      children: [
        SizedBox(
          width: 340 * s,
          child: _PanelArbol(
            seleccionada: _seleccionada,
            onSeleccion: (e) => setState(() => _seleccionada = e),
          ),
        ),
        Container(width: 1, color: Theme.of(context).colorScheme.border),
        Expanded(
          child: _seleccionada == null
              ? const _SinSeleccion()
              : _PanelDetalle(entidad: _seleccionada!),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Panel izquierdo — árbol
// ═══════════════════════════════════════════════════════════

class _PanelArbol extends ConsumerWidget {
  final EntidadInfo? seleccionada;
  final ValueChanged<EntidadInfo> onSeleccion;

  const _PanelArbol({required this.seleccionada, required this.onSeleccion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final async = ref.watch(arbolEntidadesProvider);

    return Column(
      children: [
        _BarraCabecera(s: s, cs: cs),
        Container(height: 1, color: cs.border),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorArbol(mensaje: e.toString()),
            data: (raices) => raices.isEmpty
                ? _VacioMensaje(cs: cs, s: s, texto: 'Sin entidades registradas')
                : ListView(
                    padding: EdgeInsets.symmetric(vertical: 4 * s),
                    children: raices
                        .map((e) => _NodoEntidad(
                              entidad: e,
                              profundidad: 0,
                              seleccionada: seleccionada,
                              onSeleccion: onSeleccion,
                            ))
                        .toList(),
                  ),
          ),
        ),
        _BarraPie(async: async, s: s, cs: cs),
      ],
    );
  }
}

class _BarraCabecera extends StatelessWidget {
  final double s;
  final ColorScheme cs;
  const _BarraCabecera({required this.s, required this.cs});

  @override
  Widget build(BuildContext context) => Container(
        height: 40 * s,
        padding: EdgeInsets.symmetric(horizontal: 14 * s),
        color: cs.muted.withValues(alpha: 0.4),
        child: Row(
          children: [
            Icon(LucideIcons.gitBranch, size: 14 * s, color: cs.mutedForeground),
            SizedBox(width: 8 * s),
            Text('Árbol de Entidades',
                style: TextStyle(
                    fontSize: 12 * s,
                    fontWeight: FontWeight.w600,
                    color: cs.foreground)),
            const Spacer(),
          ],
        ),
      );
}

class _BarraPie extends StatelessWidget {
  final AsyncValue<List<EntidadInfo>> async;
  final double s;
  final ColorScheme cs;
  const _BarraPie({required this.async, required this.s, required this.cs});

  @override
  Widget build(BuildContext context) => Container(
        height: 32 * s,
        padding: EdgeInsets.symmetric(horizontal: 12 * s),
        color: cs.muted,
        child: async.maybeWhen(
          data: (raices) {
            final total = _contarNodos(raices);
            return Align(
              alignment: Alignment.centerLeft,
              child: Text('$total entidades',
                  style: TextStyle(
                      fontSize: 11 * s, color: cs.mutedForeground)),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      );

  int _contarNodos(List<EntidadInfo> nodos) {
    var n = nodos.length;
    for (final e in nodos) {
      n += _contarNodos(e.hijos);
    }
    return n;
  }
}

// ═══════════════════════════════════════════════════════════
// Nodo del árbol (recursivo, expandible)
// ═══════════════════════════════════════════════════════════

class _NodoEntidad extends StatefulWidget {
  final EntidadInfo entidad;
  final int profundidad;
  final EntidadInfo? seleccionada;
  final ValueChanged<EntidadInfo> onSeleccion;

  const _NodoEntidad({
    required this.entidad,
    required this.profundidad,
    required this.seleccionada,
    required this.onSeleccion,
  });

  @override
  State<_NodoEntidad> createState() => _NodoEntidadState();
}

class _NodoEntidadState extends State<_NodoEntidad> {
  bool _expandido = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final e = widget.entidad;
    final esSeleccionada = widget.seleccionada?.entidadId == e.entidadId;
    final tieneHijos = e.hijos.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => widget.onSeleccion(e),
          child: Container(
            color: esSeleccionada
                ? cs.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            padding: EdgeInsets.only(
              left: (12 + widget.profundidad * 18) * s,
              right: 12 * s,
              top: 6 * s,
              bottom: 6 * s,
            ),
            child: Row(
              children: [
                // Flecha expandir/colapsar
                if (tieneHijos)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _expandido = !_expandido),
                    child: Icon(
                      _expandido
                          ? LucideIcons.chevronDown
                          : LucideIcons.chevronRight,
                      size: 12 * s,
                      color: cs.mutedForeground,
                    ),
                  )
                else
                  SizedBox(width: 12 * s),
                SizedBox(width: 4 * s),
                // Badge de nivel
                _BadgeNivel(nivel: e.nivel, s: s),
                SizedBox(width: 6 * s),
                // Tipo (pequeño, muted)
                Text(
                  e.tipo,
                  style: TextStyle(
                      fontSize: 10 * s,
                      color: cs.mutedForeground,
                      fontFamily: 'monospace'),
                ),
                SizedBox(width: 6 * s),
                // Nombre
                Expanded(
                  child: Text(
                    e.nombre,
                    style: TextStyle(
                        fontSize: 12 * s,
                        fontWeight: esSeleccionada
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: esSeleccionada
                            ? cs.primary
                            : cs.foreground),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Hijos (recursivos)
        if (tieneHijos && _expandido)
          ...e.hijos.map((hijo) => _NodoEntidad(
                entidad: hijo,
                profundidad: widget.profundidad + 1,
                seleccionada: widget.seleccionada,
                onSeleccion: widget.onSeleccion,
              )),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Badge de nivel con color semántico
// ═══════════════════════════════════════════════════════════

class _BadgeNivel extends StatelessWidget {
  final String nivel;
  final double s;
  const _BadgeNivel({required this.nivel, required this.s});

  Color _colorFondo() => switch (nivel) {
        'tenant' => const Color(0xFF8B5CF6).withValues(alpha: 0.18),
        'bdomain' => const Color(0xFF3B82F6).withValues(alpha: 0.18),
        'bsubdomain' => const Color(0xFF14B8A6).withValues(alpha: 0.18),
        'pos' => const Color(0xFFF59E0B).withValues(alpha: 0.18),
        'actor' => const Color(0xFF22C55E).withValues(alpha: 0.18),
        _ => const Color(0xFF94A3B8).withValues(alpha: 0.18),
      };

  Color _colorTexto() => switch (nivel) {
        'tenant' => const Color(0xFF8B5CF6),
        'bdomain' => const Color(0xFF3B82F6),
        'bsubdomain' => const Color(0xFF14B8A6),
        'pos' => const Color(0xFFF59E0B),
        'actor' => const Color(0xFF22C55E),
        _ => const Color(0xFF94A3B8),
      };

  String _etiquetaCorta() => switch (nivel) {
        'tenant' => 'TNT',
        'bdomain' => 'BDM',
        'bsubdomain' => 'BSD',
        'pos' => 'POS',
        'actor' => 'ACT',
        _ => '???',
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 1 * s),
        decoration: BoxDecoration(
          color: _colorFondo(),
          borderRadius: BorderRadius.circular(3 * s),
        ),
        child: Text(
          _etiquetaCorta(),
          style: TextStyle(
            fontSize: 9 * s,
            fontWeight: FontWeight.w700,
            color: _colorTexto(),
            fontFamily: 'monospace',
            letterSpacing: 0.3,
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
// Panel derecho — detalle de entidad
// ═══════════════════════════════════════════════════════════

class _PanelDetalle extends StatelessWidget {
  final EntidadInfo entidad;
  const _PanelDetalle({required this.entidad});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final e = entidad;
    return SingleChildScrollView(
      padding: EdgeInsets.all(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado con ícono de nivel
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconoNivel(nivel: e.nivel, s: s),
              SizedBox(width: 12 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.nombre,
                      style: TextStyle(
                          fontSize: 17 * s,
                          fontWeight: FontWeight.w600,
                          color: cs.foreground),
                    ),
                    SizedBox(height: 3 * s),
                    Row(
                      children: [
                        _BadgeNivel(nivel: e.nivel, s: s),
                        SizedBox(width: 6 * s),
                        Text(
                          e.tipo,
                          style: TextStyle(
                              fontSize: 11 * s,
                              color: cs.mutedForeground,
                              fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20 * s),
          // Sección identificadores
          _TituloSeccion('IDENTIFICADORES', cs: cs, s: s),
          SizedBox(height: 8 * s),
          _FilaDetalle('ID', e.entidadId, cs: cs, s: s, mono: true),
          _FilaDetalle('Slug', e.slug, cs: cs, s: s, mono: true),
          _FilaDetalle('Tenant', e.tenantId, cs: cs, s: s, mono: true),
          if (e.parentId != null)
            _FilaDetalle('Parent', e.parentId!, cs: cs, s: s, mono: true),
          SizedBox(height: 16 * s),
          // Sección estructura
          _TituloSeccion('POSICIÓN EN EL ÁRBOL', cs: cs, s: s),
          SizedBox(height: 8 * s),
          _FilaDetalle('Nivel', e.nivel, cs: cs, s: s),
          _FilaDetalle('Tipo', e.tipo, cs: cs, s: s),
          _FilaDetalle('Orden', '${e.sortOrder}', cs: cs, s: s),
          if (e.isInternal != null)
            _FilaDetalle(
                'Interno', e.isInternal! ? 'Sí' : 'No', cs: cs, s: s),
          if (e.hijos.isNotEmpty) ...[
            SizedBox(height: 16 * s),
            _TituloSeccion('HIJOS DIRECTOS', cs: cs, s: s),
            SizedBox(height: 8 * s),
            _ListaHijos(hijos: e.hijos, cs: cs, s: s),
          ],
        ],
      ),
    );
  }
}

class _IconoNivel extends StatelessWidget {
  final String nivel;
  final double s;
  const _IconoNivel({required this.nivel, required this.s});

  IconData _icono() => switch (nivel) {
        'tenant' => LucideIcons.building2,
        'bdomain' => LucideIcons.layers,
        'bsubdomain' => LucideIcons.mapPin,
        'pos' => LucideIcons.monitor,
        'actor' => LucideIcons.user,
        _ => LucideIcons.circle,
      };

  Color _color() => switch (nivel) {
        'tenant' => const Color(0xFF8B5CF6),
        'bdomain' => const Color(0xFF3B82F6),
        'bsubdomain' => const Color(0xFF14B8A6),
        'pos' => const Color(0xFFF59E0B),
        'actor' => const Color(0xFF22C55E),
        _ => const Color(0xFF94A3B8),
      };

  @override
  Widget build(BuildContext context) {
    final size = 40.0 * s;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8 * s),
      ),
      alignment: Alignment.center,
      child: Icon(_icono(), size: 18 * s, color: _color()),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String titulo;
  final ColorScheme cs;
  final double s;
  const _TituloSeccion(this.titulo, {required this.cs, required this.s});

  @override
  Widget build(BuildContext context) => Text(
        titulo,
        style: TextStyle(
            fontSize: 10.5 * s,
            fontWeight: FontWeight.w600,
            color: cs.mutedForeground,
            letterSpacing: 0.8),
      );
}

class _FilaDetalle extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final ColorScheme cs;
  final double s;
  final bool mono;
  const _FilaDetalle(this.etiqueta, this.valor,
      {required this.cs, required this.s, this.mono = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: 3 * s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80 * s,
              child: Text(etiqueta,
                  style:
                      TextStyle(fontSize: 12 * s, color: cs.mutedForeground)),
            ),
            Expanded(
              child: Text(
                valor,
                style: TextStyle(
                    fontSize: 12 * s,
                    color: cs.foreground,
                    fontFamily: mono ? 'monospace' : null),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

class _ListaHijos extends StatelessWidget {
  final List<EntidadInfo> hijos;
  final ColorScheme cs;
  final double s;
  const _ListaHijos(
      {required this.hijos, required this.cs, required this.s});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: hijos
            .map((h) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 2 * s),
                  child: Row(
                    children: [
                      _BadgeNivel(nivel: h.nivel, s: s),
                      SizedBox(width: 6 * s),
                      Text(h.tipo,
                          style: TextStyle(
                              fontSize: 10 * s,
                              color: cs.mutedForeground,
                              fontFamily: 'monospace')),
                      SizedBox(width: 6 * s),
                      Text(h.nombre,
                          style: TextStyle(
                              fontSize: 12 * s, color: cs.foreground)),
                    ],
                  ),
                ))
            .toList(),
      );
}

// ═══════════════════════════════════════════════════════════
// Widgets de estado
// ═══════════════════════════════════════════════════════════

class _SinSeleccion extends StatelessWidget {
  const _SinSeleccion();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.gitBranch, size: 28 * s, color: cs.mutedForeground),
          SizedBox(height: 8 * s),
          Text('Selecciona una entidad',
              style: TextStyle(fontSize: 13 * s, color: cs.mutedForeground)),
          SizedBox(height: 4 * s),
          Text(
            'tenant · bdomain · bsubdomain · pos · actor',
            style: TextStyle(
                fontSize: 10 * s,
                color: cs.mutedForeground,
                fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class _VacioMensaje extends StatelessWidget {
  final ColorScheme cs;
  final double s;
  final String texto;
  const _VacioMensaje(
      {required this.cs, required this.s, required this.texto});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(texto,
            style: TextStyle(fontSize: 12 * s, color: cs.mutedForeground)),
      );
}

class _ErrorArbol extends StatelessWidget {
  final String mensaje;
  const _ErrorArbol({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16 * s),
        child: Text(
          'Error al cargar: $mensaje',
          style: TextStyle(fontSize: 12 * s, color: cs.destructive),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
