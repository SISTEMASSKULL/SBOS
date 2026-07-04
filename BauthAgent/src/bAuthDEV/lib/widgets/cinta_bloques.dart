/// Cinta de Bloques — Patron Calculator Tape
/// Cada comando ejecutado = un bloque inmutable (comando + resultado).
/// Inspirado en Warp Terminal Blocks + Jupyter Notebook cells.

import 'dart:convert';
import 'package:flutter/material.dart';

class BloqueCinta {
  final Map<String, dynamic> comando;
  final Map<String, dynamic>? resultado;
  final String? error;
  final Duration? duracion;
  final DateTime timestamp;
  bool expandido = true;
  bool favorito = false;

  BloqueCinta({required this.comando, this.resultado, this.error, this.duracion, required this.timestamp});

  String get titulo => comando['method'] as String? ?? 'unknown';
  String get estado => error != null ? 'ERROR' : (resultado?.containsKey('error') == true ? 'ERROR RPC' : 'OK');
  Color get colorEstado => estado == 'OK' ? const Color(0xFF3FB950) : const Color(0xFFDA3633);
  String get duracionStr => duracion != null ? (duracion!.inMicroseconds < 1000 ? '${duracion!.inMicroseconds}ns' : '${duracion!.inMilliseconds}ms') : '—';
}

class CintaBloques extends StatelessWidget {
  final List<BloqueCinta> bloques;
  const CintaBloques({super.key, required this.bloques});

  @override
  Widget build(BuildContext context) {
    if (bloques.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.terminal, size: 48, color: Theme.of(context).colorScheme.onSurface.withAlpha(50)),
          const SizedBox(height: 12),
          Text('Cinta de ejecucion vacia', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(100))),
          const SizedBox(height: 4),
          Text('Selecciona un metodo del catalogo y presiona ENVIAR', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(70))),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: bloques.length,
      itemBuilder: (_, i) => _BloqueWidget(bloque: bloques[i]),
    );
  }
}

class _BloqueWidget extends StatefulWidget {
  final BloqueCinta bloque;
  const _BloqueWidget({required this.bloque});

  @override
  State<_BloqueWidget> createState() => _BloqueWidgetState();
}

class _BloqueWidgetState extends State<_BloqueWidget> {
  @override
  Widget build(BuildContext context) {
    final b = widget.bloque;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Barra superior
        InkWell(
          onTap: () => setState(() => b.expandido = !b.expandido),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Icon(b.expandido ? Icons.expand_less : Icons.expand_more, size: 16, color: Theme.of(context).colorScheme.onSurface.withAlpha(120)),
              const SizedBox(width: 6),
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: b.colorEstado)),
              const SizedBox(width: 8),
              Text(b.titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
              const Spacer(),
              Text(b.duracionStr, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withAlpha(120))),
              const SizedBox(width: 12),
              Text(_formatoHora(b.timestamp), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withAlpha(100))),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => b.favorito = !b.favorito),
                child: Icon(b.favorito ? Icons.star : Icons.star_border, size: 14, color: b.favorito ? const Color(0xFFD29922) : Theme.of(context).colorScheme.onSurface.withAlpha(80)),
              ),
            ]),
          ),
        ),
        if (b.expandido) ...[
          const Divider(height: 1),
          // Comando
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('COMANDO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withAlpha(100), letterSpacing: 1)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
                child: Text(const JsonEncoder.withIndent('  ').convert(b.comando), style: const TextStyle(fontSize: 11, fontFamily: 'monospace', height: 1.5)),
              ),
            ]),
          ),
          // Resultado o Error
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.error != null ? 'ERROR' : 'RESULTADO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: b.error != null ? const Color(0xFFDA3633) : Theme.of(context).colorScheme.onSurface.withAlpha(100), letterSpacing: 1)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: b.error != null ? const Color(0xFFDA3633).withAlpha(10) : Colors.black26, borderRadius: BorderRadius.circular(6)),
                child: SelectableText(
                  b.error ?? const JsonEncoder.withIndent('  ').convert(b.resultado ?? {}),
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', height: 1.5, color: b.error != null ? const Color(0xFFDA3633) : null),
                ),
              ),
            ]),
          ),
          // Barra de acciones
           Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Row(children: [
              _AccionBloque(Icons.refresh, 'Re-ejecutar', () {}),
              const SizedBox(width: 4),
              _AccionBloque(Icons.edit, 'Editar', () {}),
              const SizedBox(width: 4),
              _AccionBloque(Icons.copy, 'Copiar', () {}),
              const SizedBox(width: 4),
              _AccionBloque(Icons.download, 'Exportar .sh', () {}),
            ]),
          ),
        ],
      ]),
    );
  }

  String _formatoHora(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}

class _AccionBloque extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _AccionBloque(this.icon, this.tooltip, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
      ),
    );
  }
}
