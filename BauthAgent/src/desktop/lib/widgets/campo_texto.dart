// ============================================================
// bauth_desktop · widgets/campo_texto.dart
//
// Propósito: componente GLOBAL reutilizable — campo de texto etiquetado.
//   Se usa en el panel de conexión y en cualquier formulario.
// Dependencias: tf_shadcn_flutter (TextField, tema).
// Estándar: DOC-SBOS-001 N3 (widget global parametrizado).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Campo de texto con etiqueta encima. Tipo de teclado configurable.
class CampoTexto extends StatelessWidget {
  final String etiqueta;
  final TextEditingController controlador;
  final TextInputType tipo;

  const CampoTexto({
    super.key,
    required this.etiqueta,
    required this.controlador,
    this.tipo = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: TextStyle(color: cs.mutedForeground, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(controller: controlador, keyboardType: tipo),
      ],
    );
  }
}
