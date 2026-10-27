part of 'chat_screen.dart';

// Componente de ítem individual para el menú modal de opciones del chat estilo iOS.
extension _ChatScreenMenuTile on _ChatScreenState {
  Widget _buildCleanOptionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required NanoColors colors,
    required VoidCallback? onTap,
    Color? iconColor,
    bool isDestructive = false,
  }) {
    final effectiveIconColor = isDestructive
        ? const Color(0xFFEF4444)
        : (iconColor ?? colors.primary);
    final iconBgColor = effectiveIconColor.withValues(alpha: 0.12);
    final titleColor = isDestructive
        ? const Color(0xFFEF4444)
        : colors.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: effectiveIconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 15,
                color: colors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
