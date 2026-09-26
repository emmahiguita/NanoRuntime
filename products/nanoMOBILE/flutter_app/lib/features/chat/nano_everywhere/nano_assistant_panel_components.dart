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
        // Solo expone acciones reales del panel; comparación y debate ya no son rutas de producto.
        for (final mode in const [
          NanoMode.quick,
          NanoMode.action,
          NanoMode.media,
        ])
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(switch (mode) {
                NanoMode.quick => 'Conversar',
                NanoMode.action => 'Acciones',
                NanoMode.media => 'Multimedia',
                _ => 'Conversar',
              }),
              selected: mode == currentMode,
              onSelected: enabled ? (_) => onSelect(mode) : null,
            ),
          ),
      ],
    ),
  );
}

/// Presenta el texto sin exponer proveedor, ronda ni debate interno.
class NanoAssistantAnswersView extends StatelessWidget {
  const NanoAssistantAnswersView({super.key, required this.answers});
  final List<NanoAnswer> answers;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final answer in answers)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              answer.ok
                  ? answer.text
                  : 'No pude generar una respuesta. Revisa la conexión e inténtalo de nuevo.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
    ],
  );
}
