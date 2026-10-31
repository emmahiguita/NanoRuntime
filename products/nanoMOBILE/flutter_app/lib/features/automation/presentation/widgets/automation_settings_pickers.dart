import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile_providers.dart';
import 'package:nanoai/features/automation/engine/model/automation_model.dart';
import 'package:nanoai/features/models/application/models_provider.dart';
import 'package:nanoai/features/models/domain/local_model.dart';
import '../automation_visual_theme.dart';

part 'automation_settings_model_pickers.part.dart';

/// Funciones auxiliares y modales para la selecciÃ³n de parÃ¡metros del agente.
abstract class AutomationSettingsPickers {
  static String modelModeLabel(AutomationModelMode mode) => switch (mode) {
    AutomationModelMode.sameAsChat => 'Mismo que Chat',
    AutomationModelMode.specificModel => 'Modelo dedicado',
    AutomationModelMode.deterministicOnly => 'Solo determinista',
  };

  static String modelModeDescription(
    AutomationModelMode mode,
  ) => switch (mode) {
    AutomationModelMode.sameAsChat =>
      'Comparte el modelo local actualmente seleccionado en Chat.',
    AutomationModelMode.specificModel =>
      'Usa el modelo configurado exclusivamente para AutomatizaciÃ³n.',
    AutomationModelMode.deterministicOnly =>
      'No invoca un modelo; ejecuta Ãºnicamente rutas verificables conocidas.',
  };

  static Future<void> pickMode(BuildContext context, WidgetRef ref) async {
    final selected = ref.read(settingsProvider).agentAutomationMode;
    final value = await showNanoGlassWindow<AgentAutomationMode>(
      context: context,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Modo de automatizaciÃ³n',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final mode in AgentAutomationMode.values)
                  ListTile(
                    leading: Icon(
                      mode == selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: mode == selected
                          ? AutomationVisual.of(context).accent
                          : AutomationVisual.of(context).textMuted,
                    ),
                    title: Text(mode.label),
                    subtitle: Text(mode.description),
                    onTap: () => Navigator.of(context).pop(mode),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (value != null) {
      ref.read(settingsProvider.notifier).setAgentAutomationMode(value);
    }
  }

  static Future<void> pickAutomationModelMode(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final selected = ref.read(settingsProvider).automationModelMode;
    final value = await showNanoGlassWindow<AutomationModelMode>(
      context: context,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Motor de razonamiento',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final mode in AutomationModelMode.values)
                  ListTile(
                    leading: Icon(
                      mode == selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: mode == selected
                          ? AutomationVisual.of(context).accent
                          : AutomationVisual.of(context).textMuted,
                    ),
                    title: Text(modelModeLabel(mode)),
                    subtitle: Text(modelModeDescription(mode)),
                    onTap: () => Navigator.of(context).pop(mode),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (value != null) {
      ref.read(settingsProvider.notifier).setAutomationModelMode(value);
      if (value == AutomationModelMode.specificModel && context.mounted) {
        await pickSpecificModel(context, ref);
      }
    }
  }

  static Future<void> pickSpecificModel(BuildContext context, WidgetRef ref) =>
      _pickSpecificModelImpl(context, ref);

  static Future<void> pickResponseTone(BuildContext context, WidgetRef ref) =>
      _pickResponseToneImpl(context, ref);
}
