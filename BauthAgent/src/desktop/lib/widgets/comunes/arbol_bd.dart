// ============================================================
// bauth_desktop · widgets/comunes/arbol_bd.dart
//
// Propósito: árbol lazy de NodoRolTemplateBD.
//   Carga nodo a nodo — cada expansión dispara un RPC
//   bauth.rol_template.children(parent_id) al daemon.
//   Sin expansión no hay llamada → nunca satura la conexión.
//
//   Estados visibles:
//     • Raíz cargando   → spinner centrado con mensaje
//     • Raíz con error  → cuadro rojo con texto completo + Reintentar
//     • Nodo cargando   → spinner inline en la fila del nodo padre
//     • Nodo con error  → banda roja bajo la fila con Reintentar
//     • Árbol OK        → ListView plana con indentación por depth
//
// Dependencias: tf_shadcn_flutter, nucleo/api/bauth_api.
// Estándar: DDL T-162 · ADR-020 · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../nucleo/api/bauth_api.dart';

// ── Tipo del callback de carga ────────────────────────────────
typedef CargadorHijosBD = Future<List<NodoRolTemplateBD>> Function(
    String? parentId);

// ── Helpers de presentación ───────────────────────────────────

(String, Color) _infoBD(String tipo, ColorScheme cs) => switch (tipo) {
      'dominio'    => ('DOM',   cs.primary),
      'bloque'     => ('BLQ',   cs.foreground),
      'objeto'     => ('OBJ',   cs.mutedForeground),
      'lista'      => ('LISTA', cs.mutedForeground),
      'politica'   => ('POL',   cs.primary),
      'regla'      => ('REGLA', Colors.amber.shade600),
      'evaluacion' => ('ATOM',  Colors.teal.shade400),
      'atributo'   => ('ATTR',  cs.mutedForeground),
      'enumerado'  => ('ENUM',  Colors.violet.shade400),
      _            => ('?',     cs.mutedForeground),
    };

TextStyle _estiloBD(String tipo, bool activo, ColorScheme cs, double s) {
  if (activo) {
    return TextStyle(fontSize: 11.5 * s, fontWeight: FontWeight.w700, color: cs.primary);
  }
  return switch (tipo) {
    'dominio'    => TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w700, letterSpacing: 0.4 * s, color: cs.primary),
    'bloque'     => TextStyle(fontSize: 11.5 * s, fontWeight: FontWeight.w700, color: cs.foreground),
    'evaluacion' => TextStyle(fontSize: 11 * s, fontWeight: FontWeight.w600, color: Colors.teal.shade300),
    'enumerado'  => TextStyle(fontSize: 11 * s, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: Colors.violet.shade300),
    'atributo'   => TextStyle(fontSize: 11 * s, fontFamily: 'monospace', fontWeight: FontWeight.w500, color: cs.mutedForeground),
    _ => TextStyle(fontSize: 11.5 * s, fontWeight: FontWeight.w600, color: cs.foreground),
  };
}

// ── Árbol lazy ────────────────────────────────────────────────

/// Árbol interactivo con carga lazy — un RPC por expansión de nodo.
class ArbolBD extends StatefulWidget {
  /// Callback que recibe parent_id (null = raíz) y retorna hijos directos.
  final CargadorHijosBD cargarHijos;

  /// Llamado al seleccionar un nodo (null = deseleccionar).
  final ValueChanged<NodoRolTemplateBD?>? alSeleccionar;

  const ArbolBD({super.key, required this.cargarHijos, this.alSeleccionar});

  @override
  State<ArbolBD> createState() => _ArbolBDState();
}

class _ArbolBDState extends State<ArbolBD> {
  // Hijos por parent_id (null = nivel raíz)
  final Map<String?, List<NodoRolTemplateBD>> _hijos = {};
  // IDs de nodos actualmente expandidos
  final Set<String> _expandidos = {};
  // IDs de nodos cuyos hijos se están cargando (null = carga de raíz)
  final Set<String?> _cargando = {};
  // Mensajes de error por parent_id
  final Map<String?, String> _errores = {};
  // Lista plana ordenada de nodos visibles
  final List<NodoRolTemplateBD> _visibles = [];

  NodoRolTemplateBD? _seleccionado;

  @override
  void initState() {
    super.initState();
    _cargarNivel(null);
  }

  // ── Lógica de carga ─────────────────────────────────────────

  Future<void> _cargarNivel(String? parentId) async {
    if (_cargando.contains(parentId)) return;
    setState(() {
      _cargando.add(parentId);
      _errores.remove(parentId);
    });
    try {
      final hijos = await widget.cargarHijos(parentId);
      if (!mounted) return;
      setState(() {
        _hijos[parentId] = hijos;
        if (parentId != null) _expandidos.add(parentId);
        _cargando.remove(parentId);
        _reconstruirVisibles();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errores[parentId] = _mensajeError(e);
        _cargando.remove(parentId);
      });
    }
  }

