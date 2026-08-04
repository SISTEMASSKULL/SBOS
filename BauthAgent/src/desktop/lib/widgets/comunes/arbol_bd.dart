// ============================================================
// bauth_desktop · widgets/comunes/arbol_bd.dart
//
// Propósito: árbol de NodoRolTemplateBD con arquitectura MVVM.
//
//   ViewModel (_ArbolBDViewModel extends ChangeNotifier):
//     Dueño único del estado — cargando, error, árbol en memoria,
//     nodos expandidos, lista visible, selección.
//     Carga TODOS los nodos en UN solo ejecutarCmd (una SSH exec).
//     Expansiones posteriores son O(visibles) en memoria pura — sin red.
//
//   View (ArbolBD + _FilaNodo):
//     Solo reacciona al ViewModel. No tiene lógica de negocio.
//     ListenableBuilder reconstruye solo cuando el ViewModel notifica.
//     _FilaNodo usa ValueListenableBuilder para el resaltado de selección:
//     solo la fila afectada rebuilda, no toda la lista.
//
//   Overlay externo:
//     cargandoNotifier (ValueNotifier<bool>) controlado por el ViewModel.
//     La vista padre lo observa para mostrar/ocultar el overlay de carga.
//     Se pone a false cuando cargar() termina (éxito o error) → sin colgarse.
//
// Dependencias: tf_shadcn_flutter, nucleo/api/bauth_api.
// Estándar: DDL T-162 · ADR-020 · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../nucleo/api/bauth_api.dart';
import '../../nucleo/conexion/proveedor_conexion.dart';
import '../../nucleo/dominio/config_tipo_nodo.dart';
import 'indicador_procesamiento.dart';

// ── Etiqueta compuesta del nodo ───────────────────────────────
String _etiquetaNodo(NodoRolTemplateBD n) {
  if (n.tipo == 'dominio' && n.domainNumber != null) {
    return 'D${n.domainNumber!.toString().padLeft(2, '0')} · ${n.clave}';
  }
  if (n.tipo == 'bloque' && n.blockCode != null) {
    return '${n.blockCode} · ${n.clave}';
  }
  return n.clave;
}

// ═══════════════════════════════════════════════════════════
// ViewModel
// ═══════════════════════════════════════════════════════════

/// Estado del árbol BD. Extiende ChangeNotifier — la Vista
/// reacciona vía ListenableBuilder sin setState ni providers.
class _ArbolBDViewModel extends ChangeNotifier {
  /// true mientras se ejecuta cargar().
  bool cargando = true;

  /// Mensaje de error; null si no hubo error.
  String? error;

  /// Mapa parentId → hijos directos (construido en memoria tras cargar).
  final Map<String?, List<NodoRolTemplateBD>> _hijos = {};

  /// IDs de nodos actualmente expandidos.
  final Set<String> _expandidos = {};

  /// Lista plana de nodos visibles en el orden correcto.
  List<NodoRolTemplateBD> visibles = const [];

  /// Notifier de selección: solo la fila afectada rebuilda su fondo.
  final seleccionNotifier = ValueNotifier<NodoRolTemplateBD?>(null);

  @override
  void dispose() {
    seleccionNotifier.dispose();
    super.dispose();
  }

  /// Carga todos los nodos en una sola llamada y construye el árbol en memoria.
  /// Llama a [onTerminado] al finalizar (éxito o error) para el overlay externo.
  Future<void> cargar(
    Future<List<NodoRolTemplateBD>> Function() fn, {
    VoidCallback? onTerminado,
  }) async {
    cargando = true;
    error = null;
    _hijos.clear();
    _expandidos.clear();
    visibles = const [];
    notifyListeners();

    try {
      final todos = await fn();
      // Agrupar por parentId en memoria: O(n) una sola vez.
      for (final n in todos) {
        (_hijos[n.parentId] ??= []).add(n);
      }
      _reconstruirVisibles();
    } catch (e) {
      error = e.toString().length > 300
          ? '${e.toString().substring(0, 300)}…'
          : e.toString();
    } finally {
      cargando = false;
      notifyListeners();
      onTerminado?.call();
    }
  }

