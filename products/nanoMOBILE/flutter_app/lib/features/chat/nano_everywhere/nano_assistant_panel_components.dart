library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'nano_ai_models.dart';

/// Tarjetas de respuestas en cristal líquido translúcido con alto contraste.
class NanoAssistantAnswersView extends StatelessWidget {
  const NanoAssistantAnswersView({
    super.key,
    required this.answers,
    this.onSpeak,
  });
  final List<NanoAnswer> answers;
  final ValueChanged<String>? onSpeak;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final answer in answers)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .65),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 0.9,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                answer.ok
                    ? answer.text
                    : 'No pude generar una respuesta. Revisa la conexión e inténtalo de nuevo.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13.5,
                  height: 1.48,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onSpeak != null && answer.ok)
                    IconButton(
                      tooltip: 'Leer o detener respuesta',
                      onPressed: () => onSpeak!(answer.text),
                      icon: const Icon(Icons.volume_up_outlined, size: 18),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Copiar',
                    icon: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: !answer.ok
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: answer.text));
                            HapticFeedback.lightImpact();
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
    ],
  );
}
