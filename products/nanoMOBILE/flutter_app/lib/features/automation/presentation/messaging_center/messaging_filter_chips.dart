import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final contactsCount = ref.watch(allWhatsAppContactsProvider).value?.length ?? 0;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: MessagingCategoryFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = MessagingCategoryFilter.values[index];
          final isSelected = activeTab == tab;

          return GestureDetector(
            onTap: () {
              ref.read(selectedCategoryTabProvider.notifier).state = tab;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x3800FF88), Color(0x1F00FF88)],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1E293B).withValues(alpha: 0.35),
                          const Color(0xFF0F172A).withValues(alpha: 0.20),
                        ],
                      ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00FF88).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF00FF88).withValues(alpha: 0.70)
                      : Colors.white.withValues(alpha: 0.12),
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
                          ? const Color(0xFF00FF88)
                          : Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (tab == MessagingCategoryFilter.unread && totalUnread > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF88),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalUnread',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  if (tab == MessagingCategoryFilter.contacts && contactsCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00FF88)
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$contactsCount',
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
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
