import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Barra de accesos directos rápidos (Shortcuts) del navegador con íconos de marca iOS.
/// Sigue principios SOLID, Clean Architecture y diseño Glassmorphism iOS.
class BrowserQuickShortcutsBar extends StatelessWidget {
  final bool isDark;
  final ValueChanged<String> onSelectUrl;

  const BrowserQuickShortcutsBar({
    super.key,
    required this.isDark,
    required this.onSelectUrl,
  });

  static const List<_ShortcutEntry> _shortcuts = [
    _ShortcutEntry(
      name: 'Google',
      url: 'https://www.google.com',
      badgeBg: Color(0xFF4285F4),
      iconWidget: Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          fontFamily: 'sans-serif',
        ),
      ),
    ),
    _ShortcutEntry(
      name: 'YouTube',
      url: 'https://m.youtube.com',
      badgeBg: Color(0xFFFF0000),
      iconWidget: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 15),
    ),
    _ShortcutEntry(
      name: 'Facebook',
      url: 'https://m.facebook.com',
      badgeBg: Color(0xFF1877F2),
      iconWidget: Text(
        'f',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 14,
          fontFamily: 'sans-serif',
        ),
      ),
    ),
    _ShortcutEntry(
      name: 'DeepSeek',
      url: 'https://chat.deepseek.com',
      badgeBg: Color(0xFF1E88E5),
      iconWidget: Icon(Icons.auto_awesome, color: Colors.white, size: 13),
    ),
    _ShortcutEntry(
      name: 'ChatGPT',
      url: 'https://chatgpt.com',
      badgeBg: Color(0xFF10A37F),
      iconWidget: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 13),
    ),
    _ShortcutEntry(
      name: 'Wikipedia',
      url: 'https://es.wikipedia.org',
      badgeBg: Color(0xFF334155),
      iconWidget: Text(
        'W',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          fontFamily: 'serif',
        ),
      ),
    ),
    _ShortcutEntry(
      name: 'GitHub',
      url: 'https://github.com',
      badgeBg: Color(0xFF181717),
      iconWidget: Icon(Icons.code_rounded, color: Colors.white, size: 13),
    ),
    _ShortcutEntry(
      name: 'Reddit',
      url: 'https://www.reddit.com',
      badgeBg: Color(0xFFFF4500),
      iconWidget: Icon(Icons.forum_rounded, color: Colors.white, size: 13),
    ),
    _ShortcutEntry(
      name: 'X',
      url: 'https://x.com',
      badgeBg: Color(0xFF000000),
      iconWidget: Text(
        '𝕏',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x35071420) : const Color(0x30E2E8F0),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.8,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        physics: const BouncingScrollPhysics(),
        itemCount: _shortcuts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final entry = _shortcuts[index];
          return _ShortcutChip(
            entry: entry,
            isDark: isDark,
            onTap: () {
              HapticFeedback.lightImpact();
              onSelectUrl(entry.url);
            },
          );
        },
      ),
    );
  }
}

class _ShortcutEntry {
  final String name;
  final String url;
  final Color badgeBg;
  final Widget iconWidget;

  const _ShortcutEntry({
    required this.name,
    required this.url,
    required this.badgeBg,
    required this.iconWidget,
  });
}

class _ShortcutChip extends StatelessWidget {
  final _ShortcutEntry entry;
  final bool isDark;
  final VoidCallback onTap;

  const _ShortcutChip({
    required this.entry,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: entry.badgeBg.withValues(alpha: 0.20),
          highlightColor: entry.badgeBg.withValues(alpha: 0.12),
          child: Container(
            padding: const EdgeInsets.only(
              left: 4,
              right: 10,
              top: 3,
              bottom: 3,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Squircle Icon Badge Estilo iOS
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: entry.badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: entry.badgeBg.withValues(alpha: 0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: entry.iconWidget,
                ),
                const SizedBox(width: 6),

                // Nombre
                Text(
                  entry.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.92)
                        : const Color(0xFF1E293B),
                    fontFamily: 'Inter',
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
