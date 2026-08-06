// ============================================================
// bauth_desktop · vistas/vista_rol_template.dart
//
// Propósito: VISTA «Rol Template» — comparación lado a lado
//   del árbol Dart fuente (izq.) vs árbol live de SBOSDB (der.).
//   Panel derecho: Políticas colapsable.
//
// Dependencias: tf_shadcn_flutter, flutter_riverpod,
//   datos/{arbol_datos, rol_template_datos},
//   widgets/comunes/{arbol_sbos, arbol_template, arbol_bd,
//                    panel_lateral, tira_tabs, boton_sbos,
//                    dialogo_crear_atomo, indicador_procesamiento}.
// Estándar: Anexo A.01 (RolTemplate v6.0) · DDL T-162 · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../widgets/comunes/etiqueta_codigo.dart';
import '../widgets/comunes/indicador_procesamiento.dart';

import '../datos/rol_template_datos.dart';
import '../nucleo/api/bauth_api.dart';
import '../nucleo/conexion/prueba_conexion.dart';
import '../nucleo/conexion/proveedor_conexion.dart';
import '../widgets/comunes/arbol_bd.dart';
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
  final _seleccionBDNotifier = ValueNotifier<NodoRolTemplateBD?>(null);

  // Overlay elegante: true desde el primer frame para que aparezca
  // inmediatamente al abrir la vista. ArbolBD lo pone a false al terminar.
  final _cargandoBDNotifier = ValueNotifier<bool>(true);
  int _claveArbolBD = 0;

  @override
  void dispose() {
    _seleccionBDNotifier.dispose();
    _cargandoBDNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Stack permanente con dos capas:
    //   Capa 0: vista completa — ArbolBD nunca se desmonta.
    //   Capa 1: overlay de carga — aparece/desaparece sin tocar la capa 0.
    return Stack(
      children: [
        _buildVista(cs),
        ValueListenableBuilder<bool>(
          valueListenable: _cargandoBDNotifier,
          builder: (_, cargando, _) {
            if (!cargando) return const SizedBox.shrink();
            return const IndicadorProcesamiento(
              mensaje: 'Consultando SBOSDB…',
              icono: LucideIcons.database,
            );
          },
        ),
      ],
    );
  }

  Widget _buildVista(ColorScheme cs) {
    return Column(
      children: [
        SeccionConCodigo(
          'V-RT-002',
          child: const TiraTabs(
            tabs: ['Roles', 'Usuarios', 'Políticas', 'Atributos', 'Aplicaciones', 'Átomos'],
            activa: 0,
            separadorTras: 1,
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // ── Sidenav izquierdo (V-RT:VOC) — Menú Roles Template ──
              const SeccionConCodigo(
                'V-RT:VOC',
                child: PanelLateral(
                  titulo: 'Roles Template',
                  lado: LadoPanel.izquierdo,
                ),
              ),
              Expanded(
                child: SeccionConCodigo(
                  'V-RT:CNT',
                  child: _PanelComparacion(
                    cargarTodos: () =>
                        ref.read(bauthApiProvider).rolTemplateTodos(),
                    claveArbol: _claveArbolBD,
                    cargandoNotifier: _cargandoBDNotifier,
                    seleccionListenable: _seleccionBDNotifier,
                    alSeleccionarBD: (n) => _seleccionBDNotifier.value = n,
                    alRecargar: () {
                      _cargandoBDNotifier.value = false;
                      _seleccionBDNotifier.value = null;
                      setState(() { _claveArbolBD++; });
                    },
                  ),
                ),
              ),
              // ── Sidenav derecho (V-RT:POL) — Herramientas ──
              const SeccionConCodigo(
                'V-RT:POL',
                child: PanelLateral(
                  titulo: 'Herramientas',
                  lado: LadoPanel.derecho,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Panel de comparación Fuente ↔ BD
// ═══════════════════════════════════════════════════════════

/// Vista lado a lado: árbol Dart fuente (izq.) vs árbol live de la BD (der.).
/// El árbol BD solo se monta cuando banexus está conectado y bAuth responde
/// (pruebaConexionProvider.fase == exitosa). Usa llamar() vía banexus.
///
/// [seleccionListenable] evita rebuilds de ArbolBD al seleccionar nodos:
/// solo el panel de detalle derecho se actualiza.
class _PanelComparacion extends ConsumerWidget {
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
    final conexion = ref.watch(pruebaConexionProvider);
    final conectado = conexion.fase == FaseConexion.exitosa;

    // ArbolBD se pasa como child del ValueListenableBuilder:
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
          child: SeccionConCodigo(
            'V-RT-011',
            child: _PanelArbol(
              titulo: 'FUENTE · Dart',
              subtitulo: '$_kTotalFuente nodos',
              color: cs.primary,
              child: ArbolTemplate(nodos: arbolRolTemplate, alSeleccionar: (_) {}),
            ),
          ),
        ),
        Container(width: 1, color: cs.border),
        Expanded(
          child: ValueListenableBuilder<NodoRolTemplateBD?>(
            valueListenable: seleccionListenable,
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
                          'Recargar',
                          icono: LucideIcons.refreshCw,
                          alTocar: alRecargar,
                        ),
                      ],
                    )
                  : null;

              return SeccionConCodigo(
                'V-RT-012',
                child: _PanelArbol(
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Placeholder para el panel BD cuando banexus no está conectado.
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
            'Verifica la conexión banexus\n(pulsa G-BC-004 para reconectar).',
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
/// Se actualiza sola cuando cambia pruebaConexionProvider.
class _BarraConexionBD extends ConsumerWidget {
  const _BarraConexionBD();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(pruebaConexionProvider);
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;

    final esFallida = r.fase == FaseConexion.fallida;
    final esOK      = r.fase == FaseConexion.exitosa;
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
                : 'Sin conexión  — usa G-BC-004 para reconectar a bAuth';

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
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9.5 * s,
                  color: cs.mutedForeground,
                ),
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
