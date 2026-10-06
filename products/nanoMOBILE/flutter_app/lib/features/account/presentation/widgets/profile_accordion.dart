import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';

/// Etiqueta de sección editorial compacta
class ProfileSectionLabel extends StatelessWidget {
  final String label;
  final NanoColors colors;
  const ProfileSectionLabel({super.key, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Text(
          label.toUpperCase(),
          style: NanoType.overline(colors.onSurfaceVariant).copyWith(
            letterSpacing: 1.2,
            fontSize: 10,
          ),
        ),
      );
}

/// Acordeón de edición con estilo integrado al diseño Glassmorphism/Neumorphism
class ProfileEditAccordion extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final NanoColors colors;

  const ProfileEditAccordion({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline.withValues(alpha: 0.18)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: colors.primary),
          ),
          title: Text(
            title,
            style: NanoType.subtitle(colors.onSurface).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          iconColor: colors.onSurfaceVariant,
          collapsedIconColor: colors.onSurfaceVariant,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          collapsedShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          children: [
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
