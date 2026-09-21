import 'package:flutter/material.dart';
import '../../application/bot/bot_skills_catalog.dart';

/// QUÉ HACE:
/// Selector interactivo de habilidades (Skills) para asignar a un bot.
///
/// CÓMO FUNCIONA:
/// Itera sobre [BotSkillsCatalog.allSkills] y renderiza chips con ícono,
/// nombre y estado de selección, notificando a través de [onChanged].
///
/// POR QUÉ:
/// Ofrece una experiencia visual clara para componer las capacidades de cada
/// bot sin requerir configuración manual de comandos técnicos.
class BotSkillsSelector extends StatelessWidget {
  final List<String> selectedSkillIds;
  final ValueChanged<List<String>> onChanged;

  const BotSkillsSelector({
    super.key,
    required this.selectedSkillIds,
    required this.onChanged,
  });

  IconData _iconForCategory(String category) {
    return switch (category) {
      'system' => Icons.terminal_rounded,
      'web' => Icons.language_rounded,
      'messaging' => Icons.chat_bubble_outline_rounded,
      'device' => Icons.touch_app_rounded,
      'commerce' => Icons.storefront_rounded,
      'memory' => Icons.psychology_rounded,
      'productivity' => Icons.event_note_rounded,
      _ => Icons.extension_rounded,
    };
  }

  void _toggle(String skillId) {
    final updated = List<String>.from(selectedSkillIds);
    if (updated.contains(skillId)) {
      updated.remove(skillId);
    } else {
      updated.add(skillId);
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const allSkills = BotSkillsCatalog.allSkills;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allSkills.map((skill) {
        final isSelected = selectedSkillIds.contains(skill.id);
        return FilterChip(
          selected: isSelected,
          avatar: Icon(
            _iconForCategory(skill.category),
            size: 16,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
          label: Text(
            skill.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
          ),
          selectedColor: colorScheme.primary,
          backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          checkmarkColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          onSelected: (_) => _toggle(skill.id),
        );
      }).toList(),
    );
  }
}
