// ============================================================
// bauth_desktop · widgets/comunes/dialogo_crear_atomo.dart
//
// Propósito: diálogo modal para insertar un átomo bajo el nodo
//   seleccionado en bauth.idn_roles_template.
//   Ejecuta INSERT vía psql a SBOSDB con los valores del formulario.
//   path, atom_position y sort_order se calculan en SQL.
//
// Campos:
//   clave_es  — label->>'es' + fragmento del path (slug)
//   nombre_es — name->>'es'
//   nombre_en — name->>'en' (opcional)
//   help_es   — help->>'es' (opcional)
//   verbo     — verb_id (selector canónico)
//   effect    — PERMIT (true) / DENY (false)
//   alias     — alias (opcional)
//
// Dependencias: dart:convert, tf_shadcn_flutter, nucleo/api/bauth_api,
//               nucleo/conexion/cliente_rpc.
// Estándar: DDL T-162 · bAuth Desktop · DOC-SBOS-001 N3.
// ============================================================

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../nucleo/api/bauth_api.dart';
import '../../nucleo/conexion/cliente_rpc.dart';

// ── Verbos canónicos del motor bAuth ─────────────────────────

const _verbosCanonicos = [
  'read', 'write', 'create', 'delete', 'approve',
  'execute', 'export', 'delegate', 'configure', 'audit',
  'login', 'emit', 'void', 'ANY',
];

const _dsnSbos = 'postgres://postgres:postgres@localhost:15432/SBOSDB';

// ── Función de escape SQL ─────────────────────────────────────

/// Envuelve un valor en comillas simples SQL, escapando las internas.
String _lit(String v) => "'${v.replaceAll("'", "''")}'";

/// Codifica SQL en base64 para pasarlo seguro al shell via pipe.
String _b64(String sql) => base64Encode(utf8.encode(sql));

// ═══════════════════════════════════════════════════════════
// Función de apertura
// ═══════════════════════════════════════════════════════════

/// Abre el diálogo modal y llama [alCrear] tras insertar correctamente.
Future<void> mostrarDialogoCrearAtomo(
  BuildContext context, {
  required NodoRolTemplateBD padre,
  required IClienteRpc rpc,
  required VoidCallback alCrear,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoCrearAtomo(padre: padre, rpc: rpc, alCrear: alCrear),
  );
}

// ═══════════════════════════════════════════════════════════
// Diálogo
// ═══════════════════════════════════════════════════════════

class _DialogoCrearAtomo extends StatefulWidget {
  final NodoRolTemplateBD padre;
  final IClienteRpc rpc;
  final VoidCallback alCrear;

  const _DialogoCrearAtomo({
    required this.padre,
    required this.rpc,
    required this.alCrear,
  });

  @override
  State<_DialogoCrearAtomo> createState() => _DialogoCrearAtomoState();
}

class _DialogoCrearAtomoState extends State<_DialogoCrearAtomo> {
  final _claveCtrl    = TextEditingController();
  final _nombreEsCtrl = TextEditingController();
  final _nombreEnCtrl = TextEditingController();
  final _helpEsCtrl   = TextEditingController();
  final _aliasCtrl    = TextEditingController();

  String _verbo     = 'read';
  bool   _effect    = true;
  bool   _guardando = false;
  String? _error;

  @override
  void dispose() {
    _claveCtrl.dispose();    _nombreEsCtrl.dispose();
    _nombreEnCtrl.dispose(); _helpEsCtrl.dispose();
    _aliasCtrl.dispose();
    super.dispose();
  }

  // ── Validación ───────────────────────────────────────────────

