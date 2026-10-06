import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';

/// Componentes y decoraciones auxiliares para la portada y perfil social.
class ProfileSocialComponents {
  const ProfileSocialComponents._();

  static Color planColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'pro': return const Color(0xFF6366F1);
      case 'business': return const Color(0xFFF59E0B);
      default: return const Color(0xFF6B7280);
    }
  }

  static IconData planIcon(String tier) {
    switch (tier.toLowerCase()) {
      case 'pro': return Icons.bolt_rounded;
      case 'business': return Icons.business_center_rounded;
      default: return Icons.person_rounded;
    }
  }

  static Widget coverImage({required BuildContext context, required String? path}) {
    final colors = NanoThemeExtension.of(context).colors;
    final gradient = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.nanoBlue,
            colors.nanoViolet,
            colors.nanoCyan.withValues(alpha: 0.85),
          ],
        ),
      ),
    );

    if (path == null || path.isEmpty) return gradient;
    final uri = Uri.tryParse(path);
    if (uri?.scheme == 'https' || uri?.scheme == 'http') {
      return Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => gradient);
    }
    final file = File(path);
    if (!file.existsSync()) return gradient;
    return Image.file(file, fit: BoxFit.cover, errorBuilder: (_, __, ___) => gradient);
  }
}

class ProfileInfoChipItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const ProfileInfoChipItem({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outline.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: NanoType.caption(colors.onSurfaceVariant).copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

class ProfileCoverEditButton extends StatelessWidget {
  final VoidCallback onTap;
  const ProfileCoverEditButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_camera_outlined, size: 14, color: Colors.white),
            SizedBox(width: 5),
            Text(
              'Editar portada',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
