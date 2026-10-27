import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/messaging/tone_profile.dart';
import '../../engine/messaging/tone_profile_providers.dart';
import '../../personal_agent/application/persona_context.dart';
import '../../personal_agent/application/persona_repository.dart';
import '../../personal_agent/application/personal_owner_profile_editor.dart';
import 'nano_personal_agenda_card.dart';
import 'nano_personal_style_card.dart';
import 'nano_personal_owner_context_card.dart';
import 'adaptive_personal_fields.dart';

/// Identidad y agenda reales; las conexiones se administran fuera de esta pestaña.
class NanoPersonalIdentityTab extends ConsumerStatefulWidget {
  const NanoPersonalIdentityTab({super.key});
  @override
  ConsumerState<NanoPersonalIdentityTab> createState() =>
      _NanoPersonalIdentityTabState();
}

class _NanoPersonalIdentityTabState
    extends ConsumerState<NanoPersonalIdentityTab> {
  final _name = TextEditingController(),
      _nickname = TextEditingController(),
      _occupation = TextEditingController(),
      _groupMentions = TextEditingController(),
      _notes = TextEditingController();
  bool _loading = true, _saving = false, _loadFailed = false;
  String? _status;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _nickname, _occupation, _notes, _groupMentions]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final owners = await PersonaRepository.instance.listPersonas(
        rethrowFailures: true,
      );
      if (!mounted) return;
      final owner = owners.where((p) => p.personaKey == 'owner').firstOrNull;
      setState(() {
        _name.text = owner?.displayName ?? '';
        _nickname.text = owner?.facts['nickname'] ?? '';
        _occupation.text = owner?.facts['occupation'] ?? '';
        _groupMentions.text = owner?.facts['groupMentionAliases'] ?? '';
        _notes.text = owner?.facts['notas'] ?? '';
        _loading = false;
        _loadFailed = false;
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await PersonalOwnerProfileEditor.update({
        'nickname': _nickname.text.trim(),
        'occupation': _occupation.text.trim(),
        'groupMentionAliases': _groupMentions.text.trim(),
        'notas': _notes.text.trim(),
      }, name: _name.text.trim());
      await ref.read(personaContextProvider).refresh();
      if (mounted) setState(() => _status = 'Identidad guardada.');
    } catch (_) {
      if (mounted) setState(() => _status = 'No se pudo guardar la identidad.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _tone(ToneProfile value) async {
    try {
      await ref
          .read(toneProfileNotifierProvider.notifier)
          .update(value.copyWith(enabled: true));
      await ref.read(personaContextProvider).refresh();
    } catch (_) {
      if (mounted) setState(() => _status = 'No se pudo guardar el estilo.');
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    int length, {
    int lines = 1,
  }) => TextField(
    controller: controller,
    enabled: !_saving,
    maxLength: length,
    maxLines: lines,
    decoration: InputDecoration(labelText: label),
  );
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadFailed) {
      return Center(
        child: TextButton(
          onPressed: _load,
          child: const Text('No se pudo cargar. Reintentar'),
        ),
      );
    }
    final tone = ref.watch(toneProfileNotifierProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AdaptivePersonalFields(
                  children: [
                    _field(_name, 'Nombre', 100),
                    _field(_nickname, 'Apodo', 60),
                    _field(_occupation, 'Empleo u ocupación', 100),
                    _field(_notes, 'Descripción personal', 1000, lines: 3),
                  ],
                ),
                _field(
                  _groupMentions,
                  'Otras etiquetas para mencionarme en grupos',
                  320,
                ),
                const Text(
                  'En grupos, Nano solo responde a @tu nombre, @tu apodo '
                  'o estas etiquetas. Añade el nombre o número que aparece '
                  'al etiquetarte, separado por comas. Los chats privados siguen igual.',
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Guardando…' : 'Guardar identidad'),
                ),
                if (_status != null) Text(_status!),
              ],
            ),
          ),
        ),
        NanoPersonalStyleCard(tone: tone, onChanged: _tone),
        const NanoPersonalAgendaCard(),
        const NanoPersonalOwnerContextCard(),
      ],
    );
  }
}
