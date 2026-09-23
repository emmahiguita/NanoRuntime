// profile_avatar_header.dart — Cabecera de foto y estatus de identidad personal.
// QUÉ HACE: Renderiza la fotografía circular del usuario, badges y selector de imagen.
// CÓMO FUNCIONA: Muestra foto local/remota o iniciales, con modal para elegir/eliminar foto.
// POR QUÉ: La identidad del usuario debe centrarse en la persona y no en el búho de Nano.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/nano_type.dart';

class ProfileAvatarHeader extends StatelessWidget {
  final String displayName;
  final String username;
  final String? photoPath;
  final ValueChanged<String?> onPhotoChanged;

  const ProfileAvatarHeader({
    super.key,
    required this.displayName,
    required this.username,
    required this.photoPath,
    required this.onPhotoChanged,
  });

  String get _initials {
    if (displayName.trim().isEmpty) return 'U';
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  void _openPhotoSheet(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NanoRadius.large)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text('Foto de perfil', style: NanoType.title(colors.onSurface)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF10B981)),
                title: Text('Elegir de la galería', style: NanoType.body(colors.onSurface)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await FilePicker.pickFiles(type: FileType.image);
                  if (result != null && result.files.single.path != null) {
                    onPhotoChanged(result.files.single.path);
                  }
                },
              ),
              if (photoPath != null && photoPath!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                  title: Text('Eliminar foto actual', style: NanoType.body(const Color(0xFFEF4444))),
                  onTap: () {
                    Navigator.pop(ctx);
                    onPhotoChanged(null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final hasCustomPhoto = photoPath != null && photoPath!.isNotEmpty && File(photoPath!).existsSync();

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6), width: 2),
                ),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: colors.surfaceVariant,
                  backgroundImage: hasCustomPhoto ? FileImage(File(photoPath!)) : null,
                  child: !hasCustomPhoto
                      ? Text(_initials, style: NanoType.display(colors.primary).copyWith(fontWeight: FontWeight.bold, fontSize: 32))
                      : null,
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: () => _openPhotoSheet(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.background, width: 2.5),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openPhotoSheet(context),
            icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF10B981)),
            label: Text('Cambiar foto', style: NanoType.caption(const Color(0xFF10B981)).copyWith(fontWeight: FontWeight.w600)),
          ),
          Text(displayName.isNotEmpty ? displayName : 'Emmanuel Higuita',
              style: NanoType.headline(colors.onSurface).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(username.isNotEmpty ? (username.startsWith('@') ? username : '@$username') : '@emmanuel',
              style: NanoType.caption(colors.onSurfaceVariant).copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text('Cuenta personal',
                style: NanoType.caption(const Color(0xFF10B981)).copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
