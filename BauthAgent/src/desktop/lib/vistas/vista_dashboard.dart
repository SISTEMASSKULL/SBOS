// ============================================================
// bauth_desktop · vistas/vista_dashboard.dart
//
// Propósito: VISTA «Dashboard de Salud» — se monta en el outlet. Cabecera
//   (título, «En vivo», selector) + rejilla de 6 KPIs. Los gráficos (radar,
//   actividad) se añaden como componentes aparte. `scaling`.
// Dependencias: tf_shadcn_flutter, datos/kpi_datos, widgets/comunes/tarjeta_kpi.
// Estándar: prototipo bAuth Desktop · SPA (vista) · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../datos/kpi_datos.dart';
import '../widgets/comunes/tarjeta_kpi.dart';

/// Vista del Dashboard de Salud.
class VistaDashboard extends StatelessWidget {
  const VistaDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).scaling;
    return SingleChildScrollView(
      padding: EdgeInsets.all(18 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Cabecera(),
          SizedBox(height: 16 * s),
          const _RejillaKpis(),
        ],
      ),
    );
  }
}

/// Título + subtítulo, «En vivo» y selector de rango.
class _Cabecera extends StatelessWidget {
  const _Cabecera();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard de Salud',
                  style: TextStyle(fontSize: 19 * s, fontWeight: FontWeight.w600, color: cs.foreground)),
              SizedBox(height: 4 * s),
              Text('Identity Control Plane · 12 dominios monitoreados',
                  style: TextStyle(fontSize: 12.5 * s, color: cs.mutedForeground)),
            ],
          ),
        ),
        const _BadgeEnVivo(),
        SizedBox(width: 9 * s),
        const _Selector(),
      ],
    );
  }
}

/// Indicador «En vivo».
class _BadgeEnVivo extends StatelessWidget {
  const _BadgeEnVivo();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      height: 32 * s,
      padding: EdgeInsets.symmetric(horizontal: 12 * s),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        border: Border.all(color: cs.primary),
        borderRadius: BorderRadius.circular(8 * s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7 * s, height: 7 * s, decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle)),
          SizedBox(width: 7 * s),
          Text('En vivo', style: TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w600, color: cs.primary)),
        ],
      ),
    );
  }
}

/// Selector de rango (24h activo · 7d · 30d).
class _Selector extends StatelessWidget {
  const _Selector();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    Widget opcion(String t, bool activo) => Container(
          height: 32 * s,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 12 * s),
          color: activo ? cs.muted : null,
          child: Text(t,
              style: TextStyle(
                  fontSize: 12 * s,
                  fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                  color: activo ? cs.foreground : cs.mutedForeground)),
        );
    return Container(
      decoration: BoxDecoration(border: Border.all(color: cs.border), borderRadius: BorderRadius.circular(8 * s)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8 * s),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            opcion('24h', true),
            Container(width: 1, height: 32 * s, color: cs.border),
            opcion('7d', false),
            Container(width: 1, height: 32 * s, color: cs.border),
            opcion('30d', false),
          ],
        ),
      ),
    );
  }
}

/// Rejilla de los 6 KPIs.
class _RejillaKpis extends StatelessWidget {
  const _RejillaKpis();
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).scaling;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < kpisSalud.length; i++) ...[
          if (i > 0) SizedBox(width: 12 * s),
          Expanded(child: TarjetaKpi(kpi: kpisSalud[i])),
        ],
      ],
    );
  }
}
