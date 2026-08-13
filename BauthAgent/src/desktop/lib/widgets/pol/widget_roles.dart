// ============================================================
// bauth_desktop · widgets/pol/widget_roles.dart
//
// Propósito: Widget Roles del panel Herramientas (V-RT:POL).
//   Editor de nodos del árbol AtomLang (dimensión subject.rol).
//   Fuente canónica: 2.13 §5.1-5.2 · 2.14 §3.3 · §1.1 ATOMLANG-ESTRUCTURA-JERARQUICA
//
//   Regla AtomLang §1.1: todo nodo con hijos es GRUPO.
//   Todo GRUPO aparece en el árbol de Bloque A — cargado desde T-580/T-581.
//
//   Bloque A (arriba): árbol jerárquico dinámico (allAtomLangSchemasProvider).
//     Nivel 0 — tipo de nodo (encabezado de sección, no seleccionable).
//     Nivel 1 — grupos raíz del tipo (parentSlug == null).
//     Nivel 2 — sub-grupos (parentSlug != null).
//   Splitter resizable vertical (mín. 80 px por bloque).
//   Bloque B (abajo): dos tabs:
//     Tab 0 — Atrib. grupo  → atributos del GRUPO seleccionado en Bloque A.
//     Tab 1 — Atrib. comunes → grupos compartidos por todos los nodos.
//
// Dependencias: tf_shadcn_flutter · flutter_riverpod.
// Estándar: A.46 §2 · A.79 §5.1 · 2.14 §3.3 · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../nucleo/api/bauth_api.dart' show NodoSchema;
import '../../nucleo/conexion/proveedor_conexion.dart' show allAtomLangSchemasProvider;

// ── Modelo de selección ───────────────────────────────────────

/// Identifica el GRUPO activo en el árbol por schemaId único (T-580).
class _Seleccion {
  final String schemaId;
  final String slug;
  const _Seleccion(this.schemaId, this.slug);

  @override
  bool operator ==(Object other) =>
      other is _Seleccion && other.schemaId == schemaId;

  @override
  int get hashCode => schemaId.hashCode;
}

// ── Widget principal ──────────────────────────────────────────

/// Widget Roles — editor de nodos de la dimensión subject.rol (A.79 §5.1).
class WidgetRoles extends StatefulWidget {
  const WidgetRoles({super.key});

  @override
  State<WidgetRoles> createState() => _WidgetRolesState();
}

class _WidgetRolesState extends State<WidgetRoles> {
  _Seleccion? _seleccionada;
  double      _fraccionA = 0.42;

  void _ajustarSplitter(double dy, double alturaTotal) {
    setState(() {
      final minF = 80.0 / alturaTotal;
      final maxF = (alturaTotal - 80.0 - 8.0) / alturaTotal;
      _fraccionA = ((_fraccionA * alturaTotal + dy) / alturaTotal)
          .clamp(minF, maxF);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final h  = constraints.maxHeight;
        final hA = (_fraccionA * h).clamp(80.0, h - 88.0);
        final hB = (h - hA - 8.0).clamp(80.0, double.infinity);

        return Column(
          children: [
            SizedBox(
              height: hA,
              child: _BloqueA(
                seleccionada: _seleccionada,
                alSeleccionar: (sel) => setState(() => _seleccionada = sel),
              ),
            ),
            _Splitter(onDrag: (dy) => _ajustarSplitter(dy, h)),
            SizedBox(height: hB, child: _BloqueB(seleccion: _seleccionada)),
          ],
        );
      },
    );
  }
}

// ── Bloque A — árbol jerárquico dinámico de GRUPOs ───────────

/// Árbol que muestra los tipos de nodo AtomLang con sus GRUPOs anidados.
/// Los tipos y grupos se cargan desde T-580/T-581 vía allAtomLangSchemasProvider.
/// No hay listas hardcodeadas: lo que está en la BD, aparece en el árbol.
class _BloqueA extends ConsumerWidget {
  final _Seleccion?              seleccionada;
  final ValueChanged<_Seleccion> alSeleccionar;

