/// Crecimiento Horizontal — Vista 4 del Core UI.
///
/// Asistente guiado para añadir nodos al cluster o instalar nuevas fichas.
/// 3 parámetros: tipo (nodo/ficha), cantidad, ubicación (servidor lógico).
library;

import 'package:flutter/material.dart';

class GrowthScreen extends StatelessWidget {
  const GrowthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_chart, size: 64, color: Colors.cyanAccent),
          SizedBox(height: 16),
          Text('Crecimiento Horizontal',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Asistente guiado para añadir nodos o fichas.\nDisponible en Fase D del plan de implementación.'),
        ],
      ),
    );
  }
}
