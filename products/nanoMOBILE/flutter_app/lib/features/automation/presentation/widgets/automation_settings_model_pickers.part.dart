part of 'automation_settings_pickers.dart';

Future<void> _pickSpecificModelImpl(BuildContext context, WidgetRef ref) async {
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

  await showNanoGlassWindow<void>(
    context: context,
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
                  subtitle: Text('${m.id} · ${m.sizeGb.toStringAsFixed(1)} GB'),
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

Future<void> _pickResponseToneImpl(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(toneProfileNotifierProvider.notifier);
  await showNanoGlassWindow<void>(
    context: context,
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
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
