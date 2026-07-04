/// Pantalla principal — Catalogo de metodos (izq) + Cinta de bloques (der)
/// Patron: Click en metodo -> auto-llena editor -> ejecuta -> bloque nuevo en cinta

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/rpc_client.dart';
import '../../services/method_catalog.dart';
import '../../widgets/cinta_bloques.dart';
import '../../widgets/editor_rpc.dart';

class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  String _search = '';
  String? _selectedCategory;
  MethodInfo? _selectedMethod;
  final List<BloqueCinta> _bloques = [];
  bool _conectando = true;
  String? _errorConexion;

  @override
  void initState() {
    super.initState();
    _conectar();
  }

  Future<void> _conectar() async {
    final rpc = context.read<RpcClient>();
    try {
      await rpc.connect();
      setState(() { _conectando = false; _errorConexion = null; });
    } catch (e) {
      setState(() { _conectando = false; _errorConexion = e.toString(); });
    }
  }

  void _seleccionarMetodo(MethodInfo metodo) {
    setState(() { _selectedMethod = metodo; });
  }

  Future<void> _ejecutarComando(Map<String, dynamic> request) async {
    final rpc = context.read<RpcClient>();
    final inicio = DateTime.now();
    try {
      final respuesta = await rpc.call(request['method'] as String, request['params'] as Map<String, dynamic>?);
      final duracion = DateTime.now().difference(inicio);
      setState(() {
        _bloques.insert(0, BloqueCinta(
          comando: request,
          resultado: respuesta,
          duracion: duracion,
          timestamp: DateTime.now(),
        ));
      });
    } catch (e) {
      setState(() {
        _bloques.insert(0, BloqueCinta(
          comando: request,
          error: e.toString(),
          timestamp: DateTime.now(),
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rpc = context.watch<RpcClient>();
    final catalog = context.read<MethodCatalog>();

    if (_conectando) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Conectando a ${rpc.host}:${rpc.port}...', style: Theme.of(context).textTheme.bodyLarge),
          ]),
        ),
      );
    }

    if (_errorConexion != null) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Sin conexion al daemon', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('ws://${rpc.host}:${rpc.port}', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(_errorConexion!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: () { setState(() { _conectando = true; }); _conectar(); }, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
          ]),
        ),
      );
    }

    final metodosFiltrados = _search.isEmpty && _selectedCategory == null
        ? catalog.methods
        : _search.isNotEmpty
            ? catalog.search(_search)
            : catalog.byCategory(_selectedCategory!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('bAuthDEV'),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFF00D4AA).withAlpha(20), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00D4AA))),
              const SizedBox(width: 8),
              Text('${rpc.host}:${rpc.port}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text('v${rpc.daemonVersion ?? "?"}', style: const TextStyle(fontSize: 11, color: Color(0xFF8B949E))),
            ]),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(children: [
        // ── PANEL IZQUIERDO: CATALOGO ──────────
        SizedBox(
          width: 300,
          child: Column(children: [
            // Buscador
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(hintText: 'Buscar metodo...', prefixIcon: Icon(Icons.search, size: 18), isDense: true),
                onChanged: (v) => setState(() { _search = v; _selectedCategory = null; }),
              ),
            ),
            // Categorias
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _ChipCategoria('Todos', null, _selectedCategory, () => setState(() { _selectedCategory = null; _search = ''; })),
                  ...catalog.categories.map((c) => _ChipCategoria(c, c, _selectedCategory, () => setState(() { _selectedCategory = c; _search = ''; }))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Lista de metodos
            Expanded(
              child: ListView.builder(
                itemCount: metodosFiltrados.length,
                itemBuilder: (_, i) => _MetodoCard(
                  metodo: metodosFiltrados[i],
                  seleccionado: _selectedMethod?.name == metodosFiltrados[i].name,
                  onTap: () => _seleccionarMetodo(metodosFiltrados[i]),
                ),
              ),
            ),
          ]),
        ),
        const VerticalDivider(width: 1),
        // ── PANEL DERECHO: EDITOR + CINTA ───────
        Expanded(
          child: Column(children: [
            // Editor RPC (aparece al seleccionar metodo)
            if (_selectedMethod != null)
              EditorRpc(
                metodo: _selectedMethod!,
                onEjecutar: _ejecutarComando,
                onCerrar: () => setState(() { _selectedMethod = null; }),
              ),
            const Divider(height: 1),
            // Cinta de bloques
            Expanded(child: CintaBloques(bloques: _bloques)),
          ]),
        ),
      ]),
    );
  }
}

class _ChipCategoria extends StatelessWidget {
  final String label;
  final String? value;
  final String? selected;
  final VoidCallback onTap;
  const _ChipCategoria(this.label, this.value, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final activo = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: activo ? Colors.black : null)),
        selected: activo,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        selectedColor: const Color(0xFF00D4AA),
      ),
    );
  }
}

class _MetodoCard extends StatelessWidget {
  final MethodInfo metodo;
  final bool seleccionado;
  final VoidCallback onTap;
  const _MetodoCard({required this.metodo, required this.seleccionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: seleccionado ? const Color(0xFF00D4AA).withAlpha(15) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(metodo.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
              if (metodo.hasMaskVariant) const _Badge('+Mask', Color(0xFF58A6FF)),
              if (metodo.hasBlockchainVariant) const SizedBox(width: 4),
              if (metodo.hasBlockchainVariant) const _Badge('+BC', Color(0xFFD29922)),
            ]),
            const SizedBox(height: 4),
            Text(metodo.description, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
