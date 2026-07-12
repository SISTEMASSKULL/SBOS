// ============================================================
// bauth_desktop · vistas/vista_rol_template.dart
//
// Propósito: VISTA «Rol Template» (mantenimiento del template GLOBAL) — se monta
//   en el outlet. Tabs + 3 columnas: Átomos · [árbol del template arriba + panel
//   de help abajo] · Políticas. El centro divide en dos: el árbol completo de
//   los 14 bloques y, debajo, la ayuda del nodo seleccionado. Compone
//   componentes reutilizables.
// Dependencias: tf_shadcn_flutter, datos/{arbol_datos,rol_template_datos},
//   widgets/comunes/{arbol_sbos, arbol_template, panel_lateral, tira_tabs}.
// Estándar: Anexo A.01 (RolTemplate v6.0) · SPA (vista) · DOC-SBOS-001 N3.
// ============================================================

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
                  titulo: 'Átomos', conteo: '48 · D1', lado: LadoPanel.izquierdo, child: ArbolSbos(nodos: arbolAtomos)),
              Expanded(
                child: Container(
                  color: cs.background,
                  child: Column(
                    children: [
                      Expanded(
                        child: ArbolTemplate(
                          nodos: arbolRolTemplate,
                          seleccionado: _seleccion,
                          alSeleccionar: (n) => setState(() => _seleccion = n),
                        ),
                      ),
                      PanelHelp(nodo: _seleccion),
                    ],
                  ),
                ),
              ),
              const PanelLateral(
                  titulo: 'Políticas', conteo: 'dominio', lado: LadoPanel.derecho, child: ArbolSbos(nodos: arbolPoliticas)),
            ],
          ),
        ),
      ],
    );
  }
}
