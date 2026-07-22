// ============================================================
// bauth_desktop · vistas/vista_rol_template.dart
//
// Propósito: VISTA «Rol Template» — árbol completo de los 14 dominios.
//   Panel lateral izquierdo: vocabulario AtomLang v1 (referencia de lenguaje).
//   Panel central — 4 tabs:
//     Tab 0 · Árbol Fuente    — árbol SOURCE humano (RolTemplate v6.0, sin tocar)
//     Tab 1 · Árbol AtomLang  — árbol normalizado (snake_case) + ANALIZADO:
//                               nodos TipoNodo.diagnostico inyectados donde
//                               el árbol viola reglas del lenguaje AtomLang.
//                               Funciona como un linter inline (ATOMC-E/W-xxx).
//     Tab 2 · Árbol Compilado — placeholder (fase 3 — atomc → bos_atom_compiled)
//     Tab 3 · Comparación BD  — vista lado a lado: árbol fuente vs árbol BD vivo
//                               desde bauth.idn_roles_template.
//   Panel de ayuda + barra de ruta con copia al portapapeles (tabs 0-2).
//   Barra de diagnósticos en Tab 1: muestra conteo total de errores/avisos.
// Dependencias: tf_shadcn_flutter, flutter/services, flutter_riverpod,
//   datos/{arbol_datos, rol_template_datos, atomlang_datos,
//          atomlang_normalizado_datos},
//   widgets/comunes/{arbol_sbos, arbol_template, arbol_bd, panel_lateral, tira_tabs}.
// Estándar: Anexo A.01 (RolTemplate v6.0) · AtomLang-especificacion-completa.md
//           · 2.13 §4 · 2.14 §3/§10 · A.47 §9 · DDL T-162 · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../datos/arbol_datos.dart';
import '../datos/atomlang_datos.dart';
import '../datos/atomlang_normalizado_datos.dart';
import '../datos/rol_template_datos.dart';
import '../nucleo/api/bauth_api.dart';
import '../nucleo/conexion/proveedor_conexion.dart';
import '../widgets/comunes/arbol_bd.dart';
import '../widgets/comunes/arbol_sbos.dart';
import '../widgets/comunes/arbol_template.dart';
import '../widgets/comunes/boton_sbos.dart';
import '../widgets/comunes/panel_lateral.dart';
import '../widgets/comunes/tira_tabs.dart';

/// Vista de mantenimiento del RolTemplate global.
class VistaRolTemplate extends ConsumerStatefulWidget {
  const VistaRolTemplate({super.key});

  @override
  ConsumerState<VistaRolTemplate> createState() => _VistaRolTemplateState();
}

class _VistaRolTemplateState extends ConsumerState<VistaRolTemplate> {
  /// 0 = Árbol Fuente · 1 = AtomLang · 2 = Compilado · 3 = Comparación BD.
  int _tabArbol = 0;

  NodoTemplate? _seleccion;
  String _ruta = '';
  bool _copiado = false;

  // ── Estado de comparación BD (tab 3) ──
  List<NodoRolTemplateBD>? _arbolBD;
  NodoRolTemplateBD? _seleccionBD;
  bool _cargandoBD = false;
  String? _errorBD;

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

  /// Árbol activo según el tab seleccionado (solo para tabs 0-1).
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