  /// Expande o colapsa un nodo. O(visibles) — sin red.
  void toggle(NodoRolTemplateBD nodo) {
    if (!_hijos.containsKey(nodo.id)) return;
    if (_expandidos.contains(nodo.id)) {
      _expandidos.remove(nodo.id);
    } else {
      _expandidos.add(nodo.id);
    }
    _reconstruirVisibles();
    notifyListeners();
  }

  /// Selecciona un nodo. Solo actualiza el ValueNotifier —
  /// no llama notifyListeners() para no rebuildar toda la lista.
  void seleccionar(NodoRolTemplateBD nodo) {
    seleccionNotifier.value = nodo;
  }

  bool tieneHijos(String id) => _hijos.containsKey(id);
  bool estaExpandido(String id) => _expandidos.contains(id);

  void _reconstruirVisibles() {
    final lista = <NodoRolTemplateBD>[];
    _agregarNiveles(null, lista);
    visibles = lista;
  }

  void _agregarNiveles(String? parentId, List<NodoRolTemplateBD> lista) {
    for (final h in _hijos[parentId] ?? const []) {
      lista.add(h);
      if (_expandidos.contains(h.id)) _agregarNiveles(h.id, lista);
    }
  }
}

// ═══════════════════════════════════════════════════════════
// Vista — ArbolBD
// ═══════════════════════════════════════════════════════════

/// Vista del árbol de roles BD.
///
/// Crea su propio ViewModel en [initState] y delega todo el estado a él.
/// La Vista es "tonta": solo renderiza lo que el ViewModel dice.
///
/// [cargarTodos] — función que devuelve TODOS los nodos del árbol en una
///   sola llamada. Se ejecuta una vez al montar y en reintentos.
/// [alSeleccionar] — callback al padre cuando el usuario selecciona un nodo.
/// [cargandoNotifier] — notifier externo que la vista padre observa para
///   mostrar/ocultar su overlay. Se pone a false cuando cargar() termina.
class ArbolBD extends ConsumerStatefulWidget {
  final Future<List<NodoRolTemplateBD>> Function() cargarTodos;
  final ValueChanged<NodoRolTemplateBD?>? alSeleccionar;
  final ValueNotifier<bool>? cargandoNotifier;

  const ArbolBD({
    super.key,
    required this.cargarTodos,
    this.alSeleccionar,
    this.cargandoNotifier,
  });

  @override
  ConsumerState<ArbolBD> createState() => _ArbolBDState();
}

