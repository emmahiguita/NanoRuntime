// ai_preferred_provider_selector.dart — Selector horizontal de IA preferida para el router.
// QUÉ HACE: Permite elegir el modelo web por defecto (Automático, ChatGPT, DeepSeek, Gemini, Kimi, etc.).
// CÓMO FUNCIONA: Muestra una fila de ChoiceChips horizontales estilizados con Material 3 Expressive.
// POR QUÉ: Permite al usuario dirigir consultas de programación a Qwen, de investigación a Kimi, etc.
library;

import 'package:flutter/material.dart';

class AiPreferredProviderSelector extends StatelessWidget {
  final String preferred;
  final ValueChanged<String> onSelect;

  const AiPreferredProviderSelector({
    super.key,
    required this.preferred,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const options = [
      ('auto', '● Automático'),
      ('deepseek', 'DeepSeek'),
      ('chatgpt', 'ChatGPT'),
      ('gemini', 'Gemini'),
      ('kimi', 'Kimi'),
      ('qwen', 'Qwen'),
      ('claude', 'Claude'),
      ('perplexity', 'Perplexity'),
      ('copilot', 'Copilot'),
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final (id, label) = options[i];
          final isSelected = preferred == id;
          return ChoiceChip(
            label: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            selectedColor: const Color(0xFF10B981).withValues(alpha: 0.25),
            onSelected: (_) => onSelect(id),
          );
        },
      ),
    );
  }
}
