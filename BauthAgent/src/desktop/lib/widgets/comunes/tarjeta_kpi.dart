// ============================================================
// bauth_desktop · widgets/central/tarjeta_kpi.dart
//
// Propósito: tarjeta de un KPI del Dashboard de Salud — etiqueta + icono en
//   recuadro de acento, valor grande monospace y nota inferior. Colores del
//   tema; tamaños calculados con `theme.scaling`.
// Dependencias: tf_shadcn_flutter, datos/kpi_datos.
// Estándar: prototipo bAuth Desktop · shadcn_flutter · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../datos/kpi_datos.dart';

/// Tarjeta de un indicador KPI.
class TarjetaKpi extends StatelessWidget {
  final Kpi kpi;
  const TarjetaKpi({super.key, required this.kpi});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final colorNota = kpi.tono == TonoKpi.ok ? Colors.green.shade500 : cs.mutedForeground;
    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: cs.card,
        border: Border.all(color: cs.border),
        borderRadius: BorderRadius.circular(12 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(kpi.etiqueta,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5 * s, fontWeight: FontWeight.w500, color: cs.mutedForeground)),
              ),
              SizedBox(width: 8 * s),
              Container(
                width: 28 * s,
                height: 28 * s,
                decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8 * s)),
                child: Center(child: Icon(kpi.icono, size: 16 * s, color: cs.primary)),
              ),
            ],
          ),
          SizedBox(height: 9 * s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(kpi.valor,
                  style: TextStyle(
                      fontFamily: 'monospace', fontSize: 23 * s, fontWeight: FontWeight.w600, color: cs.foreground, height: 1)),
              if (kpi.unidad.isNotEmpty) ...[
                SizedBox(width: 6 * s),
                Text(kpi.unidad, style: TextStyle(fontSize: 11 * s, color: cs.mutedForeground)),
              ],
            ],
          ),
          SizedBox(height: 9 * s),
          Text(kpi.nota, style: TextStyle(fontSize: 11 * s, fontWeight: FontWeight.w500, color: colorNota)),
        ],
      ),
    );
  }
}
