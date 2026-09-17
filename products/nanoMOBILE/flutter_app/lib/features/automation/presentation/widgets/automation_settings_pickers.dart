import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/settings_provider.dart';
import 'package:nanoai/features/automation/domain/automation_policy.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile.dart';
import 'package:nanoai/features/automation/engine/messaging/tone_profile_providers.dart';
import 'package:nanoai/features/automation/engine/model/automation_model.dart';
import 'package:nanoai/features/models/application/models_provider.dart';
import 'package:nanoai/features/models/domain/local_model.dart';
import '../automation_visual_theme.dart';

/// Funciones auxiliares y modales para la selección de parámetros del agente.
abstract class AutomationSettingsPickers {
  static String modelModeLabel(AutomationModelMode mode) => switch (mode) {
    AutomationModelMode.sameAsChat => 'Mismo que Chat',
    AutomationModelMode.specificModel => 'Modelo dedicado',
    AutomationModelMode.deterministicOnly => 'Solo determinista',
  };

  static String modelModeDescription(AutomationModelMode mode) => switch (mode) {
    AutomationModelMode.sameAsChat =>
      'Comparte el modelo local actualmente seleccionado en Chat.',
    AutomationModelMode.specificModel =>
      'Usa el modelo configurado exclusivamente para Automatización.',
    AutomationModelMode.deterministicOnly =>
      'No invoca un modelo; ejecuta únicamente rutas verificables conocidas.',
  };

  static Future<void> pickMode(BuildContext context, WidgetRef ref) async {
    final selected = ref.read(settingsProvider).agentAutomationMode;
    final value = await showModalBottomSheet<AgentAutomationMode>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
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
                  'Modo de automatización',
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
    final value = await showModalBottomSheet<AutomationModelMode>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
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

  static Future<void> pickSpecificModel(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final modelsState = ref.read(modelsProvider);
    final installed = modelsState.models
        .where(
          (m) =>
              m.downloadState == ModelDownloadState.installed &&
              m.localPath != null &&
              m.localPath!.isNotEmpty,
        )
        .toList();
    final detected = modelsState.detected;

    if (installed.isEmpty && detected.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay modelos GGUF instalados o detectados. Descarga uno desde la sección Modelos.',
          ),
        ),
      );
      return;
    }

    final currentId = ref.read(settingsProvider).automationModelId;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seleccionar modelo dedicado',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige el modelo local para redactar respuestas de automatización:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AutomationVisual.of(sheetContext).textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                for (final m in installed)
                  ListTile(
                    leading: Icon(
                      m.id == currentId
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: m.id == currentId
                          ? AutomationVisual.of(sheetContext).accent
                          : AutomationVisual.of(sheetContext).textMuted,
                    ),
                    title: Text(m.name),
                    subtitle: Text(
                      '${m.id} · ${m.sizeGb.toStringAsFixed(1)} GB',
                    ),
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .setAutomationModel(m.id, m.localPath!);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                for (final d in detected)
                  ListTile(
                    leading: Icon(
                      d.name == currentId
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: d.name == currentId
                          ? AutomationVisual.of(sheetContext).accent
                          : AutomationVisual.of(sheetContext).textMuted,
                    ),
                    title: Text(d.name),
                    subtitle: Text(d.path ?? ''),
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .setAutomationModel(d.name, d.path ?? '');
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> pickResponseTone(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final notifier = ref.read(toneProfileNotifierProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Consumer(
              builder: (ctx, ref, _) {
                final current = ref.watch(toneProfileNotifierProvider);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tono de respuesta',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Activar tono personalizado'),
                      subtitle: const Text(
                        'Guía la cercanía y extensión en los mensajes automáticos',
                      ),
                      value: current.enabled,
                      onChanged: (v) =>
                          notifier.update(current.copyWith(enabled: v)),
                    ),
                    if (current.enabled) ...[
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text(
                          'Trato',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      RadioGroup<ToneWarmth>(
                        groupValue: current.warmth,
                        onChanged: (v) {
                          if (v != null) {
                            notifier.update(current.copyWith(warmth: v));
                          }
                        },
                        child: Column(
                          children: [
                            for (final warmth in ToneWarmth.values)
                              RadioListTile<ToneWarmth>(
                                title: Text(
                                  warmth == ToneWarmth.cercano
                                      ? 'Cercano'
                                      : 'Formal',
                                ),
                                value: warmth,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
