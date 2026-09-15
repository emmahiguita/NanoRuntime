import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';

class BrowserTabBarWidget extends ConsumerWidget {
  const BrowserTabBarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabState = ref.watch(browserTabProvider);
    final notifier = ref.read(browserTabProvider.notifier);
    final colors = NanoThemeExtension.of(context).colors;
    final isDark = colors is NanoDarkColors;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF09121F) : const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: tabState.tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final tab = tabState.tabs[index];
                final isActive = tab.id == tabState.activeTabId;

                return InkWell(
                  onTap: () => notifier.selectTab(tab.id),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    constraints: const BoxConstraints(maxWidth: 150, minWidth: 95),
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isDark ? const Color(0xFF10263B) : Colors.white)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? (isDark ? const Color(0xFF10B981) : const Color(0xFF2563EB))
                            : Colors.transparent,
                        width: isActive ? 1.2 : 0.0,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: (isDark ? const Color(0xFF10B981) : const Color(0xFF2563EB))
                                    .withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tab.isSecure ? Icons.lock_outline_rounded : Icons.language_rounded,
                          size: 13,
                          color: isActive
                              ? (isDark ? const Color(0xFF10B981) : const Color(0xFF2563EB))
                              : colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tab.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                              color: isActive ? colors.textPrimary : colors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => notifier.closeTab(tab.id),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? colors.textSecondary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: isActive ? colors.textPrimary : colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => notifier.addTab(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF10B981).withValues(alpha: 0.18)
                      : const Color(0xFF2563EB).withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
