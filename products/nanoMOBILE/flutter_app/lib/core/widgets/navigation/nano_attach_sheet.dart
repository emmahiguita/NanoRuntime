import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/design_tokens.dart';
import 'nano_nav_tokens.dart';

/// Tipo de adjunto elegido en la hoja flotante.
enum NanoAttachKind { photo, video, document }

/// Resultado de la elección: ruta cacheada por el SAF + nombre original.
class NanoAttachResult {
  const NanoAttachResult({
    required this.kind,
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final NanoAttachKind kind;
  final String path;
  final String name;
  final int sizeBytes;
}

/// Hoja flotante de adjuntos de la barra cósmica.
///
/// NAV-BAR-FIX-05 — el botón adjuntar abre esta ventana con tres caminos
/// reales: Foto (picker de imágenes), Video (picker de videos) y Documento
/// (cualquier archivo). El picker usa el SAF de Android vía file_picker;
/// devuelve ruta cacheada, nombre y peso para que la pantalla decida qué
/// hacer (el chat inyecta documentos como texto y media como referencia).
class NanoAttachSheet {
  const NanoAttachSheet._();

  static Future<NanoAttachResult?> show(BuildContext context) async {
    final kind = await showModalBottomSheet<NanoAttachKind>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AttachSheet(),
    );
    if (kind == null || !context.mounted) return null;

    final type = switch (kind) {
      NanoAttachKind.photo => FileType.image,
      NanoAttachKind.video => FileType.video,
      NanoAttachKind.document => FileType.any,
    };
    try {
      final result = await FilePicker.pickFiles(type: type, withData: false);
      final file = result?.files.single;
      if (file == null || file.path == null) return null;
      final sizeBytes = await File(file.path!).length();
      return NanoAttachResult(
        kind: kind,
        path: file.path!,
        name: file.name,
        sizeBytes: sizeBytes,
      );
    } catch (_) {
      // Picker cancelado o roto se trata como "no se eligió nada"; el error
      // real del archivo se reporta en la pantalla que lo consume.
      return null;
    }
  }
}

class _AttachSheet extends StatelessWidget {
  const _AttachSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xF50A1838), Color(0xF203091B)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFDFFFFFF), Color(0xF5EFF5FF)],
              ),
        border: Border.all(
          color: isDark
              ? NanoNavTokens.cyan.withValues(alpha: .30)
              : const Color(0x333B82F6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Adjuntar',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Foto, video o documento para acompañar tu mensaje',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _AttachTile(
                icon: Icons.photo_camera_outlined,
                iconColor: const Color(0xFF38BDF8),
                title: 'Foto',
                subtitle: 'Imagen de tu galería',
                onTap: () => Navigator.of(context).pop(NanoAttachKind.photo),
              ),
              const SizedBox(height: 8),
              _AttachTile(
                icon: Icons.videocam_outlined,
                iconColor: const Color(0xFFA78BFA),
                title: 'Video',
                subtitle: 'Video de tu galería',
                onTap: () => Navigator.of(context).pop(NanoAttachKind.video),
              ),
              const SizedBox(height: 8),
              _AttachTile(
                icon: Icons.description_outlined,
                iconColor: const Color(0xFF34D399),
                title: 'Documento',
                subtitle: 'TXT, MD, LOG, PDF…',
                onTap: () => Navigator.of(context).pop(NanoAttachKind.document),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;

    return Material(
      color: isDark ? const Color(0x401D3567) : const Color(0x203B82F6),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: isDark ? .22 : .16),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary.withValues(alpha: .7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
