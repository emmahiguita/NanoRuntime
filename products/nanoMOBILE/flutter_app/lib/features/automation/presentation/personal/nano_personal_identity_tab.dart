/// NANO-PERSONAL-IDENTITY-TAB — Pestaña de Identidad del Agente Personal.
///
/// QUÉ HACE:
/// Permite editar los datos de identidad de Emmanuel (nombre, descripción,
/// estilo de trato cercano/formal, emojis y retardo humano de respuesta).
///
/// CÓMO FUNCIONA:
/// Lee y persiste en [PersonaRepository] durable en SQLite (clave 'owner')
/// y sincroniza con [toneProfileNotifierProvider].
///
/// POR QUÉ:
/// Ofrece una configuración limpia y sin tecnicismos para que Nano
/// sepa a quién representa y cómo debe expresarse.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/messaging/tone_profile.dart';
import '../../engine/messaging/tone_profile_providers.dart';
import '../../personal_agent/application/persona_repository.dart';
import '../automation_visual_theme.dart';
import '../widgets/settings_tile_components.dart';

class NanoPersonalIdentityTab extends ConsumerStatefulWidget {
  const NanoPersonalIdentityTab({super.key});

  @override
  ConsumerState<NanoPersonalIdentityTab> createState() =>
      _NanoPersonalIdentityTabState();
}

class _NanoPersonalIdentityTabState
    extends ConsumerState<NanoPersonalIdentityTab> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final personas = await PersonaRepository.instance.listPersonas();
      final owner = personas.where((p) => p.personaKey == 'owner').firstOrNull;
      if (!mounted) return;
      setState(() {
        _nameController.text = owner?.displayName ?? 'Emmanuel';
        _descController.text = owner?.facts['notas'] ?? '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveData() async {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    await PersonaRepository.instance.upsertPersona('owner', name, {
      'notas': desc,
      'identidad': 'Dueño de Nano AI',
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Identidad personal guardada.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final visual = AutomationVisual.of(context);
    final tone = ref.watch(toneProfileNotifierProvider);
    final toneNotifier = ref.read(toneProfileNotifierProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        const AutomationSectionLabel('Información del Dueño'),
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: TextField(
                controller: _nameController,
                style: TextStyle(color: visual.text, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Tu nombre o apodo',
                  labelStyle: TextStyle(color: visual.textMuted),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _saveData(),
              ),
            ),
            const Divider(height: 1, thickness: 0.5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: TextField(
                controller: _descController,
                maxLines: 2,
                style: TextStyle(color: visual.text, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Descripción personal (ocupación, contexto)',
                  hintText: 'Ej. Ingeniero de software, trabajo en tecnología...',
                  labelStyle: TextStyle(color: visual.textMuted),
                  hintStyle: TextStyle(color: visual.textMuted.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _saveData(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const AutomationSectionLabel('Trato y Estilo de Escritura'),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.record_voice_over_outlined,
              title: 'Trato a personas conocidas',
              subtitle: tone.warmth == ToneWarmth.cercano
                  ? 'Cercano y natural (tuteo amigable)'
                  : 'Formal y reservado (usted)',
              trailing: ValueBadge(
                label: tone.warmth == ToneWarmth.cercano ? 'CERCANO' : 'FORMAL',
              ),
              onTap: () => toneNotifier.update(
                tone.copyWith(
                  enabled: true,
                  warmth: tone.warmth == ToneWarmth.cercano
                      ? ToneWarmth.formal
                      : ToneWarmth.cercano,
                ),
              ),
            ),
            SettingsRow(
              icon: Icons.emoji_emotions_outlined,
              title: 'Uso de emojis',
              subtitle: tone.emojis
                  ? 'Permitidos según tu estilo natural'
                  : 'Desactivados (solo texto plano)',
              trailing: Switch(
                value: tone.emojis,
                onChanged: (v) => toneNotifier.update(
                  tone.copyWith(enabled: true, emojis: v),
                ),
              ),
              showChevron: false,
            ),
            const SettingsRow(
              icon: Icons.timer_outlined,
              title: 'Retardo de respuesta humano',
              subtitle: 'Espera entre 4 y 12 segundos para simular tipeo real.',
              trailing: ValueBadge(label: '8 SEG'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saveData,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Guardar Identidad'),
          style: FilledButton.styleFrom(
            backgroundColor: visual.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
