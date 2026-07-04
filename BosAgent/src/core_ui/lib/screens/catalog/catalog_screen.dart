/// Catálogo de Fichas por Servidor — Vista 2 del Core UI.
///
/// Agrupa las fichas por servidor lógico (S-HOST, S01-S12).
/// Semaforización por estado (18 estados ADR-021).
/// Detalle desplegable con dependencias, versión, puertos.
/// Acciones JSON-RPC 2.0: install, repair, probe, remove.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/jsonrpc_client.dart';
import '../../models/ficha.dart';

/// Mapa de servidores lógicos del SBOS.
const _servers = <String, String>{
  'S-HOST': 'Infraestructura Base (Host)',
  'S01': 'Datos (PostgreSQL, Redis, MinIO)',
  'S02': 'Seguridad + Gateway (Vault, Kong, OAuth2, Nginx, Certbot)',
  'S03': 'Identidad + Malla (Keycloak, Linkerd, Kyverno)',
  'S06': 'Aplicación (sbos-notifier)',
  'S12': 'Observabilidad (Prometheus, Grafana, Alertmanager, Alloy)',
};

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  Map<String, List<FichaInfo>> _byServer = {};
  int _totalFichas = 0;
  bool _loading = true;
  String? _error;
  String? _selectedFicha;
  Map<String, dynamic>? _fichaDetail;

  @override
  void initState() {
    super.initState();
    _fetchCatalog();
  }

  Future<void> _fetchCatalog() async {
    final rpc = context.read<JsonRpcClient>();
    try {
      final resp = await rpc.call(BosMethods.fichaList);
      final result = resp['result'] as Map<String, dynamic>?;
      final list = (result?['fichas'] as List<dynamic>?)
              ?.map((e) => FichaInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      // Agrupar por servidor
      final grouped = <String, List<FichaInfo>>{};
      for (final f in list) {
        grouped.putIfAbsent(f.server, () => []).add(f);
      }
      // Ordenar fichas dentro de cada servidor
      for (final entry in grouped.entries) {
        entry.value.sort((a, b) => a.id.compareTo(b.id));
      }

      if (mounted) {
        setState(() {
          _byServer = grouped;
          _totalFichas = list.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  Future<void> _fetchDetail(String fichaId) async {
    final rpc = context.read<JsonRpcClient>();
    try {
      final resp = await rpc.call(BosMethods.fichaStatus, {'ficha_id': fichaId});
      if (mounted) {
        setState(() {
          _selectedFicha = fichaId;
          _fichaDetail = resp['result'] as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Detalle: $e')));
      }
    }
  }

  Future<void> _executeAction(String fichaId, String action) async {
    final rpc = context.read<JsonRpcClient>();
    final method = switch (action) {
      'install' => BosMethods.fichaInstall,
      'repair' => BosMethods.fichaRepair,
      'remove' => BosMethods.fichaRemove,
      _ => BosMethods.fichaProbe,
    };
    try {
      await rpc.call(method, {'ficha_id': fichaId});
      await _fetchCatalog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ $fichaId: $action ejecutado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $fichaId $action: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Sin conexión al daemon — JSON-RPC falló',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _fetchCatalog,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final serverKeys = _byServer.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return Row(
      children: [
        // Panel izquierdo: lista de servidores con fichas
        Expanded(
          flex: 3,
          child: RefreshIndicator(
            onRefresh: _fetchCatalog,
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: serverKeys.length,
              itemBuilder: (context, index) {
                final server = serverKeys[index];
                final fichas = _byServer[server]!;
                final ok = fichas.where((f) => f.state == 'INSTALADA').length;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: ExpansionTile(
                    leading: _serverIcon(server, ok, fichas.length),
                    title: Text(
                      '$server — ${_servers[server] ?? server}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text('$ok/${fichas.length} fichas OK'),
                    initiallyExpanded: true,
                    children: fichas.map((f) => _fichaTile(f)).toList(),
                  ),
                );
              },
            ),
          ),
        ),
        // Panel derecho: detalle de ficha seleccionada
        if (_selectedFicha != null)
          Expanded(
            flex: 2,
            child: _detailPanel(),
          ),
      ],
    );
  }

  Widget _serverIcon(String server, int ok, int total) {
    final color = ok == total
        ? Colors.green
        : ok > 0
            ? Colors.orange
            : Colors.grey;
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.15),
      radius: 16,
      child: Text('$ok', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _fichaTile(FichaInfo f) {
    final isSelected = _selectedFicha == f.id;
    return ListTile(
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      dense: true,
      leading: CircleAvatar(
        radius: 10,
        backgroundColor: Color(f.semaphoreColor),
      ),
      title: Text(f.id, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text('${f.state} · v${f.version}', style: const TextStyle(fontSize: 11)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 16),
            tooltip: 'Detalle',
            onPressed: () => _fetchDetail(f.id),
          ),
          PopupMenuButton<String>(
            child: const Icon(Icons.more_vert, size: 16),
            onSelected: (a) => _executeAction(f.id, a),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'install', child: Text('Install')),
              PopupMenuItem(value: 'repair', child: Text('Repair')),
              PopupMenuItem(value: 'probe', child: Text('Probe (dry-run)')),
              PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ],
      ),
      onTap: () => _fetchDetail(f.id),
    );
  }

  Widget _detailPanel() {
    if (_fichaDetail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final d = _fichaDetail!;
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Row(
              children: [
                Text(_selectedFicha!, style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedFicha = null),
                ),
              ],
            ),
            const Divider(),
            _detailRow('Estado', d['state']?.toString() ?? '?'),
            _detailRow('Versión', d['version']?.toString() ?? '?'),
            _detailRow('Servidor', d['server']?.toString() ?? '?'),
            _detailRow('Health', d['health']?.toString() ?? '?'),
            _detailRow('Orden', d['execution_order']?.toString() ?? '?'),
            const SizedBox(height: 8),
            Text('Dependencias:', style: Theme.of(context).textTheme.titleSmall),
            ...((d['dependencies'] as List<dynamic>?)?.map((dep) =>
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('• $dep'),
                    )) ??
                []),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilledButton.icon(
                  onPressed: () => _executeAction(_selectedFicha!, 'install'),
                  icon: const Icon(Icons.download),
                  label: const Text('Install'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _executeAction(_selectedFicha!, 'repair'),
                  icon: const Icon(Icons.build),
                  label: const Text('Repair'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
