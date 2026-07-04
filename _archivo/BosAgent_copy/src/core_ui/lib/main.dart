/// SBOS Core UI — Entry Point
///
/// Panel de administracion soberano del IAM Installer.
/// JSON-RPC 2.0 sobre WebSocket (ADR-020).
library sbos_core_ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/jsonrpc_client.dart';
import 'services/ws_service.dart';

void main() {
  final jsonRpc = JsonRpcClient();
  final wsService = WsService();

  runApp(
    MultiProvider(
      providers: [
        Provider<JsonRpcClient>.value(value: jsonRpc),
        Provider<WsService>.value(value: wsService),
      ],
      child: const SbosApp(),
    ),
  );

  jsonRpc.connect();
}

class SbosApp extends StatelessWidget {
  const SbosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SBOS — Core UI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00D4AA),
        brightness: Brightness.dark,
      ),
      home: const AppShell(),
    );
  }
}
