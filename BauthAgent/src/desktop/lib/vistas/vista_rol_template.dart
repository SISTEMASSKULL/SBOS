// ============================================================
// bauth_desktop · vistas/vista_rol_template.dart
//
// Propósito: VISTA «Rol Template» — árbol completo de los 14 dominios.
//   Panel lateral izquierdo: vocabulario AtomLang v1 (referencia de lenguaje).
//   Panel central — 3 tabs:
//     Tab 0 · Árbol Fuente    — vista lado a lado: árbol Dart fuente (izq.)
//                               vs árbol live BD idn_roles_template (der.).
//     Tab 1 · Árbol AtomLang  — árbol normalizado (snake_case) + ANALIZADO:
//                               nodos TipoNodo.diagnostico inyectados donde
//                               el árbol viola reglas del lenguaje AtomLang.
//                               Funciona como un linter inline (ATOMC-E/W-xxx).
//     Tab 2 · Árbol Compilado — placeholder (fase 3 — atomc → bos_atom_compiled)
//   Barra de ruta con copia al portapapeles y panel de ayuda (tab 1).
//   Barra de diagnósticos en Tab 1: muestra conteo total de errores/avisos.
// Dependencias: tf_shadcn_flutter, flutter/services, flutter_riverpod,
//   datos/{arbol_datos, rol_template_datos, atomlang_datos,
//          atomlang_normalizado_datos},
//   widgets/comunes/{arbol_sbos, arbol_template, arbol_bd, panel_lateral, tira_tabs}.
// Estándar: Anexo A.01 (RolTemplate v6.0) · AtomLang-especificacion-completa.md
//           · 2.13 §4 · 2.14 §3/§10 · A.47 §9 · DDL T-162 · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../widgets/comunes/indicador_procesamiento.dart';

import '../datos/arbol_datos.dart';
import '../datos/atomlang_datos.dart';
import '../datos/atomlang_normalizado_datos.dart';
import '../datos/rol_template_datos.dart';
import '../nucleo/api/bauth_api.dart';
import '../nucleo/conexion/prueba_conexion.dart';
import '../nucleo/conexion/proveedor_conexion.dart';
import '../widgets/comunes/arbol_bd.dart';
import '../widgets/comunes/arbol_sbos.dart';
import '../widgets/comunes/arbol_template.dart';
import '../widgets/comunes/boton_sbos.dart';
import '../widgets/comunes/dialogo_crear_atomo.dart';
import '../widgets/comunes/panel_lateral.dart';
import '../widgets/comunes/tira_tabs.dart';

// Precalculado una sola vez en tiempo de compilación — evita el DFS
// recursivo en cada rebuild de _PanelComparacion.
int _contarFuenteRec(List<NodoTemplate> ns) =>
    ns.fold(0, (s, n) => s + 1 + _contarFuenteRec(n.hijos));
final int _kTotalFuente = _contarFuenteRec(arbolRolTemplate);

/// Vista de mantenimiento del RolTemplate global.
class VistaRolTemplate extends ConsumerStatefulWidget {
  const VistaRolTemplate({super.key});

  @override
  ConsumerState<VistaRolTemplate> createState() => _VistaRolTemplateState();
}

class _VistaRolTemplateState extends ConsumerState<VistaRolTemplate> {
  int _tabArbol = 0;

  // ── Overlay de carga ──────────────────────────────────────────────────
  // Frame 1: _contenidoListo=false → solo el overlay, cero árbol pesado.
  // Frame 2+: contenido real. El overlay se muestra mientras
  //   catalogoTiposProvider.isLoading (FutureProvider siempre termina
  //   en data/error → imposible quedarse colgado).
  bool _contenidoListo = false;

  // ── Selección via ValueNotifier (sin setState en el padre) ────────────
  final _seleccionNotifier = ValueNotifier<NodoTemplate?>(null);
  final _rutaNotifier = ValueNotifier<String>('');
  final _copiadoNotifier = ValueNotifier<bool>(false);

