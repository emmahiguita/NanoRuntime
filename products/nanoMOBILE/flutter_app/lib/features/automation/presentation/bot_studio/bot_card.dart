import 'package:flutter/material.dart';
import '../../domain/bot/bot_definition.dart';
import '../../domain/bot/bot_role.dart';
import '../../application/bot/bot_skills_catalog.dart';

/// Tarjeta compacta estilo iOS Frosted Glass para gestión de agentes.
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark
                ? (bot.enabled
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.50)
                    : colorScheme.surfaceContainerLow.withValues(alpha: 0.35))
                : Colors.white.withValues(alpha: 0.85),
            isDark
                ? (bot.enabled
                    ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.30)
                    : colorScheme.surfaceContainerLowest.withValues(alpha: 0.20))
                : Colors.white.withValues(alpha: 0.60),
          ],
        ),
        border: Border.all(
          color: bot.enabled
              ? colorScheme.primary.withValues(alpha: 0.40)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05)),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: bot.enabled
                ? colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.04)
                : Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        bot.enabled
                            ? colorScheme.primary.withValues(alpha: 0.22)
                            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.40),
                        bot.enabled
                            ? colorScheme.primary.withValues(alpha: 0.06)
                            : colorScheme.surfaceContainerLowest.withValues(alpha: 0.15),
                      ],
                    ),
                    border: Border.all(
                      color: bot.enabled
                          ? colorScheme.primary.withValues(alpha: 0.40)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.06)),
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _roleIcon(bot.role),
                      size: 16,
                      color: bot.enabled
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bot.name,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1.5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              bot.role.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "• ${bot.tone.warmth.name}",
                            style: TextStyle(
                              fontSize: 10.5,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.78,
                  child: Switch.adaptive(
                    value: bot.enabled,
                    onChanged: onToggleEnabled,
                  ),
                ),
              ],
            ),
            if (bot.description.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                bot.description,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: bot.skillIds.map((id) {
                final skill = BotSkillsCatalog.getSkill(id);
                final name = skill?.name ?? id;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.03),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colorScheme.onSurface.withValues(alpha: 0.80),
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onDelete != null && bot.role != BotRole.personal)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: colorScheme.error.withValues(alpha: 0.80),
                    tooltip: 'Eliminar bot',
                    onPressed: onDelete,
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded, size: 12, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Configurar',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
