// ============================================================
// bauth_desktop · widgets/layout/bloque_lateral_derecho.dart
//
// Propósito: BLOQUE 3 del viewport — panel derecho (300) con secciones:
//   Acciones rápidas, Alertas y Uso (24h). Reproduce el prototipo con iconos
//   Lucide (en vez de emojis) para mantener el minimalismo del tema.
// Dependencias: tf_shadcn_flutter.
// Estándar: prototipo bAuth Desktop · responsive · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

/// Bloque lateral derecho: acciones, alertas y uso.
class BloqueLateralDerecho extends StatelessWidget {
  const BloqueLateralDerecho({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      width: 300 * s,
      decoration: BoxDecoration(color: cs.card, border: Border(left: BorderSide(color: cs.border))),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Seccion(icono: LucideIcons.zap, titulo: 'ACCIONES RÁPIDAS', child: const _Acciones()),
            SizedBox(height: 16 * s),
            _Seccion(icono: LucideIcons.bell, titulo: 'ALERTAS', child: const _Alertas()),
            SizedBox(height: 16 * s),
            _Seccion(icono: LucideIcons.activity, titulo: 'USO (24h)', child: const _Uso()),
          ],
        ),
      ),
    );
  }
}

/// Sección con encabezado (icono + título) y contenido.
class _Seccion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final Widget child;
  const _Seccion({required this.icono, required this.titulo, required this.child});

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
            Icon(icono, size: 12 * s, color: cs.mutedForeground),
            SizedBox(width: 6 * s),
            Text(titulo, style: TextStyle(fontSize: 10 * s, fontWeight: FontWeight.w700, letterSpacing: 1 * s, color: cs.mutedForeground)),
          ],
        ),
        SizedBox(height: 9 * s),
        child,
      ],
    );
  }
}

/// Botones de acción (el primero, primario con acento).
class _Acciones extends StatelessWidget {
  const _Acciones();
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).scaling;
    return Column(
      children: [
        const _BotonAccion(texto: '+ Nuevo Rol', primario: true),
        SizedBox(height: 7 * s),
        const _BotonAccion(texto: '+ Nuevo Usuario'),
        SizedBox(height: 7 * s),
        const _BotonAccion(texto: 'Sincronizar todo'),
        SizedBox(height: 7 * s),
        const _BotonAccion(texto: 'Exportar auditoría'),
      ],
    );
  }
}

/// Un botón de acción, alineado a la izquierda.
class _BotonAccion extends StatelessWidget {
  final String texto;
  final bool primario;
  const _BotonAccion({required this.texto, this.primario = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      height: 34 * s,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 12 * s),
      decoration: BoxDecoration(
        color: primario ? cs.primary : cs.muted,
        border: primario ? null : Border.all(color: cs.border),
        borderRadius: BorderRadius.circular(8 * s),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 12.5 * s,
              fontWeight: primario ? FontWeight.w600 : FontWeight.w500,
              color: primario ? cs.primaryForeground : cs.foreground)),
    );
  }
}

/// Lista de alertas (punto de severidad + texto).
class _Alertas extends StatelessWidget {
  const _Alertas();
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).scaling;
    return Column(
      children: [
        _Alerta(color: Colors.amber.shade500, texto: '3 roles con DRIFT'),
        SizedBox(height: 8 * s),
        _Alerta(color: Theme.of(context).colorScheme.destructive, texto: '1 sucursal degradada'),
        SizedBox(height: 8 * s),
        _Alerta(color: Colors.amber.shade500, texto: '2 usuarios bloqueados'),
      ],
    );
  }
}

/// Una fila de alerta.
class _Alerta extends StatelessWidget {
  final Color color;
  final String texto;
  const _Alerta({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11 * s, vertical: 9 * s),
      decoration: BoxDecoration(color: cs.muted, border: Border.all(color: cs.border), borderRadius: BorderRadius.circular(9 * s)),
      child: Row(
        children: [
          Container(width: 7 * s, height: 7 * s, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          SizedBox(width: 9 * s),
          Expanded(child: Text(texto, style: TextStyle(fontSize: 11.5 * s, color: cs.mutedForeground))),
        ],
      ),
    );
  }
}

/// Métricas de uso (etiqueta + valor monospace).
class _Uso extends StatelessWidget {
  const _Uso();
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).scaling;
    return Column(
      children: [
        _FilaUso(etiqueta: 'Evaluaciones', valor: '234.567'),
        SizedBox(height: 9 * s),
        _FilaUso(etiqueta: 'Tokens emitidos', valor: '1.234'),
        SizedBox(height: 9 * s),
        _FilaUso(etiqueta: 'FastPath', valor: '99.7%', destacado: true),
      ],
    );
  }
}

/// Una fila de uso.
class _FilaUso extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final bool destacado;
  const _FilaUso({required this.etiqueta, required this.valor, this.destacado = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final s = theme.scaling;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta, style: TextStyle(fontSize: 12 * s, color: cs.mutedForeground)),
        Text(valor,
            style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12 * s,
                fontWeight: FontWeight.w600,
                color: destacado ? Colors.green.shade500 : cs.foreground)),
      ],
    );
  }
}
