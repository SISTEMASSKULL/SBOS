// ============================================================
// bauth_desktop · vistas/vista_rol_template.dart
//
// Propósito: VISTA «Rol Template» — árbol completo de los 14 dominios del
//   RolTemplate global. Muestra la ruta del nodo seleccionado en una barra
//   compacta con botón de copia al portapapeles, para referenciar nodos
//   exactos en conversaciones de depuración y reparación.
// Dependencias: tf_shadcn_flutter, flutter/services,
//   datos/{arbol_datos,rol_template_datos},
//   widgets/comunes/{arbol_sbos, arbol_template, panel_lateral, tira_tabs}.
// Estándar: Anexo A.01 (RolTemplate v6.0) · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter/services.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../datos/arbol_datos.dart';
import '../datos/rol_template_datos.dart';
import '../widgets/comunes/arbol_sbos.dart';
import '../widgets/comunes/arbol_template.dart';
import '../widgets/comunes/panel_lateral.dart';
import '../widgets/comunes/tira_tabs.dart';

/// Vista de mantenimiento del RolTemplate global.
class VistaRolTemplate extends StatefulWidget {
  const VistaRolTemplate({super.key});

  @override
  State<VistaRolTemplate> createState() => _VistaRolTemplateState();
}

class _VistaRolTemplateState extends State<VistaRolTemplate> {
  NodoTemplate? _seleccion;
  String _ruta = '';
  bool _copiado = false;

  /// DFS recursivo que devuelve la ruta completa del nodo objetivo.
  /// Usa el separador › para distinguirla de rutas de archivo.
  /// Retorna cadena vacía si el nodo no se encuentra.
  String _calcularRuta(List<NodoTemplate> nodos, NodoTemplate objetivo, String prefijo) {
    for (final n in nodos) {
      final ruta = prefijo.isEmpty ? n.clave : '$prefijo › ${n.clave}';
      if (identical(n, objetivo)) return ruta;
      final sub = _calcularRuta(n.hijos, objetivo, ruta);
      if (sub.isNotEmpty) return sub;
    }
    return '';
  }

  /// Copia la ruta actual al portapapeles y activa el indicador visual por 2 s.
  Future<void> _copiarRuta() async {
    if (_ruta.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _ruta));
    setState(() => _copiado = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiado = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        const TiraTabs(
          tabs: ['Roles', 'Usuarios', 'Políticas', 'Atributos', 'Aplicaciones', 'Átomos'],
          activa: 0,
          separadorTras: 1,
        ),
        Expanded(
          child: Row(
            children: [
              const PanelLateral(
                titulo: 'Átomos',
                conteo: '48 · D1',
                lado: LadoPanel.izquierdo,
                child: ArbolSbos(nodos: arbolAtomos),
              ),
              Expanded(
                child: Container(
                  color: cs.background,
                  child: Column(
                    children: [
                      Expanded(
                        child: ArbolTemplate(
                          nodos: arbolRolTemplate,
                          seleccionado: _seleccion,
                          alSeleccionar: (n) => setState(() {
                            _seleccion = n;
                            _ruta = _calcularRuta(arbolRolTemplate, n, '');
                          }),
                        ),
                      ),
                      _BarraRuta(
                        ruta: _ruta,
                        copiado: _copiado,
                        alCopiar: _copiarRuta,
                      ),
                      PanelHelp(nodo: _seleccion),
                    ],
                  ),
                ),
              ),
              const PanelLateral(
                titulo: 'Políticas',
                conteo: 'dominio',
                lado: LadoPanel.derecho,
                child: ArbolSbos(nodos: arbolPoliticas),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Barra compacta entre el árbol y el panel de ayuda.
/// Muestra la ruta del nodo seleccionado en monoespaciado con botón de copia.
/// Ejemplo de ruta: "D1 · Acceso Lógico › metodos › required_methods{} › primary_auth{}"
class _BarraRuta extends StatelessWidget {
  final String ruta;

  /// true durante 2 s tras copiar para mostrar el ícono de confirmación.
  final bool copiado;
  final VoidCallback alCopiar;

  const _BarraRuta({
    required this.ruta,
    required this.copiado,
    required this.alCopiar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final vacia = ruta.isEmpty;

    return Container(
      height: 32 * s,
      decoration: BoxDecoration(
        color: cs.muted.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(color: cs.border),
          bottom: BorderSide(color: cs.border),
        ),
      ),
      padding: EdgeInsets.only(left: 12 * s, right: 4 * s),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                vacia ? 'Selecciona un nodo para ver su ruta' : ruta,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10.5 * s,
                  color: vacia ? cs.mutedForeground : cs.foreground,
                  fontStyle: vacia ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ),
          if (!vacia)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: alCopiar,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 6 * s),
                  child: Icon(
                    copiado ? LucideIcons.check : LucideIcons.copy,
                    size: 13 * s,
                    color: copiado ? Colors.green.shade400 : cs.mutedForeground,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
