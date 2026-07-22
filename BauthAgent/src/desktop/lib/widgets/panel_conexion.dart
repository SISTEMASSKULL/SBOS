// ============================================================
// bauth_desktop · widgets/panel_conexion.dart
//
// Propósito: panel de conexión al daemon bAuth.
//   Modo SSH  — la app crea la sesión SSH internamente (dartssh2):
//     VPS host + usuario + contraseña → ClienteRpcSsh autenticado.
//     Cada RPC usa SSH exec (sin bridge TCP, sin ServerSocket).
//   Modo Directo — host:puerto TCP convencional (túnel externo).
//
// Ciclo: toggle modo → rellenar credenciales → Conectar
//   → TunelSSH.iniciar() (modo SSH) → clienteRpcSshProvider activo
//   → probar bauth.health.check via SSH exec.
//
// Seguridad: contraseña SOLO en TextEditingController (widget state).
//   NUNCA escrita en ConfigConexion, NUNCA persistida, NUNCA logueada.
//
// Dependencias: flutter_riverpod, tf_shadcn_flutter,
//   nucleo/conexion/{config_conexion, prueba_conexion, tunel_ssh,
//                    proveedor_conexion},
//   widgets/{boton_primario, campo_texto}.
// Estándar: ADR-020 · NRS-10 · DOC-SBOS-001 N3.
// ============================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../nucleo/conexion/config_conexion.dart';
import '../nucleo/conexion/prueba_conexion.dart';
import '../nucleo/conexion/proveedor_conexion.dart';
import '../nucleo/conexion/tunel_ssh.dart';
import 'boton_primario.dart';
import 'campo_texto.dart';

// ── Panel raíz ───────────────────────────────────────────────

/// Panel lateral de conexión al daemon bAuth.
class PanelConexion extends ConsumerStatefulWidget {
  const PanelConexion({super.key});

  @override
  ConsumerState<PanelConexion> createState() => _PanelConexionState();
}

class _PanelConexionState extends ConsumerState<PanelConexion> {
  // ── Modo ────────────────────────────────────────────────────
  bool _modoSSH = true;

  // ── Campos SSH ──────────────────────────────────────────────
  final _sshHost = TextEditingController(text: '13.140.128.230');
  final _sshUsuario = TextEditingController(text: 'root');
  // Contraseña SOLO en memoria de widget — nunca en ningún otro lugar
  final _sshPassword = TextEditingController();

  // ── Campos Directo ──────────────────────────────────────────
  late final TextEditingController _hostDir;
  late final TextEditingController _puertoDir;

