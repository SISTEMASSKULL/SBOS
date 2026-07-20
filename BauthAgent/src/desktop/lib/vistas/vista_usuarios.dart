// ============================================================
// bauth_desktop · vistas/vista_usuarios.dart
//
// Propósito: VISTA «Usuarios» — lista filtrable de usuarios IAM
//   con panel de detalle lateral: info, roles asignados,
//   acciones asignar/revocar rol. Master-detail.
// Dependencias: tf_shadcn_flutter, flutter_riverpod,
//   proveedor_conexion, bauth_api.
// Estándar: Motor de Identidad (2.15) · DOC-SBOS-001 N3.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../nucleo/api/bauth_api.dart';
import '../nucleo/conexion/proveedor_conexion.dart';

/// Vista principal de Usuarios.
class VistaUsuarios extends ConsumerStatefulWidget {
  const VistaUsuarios({super.key});
  @override
  ConsumerState<VistaUsuarios> createState() => _VistaUsuariosState();
}

class _VistaUsuariosState extends ConsumerState<VistaUsuarios> {
  String _busqueda = '';
  UsuarioInfo? _seleccionado;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).scaling;
    return Row(
      children: [
        SizedBox(
          width: 320 * s,
          child: _PanelLista(
            busqueda: _busqueda,
            seleccionado: _seleccionado,
            onBusqueda: (v) => setState(() { _busqueda = v; _seleccionado = null; }),
            onSeleccion: (u) => setState(() => _seleccionado = u),
          ),
        ),
        Container(width: 1, color: Theme.of(context).colorScheme.border),
        Expanded(
          child: _seleccionado == null
              ? _SinSeleccion()
              : _PanelDetalle(usuario: _seleccionado!),
        ),
      ],
    );
  }
}

// ── Panel izquierdo: lista ─────────────────────────────────

class _PanelLista extends ConsumerWidget {
  final String busqueda;
  final UsuarioInfo? seleccionado;
  final ValueChanged<String> onBusqueda;
  final ValueChanged<UsuarioInfo> onSeleccion;

  const _PanelLista({
    required this.busqueda,
    required this.seleccionado,
    required this.onBusqueda,
    required this.onSeleccion,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    final async = ref.watch(usuariosProvider(busqueda));

    return Column(
      children: [
        _CabeceraLista(busqueda: busqueda, onBusqueda: onBusqueda),
        Container(height: 1, color: cs.border),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorCarga(mensaje: e.toString()),
            data: (usuarios) => usuarios.isEmpty
                ? _VacioMensaje(texto: busqueda.isEmpty ? 'Sin usuarios registrados' : 'Sin resultados para "$busqueda"')
                : ListView.separated(
                    itemCount: usuarios.length,
                    separatorBuilder: (_, __) => Container(height: 1, color: cs.border),
                    itemBuilder: (_, i) => _FilaUsuario(
                      usuario: usuarios[i],
                      activo: seleccionado?.uuid == usuarios[i].uuid,
                      onTap: () => onSeleccion(usuarios[i]),
                    ),
                  ),
          ),
        ),
        Container(
          height: 36 * s,
          padding: EdgeInsets.symmetric(horizontal: 12 * s),
          color: cs.muted,
          child: async.maybeWhen(
            data: (u) => Align(
              alignment: Alignment.centerLeft,
              child: Text('${u.length} usuarios', style: TextStyle(fontSize: 11 * s, color: cs.mutedForeground)),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _CabeceraLista extends StatelessWidget {
  final String busqueda;
  final ValueChanged<String> onBusqueda;
  const _CabeceraLista({required this.busqueda, required this.onBusqueda});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Padding(
      padding: EdgeInsets.all(10 * s),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 32 * s,
              decoration: BoxDecoration(
                color: cs.muted,
                border: Border.all(color: cs.border),
                borderRadius: BorderRadius.circular(6 * s),
              ),
              child: Row(
                children: [
                  SizedBox(width: 8 * s),
                  Icon(LucideIcons.search, size: 14 * s, color: cs.mutedForeground),
                  SizedBox(width: 6 * s),
                  Expanded(
                    child: EditableText(
                      controller: TextEditingController(text: busqueda),
                      focusNode: FocusNode(),
                      onChanged: onBusqueda,
                      style: TextStyle(fontSize: 12 * s, color: cs.foreground),
                      cursorColor: cs.primary,
                      backgroundCursorColor: cs.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaUsuario extends StatelessWidget {
  final UsuarioInfo usuario;
  final bool activo;
  final VoidCallback onTap;
  const _FilaUsuario({required this.usuario, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: activo ? cs.primary.withValues(alpha: 0.1) : null,
        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 10 * s),
        child: Row(
          children: [
            _Avatar(inicial: usuario.username.isNotEmpty ? usuario.username[0].toUpperCase() : '?'),
            SizedBox(width: 10 * s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(usuario.username, style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.w500, color: cs.foreground)),
                  if (usuario.email != null)
                    Text(usuario.email!, style: TextStyle(fontSize: 11 * s, color: cs.mutedForeground)),
                ],
              ),
            ),
            _ChipEstado(status: usuario.status),
          ],
        ),
      ),
    );
  }
}

// ── Panel derecho: detalle ─────────────────────────────────

class _PanelDetalle extends StatelessWidget {
  final UsuarioInfo usuario;
  const _PanelDetalle({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return SingleChildScrollView(
      padding: EdgeInsets.all(20 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(inicial: usuario.username[0].toUpperCase(), grande: true),
              SizedBox(width: 14 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(usuario.username, style: TextStyle(fontSize: 17 * s, fontWeight: FontWeight.w600, color: cs.foreground)),
                    if (usuario.email != null)
                      Text(usuario.email!, style: TextStyle(fontSize: 12 * s, color: cs.mutedForeground)),
                  ],
                ),
              ),
              _ChipEstado(status: usuario.status),
            ],
          ),
          SizedBox(height: 20 * s),
          _SeccionInfo(usuario: usuario),
          SizedBox(height: 20 * s),
          _SeccionRoles(usuario: usuario),
        ],
      ),
    );
  }
}

class _SeccionInfo extends StatelessWidget {
  final UsuarioInfo usuario;
  const _SeccionInfo({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('INFORMACIÓN', style: TextStyle(fontSize: 10.5 * s, fontWeight: FontWeight.w600,
            color: cs.mutedForeground, letterSpacing: 0.8)),
        SizedBox(height: 8 * s),
        _FilaDetalle('UUID', usuario.uuid, s: s, cs: cs),
        _FilaDetalle('Tipo', usuario.accountType ?? '—', s: s, cs: cs),
      ],
    );
  }
}

class _FilaDetalle extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final double s;
  final ColorScheme cs;
  const _FilaDetalle(this.etiqueta, this.valor, {required this.s, required this.cs});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4 * s),
        child: Row(
          children: [
            SizedBox(width: 90 * s, child: Text(etiqueta, style: TextStyle(fontSize: 12 * s, color: cs.mutedForeground))),
            Expanded(child: Text(valor, style: TextStyle(fontSize: 12 * s, color: cs.foreground))),
          ],
        ),
      );
}

