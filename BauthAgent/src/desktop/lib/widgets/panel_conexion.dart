// ============================================================
// bauth_desktop · widgets/panel_conexion.dart
//
// Propósito: panel de conexión como WIDGET del sidenav derecho. Configura el
//   extremo del túnel y prueba la conexión (hola mundo: bauth.health.check).
// Dependencias: flutter_riverpod, tf_shadcn_flutter, nucleo/conexion, widgets.
// Estándar: ADR-020 · SBOS Dark minimalista · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../nucleo/conexion/config_conexion.dart';
import '../nucleo/conexion/prueba_conexion.dart';
import 'boton_primario.dart';
import 'campo_texto.dart';

/// Panel de conexión (widget del sidenav derecho).
class PanelConexion extends ConsumerStatefulWidget {
  const PanelConexion({super.key});

  @override
  ConsumerState<PanelConexion> createState() => _PanelConexionState();
}

class _PanelConexionState extends ConsumerState<PanelConexion> {
  late final TextEditingController _host;
  late final TextEditingController _puerto;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(configConexionProvider);
    _host = TextEditingController(text: cfg.host);
    _puerto = TextEditingController(text: cfg.puerto.toString());
  }

  @override
  void dispose() {
    _host.dispose();
    _puerto.dispose();
    super.dispose();
  }

  void _probar() {
    ref.read(configConexionProvider.notifier).fijarHost(_host.text);
    ref
        .read(configConexionProvider.notifier)
        .fijarPuerto(int.tryParse(_puerto.text) ?? 9450);
    ref.read(pruebaConexionProvider.notifier).probar();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = ref.watch(pruebaConexionProvider);
    final probando = r.fase == FaseConexion.probando;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Conexión',
            style: TextStyle(color: cs.foreground, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        CampoTexto(etiqueta: 'Host', controlador: _host),
        const SizedBox(height: 12),
        CampoTexto(etiqueta: 'Puerto', controlador: _puerto, tipo: TextInputType.number),
        const SizedBox(height: 16),
        BotonPrimario(
            texto: probando ? 'Probando…' : 'Probar conexión',
            alPresionar: probando ? null : _probar),
        const SizedBox(height: 14),
        _Resultado(resultado: r),
      ],
    );
  }
}

/// Muestra el resultado del hola mundo con color según la fase.
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
      decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(6)),
      child: Text(resultado.mensaje, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
