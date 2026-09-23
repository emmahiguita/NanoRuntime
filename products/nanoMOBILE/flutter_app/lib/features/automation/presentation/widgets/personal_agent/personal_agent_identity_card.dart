import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile_providers.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_context.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_repository.dart';
import '../../automation_visual_theme.dart';
import '../settings_tile_components.dart';

/// QUÉ HACE:
/// Tarjeta para editar la identidad personal y notas de contexto del usuario.
///
/// CÓMO FUNCIONA:
/// Lee la clave 'owner' en SQLite a través de [PersonaRepository], sincroniza
/// los hechos preexistentes y actualiza el contexto conversacional del agente.
///
/// POR QUÉ:
/// El agente personal requiere hechos reales sobre su dueño para no alucinar
/// ni dar información falsa en diálogos privados o profesionales.
class PersonalAgentIdentityCard extends ConsumerStatefulWidget {
  const PersonalAgentIdentityCard({super.key});

  @override
  ConsumerState<PersonalAgentIdentityCard> createState() =>
      _PersonalAgentIdentityCardState();
}

class _PersonalAgentIdentityCardState
    extends ConsumerState<PersonalAgentIdentityCard> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final personas = await PersonaRepository.instance.listPersonas();
      final owner = personas.where((p) => p.personaKey == 'owner').firstOrNull;
      if (!mounted) return;

      final toneRaw = owner?.facts['tone'];
      if (toneRaw != null && toneRaw.isNotEmpty) {
        try {
          final toneJson = (jsonDecode(toneRaw) as Map).cast<String, dynamic>();
          final ownerTone = ToneProfile.fromJson(toneJson);
          final notifier = ref.read(toneProfileNotifierProvider.notifier);
          await notifier.ready;
          if (!ref.read(toneProfileNotifierProvider).enabled) {
            await notifier.update(ownerTone);
          }
        } catch (_) {}
      }
      setState(() {
        _nameController.text = owner?.displayName ?? '';
        _notesController.text = owner?.facts['notas'] ?? '';
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Error al leer perfil.'; });
    }
  }

  Future<void> _saveProfile() async {
    if (_saving || _loading || _error != null) return;
    final name = _nameController.text.trim();
    final notes = _notesController.text.trim();
    if (name.length > 80 || notes.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 80 letras de nombre y 500 de notas.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = PersonaRepository.instance;
      final profiles = await repo.listPersonas();
      final owner = profiles.where((p) => p.personaKey == 'owner').firstOrNull;
      final saved = await repo.upsertPersona('owner', name, {
        ...?owner?.facts,
        'notas': notes,
      });
      if (!saved) throw StateError('Fallo al guardar.');
      if (!mounted) return;
      await ref.read(personaContextProvider).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil personal guardado.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el perfil.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: visual.textMuted)),
                TextButton(onPressed: _loadProfile, child: const Text('Reintentar')),
              ],
              TextField(
                controller: _nameController,
                enabled: !_loading && !_saving && _error == null,
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: 'Tu nombre',
                  hintText: 'Ej. Emmanuel',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                style: TextStyle(color: visual.text, fontSize: 14),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                enabled: !_loading && !_saving && _error == null,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Preferencias clave sobre ti',
                  hintText: 'Ej. Respuestas cordiales, sin rodeos, no citas viernes.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                style: TextStyle(color: visual.text, fontSize: 14),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: visual.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _loading || _saving || _error != null ? null : _saveProfile,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  _saving ? 'Guardando…' : 'Guardar identidad',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
