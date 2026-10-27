import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../personal_agent/application/persona_context.dart';
import '../../personal_agent/application/persona_repository.dart';
import '../../personal_agent/application/personal_owner_profile_editor.dart';
import '../../personal_agent/domain/personal_agenda_day.dart';

/// Pausa de envíos persistida en el perfil y evaluada antes de cada despacho.
class NanoPersonalQuietHoursCard extends ConsumerStatefulWidget {
  const NanoPersonalQuietHoursCard({super.key});
  @override
  ConsumerState<NanoPersonalQuietHoursCard> createState() => _QuietHoursState();
}

class _QuietHoursState extends ConsumerState<NanoPersonalQuietHoursCard> {
  bool _enabled = false, _busy = true, _failed = false;
  int _start = 1380, _end = 360;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final owners = await PersonaRepository.instance.listPersonas(
        rethrowFailures: true,
      );
      if (!mounted) return;
      final facts =
          owners.where((p) => p.personaKey == 'owner').firstOrNull?.facts ?? {};
      setState(() {
        _enabled = facts['quietHoursEnabled'] == 'true';
        _start = int.tryParse(facts['quietHoursStart'] ?? '') ?? 1380;
        _end = int.tryParse(facts['quietHoursEnd'] ?? '') ?? 360;
        _busy = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _save(bool enabled, int start, int end) async {
    setState(() => _busy = true);
    try {
      await PersonalOwnerProfileEditor.update({
        'quietHoursEnabled': '$enabled',
        'quietHoursStart': '$start',
        'quietHoursEnd': '$end',
      });
      await ref.read(personaContextProvider).refresh();
      if (mounted) {
        setState(() {
          _enabled = enabled;
          _start = start;
          _end = end;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar la pausa.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(bool start) async {
    final minutes = start ? _start : _end;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (time == null || !mounted) return;
    final next = time.hour * 60 + time.minute;
    await _save(_enabled, start ? next : _start, start ? _end : next);
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_failed)
            TextButton(
              onPressed: _load,
              child: const Text('No se pudo cargar la pausa. Reintentar'),
            )
          else ...[
            SwitchListTile(
              title: const Text('Pausar envíos en este horario'),
              subtitle: const Text(
                'Hora local. Durante la pausa las respuestas quedan para revisión.',
              ),
              value: _enabled,
              onChanged: _busy ? null : (v) => _save(v, _start, _end),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : () => _pick(true),
                  child: Text('Desde ${PersonalAgendaEntry.clock(_start)}'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _pick(false),
                  child: Text('Hasta ${PersonalAgendaEntry.clock(_end)}'),
                ),
              ],
            ),
            if (_enabled && _start == _end)
              const Text('Horas iguales: pausa durante todo el día.'),
          ],
          if (_error != null) Text(_error!),
        ],
      ),
    ),
  );
}
