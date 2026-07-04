/// Identidad (PAP) — RolTemplates + UserTemplates.
///
/// Policy Administration Point del RolFramework.
/// Único lugar donde se crean/editan roles y usuarios.
library;

import 'package:flutter/material.dart';

class IdentityScreen extends StatelessWidget {
  const IdentityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identidad (PAP)')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings, size: 64, color: Colors.cyanAccent),
            SizedBox(height: 16),
            Text('Policy Administration Point',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('RolTemplates · UserTemplates · Roles · Permisos\nDisponible en Fase D del plan de implementación.'),
          ],
        ),
      ),
    );
  }
}
