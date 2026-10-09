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
    final isDark = theme.brightness == Brightness.dark;
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
            size: 15,
            color: isSelected
                ? Colors.white
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
          ),
          label: Text(
            skill.name,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : colorScheme.onSurface,
              fontFamily: 'Inter',
            ),
          ),
          selectedColor: colorScheme.primary,
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          checkmarkColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? colorScheme.primary
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.07)),
              width: 1,
            ),
          ),
          onSelected: (_) => _toggle(skill.id),
        );
      }).toList(),
    );
  }
}
