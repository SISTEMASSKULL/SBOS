/// Editor JSON-RPC — Aparece al seleccionar un metodo del catalogo
/// Auto-llena con datos de prueba del usuario activo

import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/method_catalog.dart';

class EditorRpc extends StatefulWidget {
  final MethodInfo metodo;
  final Function(Map<String, dynamic>) onEjecutar;
  final VoidCallback onCerrar;

  const EditorRpc({super.key, required this.metodo, required this.onEjecutar, required this.onCerrar});

  @override
  State<EditorRpc> createState() => _EditorRpcState();
}

class _EditorRpcState extends State<EditorRpc> {
  late TextEditingController _jsonCtrl;
  bool _includeMask = false;
  bool _anchorBlockchain = false;
  bool _useRS256 = false;
  String _selectedUser = 'test_cajero';

  @override
  void initState() {
    super.initState();
    _generarJson();
  }

  @override
  void didUpdateWidget(EditorRpc old) {
    super.didUpdateWidget(old);
    if (old.metodo.name != widget.metodo.name) _generarJson();
  }

  void _generarJson() {
    final params = Map<String, dynamic>.from(widget.metodo.exampleParams);
    // Auto-llenar user_uuid si existe
    if (params.containsKey('user_uuid') && MethodCatalog.testUsers.containsKey(_selectedUser)) {
      params['user_uuid'] = MethodCatalog.testUsers[_selectedUser];
    }
    // Aplicar checkboxes
    if (widget.metodo.hasMaskVariant && _includeMask) params['include_mask'] = true;
    if (widget.metodo.hasBlockchainVariant && _anchorBlockchain) params['anchor'] = true;
    if (widget.metodo.hasLegacyVariant && _useRS256) params['algorithm'] = 'RS256';

    final request = {'jsonrpc': '2.0', 'method': widget.metodo.name, 'params': params, 'id': 1};
    _jsonCtrl = TextEditingController(text: const JsonEncoder.withIndent('  ').convert(request));
  }

  void _ejecutar() {
    try {
      final request = jsonDecode(_jsonCtrl.text) as Map<String, dynamic>;
      widget.onEjecutar(request);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('JSON invalido: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Color(0xFF0D1117), border: Border(bottom: BorderSide(color: Color(0xFF30363D)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // Header
        Row(children: [
          Text(widget.metodo.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: Color(0xFF00D4AA))),
          const Spacer(),
          // Checkboxes de contexto
          if (widget.metodo.hasMaskVariant)
            _CheckboxContext('+Mask', _includeMask, (v) => setState(() { _includeMask = v; _generarJson(); })),
          if (widget.metodo.hasBlockchainVariant)
            _CheckboxContext('+BC', _anchorBlockchain, (v) => setState(() { _anchorBlockchain = v; _generarJson(); })),
          if (widget.metodo.hasLegacyVariant)
            _CheckboxContext('RS256', _useRS256, (v) => setState(() { _useRS256 = v; _generarJson(); })),
          // Selector de usuario
          if (widget.metodo.exampleParams.containsKey('user_uuid'))
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedUser,
                  isDense: true,
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  items: MethodCatalog.testUsers.keys.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 11)))).toList(),
                  onChanged: (v) => setState(() { _selectedUser = v!; _generarJson(); }),
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.close, size: 16), onPressed: widget.onCerrar, tooltip: 'Cerrar editor'),
        ]),
        const SizedBox(height: 8),
        // Editor JSON
        Expanded(
          child: TextField(
            controller: _jsonCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.5),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF30363D))),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Botones
        Row(children: [
          FilledButton.icon(onPressed: _ejecutar, icon: const Icon(Icons.play_arrow, size: 16), label: const Text('ENVIAR'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00D4AA), foregroundColor: Colors.black)),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _generarJson, child: const Text('Reset')),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: () { /* TODO: formatear */ }, icon: const Icon(Icons.auto_fix_high, size: 14), label: const Text('Formatear')),
        ]),
      ]),
    );
  }

  @override
  void dispose() { _jsonCtrl.dispose(); super.dispose(); }
}

class _CheckboxContext extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CheckboxContext(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: value ? const Color(0xFF58A6FF).withAlpha(30) : Colors.transparent, borderRadius: BorderRadius.circular(4), border: Border.all(color: value ? const Color(0xFF58A6FF) : const Color(0xFF30363D))),
          child: Text(label, style: TextStyle(fontSize: 10, color: value ? const Color(0xFF58A6FF) : const Color(0xFF8B949E), fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
