import 'package:flutter/material.dart';
import '../../domain/bot/bot_definition.dart';
import '../../domain/bot/bot_role.dart';
import '../../application/bot/bot_skills_catalog.dart';

/// QUÉ HACE:
/// Tarjeta visual que presenta un bot con su identidad, rol, skills y estado.
///
/// CÓMO FUNCIONA:
/// Muestra un avatar temático, chips compactos de las herramientas asignadas
/// y controles para activar/desactivar, editar o eliminar el bot.
///
/// POR QUÉ:
/// Ofrece una vista clara y profesional del estado de cada agente en NanoAI.
class BotCard extends StatelessWidget {
  final BotDefinition bot;
  final VoidCallback onEdit;
  final ValueChanged<bool>? onToggleEnabled;
  final VoidCallback? onDelete;

  const BotCard({
    super.key,
    required this.bot,
    required this.onEdit,
    this.onToggleEnabled,
    this.onDelete,
  });

  IconData _roleIcon(BotRole role) {
    return switch (role) {
      BotRole.personal => Icons.person_rounded,
      BotRole.sales => Icons.storefront_rounded,
      BotRole.support => Icons.support_agent_rounded,
      BotRole.assistant => Icons.smart_toy_rounded,
      BotRole.custom => Icons.auto_awesome_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: bot.enabled
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: bot.enabled
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  foregroundColor: bot.enabled
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  child: Icon(_roleIcon(bot.role), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bot.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${bot.role.label} • ${bot.tone.warmth.name}",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: bot.enabled,
                  onChanged: onToggleEnabled,
                ),
              ],
            ),
            if (bot.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                bot.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: bot.skillIds.map((id) {
                final skill = BotSkillsCatalog.getSkill(id);
                final name = skill?.name ?? id;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    name,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onDelete != null && bot.role != BotRole.personal)
                  Semantics(
                    label: 'Eliminar bot',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: colorScheme.error,
                      onPressed: onDelete,
                    ),
                  ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Configurar'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onEdit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
