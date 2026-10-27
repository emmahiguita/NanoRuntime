import 'package:flutter/material.dart';
import '../../personal_agent/domain/personal_agenda_day.dart';

/// El diálogo es dueño de sus campos y los libera al cerrarse.
Future<PersonalAgendaEntry?> showPersonalAgendaEntryDialog(
  BuildContext context, {
  PersonalAgendaEntry? existing,
  List<PersonalAgendaEntry> others = const [],
}) => showDialog<PersonalAgendaEntry>(
  context: context,
  builder: (_) => _AgendaEntryDialog(existing: existing, others: others),
);

class _AgendaEntryDialog extends StatefulWidget {
  const _AgendaEntryDialog({this.existing, required this.others});
  final PersonalAgendaEntry? existing;
  final List<PersonalAgendaEntry> others;
  @override
  State<_AgendaEntryDialog> createState() => _AgendaEntryDialogState();
}

class _AgendaEntryDialogState extends State<_AgendaEntryDialog> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late int _start = widget.existing?.start ?? 480;
  late int _end = widget.existing?.end ?? 540;
  late PersonalAgendaKind _kind =
      widget.existing?.kind ?? PersonalAgendaKind.automatic;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isStart) async {
    final minutes = isStart ? _start : _end;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: isStart ? 'Hora de inicio' : 'Hora de fin',
    );
    if (time == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = time.hour * 60 + time.minute;
      } else {
        _end = time.hour * 60 + time.minute;
      }
      _error = null;
    });
  }

  void _apply() {
    final entry = PersonalAgendaEntry(
      _title.text.trim(),
      _start,
      _end,
      kind: _kind,
    );
    final error = entry.title.isEmpty
        ? 'Escribe la actividad.'
        : _end <= _start
        ? 'La hora de fin debe ser posterior al inicio.'
        : widget.others.any(entry.conflictsWith)
        ? 'Ese horario se cruza con otra actividad.'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null ? 'Añadir actividad' : 'Editar actividad',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Actividad',
              hintText: 'Trabajo, almuerzo, descanso…',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PersonalAgendaKind>(
            initialValue: _kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tipo de actividad'),
            items: [
              for (final item in const {
                PersonalAgendaKind.automatic: 'Detectar por el nombre',
                PersonalAgendaKind.activity: 'Otra actividad',
                PersonalAgendaKind.work: 'Trabajo',
                PersonalAgendaKind.breakfast: 'Desayuno',
                PersonalAgendaKind.lunch: 'Almuerzo',
                PersonalAgendaKind.dinner: 'Cena',
              }.entries)
                DropdownMenuItem(value: item.key, child: Text(item.value)),
            ],
            onChanged: (value) => setState(() {
              _kind = value ?? PersonalAgendaKind.automatic;
              _error = null;
            }),
          ),
          const Text('Las comidas reservan una pausa dentro del trabajo.'),
          OutlinedButton.icon(
            onPressed: () => _pick(true),
            icon: const Icon(Icons.schedule),
            label: Text('Desde ${PersonalAgendaEntry.clock(_start)}'),
          ),
          OutlinedButton.icon(
            onPressed: () => _pick(false),
            icon: const Icon(Icons.schedule),
            label: Text('Hasta ${PersonalAgendaEntry.clock(_end)}'),
          ),
          const Text('Si cruza medianoche, añade un tramo en cada fecha.'),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _apply, child: const Text('Aplicar')),
    ],
  );
}