  // ── Estado del túnel ────────────────────────────────────────
  TunelSSH? _tunel;
  bool _conectando = false;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(configConexionProvider);
    _hostDir = TextEditingController(text: cfg.host);
    _puertoDir = TextEditingController(text: cfg.puerto.toString());
  }

  @override
  void dispose() {
    _sshHost.dispose();
    _sshUsuario.dispose();
    _sshPassword.dispose();
    _hostDir.dispose();
    _puertoDir.dispose();
    // Limpiar el cliente SSH del provider al destruir el panel
    try {
      ref.read(clienteRpcSshProvider.notifier).establecer(null);
    } catch (_) {}
    unawaited(_tunel?.cerrar());
    super.dispose();
  }

  // ── Conexión SSH ─────────────────────────────────────────────

  Future<void> _conectarSSH() async {
    if (_sshHost.text.trim().isEmpty) return;
    setState(() { _conectando = true; });
    try {
      await _tunel?.cerrar();
      _tunel = TunelSSH();
      // Autenticar SSH — sin bridge TCP, sin ServerSocket
      await _tunel!.iniciar(
        host: _sshHost.text.trim(),
        usuario: _sshUsuario.text.trim(),
        password: _sshPassword.text,
      );
      // Crear cliente SSH exec y activarlo como cliente RPC
      final clienteSsh = _tunel!.crearClienteRpc();
      if (mounted) {
        ref.read(clienteRpcSshProvider.notifier).establecer(clienteSsh);
        // Probar health.check via SSH exec
        ref.read(pruebaConexionProvider.notifier).probar();
      }
    } catch (e) {
      _tunel = null;
      if (mounted) {
        ref.read(clienteRpcSshProvider.notifier).establecer(null);
        final msg = 'SSH: ${e.toString().replaceAll('\n', ' ')}';
        ref.read(pruebaConexionProvider.notifier).establecerError(msg);
      }
    } finally {
      if (mounted) setState(() => _conectando = false);
    }
  }

  // ── Conexión Directa ─────────────────────────────────────────

  void _probarDirecto() {
    // En modo directo, limpiar el cliente SSH y usar TCP
    ref.read(clienteRpcSshProvider.notifier).establecer(null);
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
    final probando = r.fase == FaseConexion.probando;
    final ocupado = probando || _conectando;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título
        Text(
          'Conexión',
          style: TextStyle(
              color: cs.foreground, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),

        // Toggle modo
        _ToggleModo(
          modoSSH: _modoSSH,
          alCambiar: (v) => setState(() {
            _modoSSH = v;
          }),
        ),
        const SizedBox(height: 16),

        // Formulario según modo
        if (_modoSSH) ...[
          CampoTexto(etiqueta: 'Servidor VPS', controlador: _sshHost),
          const SizedBox(height: 10),
          CampoTexto(etiqueta: 'Usuario SSH', controlador: _sshUsuario),
          const SizedBox(height: 10),
          CampoTexto(
              etiqueta: 'Contraseña SSH',
              controlador: _sshPassword,
              obscuro: true),
          const SizedBox(height: 16),
          BotonPrimario(
            texto: _conectando ? 'Autenticando SSH…' : 'Conectar vía SSH',
            alPresionar: ocupado ? null : _conectarSSH,
          ),
        ] else ...[
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

        const SizedBox(height: 14),

        // Indicador SSH activo (solo en modo SSH cuando el túnel está activo)
        if (_modoSSH && _tunel != null && _tunel!.activo && !_conectando)
          _IndicadorSsh(cs: cs),

        // Resultado del health check
        _Resultado(resultado: r),
      ],
    );
  }
}

// ── Toggle SSH / Directo ─────────────────────────────────────

class _ToggleModo extends StatelessWidget {
  final bool modoSSH;
  final ValueChanged<bool> alCambiar;
  const _ToggleModo({required this.modoSSH, required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Row(
      children: [
        _Opcion(
          texto: 'Túnel SSH',
          activa: modoSSH,
          alTocar: () => alCambiar(true),
          cs: cs,
          s: s,
        ),
        SizedBox(width: 6 * s),
        _Opcion(
          texto: 'Directo',
          activa: !modoSSH,
          alTocar: () => alCambiar(false),
          cs: cs,
          s: s,
        ),
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  final String texto;
  final bool activa;
  final VoidCallback alTocar;
  final ColorScheme cs;
  final double s;
  const _Opcion({
    required this.texto, required this.activa,
    required this.alTocar, required this.cs, required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alTocar,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
        decoration: BoxDecoration(
          color: activa ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4 * s),
          border: activa ? null : Border.all(color: cs.border),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 11 * s,
            fontWeight: FontWeight.w600,
            color: activa ? cs.primaryForeground : cs.mutedForeground,
          ),
        ),
      ),
    );
  }
}

// ── Indicador SSH activo ──────────────────────────────────────

class _IndicadorSsh extends StatelessWidget {
  final ColorScheme cs;
  const _IndicadorSsh({required this.cs});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).scaling;
    return Padding(
      padding: EdgeInsets.only(bottom: 10 * s),
      child: Row(children: [
        Icon(LucideIcons.shieldCheck, size: 12 * s, color: Colors.green.shade400),
        SizedBox(width: 5 * s),
        Text(
          'SSH activo — RPC vía exec',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 10 * s,
            color: Colors.green.shade400,
          ),
        ),
      ]),
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
      child: Text(resultado.mensaje,
          style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
