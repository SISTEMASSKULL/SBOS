// ============================================================
// bauth_desktop · nucleo/router_vistas.dart
//
// Propósito: ROUTER de la SPA — mapea la ruta activa a la VISTA que se monta
//   en el outlet del bloque central. El shell no conoce las vistas: las pide
//   aquí por ruta.
// Dependencias: tf_shadcn_flutter, vistas/*.
// Estándar: SPA (router-outlet) · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../vistas/vista_dashboard.dart';
import '../vistas/vista_entidades.dart';
import '../vistas/vista_rol_template.dart';
import '../vistas/vista_roles.dart';
import '../vistas/vista_usuarios.dart';

/// Devuelve la vista correspondiente a una ruta (o un marcador si no existe).
Widget vistaDeRuta(String ruta) => switch (ruta) {
      'dashboard' => const VistaDashboard(),
      'rtpl' => const VistaRolTemplate(),
      'roles' => const VistaRoles(),
      'usuarios' => const VistaUsuarios(),
      'identidad' => const VistaEntidades(),
      _ => const _VistaEnConstruccion(),
    };

/// Marcador para rutas aún no desarrolladas.
class _VistaEnConstruccion extends StatelessWidget {
  const _VistaEnConstruccion();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.settings2, size: 28 * s, color: cs.mutedForeground),
          SizedBox(height: 8 * s),
          Text('En construcción', style: TextStyle(fontSize: 13 * s, color: cs.mutedForeground)),
        ],
      ),
    );
  }
}
