// ============================================================
// bauth_desktop · widgets/comunes/arbol_template.dart
//
// Propósito: árbol FUNCIONAL del RolTemplate sobre TreeView de shadcn_flutter.
//   Gestiona expansión con StatefulWidget + TreeItemExpandDefaultHandler.
//   Notifica el nodo seleccionado sin reconstruir el árbol completo.
//
//   Rendimiento:
//   · [seleccionListenable] — cuando se provee, el resaltado de selección
//     usa ValueListenableBuilder POR ITEM VISIBLE: solo las ~N filas en
//     pantalla rebuildan, sin disparar _TreeViewState.build() (que recorre
//     O(n_total) nodos con _walkFlattened en cada setState del padre).
//   · _expandir() incluye early-return si el nodo ya está en el estado
//     deseado, evitando el deep-copy de _nodos y el rebuild asociado.
//   · _diagCounts precomputa el conteo de diagnósticos en initState (O(1)
//     lookup en el builder en vez de recursión O(n) por nodo).
//
// Dependencias: tf_shadcn_flutter, datos/rol_template_datos.
// Estándar: Anexo A.01 · shadcn_flutter TreeView · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../datos/rol_template_datos.dart';

/// Rótulo + color de un tipo de rama.
(String, Color) _infoTipo(TipoNodo t, ColorScheme cs) => switch (t) {
      TipoNodo.objeto      => ('OBJETO',   cs.mutedForeground),
      TipoNodo.lista       => ('LISTA',    cs.mutedForeground),
      TipoNodo.politica    => ('POLÍTICA', cs.primary),
      TipoNodo.regla       => ('REGLA',    Colors.amber.shade600),
      TipoNodo.evaluacion  => ('ATOM',     Colors.teal.shade400),
      TipoNodo.enumerado   => ('ENUM',     Colors.violet.shade400),
      TipoNodo.diagnostico => ('ERROR',    Colors.red.shade400),
      _                    => ('',         cs.mutedForeground),
    };

/// Árbol del RolTemplate: funcional (expand/collapse), notifica selección.
///
/// [shrinkWrap] = true cuando se usa dentro de SingleChildScrollView.
/// [seleccionListenable] — opcional. Cuando se provee, el nodo activo se
///   resalta via ValueListenableBuilder por item: el árbol completo NO se
///   reconstruye en cada cambio de selección.
class ArbolTemplate extends StatefulWidget {
  final List<NodoTemplate> nodos;

  /// Notifier externo de selección — si null, no se aplica resaltado.
  final ValueListenable<NodoTemplate?>? seleccionListenable;

  final ValueChanged<NodoTemplate> alSeleccionar;
  final bool shrinkWrap;

  const ArbolTemplate({
    super.key,
    required this.nodos,
    this.seleccionListenable,
    required this.alSeleccionar,
    this.shrinkWrap = false,
  });

  @override
  State<ArbolTemplate> createState() => _ArbolTemplateState();
}

class _ArbolTemplateState extends State<ArbolTemplate> {
  late List<TreeNode<NodoTemplate>> _nodos;

  /// Conteo de descendientes TipoNodo.diagnostico por nodo (DFS postorden).
  /// Calculado en initState/didUpdateWidget — O(1) lookup en el builder.
  late Map<NodoTemplate, int> _diagCounts;

  @override
  void initState() {
    super.initState();
    _diagCounts = _calcularDiags(widget.nodos);
    _nodos = widget.nodos.map(_aItem).toList();
  }

  @override
  void didUpdateWidget(ArbolTemplate old) {
    super.didUpdateWidget(old);
    if (old.nodos != widget.nodos) {
      _diagCounts = _calcularDiags(widget.nodos);
      _nodos = widget.nodos.map(_aItem).toList();
    }
  }

  /// DFS postorden: acumula el conteo de diagnósticos para cada nodo.
  static Map<NodoTemplate, int> _calcularDiags(List<NodoTemplate> raices) {
    final mapa = <NodoTemplate, int>{};
    void visitar(NodoTemplate n) {
      for (final h in n.hijos) {
        visitar(h);
      }
      final propios = n.tipo == TipoNodo.diagnostico ? 1 : 0;
      mapa[n] = n.hijos.fold(propios, (acc, h) => acc + (mapa[h] ?? 0));
    }
    for (final r in raices) {
      visitar(r);
    }
    return mapa;
  }

  TreeItem<NodoTemplate> _aItem(NodoTemplate n) => TreeItem(
        data: n,
        expanded: n.tipo == TipoNodo.dominio,
        children: n.hijos.map(_aItem).toList(),
      );

