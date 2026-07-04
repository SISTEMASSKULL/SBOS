/// Dashboard — Vista 1 del Core UI.
///
/// Panel principal con:
/// - Estado de conexión JSON-RPC 2.0
/// - Resumen de fichas por servidor
/// - Health check del daemon
/// - Métricas rápidas (total, OK, degradadas, pendientes)
/// - Release Plane (updates disponibles)
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/jsonrpc_client.dart';
import '../../services/ws_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _state;
  Map<String, dynamic>? _health;
  List<dynamic>? _releases;
  bool _loading = true;
  String? _error;
  int _refreshCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    final rpc = context.read<JsonRpcClient>();
    if (!rpc.isConnected) {
      setState(() { _error = 'Daemon no conectado'; _loading = false; });
      return;
    }
    try {
      final results = await Future.wait([
        rpc.call(BosMethods.stateRead),
        rpc.call(BosMethods.healthCheck),
        rpc.call(BosMethods.releaseCheck, {'ficha': '*', 'version': '0.0.0'}),
      ]);
      if (mounted) {
        setState(() {
          _state = results[0]['result'] as Map<String, dynamic>?;
          _health = results[1]['result'] as Map<String, dynamic>?;
          final relResult = results[2]['result'] as Map<String, dynamic>?;
          _releases = relResult?['updates'] as List<dynamic>?;
          _loading = false;
          _error = null;
          _refreshCount++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rpc = context.read<JsonRpcClient>();

    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Conexión JSON-RPC ──────────────────────────────
          Card(
            color: rpc.isConnected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(
                rpc.isConnected ? Icons.sensors : Icons.sensors_off,
                color: rpc.isConnected ? Colors.green : Colors.red,
                size: 32,
              ),
              title: Text(rpc.isConnected ? 'JSON-RPC 2.0 Conectado' : 'JSON-RPC 2.0 Desconectado',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(rpc.isConnected
                  ? 'bos.<modulo>.<operacion> · /run/bos/bos.sock'
                  : 'Verifica que el daemon esté corriendo'),
              trailing: FilledButton.tonalIcon(
                onPressed: rpc.isConnected ? _fetchAll : () async {
                  await rpc.reconnect();
                  _fetchAll();
                },
                icon: Icon(rpc.isConnected ? Icons.refresh : Icons.power_settings_new),
                label: Text(rpc.isConnected ? 'Refresh #$_refreshCount' : 'Conectar'),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Métricas ───────────────────────────────────────
          if (_state != null) ...[
            Row(
              children: [
                _metricCard('Total', '${_state!['total'] ?? 19}', Icons.widgets, Colors.blue),
                const SizedBox(width: 8),
                _metricCard('OK', '${_state!['completados'] ?? 0}', Icons.check_circle, Colors.green),
                const SizedBox(width: 8),
                _metricCard('Alerta', '${_state!['alerta'] ?? 0}', Icons.warning, Colors.orange),
                const SizedBox(width: 8),
                _metricCard('Pendientes', '${_state!['pendientes'] ?? 0}', Icons.hourglass_empty, Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // ── Health ─────────────────────────────────────────
          if (_health != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Health Check', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _healthBadge('Estado', _health!['status']?.toString() ?? '?',
                            _health!['status'] == 'ok' ? Colors.green : Colors.red),
                        const SizedBox(width: 16),
                        _healthBadge('Versión', _health!['version']?.toString() ?? '?', Colors.cyanAccent),
                        const SizedBox(width: 16),
                        _healthBadge('Uptime', _health!['uptime']?.toString() ?? '?', Colors.white70),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),

          // ── Release Plane ──────────────────────────────────
          if (_releases != null && _releases!.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.system_update, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text('${_releases!.length} actualizaciones disponibles',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...(_releases!.take(3).map((r) {
                      final m = r as Map<String, dynamic>;
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.inventory_2, size: 18),
                        title: Text('${m['ficha']} ${m['version']}',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text('Canal: ${m['channel'] ?? '?'}',
                            style: const TextStyle(fontSize: 11)),
                      );
                    })),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),

          // ── Servidores ─────────────────────────────────────
          if (_state != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Servidores', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _serverRow('S-HOST', 'Infraestructura Host', Icons.computer),
                    _serverRow('S01', 'Datos', Icons.storage),
                    _serverRow('S02', 'Seguridad + Gateway', Icons.security),
                    _serverRow('S03', 'Identidad + Malla', Icons.verified_user),
                    _serverRow('S06', 'Aplicación', Icons.notifications),
                    _serverRow('S12', 'Observabilidad', Icons.insights),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _healthBadge(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
      ],
    );
  }

  Widget _serverRow(String id, String desc, IconData icon) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: Colors.cyanAccent),
      title: Text('$id — $desc', style: const TextStyle(fontSize: 13)),
    );
  }
}
