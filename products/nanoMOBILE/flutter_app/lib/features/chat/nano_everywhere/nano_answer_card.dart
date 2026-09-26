// nano_answer_card.dart — Tarjeta de respuesta generada para el panel Nano.
// QUÉ: Renderiza la respuesta individual con lenguaje visible para la persona.
// CÓMO: Card.filled conserva el texto y presenta un error claro sin exponer rutas internas.
// POR QUÉ: SOLID-S: extrae la presentación de respuestas fuera del panel principal,
//          manteniendo ambos componentes por debajo de 200 líneas.
import 'package:flutter/material.dart';
import 'nano_ai_models.dart';

class NanoAnswerCard extends StatelessWidget {
  const NanoAnswerCard({super.key, required this.answer});

  final NanoAnswer answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = answer.error;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                answer.ok
                    ? answer.text
                    : 'No pude generar una respuesta. Revisa la conexión e inténtalo de nuevo.',
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: error != null
                    ? theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