  const _BloqueA({required this.seleccionada, required this.alSeleccionar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final s  = Theme.of(context).scaling;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecera(cs, s),
        Expanded(child: _cuerpo(ref, cs, s)),
      ],
    );
  }

  Widget _cabecera(ColorScheme cs, double s) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 5 * s),
        decoration: BoxDecoration(
          color: cs.muted.withValues(alpha: 0.4),
          border: Border(bottom: BorderSide(color: cs.border)),
        ),
        child: Text(
          'GRUPOS',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9 * s,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: cs.mutedForeground,
          ),
        ),
      );

  Widget _cuerpo(WidgetRef ref, ColorScheme cs, double s) {
    final async = ref.watch(allAtomLangSchemasProvider);
    return async.when(
      loading: () => Center(
        child: Text(
          'Cargando árbol…',
          style: TextStyle(
            fontSize: 10 * s,
            color: cs.mutedForeground,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: EdgeInsets.all(10 * s),
        child: Text(
          'Error al cargar el schema:\n$e',
          style: TextStyle(
            fontSize: 9 * s,
            color: cs.destructive,
            fontFamily: 'monospace',
          ),
        ),
      ),
      data: (nodos) => ListView(
        padding: EdgeInsets.symmetric(vertical: 4 * s),
        children: _construirArbol(nodos, null, 0, cs, s),
      ),
    );
  }

  /// Construye el árbol recursivamente a partir de la lista plana de NodoSchema.
  /// parentId=null → nodos raíz (tipos de nodo self). Cada nodo:
  ///   esTipo=true  → _EncabezadoNodo (no seleccionable).
  ///   esTipo=false → _ItemGrupo (seleccionable, muestra atributos en Bloque B).
  List<Widget> _construirArbol(
    List<NodoSchema> nodos,
    String? parentId,
    int profundidad,
    ColorScheme cs,
    double s,
  ) {
    final items = <Widget>[];
    final hijos = nodos
        .where((n) => n.parentId == parentId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final nodo in hijos) {
      if (nodo.esTipo) {
        items.add(_EncabezadoNodo(
          nodo: nodo,
          profundidad: profundidad,
          cs: cs,
          s: s,
        ));
      } else {
        items.add(_ItemGrupo(
          nodo: nodo,
          profundidad: profundidad,
          activo: seleccionada?.schemaId == nodo.schemaId,
          onTap: () => alSeleccionar(_Seleccion(nodo.schemaId, nodo.slug)),
          cs: cs,
          s: s,
        ));
      }
      items.addAll(_construirArbol(nodos, nodo.schemaId, profundidad + 1, cs, s));
    }
    return items;
  }
}

/// Encabezado de sección para una fila "self" de tipo de nodo (no seleccionable).
/// La etiqueta proviene directamente de NodoSchema.labelEs (fuente: T-580).
class _EncabezadoNodo extends StatelessWidget {
  final NodoSchema  nodo;
  final int         profundidad;
  final ColorScheme cs;
  final double      s;

  const _EncabezadoNodo({
    required this.nodo,
    required this.profundidad,
    required this.cs,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final sangria = (8.0 + profundidad * 12.0) * s;
    return Padding(
      padding: EdgeInsets.fromLTRB(sangria, 10 * s, 8 * s, 2 * s),
      child: Row(
        children: [
          Text(
            nodo.labelEs.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 8 * s,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: cs.mutedForeground.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(width: 5 * s),
          Text(
            nodo.slug,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 7.5 * s,
              color: cs.mutedForeground.withValues(alpha: 0.30),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila seleccionable del árbol para un GRUPO del schema AtomLang.
/// La selección se rastrea por schemaId (único en T-580) — no por tipo+slug.
class _ItemGrupo extends StatelessWidget {
  final NodoSchema  nodo;
  final int         profundidad;
  final bool        activo;
  final VoidCallback onTap;
  final ColorScheme cs;
  final double      s;

  const _ItemGrupo({
    required this.nodo,
    required this.profundidad,
    required this.activo,
    required this.onTap,
    required this.cs,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final sangria = (6.0 + profundidad * 12.0) * s;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(sangria, 5 * s, 8 * s, 5 * s),
          decoration: BoxDecoration(
            color: activo ? cs.primary.withValues(alpha: 0.10) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: activo ? cs.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              if (profundidad > 0)
                Text(
                  '└─ ',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10 * s,
                    color: cs.mutedForeground.withValues(alpha: 0.4),
                  ),
                ),
              Expanded(
                child: Text(
                  nodo.labelEs,
                  style: TextStyle(
                    fontSize: 11 * s,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                    color: activo ? cs.primary : cs.foreground,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4 * s, vertical: 1 * s),
                decoration: BoxDecoration(
                  color: cs.muted,
                  borderRadius: BorderRadius.circular(3 * s),
                ),
                child: Text(
                  nodo.slug,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 8 * s,
                    color: cs.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Splitter resizable ────────────────────────────────────────

class _Splitter extends StatelessWidget {
  final ValueChanged<double> onDrag;
  const _Splitter({required this.onDrag});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s  = Theme.of(context).scaling;

    return GestureDetector(
      onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: Container(
          height: 8 * s,
          decoration: BoxDecoration(
            color: cs.muted.withValues(alpha: 0.5),
            border: Border.symmetric(
              horizontal: BorderSide(color: cs.border),
            ),
          ),
          child: Center(
            child: Container(
              width: 28 * s,
              height: 2 * s,
              decoration: BoxDecoration(
                color: cs.mutedForeground.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(1 * s),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bloque B — tabs de propiedades ───────────────────────────

class _BloqueB extends StatefulWidget {
  final _Seleccion? seleccion;
  const _BloqueB({required this.seleccion});

  @override
  State<_BloqueB> createState() => _BloqueBState();
}

class _BloqueBState extends State<_BloqueB> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.muted.withValues(alpha: 0.4),
            border: Border(bottom: BorderSide(color: cs.border)),
          ),
          child: Row(
            children: [
              _TabBtn(
                label: 'Atrib. grupo',
                activo: _tab == 0,
                alTocar: () => setState(() => _tab = 0),
              ),
              _TabBtn(
                label: 'Atrib. comunes',
                activo: _tab == 1,
                alTocar: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              _AtributosGrupo(seleccion: widget.seleccion),
              const _AtributosComunes(),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback alTocar;

  const _TabBtn({
    required this.label,
    required this.activo,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s  = Theme.of(context).scaling;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: alTocar,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: activo ? cs.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10 * s,
              fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
              color: activo ? cs.primary : cs.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tab 0 — Atributos del GRUPO seleccionado ─────────────────

/// Muestra los atributos del GRUPO seleccionado en Bloque A.
/// Reutiliza el allAtomLangSchemasProvider (ya cargado) — sin llamada extra.
/// Localiza el grupo por (nodeType, grupoSlug) y renderiza solo sus atributos.
class _AtributosGrupo extends ConsumerWidget {
  final _Seleccion? seleccion;
  const _AtributosGrupo({required this.seleccion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final s  = Theme.of(context).scaling;

    if (seleccion == null) {
      return Center(
        child: Text(
          'Selecciona un grupo\nen el árbol.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11 * s,
            color: cs.mutedForeground,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
      );
    }

    return ref.watch(allAtomLangSchemasProvider).when(
      loading: () => Center(
        child: Text(
          'Cargando schema…',
          style: TextStyle(
            fontSize: 10 * s,
            color: cs.mutedForeground,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: EdgeInsets.all(12 * s),
        child: Text(
          'Error al cargar schema:\n$e',
          style: TextStyle(fontSize: 9 * s, color: cs.destructive, fontFamily: 'monospace'),
        ),
      ),
      data: (nodos) => _renderNodo(nodos, cs, s),
    );
  }

  /// Localiza el nodo por schemaId y renderiza sus atributos.
  Widget _renderNodo(List<NodoSchema> nodos, ColorScheme cs, double s) {
    final nodo = nodos
        .where((n) => n.schemaId == seleccion!.schemaId)
        .firstOrNull;
    if (nodo == null) {
      return _MensajeInfo('Grupo "${seleccion!.slug}" no encontrado.', cs, s);
    }

    if (nodo.atributos.isEmpty) {
      return _MensajeInfo(
        'Este grupo no tiene atributos directos.\nSelecciona un sub-grupo del árbol.',
        cs, s,
      );
    }

    final campos = nodo.atributos.map((a) {
      final desc = a.enumValores.isNotEmpty
          ? '${a.descEs.isNotEmpty ? "${a.descEs} · " : ""}valores: ${a.enumValores.join(" | ")}'
          : (a.descEs.isNotEmpty ? a.descEs : a.tipo);
      return _CampoFila(a.key, desc, cs, s, soloLectura: a.readonly);
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 6 * s),
      child: _GrupoAtributos(
        titulo: nodo.labelEs,
        subcabecera: nodo.descEs.isNotEmpty ? nodo.descEs : null,
        cs: cs, s: s,
        campos: campos,
      ),
    );
  }

  // Fallback estático — respaldo si T-580/T-581 no están cargados en esta BD.
  // Los valores canónicos viven en bauth_atomlang_schema.sql (seeds T-580/T-581).
  // ignore: unused_element
  List<Widget> _gruposFallback(String tipo, ColorScheme cs, double s) =>
      switch (tipo) {

        // ── atom ──────────────────────────────────────────────────────
        'atom' => [
            _GrupoAtributos(
              titulo: 'Identificación',
              cs: cs, s: s,
              campos: [
                _CampoFila('atom_id',
                    'identificador · snake_case · asignado por sistema',
                    cs, s, soloLectura: true),
                _CampoFila('atom_position',
                    'bigint · posición bit en BitMask · asignado por sistema',
                    cs, s, soloLectura: true),
                _CampoFila('verb_id',
                    'FK privilege_verb.verb_slug · acción que autoriza este átomo',
                    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — Subject',
              cs: cs, s: s,
              subcabecera: 'target.subject — A.46 §2: kind ROL|SET|ANY',
              campos: [
                _CampoFila('kind',
                    'ROL · rol exacto | SET · conjunto de roles | ANY · todos',
                    cs, s),
                _CampoFila('role_id',
                    'FK idn_role_template.rol_slug · requerido si kind = ROL',
                    cs, s),
                _CampoFila('set_id',
                    'FK privilege_role_set.set_slug · requerido si kind = SET',
                    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — Resource',
              cs: cs, s: s,
              subcabecera: 'target.resource — recurso protegido (A.46 §2 resource_ref)',
              campos: [
                _CampoFila('resource',
                    'FK privilege_resource.resource_slug · null = cualquier recurso',
                    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — Environment[]',
              cs: cs, s: s,
              subcabecera: 'target.environment[] — array de atributo_ref (A.46 §2)',
              campos: [
                _CampoFila('property_id',
                    'FK privilege_attribute.attr_slug · propiedad del contexto (PIP)',
                    cs, s),
                _CampoFila('operator',
                    '> | < | >= | <= | == | != | IN | NOT_IN | BETWEEN',
                    cs, s),
                _CampoFila('value',
                    'valor_ref — literal tipado o @bauth_config_param.clave',
                    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — UNSET[]',
              cs: cs, s: s,
              subcabecera: 'Roles excluidos del SET — prioridad sobre set_id (A.46 §2 R-D98-06)',
              campos: [
                _CampoFila('rol_ref[]',
                    'array de rol_slug · excluidos aunque pertenezcan al SET declarado',
                    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Condition',
              cs: cs, s: s,
              subcabecera: 'Condición de activación — atributo_ref único o null (A.46 §2)',
              campos: [
                _CampoFila('property_id',
                    'FK privilege_attribute.attr_slug · null si condition = null',
                    cs, s),
                _CampoFila('operator',
                    '> | < | >= | <= | == | != | IN | NOT_IN | BETWEEN',
                    cs, s),
                _CampoFila('value',
                    'valor_ref — literal tipado o @bauth_config_param.clave',
                    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Effect',
              cs: cs, s: s,
              subcabecera: 'Decisión + obligación + consejo (A.46 §2 effect)',
              campos: [
                _CampoFila('decision',
                    'Permit · concede acceso | Deny · deniega acceso',
                    cs, s),
                _CampoFila('obligation',
                    'mapa_tipado · el PEP DEBE ejecutar (opcional)',
                    cs, s),
                _CampoFila('advice',
                    'cadena · el PEP PUEDE ignorar (opcional)',
                    cs, s),
              ],
            ),
          ],

        // ── rule ──────────────────────────────────────────────────────
        // Igual que atom pero sin atom_position (no es hoja BitMask)
        'rule' => [
            _GrupoAtributos(
              titulo: 'Identificación',
              cs: cs, s: s,
              campos: [
                _CampoFila('verb_id',
                    'FK privilege_verb.verb_slug · acción que autoriza',
                    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — Subject',
              cs: cs, s: s,
              subcabecera: 'target.subject — A.46 §2: kind ROL|SET|ANY',
              campos: [
                _CampoFila('kind',    'ROL | SET | ANY',              cs, s),
                _CampoFila('role_id', 'FK rol_slug · si kind = ROL',  cs, s),
                _CampoFila('set_id',  'FK set_slug · si kind = SET',  cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — Resource',
              cs: cs, s: s,
              campos: [
                _CampoFila('resource',
                    'FK privilege_resource.resource_slug',
                    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — Environment[]',
              cs: cs, s: s,
              subcabecera: 'target.environment[] — array de atributo_ref',
              campos: [
                _CampoFila('property_id',
                    'FK attr_slug · propiedad del contexto (PIP)', cs, s),
                _CampoFila('operator',
                    '> | < | >= | <= | == | != | IN | NOT_IN | BETWEEN', cs, s),
                _CampoFila('value',
                    'valor_ref — literal o @bauth_config_param.clave', cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — UNSET[]',
              cs: cs, s: s,
              subcabecera: 'Roles excluidos del SET',
              campos: [
                _CampoFila('rol_ref[]',
                    'array de rol_slug excluidos explícitamente',
                    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Condition',
              cs: cs, s: s,
              subcabecera: 'Condición única o null (A.46 §2)',
              campos: [
                _CampoFila('property_id',
                    'FK attr_slug · null si sin condición', cs, s),
                _CampoFila('operator', 'operador de comparación', cs, s),
                _CampoFila('value',    'valor_ref',               cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Effect',
              cs: cs, s: s,
              subcabecera: 'Decisión + obligación + consejo',
              campos: [
                _CampoFila('decision',   'Permit | Deny',                     cs, s),
                _CampoFila('obligation', 'mapa_tipado · PEP DEBE (opcional)', cs, s),
                _CampoFila('advice',     'cadena · PEP PUEDE (opcional)',      cs, s),
              ],
            ),
          ],

        // ── policy ────────────────────────────────────────────────────
        // A.46 §2: policy_id · application_id · combining_algorithm · target · atoms[]
        'policy' => [
            _GrupoAtributos(
              titulo: 'Identificación',
              cs: cs, s: s,
              campos: [
                _CampoFila('policy_id',
                    'identificador · snake_case · asignado por sistema',
                    cs, s, soloLectura: true),
                _CampoFila('application_id',
                    'int | null · null = Guardrail transversal (A.46 §2 G-02)',
                    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Algoritmo',
              cs: cs, s: s,
              subcabecera: 'combining_algorithm — OBLIGATORIO en policy (A.46 §2)',
              campos: [
                _CampoFila('combining_algorithm',
                    'deny-overrides | permit-overrides | first-applicable\n'
                    '| deny-unless-permit | permit-unless-deny\n'
                    '| aggregate-strictest (ext. bAuth)',
                    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — Subject',
              cs: cs, s: s,
              subcabecera: 'target.subject (opcional)',
              campos: [
                _CampoFila('kind',    'ROL | SET | ANY',             cs, s),
                _CampoFila('role_id', 'FK rol_slug · si kind = ROL', cs, s),
                _CampoFila('set_id',  'FK set_slug · si kind = SET', cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — Resource',
              cs: cs, s: s,
              campos: [
                _CampoFila('resource',
                    'FK privilege_resource.resource_slug',
                    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — Environment[]',
              cs: cs, s: s,
              subcabecera: 'target.environment[] (opcional)',
              campos: [
                _CampoFila('property_id', 'FK attr_slug', cs, s),
                _CampoFila('operator',    'operador',     cs, s),
                _CampoFila('value',       'valor_ref',    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — UNSET[]',
              cs: cs, s: s,
              subcabecera: 'Roles excluidos del SET (opcional)',
              campos: [
                _CampoFila('rol_ref[]',
                    'array de rol_slug excluidos',
                    cs, s),
              ],
            ),
          ],

        // ── policy_set ────────────────────────────────────────────────
        // A.46 §2: policy_set_id · combining_algorithm · target · children[]
        'policy_set' => [
            _GrupoAtributos(
              titulo: 'Identificación',
              cs: cs, s: s,
              campos: [
                _CampoFila('policy_set_id',
                    'identificador · snake_case · asignado por sistema',
                    cs, s, soloLectura: true),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Algoritmo',
              cs: cs, s: s,
              subcabecera: 'combining_algorithm — OBLIGATORIO en policy_set (A.46 §2)',
              campos: [
                _CampoFila('combining_algorithm',
                    'deny-overrides | permit-overrides | first-applicable\n'
                    '| deny-unless-permit | permit-unless-deny\n'
                    '| aggregate-strictest (ext. bAuth)',
                    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — Subject',
              cs: cs, s: s,
              subcabecera: 'target.subject (opcional)',
              campos: [
                _CampoFila('kind',    'ROL | SET | ANY',             cs, s),
                _CampoFila('role_id', 'FK rol_slug · si kind = ROL', cs, s),
                _CampoFila('set_id',  'FK set_slug · si kind = SET', cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — Resource',
              cs: cs, s: s,
              campos: [
                _CampoFila('resource',
                    'FK privilege_resource.resource_slug',
                    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — Environment[]',
              cs: cs, s: s,
              subcabecera: 'target.environment[] (opcional)',
              campos: [
                _CampoFila('property_id', 'FK attr_slug', cs, s),
                _CampoFila('operator',    'operador',     cs, s),
                _CampoFila('value',       'valor_ref',    cs, s),
              ],
            ),
            _GrupoAtributos(
              titulo: 'Target — UNSET[]',
              cs: cs, s: s,
              subcabecera: 'Roles excluidos del SET (opcional)',
              campos: [
                _CampoFila('rol_ref[]',
                    'array de rol_slug excluidos',
                    cs, s),
              ],
            ),
          ],

        // ── domain ────────────────────────────────────────────────────
        'domain' => [
            _GrupoAtributos(
              titulo: 'Identificación',
              cs: cs, s: s,
              campos: [
                _CampoFila('domain_number',
                    'int NOT NULL · código D00–D15, D98, D99', cs, s),
              ],
            ),
          ],

        // ── block ─────────────────────────────────────────────────────
        'block' => [
            _GrupoAtributos(
              titulo: 'Identificación',
              cs: cs, s: s,
              campos: [
                _CampoFila('block_code',
                    'varchar 10 NOT NULL · B01–B10', cs, s),
              ],
            ),
          ],

        // ── attribute ─────────────────────────────────────────────────
        'attribute' => [
            _GrupoAtributos(
              titulo: 'Valor',
              cs: cs, s: s,
              campos: [
                _CampoFila('value', 'text · valor del atributo', cs, s),
              ],
            ),
          ],

        // ── enum ──────────────────────────────────────────────────────
        'enum' => [
            _GrupoAtributos(
              titulo: 'Valor',
              cs: cs, s: s,
              campos: [
                _CampoFila('value',
                    'text · valor actualmente seleccionado', cs, s),
                _CampoFila('options',
                    'text[] · conjunto de valores permitidos', cs, s),
              ],
            ),
          ],

        // ── nodos contenedores sin atributos propios ───────────────────
        'object' || 'list' || 'event' => [
            _MensajeInfo(
              'Solo atributos comunes.\nVer tab "Atrib. comunes".',
              cs, s,
            ),
          ],

        // ── nodo raíz ─────────────────────────────────────────────────
        'tenant' => [
            _MensajeInfo(
              'Nodo raíz del árbol.\nConfigurado por el Administrador de Sistema.',
              cs, s,
            ),
          ],

        _ => [],
      };
}

// ── Tab 1 — Atributos comunes (todos los nodos) ───────────────

/// Grupos comunes de idn_roles_template (2.13 §5.1).
class _AtributosComunes extends StatelessWidget {
  const _AtributosComunes();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s  = Theme.of(context).scaling;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 6 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GrupoAtributos(
            titulo: 'Identidad',
            cs: cs, s: s,
            campos: [
              _CampoFila('id',        'uuid PK · uuidv7 · asignado por sistema',  cs, s, soloLectura: true),
              _CampoFila('tenant_id', 'uuid FK · tenant del árbol',               cs, s, soloLectura: true),
              _CampoFila('parent_id', 'uuid FK · nodo padre · null en raíz',      cs, s, soloLectura: true),
              _CampoFila('node_type', 'enum · tipo de nodo (12 valores canónicos)',cs, s, soloLectura: true),
            ],
          ),
          _GrupoAtributos(
            titulo: 'Nombre',
            cs: cs, s: s,
            campos: [
              _CampoFila('label',       'jsonb {es, en} · etiqueta visible multiidioma', cs, s),
              _CampoFila('name',        'jsonb {es, en} · nombre técnico multiidioma',   cs, s),
              _CampoFila('alias',       'text · slug snake_case único',                  cs, s),
              _CampoFila('description', 'text · descripción larga en lenguaje natural',  cs, s),
              _CampoFila('help',        'jsonb {es, en} · texto de ayuda contextual',    cs, s),
            ],
          ),
          _GrupoAtributos(
            titulo: 'Posición',
            cs: cs, s: s,
            campos: [
              _CampoFila('depth',      'int · nivel de profundidad en el árbol · calculado', cs, s, soloLectura: true),
              _CampoFila('path',       'text UNIQUE · ruta materializada · calculada',         cs, s, soloLectura: true),
              _CampoFila('sort_order', 'int · orden de presentación dentro del padre',         cs, s),
              _CampoFila('order_idx',  'int · índice de orden alternativo',                    cs, s),
            ],
          ),
          _GrupoAtributos(
            titulo: 'Ciclo de vida',
            cs: cs, s: s,
            campos: [
              _CampoFila('is_active',   'bool · toggle activo/inactivo',           cs, s),
              _CampoFila('version',     'int · versión del nodo · autoincremental', cs, s, soloLectura: true),
              _CampoFila('valid_from',  'date · inicio de vigencia',               cs, s),
              _CampoFila('valid_until', 'date · fin de vigencia · null = indefinido', cs, s),
              _CampoFila('created_at',  'timestamptz · creación · solo sistema',   cs, s, soloLectura: true),
              _CampoFila('updated_at',  'timestamptz · última modificación',       cs, s, soloLectura: true),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Grupo de atributos con encabezado ─────────────────────────

/// Sección con título + subcabecera opcional + lista de campos.
class _GrupoAtributos extends StatelessWidget {
  final String       titulo;
  final String?      subcabecera;
  final List<Widget> campos;
  final ColorScheme  cs;
  final double       s;

  const _GrupoAtributos({
    required this.titulo,
    required this.campos,
    required this.cs,
    required this.s,
    this.subcabecera,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
            decoration: BoxDecoration(
              color: cs.muted.withValues(alpha: 0.35),
              border: Border(
                top:    BorderSide(color: cs.border),
                bottom: BorderSide(color: cs.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 8.5 * s,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: cs.primary,
                  ),
                ),
                if (subcabecera != null) ...[
                  SizedBox(height: 1 * s),
                  Text(
                    subcabecera!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 7.5 * s,
                      color: cs.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10 * s, 8 * s, 10 * s, 4 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < campos.length; i++) ...[
                  campos[i],
                  if (i < campos.length - 1) SizedBox(height: 8 * s),
                ],
              ],
            ),
          ),
        ],
      );
}

// ── Mensaje informativo (sin campo de edición) ────────────────

class _MensajeInfo extends StatelessWidget {
  final String texto;
  final ColorScheme cs;
  final double s;

  const _MensajeInfo(this.texto, this.cs, this.s);

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.all(12 * s),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 11 * s,
            color: cs.mutedForeground,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
      );
}

// ── Campo individual — placeholder visual ─────────────────────

/// Etiqueta + descripción + input placeholder (pendiente de implementar).
class _CampoFila extends StatelessWidget {
  final String campo;
  final String descripcion;
  final ColorScheme cs;
  final double s;
  final bool soloLectura;

  const _CampoFila(
    this.campo,
    this.descripcion,
    this.cs,
    this.s, {
    this.soloLectura = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  campo,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9.5 * s,
                    fontWeight: FontWeight.w700,
                    color: cs.foreground,
                  ),
                ),
              ),
              if (soloLectura)
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 3 * s, vertical: 1 * s),
                  decoration: BoxDecoration(
                    color: cs.muted,
                    borderRadius: BorderRadius.circular(2 * s),
                  ),
                  child: Text(
                    'sistema',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 7.5 * s,
                      color: cs.mutedForeground,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 2 * s),
          Text(
            descripcion,
            style: TextStyle(fontSize: 9 * s, color: cs.mutedForeground),
          ),
          SizedBox(height: 4 * s),
          Container(
            height: 26 * s,
            decoration: BoxDecoration(
              color: cs.background,
              border: Border.all(color: cs.border),
              borderRadius: BorderRadius.circular(4 * s),
            ),
            alignment: Alignment.center,
            child: Text(
              '— pendiente —',
              style: TextStyle(
                fontSize: 9 * s,
                color: cs.mutedForeground.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
}
