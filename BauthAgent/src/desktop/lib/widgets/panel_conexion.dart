// ============================================================
// bauth_desktop · widgets/panel_conexion.dart
//
// Propósito: panel de conexión al daemon bAuth vía banexus.
//   Transporte canónico: Flutter → banexus → bhnexus → bAuth socket.
//   El usuario configura host:puerto del daemon y prueba el health check.
//
// Dependencias: flutter_riverpod, tf_shadcn_flutter,
//   nucleo/conexion/{config_conexion, prueba_conexion, proveedor_conexion},
//   widgets/{boton_primario, campo_texto, comunes/etiqueta_codigo}.
// Estándar: ADR-020 · SBOS-NEXUS §24.3 · A.64.01 · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../nucleo/conexion/config_conexion.dart';
import '../nucleo/conexion/prueba_conexion.dart';
import 'boton_primario.dart';
import 'campo_texto.dart';
import 'comunes/etiqueta_codigo.dart';

// ── Panel raíz ───────────────────────────────────────────────

/// Panel lateral de conexión al daemon bAuth.
class PanelConexion extends ConsumerStatefulWidget {
  const PanelConexion({super.key});

  @override
  ConsumerState<PanelConexion> createState() => _PanelConexionState();
}

class _PanelConexionState extends ConsumerState<PanelConexion> {
  // ── Campos de conexión banexus ───────────────────────────────
  late final TextEditingController _hostDir;
  late final TextEditingController _puertoDir;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(configConexionProvider);
    _hostDir = TextEditingController(text: cfg.host);
    _puertoDir = TextEditingController(text: cfg.puerto.toString());
  }

  @override
  void dispose() {
    _hostDir.dispose();
    _puertoDir.dispose();
    super.dispose();
  }

  // ── Acción: probar conexión ──────────────────────────────────

  void _probarDirecto() {
    ref.read(configConexionProvider.notifier).fijarHost(_hostDir.text.trim());
    ref.read(configConexionProvider.notifier).fijarPuerto(
        int.tryParse(_puertoDir.text) ?? 9450);
    ref.read(pruebaConexionProvider.notifier).probar();
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = ref.watch(pruebaConexionProvider);
    final ocupado = r.fase == FaseConexion.probando;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conexión',
          style: TextStyle(
              color: cs.foreground, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),

        SeccionConCodigo(
          'G-BD:DIR',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CampoTexto(etiqueta: 'Host', controlador: _hostDir),
              const SizedBox(height: 12),
              CampoTexto(
                  etiqueta: 'Puerto',
                  controlador: _puertoDir,
                  tipo: TextInputType.number),
              const SizedBox(height: 16),
              BotonPrimario(
                texto: ocupado ? 'Probando…' : 'Probar conexión',
                alPresionar: ocupado ? null : _probarDirecto,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

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