class _SeccionRoles extends StatelessWidget {
  final UsuarioInfo usuario;
  const _SeccionRoles({required this.usuario});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('ROLES ASIGNADOS', style: TextStyle(fontSize: 10.5 * s, fontWeight: FontWeight.w600,
                color: cs.mutedForeground, letterSpacing: 0.8)),
            const Spacer(),
            Text('${usuario.roles.length}', style: TextStyle(fontSize: 11 * s, color: cs.mutedForeground)),
          ],
        ),
        SizedBox(height: 8 * s),
        if (usuario.roles.isEmpty)
          Text('Sin roles asignados', style: TextStyle(fontSize: 12 * s, color: cs.mutedForeground))
        else
          Wrap(
            spacing: 6 * s,
            runSpacing: 6 * s,
            children: usuario.roles.map((r) => _ChipRol(rol: r)).toList(),
          ),
      ],
    );
  }
}

// ── Widgets auxiliares ──────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String inicial;
  final bool grande;
  const _Avatar({required this.inicial, this.grande = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    final size = (grande ? 44.0 : 32.0) * s;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(inicial, style: TextStyle(fontSize: (grande ? 16.0 : 12.0) * s,
          fontWeight: FontWeight.w600, color: cs.primary)),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  final String? status;
  const _ChipEstado({this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    final esActivo = status == 'active' || status == null;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7 * s, vertical: 2 * s),
      decoration: BoxDecoration(
        color: esActivo ? cs.primary.withValues(alpha: 0.12) : cs.muted,
        borderRadius: BorderRadius.circular(4 * s),
      ),
      child: Text(status ?? 'activo', style: TextStyle(fontSize: 10 * s,
          fontWeight: FontWeight.w500,
          color: esActivo ? cs.primary : cs.mutedForeground)),
    );
  }
}

class _ChipRol extends StatelessWidget {
  final String rol;
  const _ChipRol({required this.rol});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 3 * s),
      decoration: BoxDecoration(
        border: Border.all(color: cs.border),
        borderRadius: BorderRadius.circular(4 * s),
      ),
      child: Text(rol, style: TextStyle(fontSize: 11 * s, color: cs.foreground)),
    );
  }
}

class _SinSeleccion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.userSearch, size: 28 * s, color: cs.mutedForeground),
          SizedBox(height: 8 * s),
          Text('Selecciona un usuario', style: TextStyle(fontSize: 13 * s, color: cs.mutedForeground)),
        ],
      ),
    );
  }
}

class _VacioMensaje extends StatelessWidget {
  final String texto;
  const _VacioMensaje({required this.texto});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Center(child: Text(texto, style: TextStyle(fontSize: 12 * s, color: cs.mutedForeground)));
  }
}

class _ErrorCarga extends StatelessWidget {
  final String mensaje;
  const _ErrorCarga({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = Theme.of(context).scaling;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16 * s),
        child: Text('Error al cargar: $mensaje',
            style: TextStyle(fontSize: 12 * s, color: cs.destructive), textAlign: TextAlign.center),
      ),
    );
  }
}
