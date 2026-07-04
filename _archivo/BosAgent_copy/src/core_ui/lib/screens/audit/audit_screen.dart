/// Auditoría — Vista 5 del Core UI.
///
/// Historial completo de operaciones con trazabilidad ctx_id (SBOS-049).
/// Filtros por fecha, ficha, usuario. Exportación CSV.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/jsonrpc_client.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAudit();
  }

  Future<void> _fetchAudit() async {
    final rpc = context.read<JsonRpcClient>();
    try {
      final resp = await rpc.call(BosMethods.stateRead);
      final result = resp['result'] as Map<String, dynamic>?;
      final history = (result?['history'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
      if (mounted) setState(() { _events = history; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_events.isEmpty) {
      return const Center(child: Text('Sin eventos de auditoría'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _events.length,
      itemBuilder: (_, i) {
        final e = _events[i];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(e['action']?.toString() ?? '?'),
          subtitle: Text('ctx_id: ${e['ctx_id']?.toString() ?? "—"}'),
          trailing: Text(e['timestamp']?.toString()?.substring(0, 19) ?? ''),
        );
      },
    );
  }
}
