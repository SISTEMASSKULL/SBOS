// ============================================================
// bauth_desktop · widgets/panel_conexion.dart
//
// Propósito: panel de conexión al daemon bAuth vía banexus.
//   Banexus es el único transporte — no existe modo SSH ni TCP directo.
//   El binario banexus.exe/banexus corre en la misma máquina Windows y
//   proxea las llamadas a bhnexus (VPS) → bAuth (Unix socket).
//
// Ciclo: auto-conexión al arrancar → indicador de estado → botón Conectar
//   si el daemon no responde. El botón llama a controlConexionProvider.conectar().
//
// Dependencias: flutter_riverpod, tf_shadcn_flutter,
//   nucleo/conexion/{proveedor_conexion, prueba_conexion}.
// Estándar: ADR-020 · SBOS-NEXUS §24.3 · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../nucleo/conexion/proveedor_conexion.dart';
import '../nucleo/conexion/prueba_conexion.dart';
import 'boton_primario.dart';

// ── Panel raíz ───────────────────────────────────────────────

/// Panel lateral de conexión al daemon bAuth.
/// Único transporte: banexus local API (127.0.0.1:9446).
class PanelConexion extends ConsumerWidget {
  const PanelConexion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final s  = Theme.of(context).scaling;

    final estado   = ref.watch(estadoConexionProvider);
    final resultado = ref.watch(pruebaConexionProvider);
    final probando  = resultado.fase == FaseConexion.probando;

    final conectado = estado.valueOrNull == EstadoConexion.conectado;
    final conectando = estado.valueOrNull == EstadoConexion.conectando || probando;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conexión',
          style: TextStyle(
            color: cs.foreground,
            fontSize: 15 * s,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 14 * s),

        // ── Indicador de estado ──────────────────────────────
        _IndicadorEstado(
          conectado: conectado,
          conectando: conectando,
          cs: cs,
          s: s,
        ),
        SizedBox(height: 14 * s),

        // ── Botón Conectar (solo si no está conectado) ───────
        if (!conectado && !conectando)
          BotonPrimario(
            texto: 'Conectar',
            alPresionar: () {
              ref.read(controlConexionProvider).conectar();
              ref.read(pruebaConexionProvider.notifier).probar();
            },
          ),

        if (conectado)
          BotonPrimario(
            texto: probando ? 'Probando…' : 'Verificar health',
            alPresionar: probando
                ? null
                : () => ref.read(pruebaConexionProvider.notifier).probar(),
          ),

        SizedBox(height: 14 * s),

        // ── Resultado del health check ───────────────────────
        _Resultado(resultado: resultado),
      ],
    );
  }
}

// ── Indicador de estado banexus ──────────────────────────────

class _IndicadorEstado extends StatelessWidget {
  final bool conectado;
  final bool conectando;
  final ColorScheme cs;
  final double s;

  const _IndicadorEstado({
    required this.conectado,
    required this.conectando,
    required this.cs,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final color = conectado
        ? Colors.green.shade400
        : conectando
            ? Colors.orange.shade400
            : cs.destructive;

    final etiqueta = conectado
        ? 'banexus conectado — RPC activo'
        : conectando
            ? 'Conectando a banexus…'
            : 'banexus no responde en 127.0.0.1:9446';

    final icono = conectado
        ? LucideIcons.plugZap
        : conectando
            ? LucideIcons.loader
            : LucideIcons.plugZapOff;

    return Row(children: [
      Icon(icono, size: 13 * s, color: color),
      SizedBox(width: 6 * s),
      Expanded(
        child: Text(
          etiqueta,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11 * s,
            color: color,
          ),
        ),
      ),
    ]);
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
      FaseConexion.exitosa    => cs.primary,
      FaseConexion.fallida    => cs.destructive,
      _                       => cs.mutedForeground,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        resultado.mensaje,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}
