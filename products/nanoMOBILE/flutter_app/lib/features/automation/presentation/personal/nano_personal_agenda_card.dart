import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../personal_agent/application/persona_context.dart';
import '../../personal_agent/application/persona_repository.dart';
import '../../personal_agent/application/personal_owner_profile_editor.dart';
import '../../personal_agent/domain/personal_daily_agenda.dart';
import '../../personal_agent/domain/personal_agenda_day.dart';
import 'nano_personal_agenda_dialog.dart';
import 'nano_personal_agenda_view.dart';

/// Calendario editable por fecha que alimenta el contexto vivo existente.
class NanoPersonalAgendaCard extends ConsumerStatefulWidget {
  const NanoPersonalAgendaCard({super.key});
  @override
  ConsumerState<NanoPersonalAgendaCard> createState() =>
      _NanoPersonalAgendaCardState();
}

class _NanoPersonalAgendaCardState
    extends ConsumerState<NanoPersonalAgendaCard> {
  final _notes = TextEditingController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  Map<String, String> _facts = {};
  List<PersonalAgendaEntry> _entries = [];
  bool _enabled = true, _loading = true, _saving = false, _dirty = false;
  String? _status;
  bool _loadFailed = false;
  bool _repeatWeekly = false;
  int _calendarRevision = 0;
  String get _key => PersonalDailyAgenda.dateKey(_date);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final rows = await PersonaRepository.instance.listPersonas(
        rethrowFailures: true,
      );
      if (!mounted) return;
      _facts =
          rows.where((p) => p.personaKey == 'owner').firstOrNull?.facts ?? {};
      setState(() {
        _selectDay();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  void _selectDay() {
    final day = PersonalAgendaDay.forDate(_facts, _key);
    _notes.text = day.notes;
    _entries = [...day.entries];
    _enabled = day.enabled;
    final weekly = jsonDecode(_facts['agendaWeekly'] ?? '{}');
    _repeatWeekly =
        weekly is Map && weekly.containsKey(_date.weekday.toString());
    _dirty = false;
    _status = null;
  }

  Future<void> _pickDate([DateTime? selected]) async {
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cambios sin guardar'),
          content: const Text(
            'Guarda la agenda antes de cambiar de fecha o descarta estos cambios.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (discard != true) {
        setState(() => _calendarRevision++);
        return;
      }
    }
    final picked =
        selected ??
        await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          helpText: 'Fecha de la agenda',
        );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      _selectDay();
    });
  }

  Future<void> _edit([int? index]) async {
    if (index == null && _entries.length >= 24) {
      setState(() => _status = 'Puedes añadir hasta 24 actividades por fecha.');
      return;
    }
    final entry = await showPersonalAgendaEntryDialog(
      context,
      existing: index == null ? null : _entries[index],
      others: [
        for (var i = 0; i < _entries.length; i++)
          if (i != index) _entries[i],
      ],
    );
    if (entry == null || !mounted) return;
    final others = [..._entries];
    if (index != null) others.removeAt(index);
    if (others.any(entry.conflictsWith)) {
      setState(
        () => _status =
            'Ese horario se cruza con otra actividad. Edita las horas.',
      );
      return;
    }
    setState(() {
      _entries = [...others, entry]..sort((a, b) => a.start.compareTo(b.start));
      _dirty = true;
      _status = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final store = ref.read(personaContextProvider);
    final day = PersonalAgendaDay(
      enabled: _enabled,
      notes: _notes.text.trim(),
      entries: _entries,
    );
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      await PersonalOwnerProfileEditor.updateAgendaDay(
        _key,
        day,
        repeatWeekly: _repeatWeekly,
      );
      // Conserva las otras fechas y las notas del perfil original al navegar.
      final calendar = PersonalAgendaDay.calendar(_facts)
        ..[_key] = day.toJson();
      _facts = {..._facts, 'agendaCalendar': jsonEncode(calendar)};
      final weekly = Map<String, dynamic>.from(
        jsonDecode(_facts['agendaWeekly'] ?? '{}') as Map,
      );
      if (_repeatWeekly) {
        weekly[_date.weekday.toString()] = day.toJson();
      } else {
        weekly.remove(_date.weekday.toString());
      }
      _facts['agendaWeekly'] = jsonEncode(weekly);
      await store.refresh();
      if (mounted) {
        setState(() {
          _dirty = false;
          _status = 'Agenda guardada para $_key.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _status = error is StateError
              ? error.message.toString()
              : 'No se pudo guardar o actualizar la agenda. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();
    if (_loadFailed) {
      return Card(
        child: ListTile(
          title: const Text('No se pudo cargar la agenda.'),
          trailing: TextButton(
            onPressed: _load,
            child: const Text('Reintentar'),
          ),
        ),
      );
    }
    return NanoPersonalAgendaView(
      date: _date,
      entries: _entries,
      notes: _notes,
      enabled: _enabled,
      saving: _saving,
      dirty: _dirty,
      status: _status,
      onDate: _pickDate,
      onDateSelected: (date) => _pickDate(date),
      calendarRevision: _calendarRevision,
      repeatWeekly: _repeatWeekly,
      onRepeatWeekly: (v) => setState(() {
        _repeatWeekly = v;
        _dirty = true;
      }),
      onAdd: () => _edit(),
      onEdit: _edit,
      onDelete: (index) => setState(() {
        _entries.removeAt(index);
        _dirty = true;
      }),
      onEnabled: (value) => setState(() {
        _enabled = value;
        _dirty = true;
      }),
      onNotes: (_) => setState(() => _dirty = true),
      onSave: _save,
    );
  }
}
