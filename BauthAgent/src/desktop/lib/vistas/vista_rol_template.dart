// ============================================================
// bauth_desktop · vistas/vista_rol_template.dart
//
// Propósito: VISTA «Rol Template» — árbol completo de los 14 dominios.
//   Panel lateral izquierdo: vocabulario AtomLang v1 (referencia de lenguaje).
//   Panel central — 3 tabs:
//     Tab 0 · Árbol Fuente    — árbol SOURCE humano (RolTemplate v6.0, sin tocar)
//     Tab 1 · Árbol AtomLang  — mismo árbol traducido al lenguaje (salida del
//                               autómata de control de calidad: snake_case,
//                               verbo enum, condición tipada, combining_algorithm)
//     Tab 2 · Árbol Compilado — placeholder (fase 3 — atomc → bos_atom_compiled)
//   Panel de ayuda + barra de ruta con copia al portapapeles.
// Dependencias: tf_shadcn_flutter, flutter/services,
//   datos/{arbol_datos, rol_template_datos, atomlang_datos,
//          atomlang_normalizado_datos},
//   widgets/comunes/{arbol_sbos, arbol_template, panel_lateral, tira_tabs}.
// Estándar: Anexo A.01 (RolTemplate v6.0) · AtomLang-especificacion-completa.md
//           · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter/services.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../datos/arbol_datos.dart';
import '../datos/atomlang_datos.dart';
import '../datos/atomlang_normalizado_datos.dart';
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
  /// 0 = Árbol Fuente · 1 = Lenguaje AtomLang · 2 = Árbol Compilado.
  int _tabArbol = 0;

  NodoTemplate? _seleccion;
  String _ruta = '';
  bool _copiado = false;

  /// Cambia el tab activo y limpia la selección actual.
  void _cambiarTab(int idx) {
    setState(() {
      _tabArbol = idx;
      _seleccion = null;
      _ruta = '';
      _copiado = false;
    });
  }

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

  /// Árbol activo según el tab seleccionado.
  List<NodoTemplate> get _arbolActivo => switch (_tabArbol) {
        0 => arbolRolTemplate,
        1 => arbolNormalizado,
        _ => arbolAtomLang,
      };

  /// Registra la selección y calcula la ruta en el árbol activo.
  void _seleccionar(NodoTemplate n) {
    setState(() {
      _seleccion = n;
      _ruta = _calcularRuta(_arbolActivo, n, '');
    });
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
              PanelLateral(
                titulo: 'AtomLang v1',
                conteo: 'vocabulario',
                lado: LadoPanel.izquierdo,
                child: ArbolTemplate(
                  nodos: arbolAtomLang,
                  shrinkWrap: true,
                  alSeleccionar: (_) {},
                ),
              ),
              Expanded(
                child: Container(
                  color: cs.background,
                  child: Column(
                    children: [
                      // ── Barra de tabs interior del árbol ──────────────────
                      TiraTabs(
                        tabs: const ['Árbol Fuente', 'Árbol AtomLang', 'Árbol Compilado'],
                        activa: _tabArbol,
                        alSeleccionar: _cambiarTab,
                      ),
                      // ── Contenido según tab activo ────────────────────────
                      Expanded(child: _contenidoTab(cs)),
                      // ── Barra de ruta + panel de ayuda (comunes) ──────────
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

  Widget _contenidoTab(ColorScheme cs) {
    switch (_tabArbol) {
      case 0:
        return ArbolTemplate(
          nodos: arbolRolTemplate,
          seleccionado: _seleccion,
          alSeleccionar: _seleccionar,
        );
      case 1:
        return ArbolTemplate(
          nodos: arbolNormalizado,
          seleccionado: _seleccion,
          alSeleccionar: _seleccionar,
        );
      default:
        return _PlaceholderCompiladoTab(cs: cs);
    }
  }
}

/// Placeholder para el tab «Árbol Compilado» (fase 3 — atomc).
class _PlaceholderCompiladoTab extends StatelessWidget {
  final ColorScheme cs;
  const _PlaceholderCompiladoTab({required this.cs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.scaling;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.cpu, size: 40 * s, color: cs.mutedForeground.withValues(alpha: 0.4)),
          SizedBox(height: 16 * s),
          Text(
            'Árbol Compilado',
            style: TextStyle(fontSize: 14 * s, fontWeight: FontWeight.w700, color: cs.foreground),
          ),
          SizedBox(height: 8 * s),
          Text(
            'Fase 3 — Pendiente',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10 * s,
              color: cs.primary.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16 * s),
          SizedBox(
            width: 340 * s,
            child: Text(
              'Este panel mostrará el árbol técnico (IR) generado por atomc '
              'a partir del Árbol Fuente. Solo contiene IDs, enums y valores '
              'tipados — cero strings comparados en runtime.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11 * s, height: 1.6, color: cs.mutedForeground),
            ),
          ),
          SizedBox(height: 24 * s),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 6 * s),
            decoration: BoxDecoration(
              color: cs.muted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4 * s),
              border: Border.all(color: cs.border),
            ),
            child: Text(
              'atomc compile .atm.yaml → bos_atom_compiled',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10 * s,
                color: cs.mutedForeground,
              ),
            ),
          ),
        ],
      ),
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
