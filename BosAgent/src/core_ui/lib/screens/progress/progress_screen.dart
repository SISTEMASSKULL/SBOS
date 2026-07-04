/// Progreso de Operaciones — Vista 3 del Core UI.
///
/// Muestra el progreso de sagas en tiempo real vía WebSocket.
/// Barra de progreso global + por ficha + logs en vivo.
library;

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../services/ws_service.dart';
import '../../services/jsonrpc_client.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _logs = <String>[];
  double _progress = 0.0;
  String _currentFicha = '';
  String _currentStep = '';
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    final ws = context.read<WsService>();
    _wsSub = ws.events.listen(_handleEvent);
    _fetchBootstrapStatus();
  }

  void _handleEvent(WsEvent event) {
    if (!mounted) return;
    setState(() {
      switch (event.type) {
        case WsEventType.sagaStart:
          _currentFicha = event.ficha ?? '';
          _addLog('🚀 Iniciando ${event.ficha}');
        case WsEventType.stepOk:
          _currentStep = event.step ?? '';
          _progress += 0.02;
          _addLog('✅ ${event.step}: ${event.message ?? ""}');
        case WsEventType.sagaOk:
          _addLog('✅ ${event.ficha} completado');
        case WsEventType.sagaFail:
          _addLog('❌ ${event.ficha}: ${event.message ?? ""}');
        case WsEventType.systemAlert:
          _addLog('⚠️ ${event.message ?? ""}');
        default: break;
      }
    });
  }

  void _addLog(String msg) {
    _logs.add('[${DateTime.now().toString().substring(11, 19)}] $msg');
    if (_logs.length > 100) _logs.removeAt(0);
  }

  Future<void> _fetchBootstrapStatus() async {
    try {
      final rpc = context.read<JsonRpcClient>();
      final resp = await rpc.call(BosMethods.bootstrapStatus);
      final result = resp['result'] as Map<String, dynamic>?;
      if (mounted && result != null) {
        setState(() {
          _progress = (result['progress'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de progreso
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              LinearProgressIndicator(value: _progress, minHeight: 12, borderRadius: BorderRadius.circular(6)),
              const SizedBox(height: 8),
              Text('${(_progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.headlineMedium),
              if (_currentFicha.isNotEmpty) Text('📦 $_currentFicha'),
              if (_currentStep.isNotEmpty) Text('🔄 $_currentStep'),
            ],
          ),
        ),
        const Divider(),
        // Log en vivo
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _logs.length,
            itemBuilder: (_, i) => Text(
              _logs[i],
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
