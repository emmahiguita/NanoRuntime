import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';
import 'profile_social_components.dart';

/// Cabecera de perfil tipo red social con cover, avatar flotante y metadatos organizados.
class ProfileSocialCover extends StatelessWidget {
  final String displayName;
  final String username;
  final String bio;
  final String? photoPath;
  final String? coverPath;
  final String city;
  final String country;
  final String language;
  final String gender;
  final String planTier;
  final int? age;
  final VoidCallback onEditAvatar;
  final VoidCallback onEditCover;

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
    if (parts.first.isEmpty) return 'U';
    return [parts.first, if (parts.length > 1) parts.last].map((p) => p.characters.first.toUpperCase()).join();
  }

  Widget _avatarImage(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final fallback = Center(
      child: Text(_initials, style: NanoType.title(colors.primary).copyWith(fontSize: 26, fontWeight: FontWeight.w800)),
    );
    final path = photoPath;
    if (path == null || path.isEmpty) return fallback;
    final uri = Uri.tryParse(path);
    if (uri?.scheme == 'https' || uri?.scheme == 'http') {
      return Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
    }
    final file = File(path);
    return file.existsSync() ? Image.file(file, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback) : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    const coverHeight = 170.0;
    const avatarRadius = 44.0;
    const avatarBorder = 3.5;
    const avatarTotal = (avatarRadius + avatarBorder) * 2;
    final planColor = ProfileSocialComponents.planColor(planTier);
    final planIcon = ProfileSocialComponents.planIcon(planTier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: coverHeight + avatarRadius + avatarBorder,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                bottom: avatarRadius + avatarBorder,
                child: GestureDetector(
                  onTap: onEditCover,
                  child: ClipRRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ProfileSocialComponents.coverImage(context: context, path: coverPath),
                        Positioned(
                          left: 0, right: 0, bottom: 0, height: 80,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                              ),
                            ),
                          ),
                        ),
                        Positioned(top: 10, right: 12, child: ProfileCoverEditButton(onTap: onEditCover)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0, left: 20,
                child: GestureDetector(
                  onTap: onEditAvatar,
                  child: Stack(
                    children: [
                      Container(
                        width: avatarTotal, height: avatarTotal,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: avatarBorder),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ClipOval(child: _avatarImage(context)),
                      ),
                      Positioned(
                        right: 2, bottom: 2,
                        child: Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(
                            color: colors.primary, shape: BoxShape.circle,
                            border: Border.all(color: colors.surface, width: 2),
                          ),
                          child: Icon(Icons.photo_camera_rounded, size: 13, color: colors.surface),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 10, left: avatarTotal + 28,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: planColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: planColor.withValues(alpha: 0.40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(planIcon, size: 11, color: planColor),
                      const SizedBox(width: 4),
                      Text(planTier.toUpperCase(), style: NanoType.overline(planColor).copyWith(fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName.trim().isEmpty ? 'Tu nombre' : displayName.trim(),
                style: NanoType.title(colors.onSurface).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              if (username.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(username.startsWith('@') ? username : '@${username.trim()}', style: NanoType.caption(colors.onSurfaceVariant).copyWith(fontSize: 13)),
              ],
              if (bio.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(bio.trim(), style: NanoType.bodySecondary(colors.onSurface).copyWith(fontSize: 13, height: 1.45, fontStyle: FontStyle.italic), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: [
                  if (city.isNotEmpty || country.isNotEmpty)
                    ProfileInfoChipItem(icon: Icons.location_on_outlined, label: [city, country].where((v) => v.isNotEmpty).join(', ')),
                  if (age != null)
                    ProfileInfoChipItem(icon: Icons.cake_outlined, label: '$age años'),
                  if (gender.isNotEmpty && gender != 'Prefiero no decir')
                    ProfileInfoChipItem(icon: Icons.person_outline_rounded, label: gender),
                  if (language.isNotEmpty)
                    ProfileInfoChipItem(icon: Icons.translate_rounded, label: language),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }
}
