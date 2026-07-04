/// Shell de navegación del Core UI.
///
/// 5 vistas principales + identidad:
/// Dashboard | Catálogo | Operaciones | Crecimiento | Auditoría
library;

import 'package:flutter/material.dart';

import 'screens/dashboard/dashboard_screen.dart';
import 'screens/catalog/catalog_screen.dart';
import 'screens/progress/progress_screen.dart';
import 'screens/growth/growth_screen.dart';
import 'screens/audit/audit_screen.dart';
import 'screens/identity/identity_screen.dart';

/// Shell principal con navegación inferior.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const _views = <Widget>[
    DashboardScreen(),
    CatalogScreen(),
    ProgressScreen(),
    GrowthScreen(),
    AuditScreen(),
  ];

  static const _titles = [
    'Dashboard',
    'Catálogo',
    'Operaciones',
    'Crecimiento',
    'Auditoría',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        actions: [
          // Indicador de conexión JSON-RPC
          IconButton(
            icon: const Icon(Icons.sensors),
            tooltip: 'Estado JSON-RPC',
            onPressed: () {},
          ),
          // Acceso a identidad (PAP)
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Identidad (PAP)',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IdentityScreen()),
            ),
          ),
          // Menú de usuario
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Cuenta',
            onPressed: () {},
          ),
        ],
      ),
      body: _views[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.grid_view), label: 'Catálogo'),
          NavigationDestination(icon: Icon(Icons.sync), label: 'Operaciones'),
          NavigationDestination(icon: Icon(Icons.add_chart), label: 'Crecimiento'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Auditoría'),
        ],
      ),
    );
  }
}
