// ============================================================
// bauth_desktop · widgets/boton_primario.dart
//
// Propósito: componente GLOBAL reutilizable — botón primario con el color de
//   acento del tema. Deshabilitado si [alPresionar] es null.
// Dependencias: tf_shadcn_flutter.
// Estándar: DOC-SBOS-001 N3 (widget global reutilizable).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Botón primario. Reacciona al acento del tema activo.
class BotonPrimario extends StatelessWidget {
  final String texto;
  final VoidCallback? alPresionar;

  const BotonPrimario({super.key, required this.texto, this.alPresionar});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activo = alPresionar != null;
    return GestureDetector(
      onTap: alPresionar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: activo ? cs.primary : cs.muted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: activo ? cs.primaryForeground : cs.mutedForeground,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