  /// Carga el árbol desde bauth.idn_roles_template vía API JSON-RPC.
  Future<void> _cargarDesdeDB() async {
    setState(() {
      _cargandoBD = true;
      _errorBD = null;
    });
    try {
      final api = ref.read(bauthApiProvider);
      final arbol = await api.rolTemplateArbol();
      if (mounted) {
        setState(() {
          _arbolBD = arbol;
          _cargandoBD = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorBD = e.toString();
          _cargandoBD = false;
        });
      }
    }
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
                        tabs: const [
                          'Árbol Fuente',
                          'Árbol AtomLang',
                          'Árbol Compilado',
                          'Comparación BD',
                        ],
                        activa: _tabArbol,
                        alSeleccionar: _cambiarTab,
                      ),
                      // ── Contenido según tab activo ────────────────────────
                      Expanded(child: _contenidoTab(cs)),
                      // ── Barra diagnósticos (solo Tab AtomLang) ────────────
                      if (_tabArbol == 1) _BarraDiagnosticos(cs: cs),
                      // ── Barra de ruta + panel de ayuda (tabs 0-2) ─────────
                      if (_tabArbol < 3) ...[
                        _BarraRuta(
                          ruta: _ruta,
                          copiado: _copiado,
                          alCopiar: _copiarRuta,
                        ),
                        PanelHelp(nodo: _seleccion),
                      ],
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
      case 3:
        return _PanelComparacion(
          arbolBD: _arbolBD,
          cargando: _cargandoBD,
          error: _errorBD,
          seleccionBD: _seleccionBD,
          alSeleccionarBD: (n) => setState(() => _seleccionBD = n),
          alCargar: _cargarDesdeDB,
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

// ═══════════════════════════════════════════════════════════
// Panel de comparación Fuente ↔ BD (Tab 3)
// ═══════════════════════════════════════════════════════════

/// Vista lado a lado: árbol Dart fuente (izq.) vs árbol live de la BD (der.).
/// Permite verificar visualmente que el seed T-162 exportó correctamente.
class _PanelComparacion extends StatelessWidget {
  final List<NodoRolTemplateBD>? arbolBD;
  final bool cargando;
  final String? error;
  final NodoRolTemplateBD? seleccionBD;
  final ValueChanged<NodoRolTemplateBD> alSeleccionarBD;
  final VoidCallback alCargar;

  const _PanelComparacion({
    required this.arbolBD,
    required this.cargando,
    required this.error,
    required this.seleccionBD,
    required this.alSeleccionarBD,
    required this.alCargar,
  });

  int _contar(List<NodoRolTemplateBD> ns) =>
      ns.fold(0, (s, n) => s + 1 + _contar(n.hijos));

  int _contarFuente(List<NodoTemplate> ns) =>
      ns.fold(0, (s, n) => s + 1 + _contarFuente(n.hijos));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalFuente = _contarFuente(arbolRolTemplate);
    final totalBD = arbolBD != null ? _contar(arbolBD!) : null;
    final iguales = totalBD != null && totalBD == totalFuente;
    return Row(
      children: [
        Expanded(child: _PanelArbol(
          titulo: 'FUENTE · Dart',
          subtitulo: '$totalFuente nodos',
          color: cs.primary,
          child: ArbolTemplate(nodos: arbolRolTemplate, alSeleccionar: (_) {}),
        )),
        Container(width: 1, color: cs.border),
        Expanded(child: _PanelArbol(
          titulo: 'BD · idn_roles_template',
          subtitulo: totalBD != null
              ? '$totalBD nodos ${iguales ? '✓ igual' : '≠ fuente ($totalFuente)'}'
              : '—',
          color: Colors.teal.shade400,
          accion: BotonSbos(
            cargando ? 'Cargando…' : 'Cargar BD',
            icono: cargando ? null : LucideIcons.refreshCw,
            alTocar: cargando ? null : alCargar,
          ),
          footerBD: PanelHelpBD(nodo: seleccionBD),
          child: _CuerpoDerechoBD(
            arbolBD: arbolBD,
            cargando: cargando,
            error: error,
            seleccionBD: seleccionBD,
            alSeleccionarBD: alSeleccionarBD,
            alCargar: alCargar,
          ),
        )),
      ],
    );
  }
}

/// Panel con cabecera estándar, árbol scrolleable y footer opcional.
class _PanelArbol extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Color color;
  final Widget child;
  final Widget? accion;
  final Widget? footerBD;

  const _PanelArbol({
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.child,
    this.accion,
    this.footerBD,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 32 * s,
          padding: EdgeInsets.symmetric(horizontal: 12 * s),
          decoration: BoxDecoration(
            color: cs.muted.withValues(alpha: 0.3),
            border: Border(bottom: BorderSide(color: cs.border)),
          ),
          child: Row(children: [
            Icon(LucideIcons.gitCompare, size: 12 * s, color: color),
            SizedBox(width: 6 * s),
            Text(
              titulo,
              style: TextStyle(fontSize: 11 * s, fontWeight: FontWeight.w700, color: color),
            ),
            SizedBox(width: 8 * s),
            Flexible(
              child: Text(
                subtitulo,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'monospace', fontSize: 9.5 * s, color: cs.mutedForeground),
              ),
            ),
            if (accion != null) ...[const Spacer(), accion!],
          ]),
        ),
        Expanded(child: child),
        ?footerBD,
      ],
    );
  }
}

