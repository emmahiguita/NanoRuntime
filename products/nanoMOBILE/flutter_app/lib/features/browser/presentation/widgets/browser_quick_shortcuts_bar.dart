import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Barra de accesos directos rápidos (Shortcuts) del navegador.
/// Estilo Glassmorphism iOS hiperrealista y arquitectura limpia.
class BrowserQuickShortcutsBar extends StatelessWidget {
  final bool isDark;
  final ValueChanged<String> onSelectUrl;

  static const List<Map<String, String>> defaultShortcuts = [
    {'name': 'Google', 'url': 'https://www.google.com'},
    {'name': 'DeepSeek', 'url': 'https://chat.deepseek.com'},
    {'name': 'ChatGPT', 'url': 'https://chatgpt.com'},
    {'name': 'Wikipedia', 'url': 'https://es.wikipedia.org'},
    {'name': 'GitHub', 'url': 'https://github.com'},
  ];

  const BrowserQuickShortcutsBar({
    super.key,
    required this.isDark,
    required this.onSelectUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0x35071420)
            : const Color(0x30E2E8F0),
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
        padding: const EdgeInsets.symmetric(horizontal: 10),
        physics: const BouncingScrollPhysics(),
        itemCount: defaultShortcuts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = defaultShortcuts[index];
          final name = item['name']!;
          final url = item['url']!;

          return _ShortcutChip(
            name: name,
            isDark: isDark,
            onTap: () {
              HapticFeedback.lightImpact();
              onSelectUrl(url);
            },
          );
        },
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  final String name;
  final bool isDark;
  final VoidCallback onTap;

  const _ShortcutChip({
    required this.name,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.90)
                    : Colors.black87,
                fontFamily: 'Inter',
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
