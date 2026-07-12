// ============================================================
// bauth_desktop · widgets/tarjeta_motor.dart
//
// Propósito: tarjeta de un motor. Compone TarjetaSbos + PuntoEstado. El color
//   del estado se deriva del TEMA (acento/destructive/base), sin hardcode.
// Dependencias: tf_shadcn_flutter, models/motor, tarjeta_sbos, punto_estado.
// Estándar: DOC-SBOS-001 N3 (sin hardcode de color).
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../models/motor.dart';
import 'punto_estado.dart';
import 'tarjeta_sbos.dart';

/// Tarjeta que presenta un motor del catálogo.
class TarjetaMotor extends StatelessWidget {
  final Motor motor;

  const TarjetaMotor({super.key, required this.motor});

  /// Color del indicador según el nivel — tomado del tema.
  Color _colorNivel(EstadoMotor nivel, ColorScheme cs) => switch (nivel) {
        EstadoMotor.listo => cs.primary,
        EstadoMotor.defecto => cs.destructive,
        _ => cs.mutedForeground,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TarjetaSbos(
      ancho: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PuntoEstado(color: _colorNivel(motor.nivel, cs), tamano: 10),
              const SizedBox(width: 8),
              Text(motor.nombre,
                  style: TextStyle(color: cs.foreground, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(motor.verbo, style: TextStyle(color: cs.mutedForeground, fontSize: 12)),
          const SizedBox(height: 14),
          Text(motor.estado, style: TextStyle(color: cs.foreground, fontSize: 13)),
        ],
      ),
    );
  }
}
