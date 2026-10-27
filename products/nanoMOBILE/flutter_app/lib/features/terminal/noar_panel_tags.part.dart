part of 'noar_panel.dart';

const Map<String, String> _noarTags = {
  'all': 'Todo',
  'fs': 'FS',
  'shell': 'Shell',
  'rootfs': 'Rootfs',
  'pkgs': 'Pkgs',
  'kali': 'Kali',
  'containers': 'Docker',
  'monitor': 'Monitor',
  'remote': 'Remote',
  'ai': 'IA',
  'general': 'General',
};

String _noarTagLabel(String? tag) => _noarTags[tag] ?? (tag ?? 'General');

class _NoarTagSelector extends StatelessWidget {
  final String activeTag;
  final bool isDark;
  final Color accent;
  final ValueChanged<String> onSelectTag;

  const _NoarTagSelector({
    required this.activeTag,
    required this.isDark,
    required this.accent,
    required this.onSelectTag,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        children: _noarTags.entries.map((e) {
          final active = activeTag == e.key;
          final activeBg = isDark
              ? accent.withValues(alpha: 0.22)
              : accent.withValues(alpha: 0.16);
          final inactiveBg = isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04);
          final activeBorder = accent.withValues(alpha: 0.60);
          final inactiveBorder = isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07);
          final activeText = accent;
          final inactiveText = isDark
              ? const Color(0xFF94A3B8)
              : const Color(0xFF475569);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelectTag(e.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active ? activeBg : inactiveBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active ? activeBorder : inactiveBorder,
                    width: active ? 1.2 : 0.8,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.18),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      letterSpacing: 0.2,
                      color: active ? activeText : inactiveText,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
