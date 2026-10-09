// messaging_filter_chips.dart
//
// QUÉ HACE:
// Barra de pestañas de filtrado por categoría (Todos, No leídos, Grupos, Contactos, etc.)
// con estética iOS Frosted Glass, micro-bordes metálicos y badges reactivos.
//
// CÓMO FUNCIONA:
// - Despliega pestañas horizontales compactas con animación suave al cambiar de filtro.
// - Conecta con selectedCategoryTabProvider para filtrar conversaciones en tiempo real.
//
// POR QUÉ:
// Provee una segmentación rápida y táctil del hub con estilo Apple Liquid Glass (< 160 líneas).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/whatsapp_contacts_provider.dart';
import '../../domain/messaging_platform.dart';
import 'messaging_center_providers.dart';

class MessagingFilterChips extends ConsumerWidget {
  const MessagingFilterChips({super.key});

  static const _tabOrder = [
    MessagingCategoryFilter.all,
    MessagingCategoryFilter.unread,
    MessagingCategoryFilter.groups,
    MessagingCategoryFilter.contacts,
    MessagingCategoryFilter.personal,
    MessagingCategoryFilter.business,
    MessagingCategoryFilter.archived,
  ];

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

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _tabOrder.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final tab = _tabOrder[index];
          final isSelected = activeTab == tab;
          final badgeCount = switch (tab) {
            MessagingCategoryFilter.unread => totalUnread,
            MessagingCategoryFilter.contacts => contactsCount,
            MessagingCategoryFilter.archived => archivedCount,
            _ => 0,
          };

          final borderGradient = isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFFFFFFFF).withValues(alpha: 0.90),
                          const Color(0xFF38BDF8).withValues(alpha: 0.60),
                          const Color(0xFF818CF8).withValues(alpha: 0.45),
                          const Color(0xFFFFFFFF).withValues(alpha: 0.20),
                        ]
                      : [
                          const Color(0xFFFFFFFF).withValues(alpha: 0.84),
                          const Color(0xFF38BDF8).withValues(alpha: 0.75),
                          const Color(0xFF94A3B8),
                        ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: 0.24),
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.03),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.72),
                          Colors.white.withValues(alpha: 0.34),
                          const Color(0xFFCBD5E1).withValues(alpha: 0.42),
                        ],
                );

          final bgGradient = isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF334155).withValues(alpha: 0.85),
                          const Color(0xFF1E293B).withValues(alpha: 0.90),
                          const Color(0xFF0F172A).withValues(alpha: 0.95),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.70),
                          const Color(0xFFF1F5F9).withValues(alpha: 0.46),
                        ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF1E293B).withValues(alpha: 0.50),
                          const Color(0xFF0F172A).withValues(alpha: 0.60),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.42),
                          const Color(0xFFF8FAFC).withValues(alpha: 0.24),
                        ],
                );

          final textColor = isSelected
              ? (isDark ? Colors.white : const Color(0xFF0F172A))
              : (isDark ? Colors.white70 : const Color(0xFF475569));

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(selectedCategoryTabProvider.notifier).state = tab;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                gradient: borderGradient,
                boxShadow: [
                  if (isSelected) ...[
                    BoxShadow(
                      color: const Color(
                        0xFF38BDF8,
                      ).withValues(alpha: isDark ? 0.25 : 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 1.5),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.30 : 0.05,
                      ),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ] else ...[
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.15 : 0.02,
                      ),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ],
              ),
              padding: EdgeInsets.all(isSelected ? 1.2 : 0.9),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: bgGradient,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (badgeCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                    ? const Color(
                                        0xFF38BDF8,
                                      ).withValues(alpha: 0.35)
                                    : const Color(
                                        0xFF0284C7,
                                      ).withValues(alpha: 0.15))
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$badgeCount',
                          style: TextStyle(
                            color: isSelected
                                ? (isDark
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF0369A1))
                                : (isDark
                                      ? Colors.white70
                                      : const Color(0xFF334155)),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
