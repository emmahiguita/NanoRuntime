import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/theme/nano_transitions.dart';
import 'package:nanoai/core/widgets/navigation/nano_navigation_panel.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile_providers.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_context.dart';
import 'package:nanoai/features/automation/personal_agent/application/persona_repository.dart';
import 'package:nanoai/features/automation/personal_agent/presentation/personalization_studio_screen.dart';

import '../automation_layout.dart';
import '../automation_visual_theme.dart';
import '../widgets/settings_tile_components.dart';

/// Pantalla especializada (SOLID - SRP) para la configuración completa
/// del Agente Personal de WhatsApp: identidad, nivel de supervisión,
/// tono, trato, extensión, emojis y aprendizaje de conversaciones.
class PersonalAgentScreen extends ConsumerStatefulWidget {
  const PersonalAgentScreen({super.key});

  @override
  ConsumerState<PersonalAgentScreen> createState() =>
      _PersonalAgentScreenState();
}

class _PersonalAgentScreenState extends ConsumerState<PersonalAgentScreen> {
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
      // Sincronizar ToneProfile desde facts['tone'] del owner si existe y
      // no hay un perfil propio guardado (el store de SharedPrefs manda si
      // el usuario lo configuró explícitamente desde los controles).
      final toneRaw = owner?.facts['tone'];
      if (toneRaw != null && toneRaw.isNotEmpty) {
        try {
          final toneJson =
              (jsonDecode(toneRaw) as Map).cast<String, dynamic>();
          final ownerTone = ToneProfile.fromJson(toneJson);
          final notifier = ref.read(toneProfileNotifierProvider.notifier);
          await notifier.ready;
          // Solo sincroniza si el store global aún está en defaults (disabled).
          if (!ref.read(toneProfileNotifierProvider).enabled) {
            await notifier.update(ownerTone);
          }
        } catch (_) {
          // facts['tone'] corrupto: ignora silenciosamente.
        }
      }
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
          _error = 'No se pudo leer tu perfil personal.';
        });
      }
    }
  }

  Future<void> _saveProfile() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil personal guardado con éxito.')),
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
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final tone = ref.watch(toneProfileNotifierProvider);
    final toneNotifier = ref.read(toneProfileNotifierProvider.notifier);
    final visual = AutomationVisual.of(context);

    final isSupervised =
        settings.agentAutomationMode == AgentAutomationMode.assisted ||
        settings.agentAutomationMode == AgentAutomationMode.manual;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NanoShellBarScope(
        slotId: 'personal_agent_studio',
        child: SafeArea(
          top: true,
          bottom: false,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, kNanoBarScrollReserve),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: AutomationLayout.contentMaxWidth(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AutomationBackHeader(),
                      const SizedBox(height: 12),

                      // ENCABEZADO CON ICONO PROFESIONAL
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              visual.accent.withValues(alpha: 0.16),
                              visual.surface.withValues(alpha: 0.70),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: visual.accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: visual.accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: visual.accent.withValues(alpha: 0.4),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/automation/icons/icon_respuestas_wpp.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Agente Personal WPP',
                                    style: TextStyle(
                                      color: visual.text,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Respuestas privadas, identidad y estilo de comunicación',
                                    style: TextStyle(
                                      color: visual.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SECCIÓN 1: MODO DE ESCRITURA
                      const AutomationSectionLabel('Modo de Atención Personal'),
                      SettingsCard(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Cómo escribe Nano por ti',
                                        style: TextStyle(
                                          color: visual.text,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: Text(
                                        isSupervised ? 'BORRADOR' : 'AUTÓNOMO',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isSupervised
                                      ? '✏️ Modo borrador: Nano redacta la respuesta con tu estilo y te la muestra para revisar antes de enviar. Tú tienes la última palabra.'
                                      : '⚡ Modo autónomo: Nano detecta el mensaje, lo analiza y responde directamente con tu identidad y tono. Sin pasos extra.',
                                  style: TextStyle(
                                    color: visual.textMuted,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment<bool>(
                                      value: true,
                                      icon: Icon(Icons.shield_outlined, size: 16),
                                      label: Text(
                                        'Supervisado',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    ButtonSegment<bool>(
                                      value: false,
                                      icon: Icon(Icons.bolt_rounded, size: 16),
                                      label: Text(
                                        'Autónomo',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                  selected: {isSupervised},
                                  onSelectionChanged: (selected) {
                                    final supervised = selected.first;
                                    settingsNotifier.setAgentAutomationMode(
                                      supervised
                                          ? AgentAutomationMode.assisted
                                          : AgentAutomationMode.autonomous,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECCIÓN 2: IDENTIDAD PERSONAL
                      const AutomationSectionLabel('Mi Identidad y Preferencias'),
                      SettingsCard(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_loading) const LinearProgressIndicator(),
                                if (_error != null) ...[
                                  Text(
                                    _error!,
                                    style: TextStyle(color: visual.textMuted),
                                  ),
                                  TextButton(
                                    onPressed: _loadProfile,
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                                TextField(
                                  controller: _nameController,
                                  enabled: !_loading && !_saving && _error == null,
                                  maxLength: 80,
                                  decoration: InputDecoration(
                                    labelText: 'Tu nombre',
                                    hintText: 'Ej. Emmanuel',
                                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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
                                    hintText:
                                        'Ej. Trabajo en desarrollo móvil. Respuestas cordiales, sin rodeos.',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    isDense: true,
                                  ),
                                  style: TextStyle(color: visual.text, fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: _loading || _saving || _error != null
                                      ? null
                                      : _saveProfile,
                                  icon: const Icon(Icons.check_rounded, size: 18),
                                  label: Text(
                                    _saving ? 'Guardando…' : 'Guardar identidad',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECCIÓN 3: TRATO Y EXPRESIÓN PERSONAL
                      const AutomationSectionLabel('Trato y Estilo de Expresión'),
                      SettingsCard(
                        children: [
                          SettingsRow(
                            imageAsset: 'assets/automation/icons/icon_respuestas_wpp.png',
                            title: 'Estilo automático de respuestas',
                            subtitle: tone.enabled
                                ? 'Activo: guía la calidez, extensión y emojis'
                                : 'Inactivo: respuestas estándar',
                            trailing: Switch(
                              value: tone.enabled,
                              onChanged: (v) =>
                                  toneNotifier.update(tone.copyWith(enabled: v)),
                            ),
                            showChevron: false,
                          ),
                          if (tone.enabled) ...[
                            SettingsRow(
                              imageAsset: 'assets/automation/icons/icon_trato_cliente.png',
                              title: 'Trato y calidez',
                              subtitle: tone.warmth == ToneWarmth.cercano
                                  ? 'Cercano: tuteo amistoso y cercano'
                                  : 'Formal: trato respetuoso de usted',
                              trailing: ValueBadge(
                                label: tone.warmth == ToneWarmth.cercano
                                    ? 'CERCANO'
                                    : 'FORMAL',
                              ),
                              onTap: () => toneNotifier.update(
                                tone.copyWith(
                                  warmth: tone.warmth == ToneWarmth.cercano
                                      ? ToneWarmth.formal
                                      : ToneWarmth.cercano,
                                ),
                              ),
                            ),
                            SettingsRow(
                              imageAsset: 'assets/automation/icons/icon_extension.png',
                              title: 'Extensión de mensajes',
                              subtitle: switch (tone.verbosity) {
                                ToneVerbosity.breve =>
                                  'Breve: respuestas directas y al grano',
                                ToneVerbosity.media =>
                                  'Media: balance de detalle y concisión',
                                ToneVerbosity.extensa =>
                                  'Extensa: explicaciones completas y detalladas',
                              },
                              trailing: ValueBadge(
                                label: tone.verbosity.name.toUpperCase(),
                              ),
                              onTap: () {
                                final next = ToneVerbosity.values[
                                    (tone.verbosity.index + 1) %
                                        ToneVerbosity.values.length];
                                toneNotifier.update(tone.copyWith(verbosity: next));
                              },
                            ),
                            SettingsRow(
                              imageAsset: 'assets/automation/icons/icon_emoji.png',
                              title: 'Uso de emojis',
                              subtitle: tone.emojis
                                  ? 'Con moderación en mensajes casuales'
                                  : 'Sin emojis, puramente textual',
                              trailing: Switch(
                                value: tone.emojis,
                                onChanged: (v) =>
                                    toneNotifier.update(tone.copyWith(emojis: v)),
                              ),
                              showChevron: false,
                            ),
                          ],
                          // Acceso rápido al estilo avanzado del dueño
                          SettingsRow(
                            imageAsset:
                                'assets/automation/icons/icon_trato_cliente.png',
                            title: 'Estilo avanzado del dueño',
                            subtitle:
                                'Registro, slang, uso de nombre, preferencias de forma y tono por contacto',
                            trailing: const ValueBadge(label: 'CONFIGURAR'),
                            onTap: () => Navigator.of(context).push(
                              nanoGlassPageRoute<void>(
                                builder: (_) =>
                                    const PersonalizationStudioScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECCIÓN 4: HORARIOS Y DISPONIBILIDAD PERSONAL
                      const AutomationSectionLabel('Horarios Personales'),
                      const SettingsCard(
                        children: [
                          SettingsRow(
                            imageAsset: 'assets/automation/icons/icon_horarios.png',
                            title: 'Disponibilidad personal',
                            subtitle:
                                'El agente personal atiende las 24 horas respetando tu modo de supervisión.',
                            trailing: ValueBadge(label: '24/7 ACTIVO'),
                            showChevron: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECCIÓN 5: APRENDIZAJE Y MEMORIA
                      const AutomationSectionLabel('Aprendizaje y Memoria'),
                      SettingsCard(
                        children: [
                          SettingsRow(
                            imageAsset: 'assets/automation/icons/icon_reglas.png',
                            title: 'Aprender de mis conversaciones',
                            subtitle:
                                'Importa tus chats de WhatsApp para que Nano aprenda tu forma real de hablar.',
                            trailing: const ValueBadge(label: 'EXPLORAR'),
                            onTap: () => Navigator.of(context).push(
                              nanoGlassPageRoute<void>(
                                builder: (_) =>
                                    const PersonalizationStudioScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
