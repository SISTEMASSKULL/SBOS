// ============================================================
// bauth_desktop · widgets/shell/outlet.dart
//
// Propósito: OUTLET del bloque central — el hueco donde se cargan TODAS las
//   vistas. Observa la ruta activa y monta la vista que el router resuelve.
//   No dibuja contenido propio.
// Dependencias: flutter_riverpod, tf_shadcn_flutter, nucleo/{router_vistas,
//   sidenav_provider}.
// Estándar: SPA (router-outlet) · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../nucleo/router_vistas.dart';
import '../../nucleo/sidenav_provider.dart';

/// Outlet: monta la vista de la ruta activa.
class Outlet extends ConsumerWidget {
  const Outlet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ruta = ref.watch(layoutProvider).rutaActiva;
    return vistaDeRuta(ruta);
  }
}
