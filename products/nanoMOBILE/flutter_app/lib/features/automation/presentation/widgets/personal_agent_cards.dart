import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/engine/business/business_facts_providers.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile_providers.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_context.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_repository.dart';
import '../automation_visual_theme.dart';
import '../screens/business_studio_screen.dart';
import 'settings_tile_components.dart';

/// PERSONA-PROFILE-05 — perfil del dueño (nombre + datos que Nano debe
/// saber) y perfiles de relación por contacto. Guardado automático.
class PersonalAgentCard extends ConsumerStatefulWidget {
  const PersonalAgentCard({super.key});

  @override
  ConsumerState<PersonalAgentCard> createState() => _PersonalAgentCardState();
}

class _PersonalAgentCardState extends ConsumerState<PersonalAgentCard> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final personas = await PersonaRepository.instance.listPersonas();
      final owner = personas.where((p) => p.personaKey == 'owner').firstOrNull;
      if (!mounted) return;
      setState(() {
        _nameController.text = owner?.displayName ?? '';
        _notesController.text = owner?.facts['notas'] ?? '';
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo leer tu perfil. Reintenta antes de editarlo.';
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _loading || _error != null) return;
    final name = _nameController.text.trim();
    final notes = _notesController.text.trim();
    if (name.length > 80 || notes.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Máximo 80 caracteres para el nombre y 500 para las notas.',
          ),
        ),
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
      if (!saved) throw StateError('No se pudo guardar el perfil.');
      if (!mounted) return;
      await ref.read(personaContextProvider).refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Perfil guardado.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo completar el guardado. Reintenta.'),
          ),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: visual.textMuted)),
                TextButton(onPressed: _load, child: const Text('Reintentar')),
              ],
              TextField(
                controller: _nameController,
                enabled: !_loading && !_saving && _error == null,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Tu nombre',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: TextStyle(color: visual.text, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                enabled: !_loading && !_saving && _error == null,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Preferencias estables sobre ti',
                  hintText: 'Ej. Prefiero respuestas cortas.',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: TextStyle(color: visual.text, fontSize: 14),
              ),
              FilledButton(
                onPressed: _loading || _saving || _error != null ? null : _save,
                child: Text(_saving ? 'Guardando…' : 'Guardar perfil'),
              ),
              const SizedBox(height: 8),
              Text(
                'Contactos, ejemplos y memorias se administran en «Aprender de mis conversaciones».',
                style: TextStyle(color: visual.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// WA-BUSINESS-01 — Acceso directo a BusinessStudioScreen (SOLID SRP).
class BusinessDataCard extends ConsumerWidget {
  const BusinessDataCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = ref.watch(businessFactsNotifierProvider);
    final products = facts.products;
    return SettingsCard(
      children: [
        SettingsRow(
          imageAsset: 'assets/automation/whatsapp_business_icon.png',
          title: 'WhatsApp Negocio y Catálogo',
          subtitle: products.isEmpty
              ? 'Toca para abrir el estudio comercial o cargar una plantilla'
              : '${products.length} producto${products.length == 1 ? '' : 's'} configurado${products.length == 1 ? '' : 's'}',
          trailing: ValueBadge(
            label: products.isEmpty ? 'CONFIGURAR' : '${products.length} PROD',
          ),
          onTap: () => Navigator.of(context).push(
            nanoGlassPageRoute<void>(
              builder: (_) => const BusinessStudioScreen(),
            ),
          ),
        ),
      ],
    );
  }
}

/// WA-NATURAL-01 — perfil de tono de las respuestas automáticas del agente personal.
class ToneCard extends ConsumerWidget {
  const ToneCard({super.key});

  static const _warmthLabels = {
    ToneWarmth.cercano: 'Cercano',
    ToneWarmth.formal: 'Formal',
  };
  static const _verbosityLabels = {
    ToneVerbosity.breve: 'Breve',
    ToneVerbosity.media: 'Media',
    ToneVerbosity.extensa: 'Extensa',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(toneProfileNotifierProvider);
    final notifier = ref.read(toneProfileNotifierProvider.notifier);
    return SettingsCard(
      children: [
        SettingsRow(
          imageAsset: 'assets/automation/icons/icon_respuestas_wpp.png',
          title: 'Tono automático',
          subtitle: profile.enabled
              ? 'Activo — guía de estilo en las respuestas'
              : 'Inactivo — respuestas como hasta ahora',
          trailing: Switch(
            value: profile.enabled,
            onChanged: (v) => notifier.update(profile.copyWith(enabled: v)),
          ),
          showChevron: false,
        ),
        if (profile.enabled) ...[
          SettingsRow(
            imageAsset: 'assets/automation/icons/icon_trato_cliente.png',
            title: 'Trato',
            subtitle: 'Cómo se dirige a tus contactos',
            trailing: ValueBadge(
              label: _warmthLabels[profile.warmth]!.toUpperCase(),
            ),
            onTap: () => notifier.update(
              profile.copyWith(
                warmth:
                    ToneWarmth.values[(profile.warmth.index + 1) %
                        ToneWarmth.values.length],
              ),
            ),
            showChevron: false,
          ),
          SettingsRow(
            imageAsset: 'assets/automation/icons/icon_extension.png',
            title: 'Extensión',
            subtitle: 'Longitud típica de las respuestas',
            trailing: ValueBadge(
              label: _verbosityLabels[profile.verbosity]!.toUpperCase(),
            ),
            onTap: () => notifier.update(
              profile.copyWith(
                verbosity:
                    ToneVerbosity.values[(profile.verbosity.index + 1) %
                        ToneVerbosity.values.length],
              ),
            ),
            showChevron: false,
          ),
          SettingsRow(
            imageAsset: 'assets/automation/icons/icon_emoji.png',
            title: 'Emojis',
            subtitle: profile.emojis ? 'Con moderación' : 'Sin emojis',
            trailing: Switch(
              value: profile.emojis,
              onChanged: (v) => notifier.update(profile.copyWith(emojis: v)),
            ),
            showChevron: false,
          ),
        ],
      ],
    );
  }
}

