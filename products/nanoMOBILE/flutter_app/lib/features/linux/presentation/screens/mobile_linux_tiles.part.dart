part of 'mobile_linux_screen.dart';

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? accentColor;
  final bool isDestructive;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.accentColor,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final primaryColor = isDestructive ? colors.error : colors.textPrimary;
    final iconAccent = isDestructive
        ? colors.error
        : (accentColor ?? colors.accentMint);
    final tileBg = isDestructive
        ? colors.error.withValues(alpha: 0.08)
        : colors.borderSecondaryColor.withValues(alpha: 0.12);
    final borderColor = isDestructive
        ? colors.error.withValues(alpha: 0.28)
        : colors.borderSecondaryColor.withValues(alpha: 0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NanoRadius.medium),
        splashColor: iconAccent.withValues(alpha: 0.12),
        highlightColor: iconAccent.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(NanoRadius.medium),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(NanoRadius.small),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconAccent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDestructive
                              ? colors.error.withValues(alpha: 0.8)
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: isDestructive
                    ? colors.error.withValues(alpha: 0.6)
                    : colors.textSecondary.withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
