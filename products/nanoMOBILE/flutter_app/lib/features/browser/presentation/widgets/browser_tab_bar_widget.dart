import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/browser/application/browser_tab_notifier.dart';

/// Franja horizontal de pestañas estilo cápsulas iOS con acabado frosted glass.
/// 
/// - QUÉ HACE: Muestra la lista horizontal de pestañas con favicons, títulos y cierre.
/// - CÓMO FUNCIONA: Observa [browserTabProvider] y despacha selección y cierre con hápticos.
/// - POR QUÉ: Ofrece conmutación instantánea entre páginas web activas (<200 líneas).
class BrowserTabBarWidget extends ConsumerWidget {
  final VoidCallback? onOpenCarousel;
  const BrowserTabBarWidget({super.key, this.onOpenCarousel});

  static IconData getBrandIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube')) return CupertinoIcons.play_circle_fill;
    if (lower.contains('facebook') || lower.contains('fb.com')) return CupertinoIcons.person_2_fill;
    if (lower.contains('google')) return CupertinoIcons.search;
    if (lower.contains('deepseek')) return CupertinoIcons.sparkles;
    if (lower.contains('chatgpt') || lower.contains('openai')) return CupertinoIcons.chat_bubble_2_fill;
    if (lower.contains('github')) return CupertinoIcons.chevron_left_slash_chevron_right;
    if (lower.contains('reddit')) return CupertinoIcons.bubble_left_bubble_right_fill;
    return CupertinoIcons.globe;
  }

  static Color getBrandColor(String url, bool isDark) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube')) return const Color(0xFFFF3B30);
    if (lower.contains('facebook') || lower.contains('fb.com')) return const Color(0xFF1877F2);
    if (lower.contains('google')) return const Color(0xFF4285F4);
    if (lower.contains('deepseek')) return const Color(0xFF38BDF8);
    if (lower.contains('chatgpt') || lower.contains('openai')) return const Color(0xFF10A37F);
    if (lower.contains('reddit')) return const Color(0xFFFF4500);
    return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(browserTabProvider);
    final notifier = ref.read(browserTabProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF080D17) : const Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
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
                  button: true, selected: active, label: 'Pestaña ${tab.title}',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () { HapticFeedback.selectionClick(); notifier.selectTab(tab.id); },
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        constraints: const BoxConstraints(minWidth: 90, maxWidth: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        decoration: BoxDecoration(
                          color: active
                              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active ? brand.withValues(alpha: 0.6) : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                            width: active ? 1.0 : 0.8,
                          ),
                          boxShadow: active
                              ? [BoxShadow(color: brand.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(getBrandIcon(tab.url), size: 13, color: active ? brand : muted),
                            const SizedBox(width: 6),
                            Expanded(child: Text(
                              tab.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: active ? text : muted, fontSize: 11.5, fontWeight: active ? FontWeight.w600 : FontWeight.w500),
                            )),
                            InkResponse(
                              onTap: () { HapticFeedback.lightImpact(); notifier.closeTab(tab.id); },
                              radius: 12,
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(CupertinoIcons.xmark, size: 11, color: muted),
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
          _StripAction(tooltip: 'Nueva pestaña', icon: CupertinoIcons.plus, isDark: isDark, onTap: () { HapticFeedback.mediumImpact(); notifier.addTab(); }),
          if (onOpenCarousel != null) ...[
            const SizedBox(width: 4),
            _StripAction(tooltip: 'Vista 3D', icon: CupertinoIcons.square_stack_3d_up_fill, isDark: isDark, onTap: onOpenCarousel!),
          ],
        ],
      ),
    );
  }
}

class _StripAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _StripAction({required this.tooltip, required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    label: tooltip, button: true,
    child: Material(
      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 30, height: 30,
          child: Icon(icon, size: 14, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB)),
        ),
      ),
    ),
  );
}

