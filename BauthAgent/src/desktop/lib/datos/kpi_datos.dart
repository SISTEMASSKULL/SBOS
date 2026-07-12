// ============================================================
// bauth_desktop · datos/kpi_datos.dart
//
// Propósito: datos de los indicadores KPI del Dashboard de Salud, transcritos
//   del prototipo bAuth Desktop. Solo datos; la presentación vive en TarjetaKpi.
// Dependencias: tf_shadcn_flutter (IconData/LucideIcons).
// Estándar: prototipo bAuth Desktop · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Tono semántico de la nota inferior de un KPI.
enum TonoKpi { neutro, ok }

/// Un indicador KPI: etiqueta + icono, valor (con unidad) y nota inferior.
class Kpi {
  final String etiqueta;
  final IconData icono;
  final String valor;
  final String unidad;
  final String nota;
  final TonoKpi tono;
  const Kpi(this.etiqueta, this.icono, this.valor,
      {this.unidad = '', required this.nota, this.tono = TonoKpi.neutro});
}

/// Los 6 KPIs del Dashboard de Salud (orden del prototipo).
const List<Kpi> kpisSalud = [
  Kpi('Usuarios totales', LucideIcons.users, '1.247', nota: '89 conectados', tono: TonoKpi.ok),
  Kpi('Roles activos', LucideIcons.search, '366', nota: '3 con DRIFT'),
  Kpi('Átomos', LucideIcons.clipboardCheck, '5.808', nota: 'catálogo completo'),
  Kpi('FastPath', LucideIcons.zap, '99.7', unidad: '%', nota: '0.3 % PolicyPath', tono: TonoKpi.ok),
  Kpi('Latencia eval.', LucideIcons.activity, '0.3', unidad: 'ns', nota: 'P99 4.7 ms'),
  Kpi('CPU daemon', LucideIcons.cpu, '18', unidad: '%', nota: 'RAM 62 MB · 47 hilos'),
];
