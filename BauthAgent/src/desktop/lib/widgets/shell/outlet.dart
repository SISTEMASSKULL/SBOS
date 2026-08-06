// ============================================================
// bauth_desktop · widgets/shell/outlet.dart
//
// Propósito: OUTLET del bloque central (G-BC:OUT) — monta cada vista
//   UNA SOLA VEZ y la mantiene viva con Offstage + TickerMode.
//
//   Patrón: caché lazy — la vista se crea en el primer acceso y nunca
//   se destruye mientras el usuario esté en la sesión. Al navegar a otra
//   sección, la vista anterior queda Offstage (invisible y sin ticks).
//   Al volver, recupera su estado exacto sin re-inicialización.
//
//   Sin esta caché: el Outlet recrea la vista en cada rebuild del parent
//   → ArbolTemplate.initState() vuelve a ejecutar el DFS sobre 3826 líneas
//   de datos → freeze de 4-10 s en cada retorno a la sección Rol.
//
// Dependencias: flutter_riverpod, tf_shadcn_flutter, nucleo/{router_vistas,
//   sidenav_provider}, widgets/comunes/etiqueta_codigo.
// Estándar: G-BC:OUT · A.64.01 · SPA (router-outlet) · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../nucleo/router_vistas.dart';
import '../../nucleo/sidenav_provider.dart';
import '../comunes/etiqueta_codigo.dart';

// Rutas registradas en el router — orden define el z-order en el Stack.
const _rutas = ['dashboard', 'rtpl', 'roles', 'usuarios', 'identidad'];

/// Código A.64.01 de la vista activa — marca la sección visible al usuario.
String _codigoDeVista(String ruta) => switch (ruta) {
      'dashboard' => 'V-DS',
      'rtpl'      => 'V-RT',
      'roles'     => 'V-CR',
      'usuarios'  => 'V-US',
      'identidad' => 'V-AE',
      _           => 'V-??',
    };

/// Outlet con caché lazy de vistas.
///
/// Cada vista se crea la primera vez que el usuario navega a ella y se
/// mantiene en el árbol como [Offstage] en las navegaciones posteriores.
/// [TickerMode] pausa todas las animaciones en las vistas invisibles.
class Outlet extends ConsumerStatefulWidget {
  const Outlet({super.key});

  @override
  ConsumerState<Outlet> createState() => _OutletState();
}

class _OutletState extends ConsumerState<Outlet> {
  /// Caché de vistas ya construidas. El Widget aquí es inmutable — la vista
  /// conserva su estado gracias al árbol de Flutter (GlobalKey implícito).
  final Map<String, Widget> _cache = {};

  /// Devuelve la vista para [ruta], creándola si es la primera visita.
  Widget _vista(String ruta) => _cache.putIfAbsent(
        ruta,
        () => SeccionConCodigo(
          _codigoDeVista(ruta),
          child: vistaDeRuta(ruta),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final rutaActiva = ref.watch(layoutProvider).rutaActiva;

    return Stack(
      fit: StackFit.expand,
      children: _rutas.map((ruta) {
        final esActiva = ruta == rutaActiva;

        // Si la vista nunca fue visitada y no es la activa, colocar
        // un placeholder vacío — no se construye ni se inicializa.
        if (!_cache.containsKey(ruta) && !esActiva) {
          return const SizedBox.shrink();
        }

        return TickerMode(
          enabled: esActiva,
          child: Offstage(
            offstage: !esActiva,
            child: _vista(ruta),
          ),
        );
      }).toList(),
    );
  }
}
