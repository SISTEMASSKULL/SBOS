/// Barra de estado inferior — muestra conexion y atajos

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rpc_client.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final rpc = context.watch<RpcClient>();
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(color: Color(0xFF0D1117), border: Border(top: BorderSide(color: Color(0xFF30363D)))),
      child: Row(children: [
        Icon(Icons.circle, size: 8, color: rpc.isConnected ? const Color(0xFF3FB950) : const Color(0xFFDA3633)),
        const SizedBox(width: 6),
        Text(rpc.isConnected ? 'Conectado' : 'Desconectado', style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 16),
        Text('${rpc.host}:${rpc.port}', style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
        if (rpc.daemonVersion != null) ...[
          const SizedBox(width: 16),
          Text('bAuth v${rpc.daemonVersion}', style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
        ],
        const Spacer(),
        const Text('Ctrl+Enter: Enviar | Ctrl+F: Buscar | Esc: Cerrar', style: TextStyle(fontSize: 10, color: Color(0xFF484F58))),
      ]),
    );
  }
}
