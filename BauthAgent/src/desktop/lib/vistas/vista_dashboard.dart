// ============================================================
// bauth_desktop · vistas/vista_dashboard.dart
//
// Propósito: VISTA «Dashboard de Salud» — conectada a bauth.sync.status.
//   Cabecera (título, badge de estado, selector de rango) + rejilla de
//   6 KPIs en vivo. Los KPIs se actualizan cada 30 s automáticamente.
//
// Fuente de datos: syncStatusProvider → bauth.sync.status (Rust).
// Dependencias: flutter_riverpod, tf_shadcn_flutter, proveedor_conexion.
// Estándar: bAuth Desktop · SPA (vista) · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../nucleo/api/bauth_api.dart';
import '../nucleo/conexion/proveedor_conexion.dart';

/// Vista del Dashboard de Salud con datos reales del daemon.
class VistaDashboard extends ConsumerWidget {
  const VistaDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = Theme.of(context).scaling;
    final syncAsync = ref.watch(syncStatusProvider);
    return SingleChildScrollView(
      padding: EdgeInsets.all(18 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cabecera(syncAsync: syncAsync),
          SizedBox(height: 16 * s),
          _RejillaKpis(syncAsync: syncAsync),
        ],
      ),
    );
  }
}

// ── Cabecera ─────────────────────────────────────────────────

class _Cabecera extends StatelessWidget {
  final AsyncValue<SyncStatusInfo> syncAsync;
  const _Cabecera({required this.syncAsync});

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
              Text('Identity Control Plane · 18 dominios de control',
                  style: TextStyle(fontSize: 12.5 * s, color: cs.mutedForeground)),
            ],
          ),
        ),
        _BadgeEstado(syncAsync: syncAsync),
        SizedBox(width: 9 * s),
        const _SelectorRango(),
      ],
    );
  }
}

/// Badge que muestra OPERATIONAL / CARGANDO / ERROR según el estado del daemon.
class _BadgeEstado extends StatelessWidget {
  final AsyncValue<SyncStatusInfo> syncAsync;
  const _BadgeEstado({required this.syncAsync});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;

    final (String texto, Color color) = syncAsync.when(
      data: (d) => d.status == 'OPERATIONAL'
          ? ('OPERACIONAL', cs.primary)
          : (d.status, cs.destructive),
      loading: () => ('CONECTANDO', cs.mutedForeground),
      error: (e, _) => ('SIN CONEXIÓN', cs.destructive),
    );

    return Container(
      height: 32 * s,
      padding: EdgeInsets.symmetric(horizontal: 12 * s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8 * s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7 * s, height: 7 * s,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          SizedBox(width: 7 * s),
          Text(texto,
              style: TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Selector de rango (visual — sin lógica de filtrado aún).
class _SelectorRango extends StatelessWidget {
  const _SelectorRango();

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
            opcion('En vivo', true),
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

// ── Rejilla de KPIs ──────────────────────────────────────────

class _RejillaKpis extends StatelessWidget {
  final AsyncValue<SyncStatusInfo> syncAsync;
  const _RejillaKpis({required this.syncAsync});

  @override
  Widget build(BuildContext context) {
    return syncAsync.when(
      loading: () => _rejilla(context, _kpisCargando()),
      error: (e, _) => _rejilla(context, _kpisError(e.toString())),
      data: (d) => _rejilla(context, _kpisDeStatus(d)),
    );
  }

  Widget _rejilla(BuildContext context, List<_KpiData> kpis) {
    final s = Theme.of(context).scaling;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < kpis.length; i++) ...[
          if (i > 0) SizedBox(width: 12 * s),
          Expanded(child: _TarjetaKpi(kpi: kpis[i])),
        ],
      ],
    );
  }

  List<_KpiData> _kpisDeStatus(SyncStatusInfo d) => [
    _KpiData('Usuarios activos', LucideIcons.users,
        d.usuariosActivos.toString(), '',
        '${d.sesionesActivas} sesiones activas', _Tono.ok),
    _KpiData('Roles activos', LucideIcons.shieldCheck,
        d.rolesTotal.toString(), '',
        '${d.atomosActivos} átomos en catálogo', _Tono.neutro),
    _KpiData('Átomos con posición', LucideIcons.clipboardCheck,
        d.atomosConPosicion.toString(), '',
        'de ${d.atomosActivos} átomos activos',
        d.atomosConPosicion == d.atomosActivos && d.atomosActivos > 0 ? _Tono.ok : _Tono.neutro),
    _KpiData('Credenciales', LucideIcons.keyRound,
        d.credencialesActivas.toString(), '',
        '${d.intentosUltimaHora} intentos última hora', _Tono.neutro),
    _KpiData('Algoritmos', LucideIcons.lock,
        d.algoritmosAprobados.toString(), ' aprobados',
        'FIPS 203/204/205 + PQC', _Tono.ok),
    _KpiData('Estado daemon', LucideIcons.activity,
        d.status, '',
        'Actualizado hace < 30 s', _Tono.ok),
  ];

  List<_KpiData> _kpisCargando() => List.generate(6, (i) =>
      _KpiData('Cargando…', LucideIcons.loader, '—', '', '', _Tono.neutro));

  List<_KpiData> _kpisError(String msg) => [
    _KpiData('Sin conexión', LucideIcons.wifiOff, '—', '', msg, _Tono.error),
    ...List.generate(5, (i) =>
        _KpiData('—', LucideIcons.minus, '—', '', '', _Tono.neutro)),
  ];
}

// ── Modelo y tarjeta KPI ─────────────────────────────────────

enum _Tono { neutro, ok, error }

class _KpiData {
  final String etiqueta;
  final IconData icono;
  final String valor;
  final String unidad;
  final String nota;
  final _Tono tono;
  const _KpiData(this.etiqueta, this.icono, this.valor, this.unidad,
      this.nota, this.tono);
}

class _TarjetaKpi extends StatelessWidget {
  final _KpiData kpi;
  const _TarjetaKpi({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;

    final Color notaColor = switch (kpi.tono) {
      _Tono.ok    => cs.primary,
      _Tono.error => cs.destructive,
      _Tono.neutro => cs.mutedForeground,
    };

    return Container(
      padding: EdgeInsets.all(16 * s),
      decoration: BoxDecoration(
        color: cs.card,
        border: Border.all(color: cs.border),
        borderRadius: BorderRadius.circular(10 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(kpi.icono, size: 16 * s, color: cs.mutedForeground),
              SizedBox(width: 6 * s),
              Expanded(
                child: Text(kpi.etiqueta,
                    style: TextStyle(fontSize: 12 * s, color: cs.mutedForeground),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          SizedBox(height: 10 * s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(kpi.valor,
                    style: TextStyle(
                        fontSize: 22 * s,
                        fontWeight: FontWeight.w700,
                        color: cs.foreground,
                        fontVariations: const [FontVariation('wght', 700)]),
                    overflow: TextOverflow.ellipsis),
              ),
              if (kpi.unidad.isNotEmpty) ...[
                SizedBox(width: 3 * s),
                Text(kpi.unidad,
                    style: TextStyle(fontSize: 13 * s, color: cs.mutedForeground)),
              ],
            ],
          ),
          if (kpi.nota.isNotEmpty) ...[
            SizedBox(height: 6 * s),
            Text(kpi.nota,
                style: TextStyle(fontSize: 11.5 * s, color: notaColor),
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}
