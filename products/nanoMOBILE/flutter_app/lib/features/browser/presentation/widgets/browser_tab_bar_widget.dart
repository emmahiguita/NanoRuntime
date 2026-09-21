import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';

/// Compact tab strip. The visual overview is optional and never owns WebViews.
class BrowserTabBarWidget extends ConsumerWidget {
  const BrowserTabBarWidget({super.key, this.onOpenCarousel});

  final VoidCallback? onOpenCarousel;

  static IconData getBrandIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube')) return Icons.play_arrow_rounded;
    if (lower.contains('facebook') || lower.contains('fb.com')) {
      return Icons.people_alt_rounded;
    }
    if (lower.contains('google')) return Icons.search_rounded;
    if (lower.contains('deepseek')) return Icons.auto_awesome_rounded;
    if (lower.contains('chatgpt') || lower.contains('openai')) {
      return Icons.smart_toy_rounded;
    }
    if (lower.contains('github')) return Icons.code_rounded;
    if (lower.contains('reddit')) return Icons.forum_rounded;
    return Icons.language_rounded;
  }

  static Color getBrandColor(String url, bool isDark) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube')) return const Color(0xFFFF3B30);
    if (lower.contains('facebook') || lower.contains('fb.com')) {
      return const Color(0xFF1877F2);
    }
    if (lower.contains('google')) return const Color(0xFF4285F4);
    if (lower.contains('deepseek')) return const Color(0xFF3B82F6);
    if (lower.contains('chatgpt') || lower.contains('openai')) {
      return const Color(0xFF10A37F);
    }
    if (lower.contains('reddit')) return const Color(0xFFFF4500);
    return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(browserTabProvider);
    final notifier = ref.read(browserTabProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : const Color(0xFF172033);
    final muted = isDark ? Colors.white54 : const Color(0xFF64748B);

    return Container(
      height: 44,
      padding: const EdgeInsets.fromLTRB(8, 5, 7, 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C1623) : const Color(0xFFF0F4F8),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFDDE4ED),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: state.tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final tab = state.tabs[index];
                final active = tab.id == state.activeTabId;
                final brand = getBrandColor(tab.url, isDark);
                return Semantics(
                  button: true,
                  selected: active,
                  label: 'Pestaña ${tab.title}',
                  child: Material(
                    color: active
                        ? (isDark ? const Color(0xFF18263A) : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        notifier.selectTab(tab.id);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        constraints: const BoxConstraints(
                          minWidth: 96,
                          maxWidth: 154,
                        ),
                        padding: const EdgeInsets.only(left: 9, right: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active
                                ? brand.withValues(alpha: 0.65)
                                : (isDark
                                      ? Colors.white10
                                      : const Color(0xFFDDE4ED)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(getBrandIcon(tab.url), size: 14, color: brand),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                tab.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: active ? text : muted,
                                  fontSize: 11.5,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            InkResponse(
                              onTap: () => notifier.closeTab(tab.id),
                              radius: 14,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 13,
                                  color: muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          _StripAction(
            tooltip: 'Nueva pestaña',
            icon: Icons.add_rounded,
            isDark: isDark,
            onTap: () {
              HapticFeedback.mediumImpact();
              notifier.addTab();
            },
          ),
          if (onOpenCarousel != null) ...[
            const SizedBox(width: 4),
            _StripAction(
              tooltip: 'Vista 3D de pestañas',
              icon: Icons.view_carousel_outlined,
              isDark: isDark,
              onTap: onOpenCarousel!,
            ),
          ],
        ],
      ),
    );
  }
}

class _StripAction extends StatelessWidget {
  const _StripAction({
    required this.tooltip,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      child: Material(
        color: isDark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icon,
              size: 18,
              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
            ),
          ),
        ),
      ),
    );
  }
}
