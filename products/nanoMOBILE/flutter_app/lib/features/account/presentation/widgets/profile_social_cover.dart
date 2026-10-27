import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

/// Cabecera de perfil ejecutivo estilo Apple ID / iOS.
///
/// - QUÉ HACE: Renderiza el avatar central compacto, nombre de usuario y metadatos.
/// - CÓMO FUNCIONA: Emplea jerarquía centrada con botón de cámara discreto y distintivo
///   neutral de suscripción sin colores saturados.
/// - POR QUÉ: Mantiene sobriedad ejecutiva, eliminando estéticas coloridas tipo vibecoder.
class ProfileSocialCover extends StatelessWidget {
  final String displayName, username, bio, city, country, language, gender, planTier;
  final String? photoPath, coverPath;
  final int? age;
  final VoidCallback onEditAvatar, onEditCover;

  const ProfileSocialCover({
    super.key,
    required this.displayName,
    required this.username,
    required this.bio,
    required this.photoPath,
    required this.coverPath,
    required this.city,
    required this.country,
    required this.language,
    required this.gender,
    required this.planTier,
    required this.age,
    required this.onEditAvatar,
    required this.onEditCover,
  });

  String get _initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'OP';
    return [
      parts.first,
      if (parts.length > 1) parts.last,
    ].map((p) => p.characters.first.toUpperCase()).join();
  }

  Widget _avatarImage(BuildContext context, NanoColors colors) {
    final fallback = Center(
      child: Text(
        _initials,
        style: TextStyle(
          fontFamily: 'Inter',
          color: colors.primary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        ),
      ),
    );
    final path = photoPath;
    if (path == null || path.isEmpty) return fallback;
    final uri = Uri.tryParse(path);
    if (uri?.scheme == 'https' || uri?.scheme == 'http') {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    final file = File(path);
    return file.existsSync()
        ? Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          )
        : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final themeExt = NanoThemeExtension.maybeOf(context);
    final colors = themeExt?.colors ?? const NanoDarkColors();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final locationStr = [city, country].where((s) => s.trim().isNotEmpty).join(', ');
    final metaItems = <String>[
      if (locationStr.isNotEmpty) locationStr,
      if (age != null) '$age años',
      if (language.isNotEmpty) language,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? colors.surfaceVariant.withValues(alpha: 0.50)
                        : colors.surface,
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.55),
                      width: 1.2,
                    ),
                  ),
                  child: ClipOval(child: _avatarImage(context, colors)),
                ),
                GestureDetector(
                  onTap: onEditAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isDark ? colors.surfaceVariant : colors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            displayName.trim().isEmpty ? 'Mi perfil' : displayName.trim(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              color: colors.onSurface,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (username.trim().isNotEmpty) ...[
                Text(
                  username.startsWith('@') ? username.trim() : '@${username.trim()}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: colors.onSurfaceVariant,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant.withValues(alpha: 0.40),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.25),
                    width: 0.7,
                  ),
                ),
                child: Text(
                  planTier.isNotEmpty ? planTier.toUpperCase() : 'SOBERANO',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: colors.onSurfaceVariant,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          if (bio.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                bio.trim(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: colors.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.35,
                  decoration: TextDecoration.none,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (metaItems.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              metaItems.join('  •  '),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                color: colors.onSurfaceVariant.withValues(alpha: 0.75),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