class _ArbolBDState extends ConsumerState<ArbolBD> {
  late final _ArbolBDViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = _ArbolBDViewModel();
    // postFrameCallback: seguro señalar al padre fuera del frame de build actual.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.cargandoNotifier?.value = true;
      _vm.cargar(widget.cargarTodos, onTerminado: () {
        if (mounted) widget.cargandoNotifier?.value = false;
      });
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _reintentar() {
    widget.cargandoNotifier?.value = true;
    _vm.cargar(widget.cargarTodos, onTerminado: () {
      if (mounted) widget.cargandoNotifier?.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = ref.watch(catalogoTiposProvider).asData?.value ?? const {};

    // ListenableBuilder: reconstruye cuando el ViewModel notifica un cambio
    // de estado (cargando → listo, o toggle de nodo).
    // La selección usa ValueListenableBuilder por fila → no pasa por aquí.
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.cargando) {
          return const IndicadorProcesamiento(
            tipo: TipoIndicador.barra,
            opacidadFondo: 0,
          );
        }
        if (_vm.error != null) {
          return _ErrorRaiz(
            mensaje: _vm.error!,
            onReintentar: _reintentar,
          );
        }
        if (_vm.visibles.isEmpty) return _VacioBD();

        return ListView.builder(
          itemCount: _vm.visibles.length,
          itemBuilder: (ctx, i) {
            final n = _vm.visibles[i];
            return _FilaNodo(
              nodo: n,
              config: catalogo[n.tipo] ?? kConfigDesconocido,
              expandido: _vm.estaExpandido(n.id),
              tieneHijos: _vm.tieneHijos(n.id),
              seleccionadoNotifier: _vm.seleccionNotifier,
              onToggle: () => _vm.toggle(n),
              onSeleccionar: () {
                _vm.seleccionar(n);
                widget.alSeleccionar?.call(n);
              },
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Fila de nodo
// ═══════════════════════════════════════════════════════════

/// Fila de un nodo en el árbol BD.
///
/// Usa [ValueListenableBuilder] internamente para el resaltado de selección:
/// solo la fila cuyo id coincide rebuilda su fondo — O(1) en vez de O(visibles).
class _FilaNodo extends StatelessWidget {
  final NodoRolTemplateBD nodo;
  final ConfigTipoNodo config;
  final bool expandido;
  final bool tieneHijos;
  final ValueNotifier<NodoRolTemplateBD?> seleccionadoNotifier;
  final VoidCallback onToggle;
  final VoidCallback onSeleccionar;

  const _FilaNodo({
    required this.nodo,
    required this.config,
    required this.expandido,
    required this.tieneHijos,
    required this.seleccionadoNotifier,
    required this.onToggle,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    final color = config.colorAcentoDe(cs);
    final indent = nodo.depth * 14.0 * s;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onSeleccionar,
        // ValueListenableBuilder: solo esta fila rebuilda cuando cambia
        // la selección. Las demás filas no se reconstruyen.
        child: ValueListenableBuilder<NodoRolTemplateBD?>(
          valueListenable: seleccionadoNotifier,
          builder: (_, selec, _) {
            final activo = selec?.id == nodo.id;
            return Container(
              color: activo ? cs.primary.withValues(alpha: 0.12) : null,
              padding: EdgeInsets.only(
                left: 6 * s + indent,
                top: 3 * s,
                bottom: 3 * s,
                right: 8 * s,
              ),
              child: Row(children: [
                // Icono de expansión (solo si tiene hijos)
                SizedBox(
                  width: 18 * s,
                  height: 18 * s,
                  child: tieneHijos
                      ? MouseRegion(
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
                        )
                      : null,
                ),
                SizedBox(width: 3 * s),
                // Etiqueta con estilo reactivo a selección
                Flexible(
                  child: Text(
                    _etiquetaNodo(nodo),
                    overflow: TextOverflow.ellipsis,
                    style: config.estiloTextoDe(activo, cs, s),
                  ),
                ),
                // Badge de tipo
                if (config.showBadge) ...[
                  SizedBox(width: 6 * s),
                  _BadgeBD(
                      rotulo: config.abbreviation, color: color, s: s),
                ],
                // Valor inline
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
                        color: config.colorValorDe(cs),
                      ),
                    ),
                  ),
                ],
              ]),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Estados de carga / error / vacío
// ═══════════════════════════════════════════════════════════

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
            'Error al cargar árbol BD',
            style: TextStyle(
                fontSize: 13 * s,
                fontWeight: FontWeight.w700,
                color: cs.destructive),
          ),
          SizedBox(height: 8 * s),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10 * s),
            decoration: BoxDecoration(
              color: cs.destructive.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6 * s),
            ),
            child: Text(
              mensaje,
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10 * s,
                  color: cs.destructive),
            ),
          ),
          SizedBox(height: 14 * s),
          GestureDetector(
            onTap: onReintentar,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 14 * s, vertical: 6 * s),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(4 * s),
              ),
              child: Text(
                'Reintentar',
                style: TextStyle(
                    fontSize: 12 * s,
                    fontWeight: FontWeight.w600,
                    color: cs.primaryForeground),
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
        'Sin registros en idn_roles_template',
        style: TextStyle(
            fontSize: 11 * s,
            fontStyle: FontStyle.italic,
            color: cs.mutedForeground),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Badge de tipo
// ═══════════════════════════════════════════════════════════

class _BadgeBD extends StatelessWidget {
  final String rotulo;
  final Color color;
  final double s;
  const _BadgeBD(
      {required this.rotulo, required this.color, required this.s});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4 * s, vertical: 1 * s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3 * s),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

// ═══════════════════════════════════════════════════════════
// Panel de detalle del nodo seleccionado
// ═══════════════════════════════════════════════════════════

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
                      _etiquetaNodo(n),
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
              ],
            ),
    );
  }
}