  // ── Estado de comparación BD (tab 0) ──
  final _seleccionBDNotifier = ValueNotifier<NodoRolTemplateBD?>(null);
  // Overlay MVVM correcto: false=libre, true=cargando.
  // ArbolBD lo pone a true en initState y a false cuando el ViewModel termina.
  // Nunca depende de timers ni de FutureProvider.isLoading.
  final _cargandoBDNotifier = ValueNotifier<bool>(false);
  int _claveArbolBD = 0;

  @override
  void initState() {
    super.initState();
    // Frame 1 pinta solo el overlay (instantáneo).
    // Frame 2 activa el contenido real.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _contenidoListo = true);
    });
  }

  @override
  void dispose() {
    _seleccionNotifier.dispose();
    _rutaNotifier.dispose();
    _copiadoNotifier.dispose();
    _seleccionBDNotifier.dispose();
    _cargandoBDNotifier.dispose();
    super.dispose();
  }

  /// Cambia el tab activo y limpia la selección actual.
  void _cambiarTab(int idx) {
    setState(() { _tabArbol = idx; });
    _seleccionNotifier.value = null;
    _rutaNotifier.value = '';
    _copiadoNotifier.value = false;
    _seleccionBDNotifier.value = null;
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
  /// Sin setState: actualiza solo los notifiers para que PanelHelp y
  /// _BarraRuta rebuildan solos sin tocar ArbolTemplate ni _TreeViewState.
  void _seleccionar(NodoTemplate n) {
    _seleccionNotifier.value = n;
    _rutaNotifier.value = _calcularRuta(_arbolActivo, n, '');
  }

  /// Copia la ruta actual al portapapeles y activa el indicador visual por 2 s.
  Future<void> _copiarRuta() async {
    if (_rutaNotifier.value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _rutaNotifier.value));
    _copiadoNotifier.value = true;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _copiadoNotifier.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Frame 1: spinner solo — sin árbol pesado, aparece instantáneo.
    if (!_contenidoListo) return const IndicadorProcesamiento();

    // Frame 2+: Stack permanente con dos capas:
    //   - Capa 0: vista completa — SIEMPRE presente; ArbolBD nunca se desmonta.
    //   - Capa 1: overlay — aparece/desaparece como SizedBox.shrink sin tocar la capa 0.
    //
    // CRÍTICO: el overlay NO puede envolver la vista.
    // Si lo hiciera, cada cambio de ValueListenableBuilder cambiaría el tipo raíz
    // (Column → Stack o viceversa), obligando a Flutter a desmontar y remontar
    // ArbolBD, que en su initState volvería a activar el notifier → loop infinito.
    return Stack(
      children: [
        _buildVista(cs),
        ValueListenableBuilder<bool>(
          valueListenable: _cargandoBDNotifier,
          builder: (_, cargando, __) {
            if (!cargando || _tabArbol != 0) return const SizedBox.shrink();
            return const IndicadorProcesamiento(
              mensaje: 'Consultando SBOSDB…',
              icono: LucideIcons.database,
            );
          },
        ),
      ],
    );
  }

  /// Vista completa separada del overlay para que ArbolBD sea estable en el árbol.
  Widget _buildVista(ColorScheme cs) {
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
              const _PanelVocabulario(),
              Expanded(
                child: Container(
                  color: cs.background,
                  child: Column(
                    children: [
                      TiraTabs(
                        tabs: const [
                          'Árbol Fuente',
                          'Árbol AtomLang',
                          'Árbol Compilado',
                        ],
                        activa: _tabArbol,
                        alSeleccionar: _cambiarTab,
                      ),
                      Expanded(child: _contenidoTab(cs)),
                      if (_tabArbol == 1) _BarraDiagnosticos(cs: cs),
                      if (_tabArbol == 1) ...[
                        ListenableBuilder(
                          listenable: Listenable.merge(
                              [_rutaNotifier, _copiadoNotifier]),
                          builder: (_, _) => _BarraRuta(
                            ruta: _rutaNotifier.value,
                            copiado: _copiadoNotifier.value,
                            alCopiar: _copiarRuta,
                          ),
                        ),
                        ValueListenableBuilder<NodoTemplate?>(
                          valueListenable: _seleccionNotifier,
                          builder: (_, nodo, _) => PanelHelp(nodo: nodo),
                        ),
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
        return _PanelComparacion(
          // Una sola SSH exec para todos los nodos — sin carga lazy por nodo.
          cargarTodos: () => ref.read(bauthApiProvider).rolTemplateTodos(),
          claveArbol: _claveArbolBD,
          cargandoNotifier: _cargandoBDNotifier,
          seleccionListenable: _seleccionBDNotifier,
          alSeleccionarBD: (n) => _seleccionBDNotifier.value = n,
          alRecargar: () {
            // Reinicia el overlay antes de que ArbolBD remonte.
            _cargandoBDNotifier.value = false;
            _seleccionBDNotifier.value = null;
            setState(() { _claveArbolBD++; });
          },
        );
      case 1:
        return ArbolTemplate(
          nodos: arbolNormalizado,
          seleccionListenable: _seleccionNotifier,
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

// ═══════════════════════════════════════════════════════════
// Panel de comparación Fuente ↔ BD (Tab 3)
// ═══════════════════════════════════════════════════════════

/// Vista lado a lado: árbol Dart fuente (izq.) vs árbol live de la BD (der.).
/// El árbol BD solo se monta cuando hay conexión SSH activa — previene el
/// cuelgue de 10 min que ocurre cuando TCP intenta conectar a localhost:9450.
///
/// [seleccionListenable] en vez de un valor directo: cuando el usuario selecciona
/// un nodo en ArbolBD solo rebuilda el ValueListenableBuilder interior (subtítulo,
/// botón + Átomo, PanelHelpBD) — ArbolBD y ArbolTemplate izquierdo NO rebuildan.
class _PanelComparacion extends ConsumerWidget {
  /// Carga TODOS los nodos en una sola SSH exec — sin lazy loading por nodo.
  final Future<List<NodoRolTemplateBD>> Function() cargarTodos;
  final int claveArbol;
  /// Notifier que ArbolBD usa para señalar inicio/fin de carga al padre.
  final ValueNotifier<bool>? cargandoNotifier;
  final ValueListenable<NodoRolTemplateBD?> seleccionListenable;
  final ValueChanged<NodoRolTemplateBD?> alSeleccionarBD;
  final VoidCallback alRecargar;

  const _PanelComparacion({
    required this.cargarTodos,
    required this.claveArbol,
    required this.seleccionListenable,
    required this.alSeleccionarBD,
    required this.alRecargar,
    this.cargandoNotifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final s  = Theme.of(context).scaling;
    // _kTotalFuente se calcula UNA vez al cargar la biblioteca — no en cada rebuild.
    final conexion = ref.watch(pruebaConexionProvider);
    final conectado = conexion.fase == FaseConexion.exitosa;

    // ArbolBD se pasa como child de ValueListenableBuilder:
    // NO rebuilda cuando cambia la selección — solo el panel derecho lo hace.
    final arbolBDOPlaceholder = conectado
        ? ArbolBD(
            key: ValueKey(claveArbol),
            cargarTodos: cargarTodos,
            alSeleccionar: alSeleccionarBD,
            cargandoNotifier: cargandoNotifier,
          )
        : const _PlaceholderSinConexionBD();

    return Row(
      children: [
        Expanded(
          child: _PanelArbol(
            titulo: 'FUENTE · Dart',
            subtitulo: '$_kTotalFuente nodos',
            color: cs.primary,
            child: ArbolTemplate(nodos: arbolRolTemplate, alSeleccionar: (_) {}),
          ),
        ),
        Container(width: 1, color: cs.border),
        Expanded(
          child: ValueListenableBuilder<NodoRolTemplateBD?>(
            valueListenable: seleccionListenable,
            // child: ArbolBD no rebuilda en cada cambio de selección
            child: arbolBDOPlaceholder,
            builder: (context, seleccionBD, arbolBDChild) {
              final puedeAgregar =
                  conectado && seleccionBD != null && seleccionBD.tipo != 'atom';

              final accionBD = conectado
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (puedeAgregar) ...[
                          BotonSbos(
                            '+ Átomo',
                            icono: LucideIcons.plus,
                            alTocar: () => mostrarDialogoCrearAtomo(
                              context,
                              padre: seleccionBD,
                              rpc: ref.read(clienteRpcActivoProvider),
                              alCrear: alRecargar,
                            ),
                          ),
                          SizedBox(width: 6 * s),
                        ],
                        BotonSbos(
                            'Recargar', icono: LucideIcons.refreshCw, alTocar: alRecargar),
                      ],
                    )
                  : null;

              return _PanelArbol(
                titulo: 'BD · idn_roles_template',
                subtitulo: conectado
                    ? (seleccionBD != null
                        ? 'selección: ${seleccionBD.clave}'
                        : 'sin selección')
                    : 'sin conexión',
                color: Colors.teal.shade400,
                accion: accionBD,
                footerBD: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (conectado) PanelHelpBD(nodo: seleccionBD, alto: 65),
                    const _BarraConexionBD(),
                  ],
                ),
                child: arbolBDChild!,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Overlay de carga inicial ─────────────────────────────────


/// Placeholder para el panel BD cuando no hay conexión SSH activa.
class _PlaceholderSinConexionBD extends StatelessWidget {
  const _PlaceholderSinConexionBD();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.wifiOff,
            size: 32 * s,
            color: cs.mutedForeground.withValues(alpha: 0.35),
          ),
          SizedBox(height: 12 * s),
          Text(
            'Sin conexión a bAuth',
            style: TextStyle(
              fontSize: 13 * s,
              fontWeight: FontWeight.w700,
              color: cs.foreground,
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            'Configura el túnel SSH en el panel lateral\ny pulsa "Conectar vía SSH".',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11 * s,
              height: 1.55,
              color: cs.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de estado de conexión al pie del panel BD.
/// Muestra en tiempo real el resultado del health check / error del túnel SSH.
/// Se actualiza sola cuando cambia pruebaConexionProvider.
class _BarraConexionBD extends ConsumerWidget {
  const _BarraConexionBD();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(pruebaConexionProvider);
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;

    final esFallida = r.fase == FaseConexion.fallida;
    final esOK = r.fase == FaseConexion.exitosa;
    final esProbando = r.fase == FaseConexion.probando;

    final color = esFallida
        ? cs.destructive
        : esOK
            ? Colors.green.shade400
            : cs.mutedForeground;

    final icono = esOK
        ? LucideIcons.shieldCheck
        : esProbando
            ? LucideIcons.refreshCw
            : LucideIcons.wifiOff;

    final texto = esFallida
        ? r.mensaje
        : esOK
            ? '${r.mensaje}  — si el árbol muestra error, pulsa Recargar'
            : esProbando
                ? 'Verificando conexión con bAuth…'
                : 'Sin conexión  — configura el túnel SSH en el panel de conexión';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
      decoration: BoxDecoration(
        color: esFallida
            ? cs.destructive.withValues(alpha: 0.07)
            : cs.muted.withValues(alpha: 0.25),
        border: Border(
          top: BorderSide(
            color: esFallida
                ? cs.destructive.withValues(alpha: 0.4)
                : cs.border,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1 * s),
            child: Icon(icono, size: 11 * s, color: color),
          ),
          SizedBox(width: 6 * s),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontFamily: esFallida ? 'monospace' : null,
                fontSize: 9.5 * s,
                color: color,
                height: 1.45,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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

/// Panel izquierdo del vocabulario AtomLang v1 (referencia de lenguaje).
///
/// Widget const: Flutter detecta la misma instancia en cada rebuild del padre
/// y OMITE la actualización del element — el árbol de vocabulario no se
/// reconstruye cuando el usuario selecciona un nodo en el árbol principal.
class _PanelVocabulario extends StatelessWidget {
  const _PanelVocabulario();

  static void _ignorar(NodoTemplate _) {}

  @override
  Widget build(BuildContext context) {
    return PanelLateral(
      titulo: 'AtomLang v1',
      conteo: 'vocabulario',
      lado: LadoPanel.izquierdo,
      child: ArbolTemplate(
        nodos: arbolAtomLang,
        shrinkWrap: true,
        alSeleccionar: _ignorar,
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
