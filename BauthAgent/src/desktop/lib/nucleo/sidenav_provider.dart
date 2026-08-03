// ============================================================
// bauth_desktop · nucleo/sidenav_provider.dart
//
// Propósito: estado del LAYOUT de 3 bloques. El bloque izquierdo se extiende o
//   colapsa (`izqExpandido`); el bloque central muestra la `rutaActiva` que el
//   menú selecciona; el bloque derecho activa un destino (`activoDer`).
// Dependencias: flutter_riverpod.
// Estándar: maqueta bAuth Desktop (3 bloques) · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Un destino del bloque derecho: identificador + su icono en la barra slim.
class DestinoSidenav {
  final String id;
  final String icono;
  const DestinoSidenav(this.id, this.icono);
}

/// Estado del layout: expansión izquierda, ruta activa central, destino derecho.
class EstadoLayout {
  final bool izqExpandido;
  final String rutaActiva;
  final String? activoDer;
  const EstadoLayout({this.izqExpandido = true, this.rutaActiva = 'dashboard', this.activoDer});

  EstadoLayout copyWith({bool? izqExpandido, String? rutaActiva, String? activoDer, bool limpiarDer = false}) =>
      EstadoLayout(
        izqExpandido: izqExpandido ?? this.izqExpandido,
        rutaActiva: rutaActiva ?? this.rutaActiva,
        activoDer: limpiarDer ? null : (activoDer ?? this.activoDer),
      );
}

/// Conmuta la expansión izquierda, la ruta central y el destino derecho.
class LayoutNotifier extends Notifier<EstadoLayout> {
  @override
  EstadoLayout build() => const EstadoLayout();

  /// Extiende ↔ colapsa el bloque izquierdo (invocado desde el bloque central).
  void alternarIzq() => state = state.copyWith(izqExpandido: !state.izqExpandido);

  /// Fija la ruta que muestra el bloque central (invocado desde el menú).
  void seleccionarRuta(String ruta) => state = state.copyWith(rutaActiva: ruta);

  /// Activa/pliega un destino del bloque derecho (mismo id = plegar).
  void alternarDer(String id) =>
      state = state.activoDer == id ? state.copyWith(limpiarDer: true) : state.copyWith(activoDer: id);
}

/// Provider del estado del layout.
final layoutProvider = NotifierProvider<LayoutNotifier, EstadoLayout>(LayoutNotifier.new);

// ═══════════════════════════════════════════════════════════
// Visibilidad de etiquetas de código A.64.01
// ═══════════════════════════════════════════════════════════

/// Notifier para el toggle de etiquetas A.64.01.
class MostrarCodigosNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Alterna la visibilidad de las etiquetas de código A.64.01.
  void alternar() => state = !state;
}

/// Controla la visibilidad de las etiquetas de referencia A.64.01.
/// false (por defecto) = ocultas; true = visibles.
/// El toggle en BarraSuperior (G-BC-007) invoca alternar().
final mostrarCodigosProvider =
    NotifierProvider<MostrarCodigosNotifier, bool>(MostrarCodigosNotifier.new);
