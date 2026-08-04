// ============================================================
// bauth_desktop · widgets/comunes/indicador_procesamiento.dart
//
// Propósito: indicador universal de procesamiento — spinner o barra
//   indeterminada con ícono y mensaje opcionales.
//
//   No tiene contexto de uso — no sabe si carga un árbol, guarda un
//   formulario o espera una conexión. Solo indica "hay trabajo en curso".
//
//   Dos modos:
//     TipoIndicador.spinner — CircularProgressIndicator indeterminado (defecto).
//     TipoIndicador.barra   — LinearProgressIndicator indeterminado.
//
//   Uso canónico en Stack (la vista no se desmonta al cambiar el overlay):
//     Stack(children: [
//       _buildVista(),
//       ValueListenableBuilder<bool>(
//         valueListenable: _cargandoNotifier,
//         builder: (_, cargando, __) => cargando
//             ? const IndicadorProcesamiento(mensaje: 'Guardando…')
//             : const SizedBox.shrink(),
//       ),
//     ]);
//
//   Con opacidadFondo: 0 funciona como indicador inline (sin overlay).
//
// Dependencias: tf_shadcn_flutter (CircularProgressIndicator, LinearProgressIndicator).
// Estándar: DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Modo de animación del indicador de procesamiento.
enum TipoIndicador {
  /// Spinner circular indeterminado — para esperas sin progreso conocido.
  spinner,

  /// Barra lineal indeterminada — para indicar actividad de consulta/descarga.
  barra,
}

/// Indicador universal de procesamiento.
///
/// Cubre el área disponible de su parent con fondo semiopaco y muestra
/// una animación de espera. Completamente desacoplado del contexto de uso.
///
/// Parámetros:
/// - [mensaje]       texto descriptivo bajo el animador (opcional).
/// - [icono]         ícono decorativo sobre el animador (opcional).
/// - [tipo]          [TipoIndicador.spinner] (defecto) o [TipoIndicador.barra].
/// - [opacidadFondo] opacidad del fondo [0.0–1.0]; 0 = inline sin overlay.
class IndicadorProcesamiento extends StatelessWidget {
  final String? mensaje;
  final IconData? icono;
  final TipoIndicador tipo;
  final double opacidadFondo;

  const IndicadorProcesamiento({
    super.key,
    this.mensaje,
    this.icono,
    this.tipo = TipoIndicador.spinner,
    this.opacidadFondo = 0.82,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;

    return Container(
      color: cs.background.withValues(alpha: opacidadFondo),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 38 * s, color: cs.primary.withValues(alpha: 0.65)),
            SizedBox(height: 22 * s),
          ],
          _buildAnimador(cs, s),
          if (mensaje != null) ...[
            SizedBox(height: 18 * s),
            Text(
              mensaje!,
              style: TextStyle(
                fontSize: 13 * s,
                fontWeight: FontWeight.w600,
                color: cs.foreground,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimador(ColorScheme cs, double s) => switch (tipo) {
        TipoIndicador.spinner => CircularProgressIndicator(
            size: 32 * s,
            color: cs.primary,
            backgroundColor: cs.muted,
          ),
        TipoIndicador.barra => SizedBox(
            width: 200 * s,
            child: LinearProgressIndicator(
              color: cs.primary,
              backgroundColor: cs.muted,
              minHeight: 3 * s,
            ),
          ),
      };
}