  Future<void> _toggleNodo(NodoRolTemplateBD nodo) async {
    if (_expandidos.contains(nodo.id)) {
      setState(() {
        _expandidos.remove(nodo.id);
        _reconstruirVisibles();
      });
      return;
    }
    if (_hijos.containsKey(nodo.id)) {
      setState(() {
        _expandidos.add(nodo.id);
        _reconstruirVisibles();
      });
    } else {
      await _cargarNivel(nodo.id);
    }
  }

  void _reconstruirVisibles() {
    _visibles.clear();
    _agregarNiveles(null);
  }

  void _agregarNiveles(String? parentId) {
    final lista = _hijos[parentId] ?? [];
    for (final h in lista) {
      _visibles.add(h);
      if (_expandidos.contains(h.id)) _agregarNiveles(h.id);
    }
  }

  String _mensajeError(Object e) {
    final s = e.toString();
    if (s.length > 300) return '${s.substring(0, 300)}…';
    return s;
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_cargando.contains(null) && _hijos[null] == null) {
      return _CargandoRaiz();
    }
    if (_errores.containsKey(null) && _hijos[null] == null) {
      return _ErrorRaiz(
        mensaje: _errores[null]!,
        onReintentar: () => _cargarNivel(null),
      );
    }
    if (_visibles.isEmpty) {
      return _VacioBD();
    }
    return ListView.builder(
      itemCount: _visibles.length,
      itemBuilder: (ctx, i) {
        final n = _visibles[i];
        return _FilaNodo(
          nodo: n,
          expandido: _expandidos.contains(n.id),
          cargando: _cargando.contains(n.id),
          error: _errores[n.id],
          seleccionado: _seleccionado?.id == n.id,
          onToggle: () => _toggleNodo(n),
          onReintentar: () => _cargarNivel(n.id),
          onSeleccionar: () {
            setState(() => _seleccionado = n);
            widget.alSeleccionar?.call(n);
          },
        );
      },
    );
  }
}

// ── Fila de nodo ─────────────────────────────────────────────

class _FilaNodo extends StatelessWidget {
  final NodoRolTemplateBD nodo;
  final bool expandido;
  final bool cargando;
  final String? error;
  final bool seleccionado;
  final VoidCallback onToggle;
  final VoidCallback onReintentar;
  final VoidCallback onSeleccionar;

