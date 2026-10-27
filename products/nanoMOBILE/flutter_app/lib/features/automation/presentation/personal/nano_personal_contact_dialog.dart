import 'package:flutter/material.dart';
import '../../personal_agent/domain/persona_profile.dart';
import '../../personal_agent/domain/personal_contact_policy.dart';

class PersonalContactEdit {
  const PersonalContactEdit(
    this.name,
    this.conversations,
    this.groups,
    this.style,
    this.autoReply,
  );
  final String name, style;
  final List<String> conversations, groups;
  final bool autoReply;
}

Future<PersonalContactEdit?> showPersonalContactEditor(
  BuildContext context, {
  RelationshipProfile? existing,
  required Map<String, String> conversations,
}) => showDialog<PersonalContactEdit>(
  context: context,
  builder: (_) =>
      _ContactEditor(existing: existing, conversations: conversations),
);

class _ContactEditor extends StatefulWidget {
  const _ContactEditor({this.existing, required this.conversations});
  final RelationshipProfile? existing;
  final Map<String, String> conversations;
  @override
  State<_ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<_ContactEditor> {
  late final _name = TextEditingController(
    text: widget.existing?.displayName ?? '',
  );
  late final Set<String> _ids = widget.existing == null
      ? <String>{}
      : PersonalContactPolicy.conversations(widget.existing!).toSet();
  late final Set<String> _groups = {
    ...PersonalContactPolicy.list(widget.existing?.facts['groups']),
  };
  late String _style = PersonalContactPolicy.normalizeStyle(
    widget.existing?.facts['styleRegister'],
  );
  late bool _auto = widget.existing?.facts['autoReply'] == 'true';
  String? _error;
  bool get _batch => widget.existing == null;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choices = {
      ...widget.conversations,
      for (final id in _ids)
        if (!widget.conversations.containsKey(id)) id: 'Conversación vinculada',
    };
    return AlertDialog(
      title: Text(_batch ? 'Agregar contactos a grupos' : 'Editar contacto'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_batch)
                TextField(
                  controller: _name,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Nombre o apodo del contacto',
                  ),
                ),
              const Text('Grupos de organización'),
              Wrap(
                spacing: 6,
                children: PersonalContactPolicy.groups
                    .map(
                      (group) => FilterChip(
                        label: Text(group),
                        selected: _groups.contains(group),
                        onSelected: (v) => setState(() {
                          v ? _groups.add(group) : _groups.remove(group);
                        }),
                      ),
                    )
                    .toList(),
              ),
              DropdownButtonFormField<String>(
                initialValue: _style,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Estilo'),
                items: const [
                  DropdownMenuItem(
                    value: 'inherit',
                    child: Text('Según los grupos'),
                  ),
                  DropdownMenuItem(value: 'formal', child: Text('Formal')),
                  DropdownMenuItem(value: 'close', child: Text('Cercano')),
                  DropdownMenuItem(value: 'casual', child: Text('Natural')),
                  DropdownMenuItem(value: 'brief', child: Text('Breve')),
                ],
                onChanged: (v) => setState(() => _style = v ?? 'inherit'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Permitir respuestas automáticas'),
                subtitle: const Text(
                  'También se respetan supervisión, pausas y horario nocturno.',
                ),
                value: _auto,
                onChanged: (v) => setState(() => _auto = v),
              ),
              const Text(
                'Conversaciones reales. No se unen personas por nombre.',
              ),
              if (choices.isEmpty)
                const Text(
                  'Aún no hay conversaciones observadas. Recibe un mensaje del contacto y actualiza la lista.',
                ),
              for (final entry in choices.entries)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  value: _ids.contains(entry.key),
                  onChanged: (v) => setState(() {
                    v == true ? _ids.add(entry.key) : _ids.remove(entry.key);
                  }),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if ((_batch && _ids.isEmpty) ||
                (!_batch && _name.text.trim().isEmpty)) {
              setState(
                () => _error = _batch
                    ? 'Selecciona al menos una conversación.'
                    : 'Escribe el nombre.',
              );
              return;
            }
            Navigator.pop(
              context,
              PersonalContactEdit(
                _name.text.trim(),
                _ids.toList(),
                _groups.toList(),
                _style,
                _auto,
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