  /// Expande o colapsa un nodo.
  /// Early-return si el nodo ya está en el estado deseado: evita el
  /// deep-copy de la lista y el setState/rebuild del árbol innecesario.
  void _expandir(
    List<TreeNode<NodoTemplate>> nodos,
    TreeNode<NodoTemplate> item,
    bool expanded,
  ) {
    if (item is TreeItem<NodoTemplate> && item.expanded == expanded) return;
    final handler = TreeItemExpandDefaultHandler<NodoTemplate>(
      nodos,
      item,
      (actualizado) => setState(() => _nodos = actualizado),
    );
    handler(expanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final listenable = widget.seleccionListenable;

    return TreeView<NodoTemplate>(
      nodes: _nodos,
      shrinkWrap: widget.shrinkWrap,
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 8 * s),
      builder: (context, item) {
        final n = item.data;

        // ── Diagnósticos: renderizado especial, sin resaltado de selección ──
        if (n.tipo == TipoNodo.diagnostico) {
          return TreeItemView(
            onExpand: (exp) => _expandir(_nodos, item, exp),
            onPressed: () => widget.alSeleccionar(n),
            child: _buildDiagnostico(n, cs, s),
          );
        }

        // ── Nodos normales ────────────────────────────────────────────────
        final nDiags = _diagCounts[n] ?? 0;

        // Sin listenable: el árbol se usa solo como referencia (vocabulario).
        if (listenable == null) {
          return TreeItemView(
            onExpand: (exp) => _expandir(_nodos, item, exp),
            onPressed: () => widget.alSeleccionar(n),
            child: _buildFila(n, nDiags, false, cs, s),
          );
        }

        // Con listenable: solo la fila interna rebuilda en cada cambio de
        // selección — TreeItemView y _TreeViewState NO se reconstruyen.
        return TreeItemView(
          onExpand: (exp) => _expandir(_nodos, item, exp),
          onPressed: () => widget.alSeleccionar(n),
          child: ValueListenableBuilder<NodoTemplate?>(
            valueListenable: listenable,
            builder: (_, selec, _) =>
                _buildFila(n, nDiags, identical(n, selec), cs, s),
          ),
        );
      },
    );
  }

  // ── Constructores de contenido de fila ────────────────────────────────

