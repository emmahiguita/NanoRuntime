import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../application/whatsapp_contacts_provider.dart';
import '../../domain/messaging_platform.dart';
import 'messaging_center_providers.dart';

/// Pestañas de categoría (Todos, No leídos, Personales, Negocios, Contactos, etc.).
class MessagingFilterChips extends ConsumerWidget {
  const MessagingFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(selectedCategoryTabProvider);
    final totalUnread = ref.watch(pendingRepliesCountProvider);
    final archivedCount =
        ref.watch(categoryCountsProvider)[MessagingCategoryFilter.archived] ??
        0;
    final contactsCount =
        ref.watch(allWhatsAppContactsProvider).value?.length ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = NanoThemeExtension.of(context).colors;
    final accentColor = isDark ? const Color(0xFF00FF88) : colors.primary;

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: MessagingCategoryFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final tab = MessagingCategoryFilter.values[index];
          final isSelected = activeTab == tab;
          final badgeCount = switch (tab) {
            MessagingCategoryFilter.unread => totalUnread,
            MessagingCategoryFilter.contacts => contactsCount,
            MessagingCategoryFilter.archived => archivedCount,
            _ => 0,
          };

          return GestureDetector(
            onTap: () {
              ref.read(selectedCategoryTabProvider.notifier).state = tab;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? null
                    : (isDark ? null : Colors.white),
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? const [Color(0x3800FF88), Color(0x1F00FF88)]
                            : [
                                accentColor.withValues(alpha: 0.15),
                                accentColor.withValues(alpha: 0.08),
                              ],
                      )
                    : (isDark
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1E293B).withValues(alpha: 0.35),
                              const Color(0xFF0F172A).withValues(alpha: 0.20),
                            ],
                          )
                        : null),
                borderRadius: BorderRadius.circular(10),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(
                            alpha: isDark ? 0.25 : 0.15,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : (!isDark
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null),
                border: Border.all(
                  color: isSelected
                      ? accentColor.withValues(alpha: isDark ? 0.70 : 0.60)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : colors.outline),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tab.label,
                    style: TextStyle(
                      color: isSelected
                          ? accentColor
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.75)
                              : colors.onSurfaceVariant),
                      fontSize: 10.5,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: TextStyle(
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white : colors.onSurface),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