  String? _validar() {
    final clave = _claveCtrl.text.trim();
    if (clave.isEmpty) return 'La clave (slug ES) es obligatoria.';
    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(clave)) {
      return 'Clave: solo minúsculas, dígitos, punto y guión bajo.';
    }
    if (_nombreEsCtrl.text.trim().isEmpty) return 'El nombre (ES) es obligatorio.';
    return null;
  }

  // ── SQL ──────────────────────────────────────────────────────

  String _sql() {
    final clave    = _claveCtrl.text.trim();
    final nombreEs = _nombreEsCtrl.text.trim();
    final nombreEn = _nombreEnCtrl.text.trim();
    final helpEs   = _helpEsCtrl.text.trim();
    final alias    = _aliasCtrl.text.trim();
    final pid      = widget.padre.id;
    final nuevaRuta = '${widget.padre.path}.$clave';
    final profundidad = widget.padre.depth + 1;
    final blockCode   = widget.padre.blockCode ?? widget.padre.clave;
    final domSql      = widget.padre.domainNumber?.toString() ?? 'NULL';
    final nameEn      = nombreEn.isNotEmpty ? nombreEn : nombreEs;

    final labelJson = "jsonb_build_object('es',${_lit(clave)},'en',${_lit(clave)})";
    final nameJson  = "jsonb_build_object('es',${_lit(nombreEs)},'en',${_lit(nameEn)})";
    final helpJson  = helpEs.isNotEmpty
        ? "jsonb_build_object('es',${_lit(helpEs)})"
        : "'{}'::jsonb";
    final aliasSql  = alias.isNotEmpty ? _lit(alias) : 'NULL';

    return "INSERT INTO bauth.idn_roles_template"
        " (tenant_id,parent_id,path,domain_number,depth,node_type,block_code,"
        "  label,name,help,effect,verb_id,atom_position,sort_order,is_active,alias,ctx_id)"
        " SELECT t.tenant_id,'$pid'::uuid,${_lit(nuevaRuta)},"
        "$domSql,$profundidad,'atom',${_lit(blockCode)},"
        "$labelJson,$nameJson,$helpJson,"
        "${_effect ? 'true' : 'false'},${_lit(_verbo)},"
        " COALESCE((SELECT MAX(atom_position)+1 FROM bauth.idn_roles_template"
        "           WHERE parent_id='$pid'::uuid AND node_type='atom'),1),"
        " COALESCE((SELECT MAX(sort_order)+10  FROM bauth.idn_roles_template"
        "           WHERE parent_id='$pid'::uuid),10),"
        " true,$aliasSql,'desktop-creator'"
        " FROM bauth.idn_tenant t WHERE t.tenant_slug='skull'"
        " RETURNING id::text,path,atom_position;";
  }

  // ── Guardar ──────────────────────────────────────────────────

  Future<void> _guardar() async {
    final err = _validar();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() { _guardando = true; _error = null; });
    try {
      final b64 = _b64(_sql());
      final r = await widget.rpc.ejecutarCmd(
        "echo $b64 | base64 -d | psql '$_dsnSbos' -t -A",
      );
      final resultado = r.trim();
      if (resultado.isEmpty || resultado == 'null') {
        setState(() {
          _error = 'INSERT sin filas — el path puede existir ya o el padre no existe.';
          _guardando = false;
        });
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.alCrear();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _guardando = false; });
    }
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final s     = theme.scaling;
    final clave = _claveCtrl.text.trim();
    final previaRuta = '${widget.padre.path}.${clave.isEmpty ? '<clave>' : clave}';

    return Center(
      child: Card(
        padding: EdgeInsets.zero,
        child: SizedBox(
        width: 520 * s,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Título ────────────────────────────────────────
              Row(children: [
                Icon(LucideIcons.plus, size: 18 * s, color: cs.primary),
                SizedBox(width: 8 * s),
                Text('Nuevo átomo',
                    style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (!_guardando)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(LucideIcons.x, size: 18 * s, color: cs.mutedForeground),
                  ),
              ]),
              SizedBox(height: 10 * s),
              // Contexto del padre
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 7 * s),
                decoration: BoxDecoration(
                    color: cs.muted, borderRadius: BorderRadius.circular(6 * s)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Padre: ${widget.padre.clave}  (depth ${widget.padre.depth})',
                      style: TextStyle(fontSize: 10.5 * s, color: cs.mutedForeground)),
                  SizedBox(height: 3 * s),
                  Text('Ruta prevista: $previaRuta',
                      style: TextStyle(fontSize: 10 * s, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
              SizedBox(height: 16 * s),
              // ── Campos ───────────────────────────────────────
              _CampoTexto('Clave (slug ES) *', 'ej: usuario.activo', _claveCtrl, s, cs,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_.]'))],
                  alCambiar: (_) => setState(() {})),
              SizedBox(height: 10 * s),
              _CampoTexto('Nombre (ES) *', 'ej: Usuario activo', _nombreEsCtrl, s, cs),
              SizedBox(height: 10 * s),
              _CampoTexto('Nombre (EN)', 'ej: Active user', _nombreEnCtrl, s, cs),
              SizedBox(height: 10 * s),
              _CampoTexto('Help (ES)', 'Descripción del átomo', _helpEsCtrl, s, cs, lineas: 2),
              SizedBox(height: 10 * s),
              _CampoTexto('Alias', 'slug técnico alternativo', _aliasCtrl, s, cs),
              SizedBox(height: 14 * s),
              Row(children: [
                Expanded(child: _SelectorVerbo(
                    valor: _verbo, verbos: _verbosCanonicos, s: s, cs: cs,
                    alCambiar: (v) => setState(() => _verbo = v))),
                SizedBox(width: 12 * s),
                _ToggleEfecto(
                    effect: _effect, s: s, cs: cs,
                    alCambiar: (v) => setState(() => _effect = v)),
              ]),
              // ── Error ─────────────────────────────────────────
              if (_error != null) ...[
                SizedBox(height: 12 * s),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10 * s),
                  decoration: BoxDecoration(
                    color: cs.destructive.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6 * s),
                    border: Border.all(color: cs.destructive.withValues(alpha: 0.5)),
                  ),
                  child: Text(_error!,
                      style: TextStyle(fontSize: 11 * s, color: cs.destructive)),
                ),
              ],
              SizedBox(height: 20 * s),
              // ── Acciones ──────────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (!_guardando)
                  Button(
                    onPressed: () => Navigator.of(context).pop(),
                    style: const ButtonStyle.ghost(),
                    child: Text('Cancelar',
                        style: TextStyle(color: cs.mutedForeground, fontSize: 13 * s)),
                  ),
                SizedBox(width: 8 * s),
                PrimaryButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? SizedBox(
                          width: 16 * s, height: 16 * s,
                          child: CircularProgressIndicator(
                              size: 16 * s, strokeWidth: 2))
                      : Text('Crear átomo', style: TextStyle(fontSize: 13 * s)),
                ),
              ]),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────

