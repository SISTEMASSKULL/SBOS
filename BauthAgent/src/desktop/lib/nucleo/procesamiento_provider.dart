// ============================================================
// bauth_desktop · nucleo/procesamiento_provider.dart
//
// Propósito: estado global de procesamiento para toda la aplicación.
//   Cualquier widget que inicie una tarea asíncrona llama a:
//     ref.read(procesamientoProvider.notifier).iniciar('Mensaje…');
//   Al terminar (éxito o error):
//     ref.read(procesamientoProvider.notifier).terminar();
//   BarraEstado (G-BC:SB-005) escucha este provider y muestra
//   la barra de progreso global automáticamente.
//
// Dependencias: flutter_riverpod.
// Estándar: G-BC:SB-005 · A.64.01 · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado inmutable de la barra de progreso global.
class EstadoProcesamiento {
  /// true mientras alguna tarea asíncrona está activa.
  final bool activo;

  /// Descripción de la tarea en curso. null = sin mensaje visible.
  final String? mensaje;

  const EstadoProcesamiento({this.activo = false, this.mensaje});
}

/// Notifier que gestiona el estado de procesamiento global.
/// Accesible desde cualquier ConsumerWidget del desktop.
class ProcesamientoNotifier extends Notifier<EstadoProcesamiento> {
  @override
  EstadoProcesamiento build() => const EstadoProcesamiento();

  /// Activa la barra de progreso con el mensaje indicado (opcional).
  void iniciar([String? mensaje]) =>
      state = EstadoProcesamiento(activo: true, mensaje: mensaje);

  /// Desactiva la barra de progreso al terminar la tarea.
  void terminar() => state = const EstadoProcesamiento();
}

/// Provider global de estado de procesamiento.
/// Uso en cualquier ConsumerWidget:
///   ref.watch(procesamientoProvider)  → EstadoProcesamiento
///   ref.read(procesamientoProvider.notifier).iniciar('…')
///   ref.read(procesamientoProvider.notifier).terminar()
final procesamientoProvider =
    NotifierProvider<ProcesamientoNotifier, EstadoProcesamiento>(
  ProcesamientoNotifier.new,
);
