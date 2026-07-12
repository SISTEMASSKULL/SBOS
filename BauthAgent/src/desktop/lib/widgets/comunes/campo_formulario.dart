// ============================================================
// bauth_desktop · widgets/comunes/campo_formulario.dart
//
// Propósito: campo de formulario reutilizable (etiqueta opcional + caja de
//   texto o selección) y una rejilla de 2 columnas para agruparlos. Se usan en
//   cualquier vista. Presentacional por ahora; `scaling`.
// Dependencias: tf_shadcn_flutter.
// Estándar: shadcn_flutter · DOC-SBOS-001 N3 (componente reutilizable).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Campo de formulario: etiqueta (opcional) + caja de entrada.
class CampoFormulario extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final bool esSeleccion;
  const CampoFormulario({super.key, this.etiqueta = '', required this.valor, this.esSeleccion = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (etiqueta.isNotEmpty) ...[
          Text(etiqueta, style: TextStyle(fontSize: 10 * s, fontFamily: 'monospace', color: cs.mutedForeground)),
          SizedBox(height: 3 * s),
        ],
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 5 * s),
          decoration: BoxDecoration(color: cs.muted, border: Border.all(color: cs.border), borderRadius: BorderRadius.circular(4 * s)),
          child: Row(
            children: [
              Expanded(child: Text(valor, style: TextStyle(fontSize: 11 * s, color: cs.foreground))),
              if (esSeleccion) Icon(LucideIcons.chevronDown, size: 13 * s, color: cs.mutedForeground),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rejilla de formulario en 2 columnas (empareja campos por filas).
class RejillaFormulario extends StatelessWidget {
  final List<Widget> campos;
  const RejillaFormulario({super.key, required this.campos});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).scaling;
    final filas = <Widget>[];
    for (int i = 0; i < campos.length; i += 2) {
      filas.add(Padding(
        padding: EdgeInsets.only(bottom: 8 * s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: campos[i]),
            SizedBox(width: 8 * s),
            Expanded(child: i + 1 < campos.length ? campos[i + 1] : const SizedBox()),
          ],
        ),
      ));
    }
    return Column(children: filas);
  }
}
