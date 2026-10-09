import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

/// Componentes auxiliares con acabado iOS Glass para el perfil profesional.
class ProfileSocialComponents {
  const ProfileSocialComponents._();

  static Color planColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'pro': return const Color(0xFF6366F1);
      case 'business':
      case 'enterprise': return const Color(0xFFF59E0B);
      case 'master': return const Color(0xFF10B981);
      default: return const Color(0xFF0EA5E9);
    }
  }

  static IconData planIcon(String tier) {
    switch (tier.toLowerCase()) {
      case 'pro': return Icons.bolt_rounded;
      case 'business':
      case 'enterprise': return Icons.workspace_premium_rounded;
      case 'master': return Icons.shield_rounded;
      default: return Icons.smart_toy_rounded;
    }
  }

  static Widget coverImage({required BuildContext context, required String? path}) {
    final colors = NanoThemeExtension.of(context).colors;
    final gradient = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [colors.nanoBlue, colors.nanoViolet.withValues(alpha: 0.95), const Color(0xFF0F172A)],
        ),
      ),
    );

    if (path == null || path.isEmpty) return gradient;
    final uri = Uri.tryParse(path);
    if (uri?.scheme == 'https' || uri?.scheme == 'http') {
      return Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => gradient);
    }
    final file = File(path);
    return file.existsSync() ? Image.file(file, fit: BoxFit.cover, errorBuilder: (_, __, ___) => gradient) : gradient;
  }
}

/// Chip miniatura de metadatos estilo iOS Glass translúcido.
class ProfileInfoChipItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? customAccent;

  const ProfileInfoChipItem({super.key, required this.icon, required this.label, this.customAccent});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final accent = customAccent ?? colors.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colors.surfaceVariant.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.45), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: accent),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontFamily: 'Inter', color: colors.onSurface, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón translúcido iOS Glass para editar portada.
class ProfileCoverEditButton extends StatelessWidget {
  final VoidCallback onTap;
  const ProfileCoverEditButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Cambiar portada', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Burbuja de biografía estilo iOS Frosted Glass.
class ProfileBioQuoteBubble extends StatelessWidget {
  final String bio;
  const ProfileBioQuoteBubble({super.key, required this.bio});

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceVariant.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.30)),
          ),
          child: Text(
            bio.trim(),
            style: TextStyle(fontFamily: 'Inter', color: colors.onSurfaceVariant, fontSize: 13, height: 1.45, fontStyle: FontStyle.italic),
            maxLines: 3, overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