/// Campo de texto etiquetado usando el TextField nativo de shadcn.
class _CampoTexto extends StatelessWidget {
  final String etiqueta;
  final String placeholder;
  final TextEditingController ctrl;
  final double s;
  final ColorScheme cs;
  final int lineas;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? alCambiar;

  const _CampoTexto(this.etiqueta, this.placeholder, this.ctrl, this.s, this.cs,
      {this.lineas = 1, this.inputFormatters, this.alCambiar});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta,
            style: TextStyle(
                fontSize: 11.5 * s, fontWeight: FontWeight.w500, color: cs.foreground)),
        SizedBox(height: 4 * s),
        TextField(
          controller: ctrl,
          maxLines: lineas,
          inputFormatters: inputFormatters,
          onChanged: alCambiar,
          style: TextStyle(fontSize: 13 * s, color: cs.foreground),
          placeholder: Text(placeholder,
              style: TextStyle(color: cs.mutedForeground, fontSize: 12 * s)),
        ),
      ],
    );
  }
}

/// Selector de verbo usando Select<String> de shadcn.
class _SelectorVerbo extends StatelessWidget {
  final String valor;
  final List<String> verbos;
  final ValueChanged<String> alCambiar;
  final double s;
  final ColorScheme cs;

  const _SelectorVerbo({
    required this.valor, required this.verbos, required this.alCambiar,
    required this.s, required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Verbo *',
            style: TextStyle(
                fontSize: 11.5 * s, fontWeight: FontWeight.w500, color: cs.foreground)),
        SizedBox(height: 4 * s),
        Select<String>(
          value: valor,
          onChanged: (v) { if (v != null) alCambiar(v); },
          placeholder: Text('Seleccionar verbo',
              style: TextStyle(color: cs.mutedForeground, fontSize: 12.5 * s)),
          itemBuilder: (context, v) =>
              Text(v, style: TextStyle(fontSize: 12.5 * s, color: cs.foreground)),
          popup: (context) => SelectPopup<String>(
            items: SelectItemList(
              children: verbos
                  .map((v) => SelectItemButton<String>(
                        value: v,
                        child: Text(v, style: TextStyle(fontSize: 12.5 * s)),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Toggle visual PERMIT / DENY con color semántico.
class _ToggleEfecto extends StatelessWidget {
  final bool effect;
  final ValueChanged<bool> alCambiar;
  final double s;
  final ColorScheme cs;

  const _ToggleEfecto({
    required this.effect, required this.alCambiar,
    required this.s, required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final color = effect ? cs.primary : cs.destructive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Efecto *',
            style: TextStyle(
                fontSize: 11.5 * s, fontWeight: FontWeight.w500, color: cs.foreground)),
        SizedBox(height: 4 * s),
        GestureDetector(
          onTap: () => alCambiar(!effect),
          child: Container(
            height: 36 * s,
            padding: EdgeInsets.symmetric(horizontal: 12 * s),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(6 * s),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(effect ? LucideIcons.check : LucideIcons.x,
                    size: 14 * s, color: color),
                SizedBox(width: 6 * s),
                Text(effect ? 'PERMIT' : 'DENY',
                    style: TextStyle(
                        fontSize: 12 * s, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
