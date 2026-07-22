// ============================================================
// bauth_desktop · widgets/layout/bloque_lateral_derecho.dart
//
// Propósito: BLOQUE 3 del viewport — panel de conexión al daemon
//   bAuth. Permite configurar el túnel SSH (VPS host + usuario +
//   contraseña) o conexión directa host:puerto, y ver el estado
//   del health check en tiempo real.
// Dependencias: tf_shadcn_flutter, widgets/panel_conexion.
// Estándar: ADR-020 · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../panel_conexion.dart';

/// Bloque lateral derecho: panel de conexión al daemon bAuth.
class BloqueLateralDerecho extends StatelessWidget {
  const BloqueLateralDerecho({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      width: 280 * s,
      decoration: BoxDecoration(
        color: cs.card,
        border: Border(left: BorderSide(color: cs.border)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16 * s),
        child: const PanelConexion(),
      ),
    );
  }
}