/// Cuerpo del panel derecho: loading / error / invitación / árbol BD.
class _CuerpoDerechoBD extends StatelessWidget {
  final List<NodoRolTemplateBD>? arbolBD;
  final bool cargando;
  final String? error;
  final NodoRolTemplateBD? seleccionBD;
  final ValueChanged<NodoRolTemplateBD> alSeleccionarBD;
  final VoidCallback alCargar;

  const _CuerpoDerechoBD({
    required this.arbolBD,
    required this.cargando,
    required this.error,
    required this.seleccionBD,
    required this.alSeleccionarBD,
    required this.alCargar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;

    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24 * s),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.wifiOff, size: 32 * s, color: cs.destructive.withValues(alpha: 0.7)),
            SizedBox(height: 12 * s),
            Text(
              'Error al conectar con bAuth',
              style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.w700, color: cs.foreground),
            ),
            SizedBox(height: 6 * s),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'monospace', fontSize: 9.5 * s, color: cs.mutedForeground),
            ),
            SizedBox(height: 16 * s),
            BotonSbos('Reintentar', icono: LucideIcons.refreshCw, alTocar: alCargar),
          ]),
        ),
      );
    }

    if (arbolBD == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.database, size: 36 * s, color: Colors.teal.shade400.withValues(alpha: 0.5)),
          SizedBox(height: 12 * s),
          Text(
            'Árbol BD no cargado',
            style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.w700, color: cs.foreground),
          ),
          SizedBox(height: 6 * s),
          Text(
            'Pulsa «Cargar BD» para leer bauth.idn_roles_template\nvía el daemon bAuth en ejecución.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11 * s, height: 1.5, color: cs.mutedForeground),
          ),
          SizedBox(height: 16 * s),
          BotonSbos('Cargar BD', icono: LucideIcons.database, alTocar: alCargar),
        ]),
      );
    }

    if (arbolBD!.isEmpty) {
      return Center(
        child: Text(
          'Sin nodos en bauth.idn_roles_template — ejecuta el seed T-162.',
          style: TextStyle(fontSize: 11.5 * s, color: cs.mutedForeground),
        ),
      );
    }

    return ArbolBD(
      nodos: arbolBD!,
      seleccionado: seleccionBD,
      alSeleccionar: alSeleccionarBD,
    );
  }
}

// ═══════════════════════════════════════════════════════════

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

/// Barra de diagnósticos: aparece debajo del árbol en Tab «Árbol AtomLang».
/// Muestra el total de errores/avisos detectados por el validador AtomLang,
/// comportándose como la barra de problemas de un IDE (Problems panel).
class _BarraDiagnosticos extends StatelessWidget {
  final ColorScheme cs;
  const _BarraDiagnosticos({required this.cs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.scaling;
    final total = totalDiagnosticosArbol;
    final sinErrores = total == 0;

    return Container(
      height: 26 * s,
      decoration: BoxDecoration(
        color: sinErrores
            ? Colors.green.shade900.withValues(alpha: 0.25)
            : Colors.red.shade900.withValues(alpha: 0.25),
        border: Border(
          top: BorderSide(
            color: sinErrores
                ? Colors.green.shade700.withValues(alpha: 0.4)
                : Colors.red.shade700.withValues(alpha: 0.4),
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12 * s),
      child: Row(
        children: [
          Icon(
            sinErrores ? LucideIcons.circleCheck : LucideIcons.circleAlert,
            size: 12 * s,
            color: sinErrores ? Colors.green.shade400 : Colors.red.shade400,
          ),
          SizedBox(width: 6 * s),
          Text(
            sinErrores
                ? 'Árbol AtomLang válido — sin violaciones de lenguaje'
                : '$total violación${total == 1 ? '' : 'es'} detectada${total == 1 ? '' : 's'} '
                    '— expande los nodos marcados con badge rojo para ver detalles',
            style: TextStyle(
              fontSize: 10 * s,
              fontWeight: FontWeight.w600,
              color: sinErrores ? Colors.green.shade400 : Colors.red.shade400,
            ),
          ),
          const Spacer(),
          Text(
            'ATOMC linter · 2.13/2.14/A.47',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9 * s,
              color: cs.mutedForeground.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
