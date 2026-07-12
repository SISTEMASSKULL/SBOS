// ============================================================
// bauth_desktop · widgets/menu/fila_menu.dart
//
// Propósito: una FILA del menú, fiel al prototipo bAuth Desktop. Colapsada
//   muestra solo el icono (+ punto de estado); extendida agrega etiqueta y
//   badge. El ítem activo lleva fondo acento-dim + barra izquierda de acento.
//   Todos los tamaños se calculan con `theme.scaling` (responsive).
// Dependencias: tf_shadcn_flutter, datos/menu_datos.
// Estándar: prototipo bAuth Desktop · shadcn_flutter · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import '../../datos/menu_datos.dart';

/// Fila de un ítem del menú (modo colapsado o extendido).
class FilaMenu extends StatelessWidget {
  final ItemMenu item;
  final bool expandido;
  final bool activo;
  final VoidCallback alTocar;

  const FilaMenu({
    super.key,
    required this.item,
    required this.expandido,
    required this.activo,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return GestureDetector(
      onTap: alTocar,
      child: Container(
        margin: EdgeInsets.only(bottom: 3 * s),
        decoration: BoxDecoration(
          color: activo ? cs.primary.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(8 * s),
        ),
        child: Stack(
          children: [
            if (activo)
              Positioned(
                left: 0,
                top: 7 * s,
                bottom: 7 * s,
                child: Container(
                    width: 2.5 * s,
                    decoration: BoxDecoration(
                        color: cs.primary, borderRadius: BorderRadius.circular(2 * s))),
              ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 9 * s, horizontal: 10 * s),
              child: Row(
                children: [
                  Icon(item.icono, size: 18 * s, color: activo ? cs.primary : cs.mutedForeground),
                  if (expandido) ...[
                    SizedBox(width: 11 * s),
                    Expanded(
                      child: Text(item.etiqueta,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5 * s,
                              fontWeight: FontWeight.w500,
                              color: activo ? cs.foreground : cs.mutedForeground)),
                    ),
                    if (item.badge != null) _Badge(texto: item.badge!),
                    if (item.punto != null)
                      Padding(padding: EdgeInsets.only(left: 8 * s), child: _PuntoEstado(estado: item.punto!)),
                  ] else if (item.punto != null) ...[
                    const Spacer(),
                    _PuntoEstado(estado: item.punto!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge/contador monospace redondeado (fondo elevado del tema).
class _Badge extends StatelessWidget {
  final String texto;
  const _Badge({required this.texto});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7 * s, vertical: 1 * s),
      decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(20 * s)),
      child: Text(texto,
          style: TextStyle(
              fontFamily: 'monospace', fontSize: 11 * s, fontWeight: FontWeight.w600, color: cs.mutedForeground)),
    );
  }
}

/// Punto de estado: ok (verde) o advertencia (ámbar), de la paleta de shadcn.
class _PuntoEstado extends StatelessWidget {
  final EstadoPunto estado;
  const _PuntoEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).scaling;
    final color = estado == EstadoPunto.ok ? Colors.green.shade500 : Colors.amber.shade500;
    return Container(width: 7 * s, height: 7 * s, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
