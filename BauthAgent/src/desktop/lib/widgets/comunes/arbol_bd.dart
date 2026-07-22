// ============================================================
// bauth_desktop · widgets/comunes/arbol_bd.dart
//
// Propósito: árbol visual de NodoRolTemplateBD — datos leídos
//   en vivo desde bauth.idn_roles_template vía API JSON-RPC.
//   Renderiza tipos dominio/bloque/objeto/lista/politica/regla/
//   evaluacion/atributo/enumerado con colores y badges propios.
//   PanelHelpBD muestra path, tipo y help del nodo seleccionado.
// Dependencias: tf_shadcn_flutter, nucleo/api/bauth_api.
// Estándar: DDL T-162 · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../nucleo/api/bauth_api.dart';

// ── Helpers de presentación ──────────────────────────────────

/// Rótulo + color del badge según tipo de nodo BD.
(String, Color) _infoBD(String tipo, ColorScheme cs) => switch (tipo) {
      'dominio'    => ('DOM',    cs.primary),
      'bloque'     => ('BLQ',    cs.foreground),
      'objeto'     => ('OBJ',    cs.mutedForeground),
      'lista'      => ('LISTA',  cs.mutedForeground),
      'politica'   => ('POL',    cs.primary),
      'regla'      => ('REGLA',  Colors.amber.shade600),
      'evaluacion' => ('ATOM',   Colors.teal.shade400),
      'atributo'   => ('ATTR',   cs.mutedForeground),
      'enumerado'  => ('ENUM',   Colors.violet.shade400),
      _            => ('?',      cs.mutedForeground),
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

// ── Árbol BD ─────────────────────────────────────────────────

/// Árbol interactivo de nodos leídos desde bauth.idn_roles_template.
/// Recibe la raíz ya construida (estructura anidada).
class ArbolBD extends StatefulWidget {
  final List<NodoRolTemplateBD> nodos;
  final NodoRolTemplateBD? seleccionado;
  final ValueChanged<NodoRolTemplateBD> alSeleccionar;

  const ArbolBD({
    super.key,
    required this.nodos,
    this.seleccionado,
    required this.alSeleccionar,
  });

  @override
  State<ArbolBD> createState() => _ArbolBDState();
}

class _ArbolBDState extends State<ArbolBD> {
  late List<TreeNode<NodoRolTemplateBD>> _nodos;

  @override
  void initState() {
    super.initState();
    _nodos = widget.nodos.map(_aItem).toList();
  }

  @override
  void didUpdateWidget(ArbolBD old) {
    super.didUpdateWidget(old);
    if (old.nodos != widget.nodos) _nodos = widget.nodos.map(_aItem).toList();
  }

  TreeItem<NodoRolTemplateBD> _aItem(NodoRolTemplateBD n) => TreeItem(
        data: n,
        expanded: n.tipo == 'dominio',
        children: n.hijos.map(_aItem).toList(),
      );

  void _expandir(
    List<TreeNode<NodoRolTemplateBD>> nodos,
    TreeNode<NodoRolTemplateBD> item,
    bool expanded,
  ) {
    final handler = TreeItemExpandDefaultHandler<NodoRolTemplateBD>(
      nodos,
      item,
      (act) => setState(() => _nodos = act),
    );
    handler(expanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return TreeView<NodoRolTemplateBD>(
      nodes: _nodos,
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 8 * s),
      builder: (context, item) {
        final n = item.data;
        final activo = n == widget.seleccionado;
        final (rotulo, color) = _infoBD(n.tipo, cs);
        final ocultarBadge =
            n.tipo == 'dominio' || n.tipo == 'bloque' || n.tipo == 'atributo';
        return TreeItemView(
          onExpand: (exp) => _expandir(_nodos, item, exp),
          onPressed: () => widget.alSeleccionar(n),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  n.clave,
                  overflow: TextOverflow.ellipsis,
                  style: _estiloBD(n.tipo, activo, cs, s),
                ),
              ),
              if (!ocultarBadge)
                Padding(
                  padding: EdgeInsets.only(left: 5 * s),
                  child: _BadgeBD(rotulo: rotulo, color: color, s: s),
                ),
              if (n.valor != null) ...[
                SizedBox(width: 8 * s),
                Flexible(
                  flex: 2,
                  child: Text(
                    n.valor!,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5 * s,
                      color: n.tipo == 'enumerado'
                          ? Colors.violet.shade300
                          : cs.mutedForeground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

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

// ── Panel de ayuda BD ────────────────────────────────────────

/// Panel de detalle del nodo BD seleccionado: path, tipo, help.
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
                style: TextStyle(fontSize: 11 * s, fontStyle: FontStyle.italic, color: cs.mutedForeground),
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
                      style: TextStyle(fontSize: 11.5 * s, fontWeight: FontWeight.w700, color: cs.foreground),
                    ),
                  ),
                ]),
                SizedBox(height: 3 * s),
                Text(
                  'path: ${n.path}  ·  tipo: ${n.tipo}  ·  prof: ${n.depth}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 9 * s, color: cs.mutedForeground),
                ),
                if (n.valor != null)
                  Padding(
                    padding: EdgeInsets.only(top: 2 * s),
                    child: Text(
                      n.valor!,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 10.5 * s, color: cs.primary),
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
