// ============================================================
// bauth_desktop · widgets/panel_conexion.dart
//
// Propósito: panel de estado de conexión a bAuth via banexus.
//   La conexión se establece automáticamente al iniciar la app.
//   El botón "Reconectar" solo aparece cuando la conexión falla.
//
// Dependencias: flutter_riverpod, tf_shadcn_flutter,
//   nucleo/conexion/prueba_conexion, widgets/{boton_primario, etiqueta_codigo}.
// Estándar: ADR-020 · 2.18 Motor de Comunicación · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../nucleo/conexion/prueba_conexion.dart';
import 'boton_primario.dart';
import 'comunes/etiqueta_codigo.dart';

// ── Panel raíz ───────────────────────────────────────────────

/// Panel lateral de estado de conexión a bAuth.
/// Conexión automática al arrancar — botón solo si hay fallo.
class PanelConexion extends ConsumerWidget {
  const PanelConexion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    final r = ref.watch(pruebaConexionProvider);
    final fallida = r.fase == FaseConexion.fallida;
    final probando = r.fase == FaseConexion.probando;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conexión',
          style: TextStyle(
              color: cs.foreground, fontSize: 15 * s, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 12 * s),

        // Chip informativo — transporte fijo, no editable
        SeccionConCodigo(
          'G-BD:INFO',
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 8 * s),
            decoration: BoxDecoration(
              color: cs.muted,
              border: Border.all(color: cs.border),
              borderRadius: BorderRadius.circular(7 * s),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.plug, size: 14 * s, color: cs.mutedForeground),
                SizedBox(width: 8 * s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('banexus',
                          style: TextStyle(
                              fontSize: 12 * s,
                              fontWeight: FontWeight.w600,
                              color: cs.foreground)),
                      Text('13.140.128.230:9444 → bAuth',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10 * s,
                              color: cs.mutedForeground)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 14 * s),

        // Botón "Reconectar" — solo visible cuando la conexión falla
        if (fallida)
          SeccionConCodigo(
            'G-BD:BTN',
            child: BotonPrimario(
              texto: 'Reconectar',
              alPresionar: () =>
                  ref.read(pruebaConexionProvider.notifier).probar(),
            ),
          ),

        // Spinner: muestra el mensaje exacto del monitor
        // ("Conectando…", "Reconectando…", "Verificando…")
        if (probando)
          SeccionConCodigo(
            'G-BD:BTN',
            child: Row(
              children: [
                SizedBox(
                  width: 14 * s,
                  height: 14 * s,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.mutedForeground),
                ),
                SizedBox(width: 8 * s),
                Text(r.mensaje,
                    style: TextStyle(
                        fontSize: 12 * s, color: cs.mutedForeground)),
              ],
            ),
          ),

        if (fallida || probando) SizedBox(height: 14 * s),

        SeccionConCodigo('G-BD:RES', child: _Resultado(resultado: r)),
      ],
    );
  }
}

// ── Resultado del health check ───────────────────────────────

class _Resultado extends StatelessWidget {
  final ResultadoConexion resultado;
  const _Resultado({required this.resultado});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (resultado.fase) {
      FaseConexion.exitosa => cs.primary,
      FaseConexion.fallida => cs.destructive,
      _ => cs.mutedForeground,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: cs.muted, borderRadius: BorderRadius.circular(6)),
      child: SelectableText(resultado.mensaje,
          style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace')),
    );
  }
}
