import 'package:flutter/material.dart';
import 'nano_ai_models.dart';

/// Modos excluyentes con semántica Material; evita otra animación ornamental.
class NanoAssistantModeBar extends StatelessWidget {
  const NanoAssistantModeBar({
    super.key,
    required this.currentMode,
    required this.onSelect,
    this.enabled = true,
  });
  final NanoMode currentMode;
  final ValueChanged<NanoMode> onSelect;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final mode in NanoMode.values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(switch (mode) {
                NanoMode.quick => 'Web AI',
                NanoMode.action => 'Automatizar',
                NanoMode.compare => 'Comparar',
                NanoMode.media => 'Media',
                NanoMode.debate => 'Debate',
              }),
              selected: mode == currentMode,
              onSelected: enabled ? (_) => onSelect(mode) : null,
            ),
          ),
      ],
    ),
  );
}

/// Las respuestas comparten el scroll del panel: sin listas anidadas diminutas.
class NanoAssistantAnswersView extends StatelessWidget {
  const NanoAssistantAnswersView({super.key, required this.answers});
  final List<NanoAnswer> answers;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: answers
        .map(
          (answer) => Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(answer.provider.name, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  SelectableText(
                    answer.error ?? answer.text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        )
        .toList(),
  );
}
