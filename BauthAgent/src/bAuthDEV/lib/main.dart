/// bAuthDEV — Plataforma de Desarrollo e Integracion bAuth
/// Stack: Flutter 3.44 + Material 3 + JSON-RPC 2.0 WebSocket

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'services/rpc_client.dart';
import 'services/method_catalog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(const Size(1100, 700));
  await windowManager.setTitle('bAuthDEV — Identity Control Plane SBOS');

  final rpc = RpcClient();
  final catalog = MethodCatalog();

  runApp(
    MultiProvider(
      providers: [
        Provider<RpcClient>.value(value: rpc),
        Provider<MethodCatalog>.value(value: catalog),
      ],
      child: const BauthDevApp(),
    ),
  );
}
