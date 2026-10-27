import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../personal_agent/application/persona_context.dart';
import '../../personal_agent/application/personal_owner_profile_editor.dart';
import '../../personal_agent/application/persona_repository.dart';
import '../../personal_agent/domain/personal_daily_agenda.dart';
import 'adaptive_personal_fields.dart';

/// QUÉ: preferencias estables y estado diario editables, conectados al contexto.
/// CÓMO: guarda por la cola del perfil; editar otra opción no renueva el estado.
/// POR QUÉ: el estado de ayer no debe reaparecer como actividad actual.
class NanoPersonalOwnerContextCard extends ConsumerStatefulWidget {
  const NanoPersonalOwnerContextCard({super.key});
  @override
  ConsumerState<NanoPersonalOwnerContextCard> createState() =>
      _OwnerContextState();
}

class _OwnerContextState extends ConsumerState<NanoPersonalOwnerContextCard> {
  final _preferences = TextEditingController(),
      _daily = TextEditingController();
  String _date = '', _feedback = '';
  bool _allowCloudMedia = false;
  bool _loading = true, _saving = false, _editedDaily = false, _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _preferences.dispose();
    _daily.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await PersonaRepository.instance.listPersonas(
        rethrowFailures: true,
      );
      if (!mounted) return;
      final facts =
          rows.where((p) => p.personaKey == 'owner').firstOrNull?.facts ?? {};
      setState(() {
        _preferences.text = facts['preferences'] ?? '';
        _daily.text = facts['dailyStatus'] ?? '';
        _date = facts['dailyStatusDate'] ?? '';
        _allowCloudMedia = facts['allowCloudMedia'] == 'true';
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final context = ref.read(personaContextProvider);
    final date = _editedDaily
        ? PersonalDailyAgenda.dateKey(DateTime.now())
        : _date;
    setState(() => _saving = true);
    try {
      await PersonalOwnerProfileEditor.update({
        'preferences': _preferences.text.trim(),
        'allowCloudMedia': '$_allowCloudMedia',
        if (_editedDaily) 'dailyStatus': _daily.text.trim(),
        if (_editedDaily) 'dailyStatusDate': date,
      });
      await context.refresh();
      if (mounted) {
        setState(() {
          _date = date;
          _editedDaily = false;
          _feedback = 'Información guardada.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _feedback = 'No se pudo guardar. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();
    if (_failed) {
      return TextButton(
        onPressed: _load,
        child: const Text('Reintentar carga de preferencias'),
      );
    }
    final today = PersonalDailyAgenda.dateKey(DateTime.now());
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mis preferencias y estado de hoy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            AdaptivePersonalFields(
              children: [
                TextField(
                  controller: _preferences,
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Preferencias para responder',
                    hintText:
                        'Qué planes te gustan, cómo prefieres coordinar y qué no quieres prometer.',
                  ),
                ),
                TextField(
                  controller: _daily,
                  enabled: !_saving,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 250,
                  onChanged: (_) => setState(() => _editedDaily = true),
                  decoration: const InputDecoration(
                    labelText: 'Estado que declaro para hoy',
                    hintText: 'Estoy ocupado hasta las 5; hoy no puedo salir.',
                  ),
                ),
              ],
            ),
            Text(
              _editedDaily || _date == today
                  ? 'El estado se usa solo hoy, junto con tu agenda.'
                  : _date.isEmpty
                  ? 'Sin estado diario vigente.'
                  : 'Estado anterior ($_date): no se usa como estado de hoy.',
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Permitir Gemini para comprender adjuntos'),
              subtitle: const Text(
                'Usa el modelo y la clave del Hub si la lectura local no basta. '
                'Envía el archivo a esa API y respeta el modo solo local.',
              ),
              value: _allowCloudMedia,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _allowCloudMedia = value),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                _saving ? 'Guardando…' : 'Guardar preferencias y estado',
              ),
            ),
            if (_feedback.isNotEmpty) Text(_feedback),
          ],
        ),
      ),
    );
  }
}
