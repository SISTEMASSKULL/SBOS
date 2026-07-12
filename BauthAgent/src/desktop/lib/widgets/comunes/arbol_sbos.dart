// ============================================================
// bauth_desktop · widgets/comunes/arbol_sbos.dart
//
// Propósito: árbol FUNCIONAL y REUTILIZABLE sobre TreeView de shadcn_flutter.
//   Gestiona el estado de expansión en StatefulWidget; cada clic en la flecha
//   llama a TreeItemExpandDefaultHandler que muta la lista y dispara setState.
// Dependencias: tf_shadcn_flutter, datos/arbol_datos.
// Estándar: shadcn_flutter TreeView · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../datos/arbol_datos.dart';

/// Árbol genérico funcional: expand/collapse con estado propio.
class ArbolSbos extends StatefulWidget {
  final List<NodoArbol> nodos;
  final bool ajustarContenido;

  const ArbolSbos({super.key, required this.nodos, this.ajustarContenido = true});

  @override
  State<ArbolSbos> createState() => _ArbolSbosState();
}

class _ArbolSbosState extends State<ArbolSbos> {
  late List<TreeNode<NodoArbol>> _nodos;

  @override
  void initState() {
    super.initState();
    _nodos = widget.nodos.map(_aItem).toList();
  }

  @override
  void didUpdateWidget(ArbolSbos old) {
    super.didUpdateWidget(old);
    if (old.nodos != widget.nodos) {
      _nodos = widget.nodos.map(_aItem).toList();
    }
  }

  TreeItem<NodoArbol> _aItem(NodoArbol n) =>
      TreeItem(data: n, expanded: true, children: n.hijos.map(_aItem).toList());

  void _expandir(List<TreeNode<NodoArbol>> nodos, TreeNode<NodoArbol> item, bool expanded) {
    final handler = TreeItemExpandDefaultHandler<NodoArbol>(
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
    return TreeView<NodoArbol>(
      nodes: _nodos,
      shrinkWrap: widget.ajustarContenido,
      padding: EdgeInsets.symmetric(vertical: 4 * s),
      builder: (context, item) {
        final n = item.data;
        return TreeItemView(
          onExpand: (expanded) => _expandir(_nodos, item, expanded),
          leading: n.icono != null ? Icon(n.icono, size: 14 * s, color: cs.mutedForeground) : null,
          trailing: n.badge != null
              ? Text(n.badge!, style: TextStyle(fontFamily: 'monospace', fontSize: 10 * s, color: cs.mutedForeground))
              : null,
          child: Text(n.etiqueta, style: TextStyle(fontSize: 12 * s, color: cs.foreground)),
        );
      },
    );
  }
}
