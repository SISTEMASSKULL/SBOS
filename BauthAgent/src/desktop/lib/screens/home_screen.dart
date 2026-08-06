// ============================================================
// bauth_desktop · screens/home_screen.dart
//
// Propósito: contenido CENTRAL del dashboard (el "contenedor de datos" del
//   viewport) — el tablero de los 7 motores. La navegación y las
//   configuraciones viven en los sidenavs del marco (EstructuraDesktop).
// Dependencias: tf_shadcn_flutter, models/motor, widgets/tarjeta_motor.
// Estándar: ADR-013 · DOC-SBOS-001 N3 (solo el contenido, sin marco).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../models/motor.dart';
import '../widgets/tarjeta_motor.dart';

/// Tablero de motores — contenido central del dashboard.
class TableroMotores extends StatelessWidget {
  const TableroMotores({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s  = theme.scaling;
    return Padding(
      padding: EdgeInsets.all(24 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Motores de bAuth',
              style: TextStyle(color: cs.foreground, fontSize: 24 * s, fontWeight: FontWeight.w700)),
          SizedBox(height: 4 * s),
          Text('Una capacidad, un motor, un punto de cambio (ADR-013)',
              style: TextStyle(color: cs.mutedForeground, fontSize: 13 * s)),
          SizedBox(height: 20 * s),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 16 * s,
                runSpacing: 16 * s,
                children: [for (final m in catalogoMotores) TarjetaMotor(motor: m)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
