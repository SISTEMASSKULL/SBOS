// ============================================================
// bauth_desktop · widgets/shell/outlet.dart
//
// Propósito: OUTLET del bloque central (G-BC:OUT) — el hueco donde se cargan
//   TODAS las vistas. Observa la ruta activa, monta la vista que el router
//   resuelve y la envuelve con su etiqueta A.64.01 (V-DS/V-RT/V-CR/V-US/V-AE).
// Dependencias: flutter_riverpod, tf_shadcn_flutter, nucleo/{router_vistas,
//   sidenav_provider}, widgets/comunes/etiqueta_codigo.
// Estándar: G-BC:OUT · A.64.01 · SPA (router-outlet) · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../nucleo/router_vistas.dart';
import '../../nucleo/sidenav_provider.dart';
import '../comunes/etiqueta_codigo.dart';

/// Outlet: monta la vista de la ruta activa con su etiqueta A.64.01.
class Outlet extends ConsumerWidget {
  const Outlet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ruta = ref.watch(layoutProvider).rutaActiva;
    return SeccionConCodigo(_codigoDeVista(ruta), child: vistaDeRuta(ruta));
  }
}

/// Resuelve el código A.64.01 de la vista activa.
String _codigoDeVista(String ruta) => switch (ruta) {
      'dashboard' => 'V-DS',
      'rtpl' => 'V-RT',
      'roles' => 'V-CR',
      'usuarios' => 'V-US',
      'identidad' => 'V-AE',
      _ => 'V-??',
    };
