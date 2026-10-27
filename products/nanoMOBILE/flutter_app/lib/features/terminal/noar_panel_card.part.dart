part of 'noar_panel.dart';

class _NoarCommandCard extends StatefulWidget {
  final Map<String, dynamic> cmd;
  final String tagLabel;
  final bool isHistory;
  final bool isDark;
  final Color accent;
  final VoidCallback onCopy;
  final VoidCallback onUse;

  const _NoarCommandCard({
    required this.cmd,
    required this.tagLabel,
    required this.isHistory,
    required this.isDark,
    required this.accent,
    required this.onCopy,
    required this.onUse,
  });

  @override
  State<_NoarCommandCard> createState() => _NoarCommandCardState();
}

class _NoarCommandCardState extends State<_NoarCommandCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cmd = widget.cmd['cmd'] as String? ?? '';
    final desc = widget.cmd['desc'] as String? ?? '';
    final isDark = widget.isDark;
    final accent = widget.accent;

    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.65);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFCBD5E1).withValues(alpha: 0.60);
    final descColor = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF334155);

    // Bloque de código terminal de alto contraste universal (siempre legible)
    const codeBg = Color(0xFF090E17);
    const codeBorder = Color(0xFF1E293B);
    const codeTextColor = Color(0xFFF8FAFC);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.fromLTRB(14, 11, 11, 11),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: accent.withValues(alpha: isDark ? 0.35 : 0.30),
                      ),
                    ),
                    child: Text(
                      widget.tagLabel.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: accent,
                      ),
                    ),
                  ),
                  if (widget.isHistory) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.history_rounded,
                      size: 13,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ],
                  const Spacer(),
                  Semantics(
                    label: 'Copiar comando',
                    button: true,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 17,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      onPressed: widget.onCopy,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Semantics(
                    label: 'Ejecutar comando',
                    button: true,
                    child: GestureDetector(
                      onTap: widget.onUse,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent,
                              accent.withValues(alpha: 0.75),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.30),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 20,
                          color: Color(0xFF04202E),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              GestureDetector(
                onTap: widget.onCopy,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: codeBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: codeBorder, width: 0.9),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r'$ ',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: accent,
                          height: 1.4,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          cmd,
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: codeTextColor,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 7),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    desc,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: descColor,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