  const _FilaNodo({
    required this.nodo,
    required this.expandido,
    required this.cargando,
    required this.error,
    required this.seleccionado,
    required this.onToggle,
    required this.onReintentar,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    final (rotulo, color) = _infoBD(nodo.tipo, cs);
    final indent = nodo.depth * 14.0 * s;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Fila principal ───────────────────────────────────
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onSeleccionar,
            child: Container(
              color: seleccionado
                  ? cs.primary.withValues(alpha: 0.12)
                  : null,
              padding: EdgeInsets.only(
                left: 6 * s + indent,
                top: 3 * s,
                bottom: 3 * s,
                right: 8 * s,
              ),
              child: Row(children: [
                // Toggle — spinner si cargando hijos, flecha si no
                SizedBox(
                  width: 18 * s,
                  height: 18 * s,
                  child: cargando
                      ? Center(
                          child: SizedBox(
                            width: 11 * s,
                            height: 11 * s,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        )
                      : MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: onToggle,
                            child: Icon(
                              expandido
                                  ? LucideIcons.chevronDown
                                  : LucideIcons.chevronRight,
                              size: 13 * s,
                              color: cs.mutedForeground.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                ),
                SizedBox(width: 3 * s),
                // Badge de tipo
                _BadgeBD(rotulo: rotulo, color: color, s: s),
                SizedBox(width: 5 * s),
                // Clave del nodo
                Flexible(
                  child: Text(
                    nodo.clave,
                    overflow: TextOverflow.ellipsis,
                    style: _estiloBD(nodo.tipo, seleccionado, cs, s),
                  ),
                ),
                // Valor (si aplica)
                if (nodo.valor != null && nodo.valor!.isNotEmpty) ...[
                  SizedBox(width: 6 * s),
                  Flexible(
                    flex: 2,
                    child: Text(
                      nodo.valor!,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10 * s,
                        color: nodo.tipo == 'enumerado'
                            ? Colors.violet.shade300
                            : cs.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
        // ── Banda de error al cargar hijos ───────────────────
        if (error != null)
          _BandaError(
            mensaje: error!,
            indent: indent + 24 * s,
            onReintentar: onReintentar,
          ),
      ],
    );
  }
}

// ── Banda de error inline ─────────────────────────────────────

class _BandaError extends StatelessWidget {
  final String mensaje;
  final double indent;
  final VoidCallback onReintentar;
  const _BandaError({
    required this.mensaje,
    required this.indent,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Padding(
      padding: EdgeInsets.only(left: indent, right: 8 * s, bottom: 4 * s),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 4 * s),
        decoration: BoxDecoration(
          color: cs.destructive.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4 * s),
          border: Border.all(color: cs.destructive.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(LucideIcons.circleAlert, size: 11 * s, color: cs.destructive),
          SizedBox(width: 5 * s),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9.5 * s,
                color: cs.destructive,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8 * s),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onReintentar,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.refreshCw, size: 10 * s, color: cs.primary),
                SizedBox(width: 3 * s),
                Text(
                  'Reintentar',
                  style: TextStyle(
                    fontSize: 9.5 * s,
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Estados especiales ────────────────────────────────────────

class _CargandoRaiz extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 28 * s,
          height: 28 * s,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(height: 12 * s),
        Text(
          'Consultando bauth.role.template.list…',
          style: TextStyle(fontSize: 11 * s, color: cs.mutedForeground),
        ),
      ],
    );
  }
}

class _ErrorRaiz extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;
  const _ErrorRaiz({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return SingleChildScrollView(
      padding: EdgeInsets.all(24 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.wifiOff, size: 32 * s,
              color: cs.destructive.withValues(alpha: 0.75)),
          SizedBox(height: 10 * s),
          Text(
            'Error al conectar con bAuth',
            style: TextStyle(
              fontSize: 13 * s,
              fontWeight: FontWeight.w700,
              color: cs.foreground,
            ),
          ),
          SizedBox(height: 8 * s),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10 * s),
            decoration: BoxDecoration(
              color: cs.destructive.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4 * s),
              border: Border.all(color: cs.destructive.withValues(alpha: 0.35)),
            ),
            child: Text(
              mensaje,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9.5 * s,
                color: cs.destructive,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 14 * s),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onReintentar,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 8 * s),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(6 * s),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.refreshCw, size: 13 * s, color: cs.primaryForeground),
                  SizedBox(width: 6 * s),
                  Text(
                    'Reintentar',
                    style: TextStyle(
                      fontSize: 12 * s,
                      fontWeight: FontWeight.w600,
                      color: cs.primaryForeground,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VacioBD extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Center(
      child: Text(
        'Sin nodos — ejecuta el seed T-162.',
        style: TextStyle(fontSize: 11.5 * s, color: cs.mutedForeground),
      ),
    );
  }
}

// ── Badge de tipo ─────────────────────────────────────────────

class _BadgeBD extends StatelessWidget {
  final String rotulo;
  final Color color;
  final double s;
  const _BadgeBD({required this.rotulo, required this.color, required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 1 * s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3 * s),
      ),
      child: Text(
        rotulo,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 8 * s,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4 * s,
          color: color,
        ),
      ),
    );
  }
}

// ── Panel de detalle del nodo seleccionado ────────────────────

/// Panel inferior que muestra path, tipo y help del nodo BD seleccionado.
class PanelHelpBD extends StatelessWidget {
  final NodoRolTemplateBD? nodo;
  final double alto;
  const PanelHelpBD({super.key, this.nodo, this.alto = 80});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final n = nodo;
    return Container(
      height: alto * s,
      width: double.infinity,
      padding: EdgeInsets.all(10 * s),
      decoration: BoxDecoration(
        color: cs.card,
        border: Border(top: BorderSide(color: cs.border)),
      ),
      child: n == null
          ? Center(
              child: Text(
                'Selecciona un nodo del árbol BD para ver su detalle.',
                style: TextStyle(
                  fontSize: 11 * s,
                  fontStyle: FontStyle.italic,
                  color: cs.mutedForeground,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(LucideIcons.database, size: 12 * s, color: cs.primary),
                  SizedBox(width: 5 * s),
                  Expanded(
                    child: Text(
                      n.clave,
                      style: TextStyle(
                        fontSize: 11.5 * s,
                        fontWeight: FontWeight.w700,
                        color: cs.foreground,
                      ),
                    ),
                  ),
                ]),
                SizedBox(height: 3 * s),
                Text(
                  'path: ${n.path}  ·  tipo: ${n.tipo}  ·  prof: ${n.depth}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9 * s,
                    color: cs.mutedForeground,
                  ),
                ),
                if (n.valor != null)
                  Padding(
                    padding: EdgeInsets.only(top: 2 * s),
                    child: Text(
                      n.valor!,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5 * s,
                        color: cs.primary,
                      ),
                    ),
                  ),
                if (n.help != null) ...[
                  SizedBox(height: 4 * s),
                  Expanded(
                    child: Text(
                      n.help!,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: TextStyle(fontSize: 11 * s, color: cs.mutedForeground),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
