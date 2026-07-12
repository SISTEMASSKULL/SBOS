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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Motores de bAuth',
              style: TextStyle(color: cs.foreground, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Una capacidad, un motor, un punto de cambio (ADR-013)',
              style: TextStyle(color: cs.mutedForeground, fontSize: 13)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [for (final m in catalogoMotores) TarjetaMotor(motor: m)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