  /// Fila para nodos de diagnóstico (icono de error/aviso + texto monoespacio).
  Widget _buildDiagnostico(NodoTemplate n, ColorScheme cs, double s) {
    final esDiagError = n.clave.startsWith('✕');
    final colorDiag =
        esDiagError ? Colors.red.shade400 : Colors.amber.shade500;
    return Row(
      children: [
        Icon(
          esDiagError ? LucideIcons.circleX : LucideIcons.triangleAlert,
          size: 11 * s,
          color: colorDiag,
        ),
        SizedBox(width: 5 * s),
        Flexible(
          child: Text(
            n.clave,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10 * s,
              fontWeight: FontWeight.w700,
              color: colorDiag,
            ),
          ),
        ),
        if (n.valor != null) ...[
          SizedBox(width: 8 * s),
          Text(
            n.valor!,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9 * s,
              color: colorDiag.withValues(alpha: 0.65),
            ),
          ),
        ],
      ],
    );
  }

  /// Fila para nodos normales (clave + badge diagnóstico + tipo + valor).
  /// [activo] — true cuando este nodo es el seleccionado: aplica color primary.
  Widget _buildFila(
    NodoTemplate n,
    int nDiags,
    bool activo,
    ColorScheme cs,
    double s,
  ) {
    final filaDiagBadge = nDiags > 0
        ? Padding(
            padding: EdgeInsets.only(left: 5 * s),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 4 * s, vertical: 1 * s),
              decoration: BoxDecoration(
                color: Colors.red.shade700.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(3 * s),
                border: Border.all(
                    color: Colors.red.shade700.withValues(alpha: 0.4)),
              ),
              child: Text(
                '$nDiags',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 8 * s,
                  fontWeight: FontWeight.w800,
                  color: Colors.red.shade400,
                ),
              ),
            ),
          )
        : null;

    final fila = Row(
      children: [
        Flexible(
          child: Text(
            n.clave,
            overflow: TextOverflow.ellipsis,
            style: _estiloClave(n.tipo, activo, cs, s),
          ),
        ),
        ?filaDiagBadge,
        if (n.tipo != TipoNodo.atributo &&
            n.tipo != TipoNodo.dominio &&
            n.tipo != TipoNodo.bloque)
          Padding(
            padding: EdgeInsets.only(left: 6 * s),
            child: _BadgeTipo(tipo: n.tipo),
          ),
        if (n.valor != null) ...[
          SizedBox(width: 10 * s),
          Flexible(
            flex: 2,
            child: Text(
              n.valor!,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5 * s,
                color: n.tipo == TipoNodo.enumerado
                    ? Colors.violet.shade300
                    : cs.mutedForeground,
              ),
            ),
          ),
        ],
      ],
    );

    // Nodos ENUMERADO: menú contextual (clic derecho) con todas las opciones.
    if (n.tipo == TipoNodo.enumerado && n.opciones.isNotEmpty) {
      return ContextMenu(
        items: n.opciones
            .map((op) => MenuButton(
                  child: Text(
                    op,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11 * s,
                      fontWeight:
                          op == n.valor ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ))
            .toList(),
        child: fila,
      );
    }
    return fila;
  }

  TextStyle _estiloClave(TipoNodo t, bool activo, ColorScheme cs, double s) {
    if (activo) {
      return TextStyle(
          fontSize: 11.5 * s, fontWeight: FontWeight.w700, color: cs.primary);
    }
    return switch (t) {
      TipoNodo.dominio => TextStyle(
          fontSize: 12 * s,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4 * s,
          color: cs.primary),
      TipoNodo.bloque => TextStyle(
          fontSize: 11.5 * s,
          fontWeight: FontWeight.w700,
          color: cs.foreground),
      TipoNodo.evaluacion => TextStyle(
          fontSize: 11 * s,
          fontWeight: FontWeight.w600,
          color: Colors.teal.shade300),
      TipoNodo.enumerado => TextStyle(
          fontSize: 11 * s,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          color: Colors.violet.shade300),
      TipoNodo.atributo => TextStyle(
          fontSize: 11 * s,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w500,
          color: cs.mutedForeground),
      TipoNodo.diagnostico => TextStyle(
          fontSize: 10 * s,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          color: Colors.red.shade400),
      _ => TextStyle(
          fontSize: 11.5 * s,
          fontWeight: FontWeight.w600,
          color: cs.foreground),
    };
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

/// Badge del tipo de rama (OBJETO/LISTA/POLÍTICA/REGLA/EVAL/ENUM).
class _BadgeTipo extends StatelessWidget {
  final TipoNodo tipo;
  const _BadgeTipo({required this.tipo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final (rotulo, color) = _infoTipo(tipo, cs);
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

/// Panel de ayuda: comentario del anexo del nodo seleccionado.
class PanelHelp extends StatelessWidget {
  final NodoTemplate? nodo;
  final double alto;
  const PanelHelp({super.key, this.nodo, this.alto = 96});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final n = nodo;
    return Container(
      height: alto * s,
      width: double.infinity,
      padding: EdgeInsets.all(12 * s),
      decoration: BoxDecoration(
        color: cs.card,
        border: Border(top: BorderSide(color: cs.border)),
      ),
      child: n == null
          ? Center(
              child: Text(
                'Selecciona un nodo o sección del árbol para ver su ayuda.',
                style: TextStyle(
                    fontSize: 11.5 * s,
                    fontStyle: FontStyle.italic,
                    color: cs.mutedForeground),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.info, size: 13 * s, color: cs.primary),
                    SizedBox(width: 6 * s),
                    Expanded(
                      child: Text(
                        n.clave,
                        style: TextStyle(
                            fontSize: 12 * s,
                            fontWeight: FontWeight.w700,
                            color: cs.foreground),
                      ),
                    ),
                    if (n.tipo != TipoNodo.atributo &&
                        n.tipo != TipoNodo.dominio &&
                        n.tipo != TipoNodo.bloque)
                      _BadgeTipo(tipo: n.tipo),
                  ],
                ),
                if (n.valor != null)
                  Padding(
                    padding: EdgeInsets.only(top: 3 * s),
                    child: Text(
                      n.valor!,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11 * s,
                        color: n.tipo == TipoNodo.enumerado
                            ? Colors.violet.shade300
                            : cs.primary,
                      ),
                    ),
                  ),
                if (n.tipo == TipoNodo.enumerado && n.opciones.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 6 * s),
                    child: Wrap(
                      spacing: 4 * s,
                      runSpacing: 3 * s,
                      children: n.opciones.map((op) {
                        final esActual = op == n.valor;
                        return Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 6 * s, vertical: 2 * s),
                          decoration: BoxDecoration(
                            color: esActual
                                ? Colors.violet.shade400.withValues(alpha: 0.2)
                                : cs.muted.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(3 * s),
                            border: Border.all(
                              color: esActual
                                  ? Colors.violet.shade400
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            op,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9.5 * s,
                              fontWeight: esActual
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: esActual
                                  ? Colors.violet.shade300
                                  : cs.mutedForeground,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                SizedBox(height: 6 * s),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      n.help ?? 'Sin ayuda documentada para este nodo.',
                      style: TextStyle(
                          fontSize: 11.5 * s,
                          height: 1.5,
                          color: cs.mutedForeground),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
