import 'package:flutter/material.dart';
import '../../personal_agent/domain/personal_memory.dart';

class NanoPersonalMemoryDialog {
  static Future<PersonalMemory?> show(
    BuildContext context, [
    PersonalMemory? existing,
  ]) => showDialog<PersonalMemory>(
    context: context,
    builder: (_) => _MemoryEditor(existing: existing),
  );
}

class _MemoryEditor extends StatefulWidget {
  const _MemoryEditor({this.existing});
  final PersonalMemory? existing;
  @override
  State<_MemoryEditor> createState() => _MemoryEditorState();
}

class _MemoryEditorState extends State<_MemoryEditor> {
  late final _key = TextEditingController(text: widget.existing?.key ?? '');
  late final _value = TextEditingController(text: widget.existing?.value ?? '');
  String? _error;
  @override
  void dispose() {
    _key.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Nuevo dato' : 'Editar dato'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _key,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Tema o aspecto'),
          ),
          TextField(
            controller: _value,
            maxLength: 1000,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Dato que Nano debe recordar',
            ),
          ),
          if (_error != null) Text(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_key.text.trim().isEmpty || _value.text.trim().isEmpty) {
            setState(() => _error = 'Completa el tema y el dato.');
            return;
          }
          Navigator.pop(
            context,
            PersonalMemory(
              id: widget.existing?.id ?? -1,
              scopeKey: widget.existing?.scopeKey ?? 'owner',
              key: _key.text.trim(),
              value: _value.text.trim(),
              kind: widget.existing?.kind ?? 'stablePreference',
              observedAt: DateTime.now().millisecondsSinceEpoch,
              metadata: widget.existing?.metadata ?? const {},
            ),
          );
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
