import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/chat/domain/camera_capture_backend.dart';

import '../../theme/design_tokens.dart';

/// Tipo de adjunto de archivo.
enum NanoAttachKind { photo, video, audio, document }

/// Tipo de selección realizada en la hoja flotante: comando o archivo.
enum NanoAttachSelectionType { attachment, command }

/// Resultado de la elección en la hoja flotante (+).
class NanoAttachSelection {
  const NanoAttachSelection.attachment(this.attachment)
    : type = NanoAttachSelectionType.attachment,
      command = null;

  const NanoAttachSelection.command(this.command)
    : type = NanoAttachSelectionType.command,
      attachment = null;

  final NanoAttachSelectionType type;
  final NanoAttachResult? attachment;
  final String? command;
}

/// Resultado de la elección de archivo: ruta cacheada por el SAF + nombre original.
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

/// Hoja flotante de inyección rápida de IAs, MCP y adjuntos (+).
class NanoAttachSheet {
  const NanoAttachSheet._();

  static Future<NanoAttachSelection?> show(
    BuildContext context, {
    CameraCaptureBackend camera = const AndroidCameraCaptureBackend(),
  }) async {
    final rawResult = await showModalBottomSheet<Object>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AttachSheet(),
    );
    if (rawResult == null || !context.mounted) return null;

    if (rawResult is String) {
      return NanoAttachSelection.command(rawResult);
    }

    if (rawResult is NanoAttachKind) {
      if (rawResult == NanoAttachKind.photo) {
        final photo = await camera.capturePhoto();
        if (photo == null) return null;
        return NanoAttachSelection.attachment(
          NanoAttachResult(
            kind: NanoAttachKind.photo,
            path: photo.path,
            name: photo.name,
            sizeBytes: photo.sizeBytes,
          ),
        );
      }
      final type = switch (rawResult) {
        NanoAttachKind.photo => FileType.image,
        NanoAttachKind.video => FileType.video,
        NanoAttachKind.audio => FileType.audio,
        NanoAttachKind.document => FileType.any,
      };
      try {
        final result = await FilePicker.pickFiles(type: type, withData: false);
        final file = result?.files.single;
        if (file == null || file.path == null) return null;
        final sizeBytes = await File(file.path!).length();
        return NanoAttachSelection.attachment(
          NanoAttachResult(
            kind: rawResult,
            path: file.path!,
            name: file.name,
            sizeBytes: sizeBytes,
          ),
        );
      } catch (_) {
        return null;
      }
    }

    return null;
  }
}

class _AttachSheet extends StatelessWidget {
  const _AttachSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is! NanoLightColors;
    final mediaQuery = MediaQuery.of(context);
    final isLandscape =
        mediaQuery.orientation == Orientation.landscape ||
        mediaQuery.size.height < 520;
    final maxHeight = mediaQuery.size.height * (isLandscape ? 0.85 : 0.75);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xE6182130)
                : Colors.white.withValues(alpha: 0.95),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                14,
                10,
                14,
                mediaQuery.padding.bottom + (isLandscape ? 10 : 16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tirador ergonómico
                  Center(
                    child: Container(
                      width: 32,
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: colors.onSurface.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Encabezado compacto
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: colors.primary,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inyección & Adjuntos (+)',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: colors.onSurface,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              'Modelos de IA web, comandos MCP y archivos',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: colors.onSurfaceVariant,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── SECCIÓN 1: IAs WEB ───────────────────────────────────
                  const _SectionLabel(
                    title: 'Modelos de IA Web (@)',
                    icon: Icons.psychology_rounded,
                  ),
                  const SizedBox(height: 6),
                  const Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _AiInjectTile(
                        label: 'ChatGPT',
                        command: '@chatgpt ',
                        icon: Icons.smart_toy_rounded,
                        accentColor: Color(0xFF10A37F),
                      ),
                      _AiInjectTile(
                        label: 'Gemini',
                        command: '@gemini ',
                        icon: Icons.auto_awesome_rounded,
                        accentColor: Color(0xFF38BDF8),
                      ),
                      _AiInjectTile(
                        label: 'DeepSeek',
                        command: '@deepseek ',
                        icon: Icons.explore_rounded,
                        accentColor: Color(0xFF2563EB),
                      ),
                      _AiInjectTile(
                        label: 'Claude',
                        command: '@claude ',
                        icon: Icons.lightbulb_rounded,
                        accentColor: Color(0xFFD97706),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── SECCIÓN 2: COMANDOS MCP & SISTEMA ───────────────────
                  const _SectionLabel(
                    title: 'Comandos MCP & Sistema',
                    icon: Icons.terminal_rounded,
                  ),
                  const SizedBox(height: 6),
                  const Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _CommandTile(
                        title: 'Diagnóstico MCP',
                        subtitle: '@mcp call device.diagnostics',
                        command: '@mcp call device.diagnostics',
                        icon: Icons.phonelink_setup_rounded,
                      ),
                      _CommandTile(
                        title: 'Git Status',
                        subtitle: '@git status',
                        command: '@git status',
                        icon: Icons.account_tree_rounded,
                      ),
                      _CommandTile(
                        title: 'Búsqueda Web',
                        subtitle: '@buscar <consulta>',
                        command: '@buscar ',
                        icon: Icons.travel_explore_rounded,
                      ),
                      _CommandTile(
                        title: 'Resumen Apps',
                        subtitle: '@mcp call device.app_summary',
                        command: '@mcp call device.app_summary',
                        icon: Icons.apps_rounded,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── SECCIÓN 3: ADJUNTOS DE ARCHIVO ──────────────────────
                  const _SectionLabel(
                    title: 'Adjuntar Archivo Local',
                    icon: Icons.attach_file_rounded,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _FileTile(
                          icon: Icons.photo_camera_outlined,
                          title: 'Cámara',
                          color: const Color(0xFF38BDF8),
                          onTap: () =>
                              Navigator.of(context).pop(NanoAttachKind.photo),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _FileTile(
                          icon: Icons.audiotrack_outlined,
                          title: 'Audio',
                          color: const Color(0xFF818CF8),
                          onTap: () =>
                              Navigator.of(context).pop(NanoAttachKind.audio),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _FileTile(
                          icon: Icons.videocam_outlined,
                          title: 'Video',
                          color: const Color(0xFFEC4899),
                          onTap: () =>
                              Navigator.of(context).pop(NanoAttachKind.video),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _FileTile(
                          icon: Icons.description_outlined,
                          title: 'Documento',
                          color: const Color(0xFF10B981),
                          onTap: () =>
                              Navigator.of(context).pop(NanoAttachKind.document),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return Row(
      children: [
        Icon(icon, size: 12, color: colors.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            color: colors.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _AiInjectTile extends StatelessWidget {
  const _AiInjectTile({
    required this.label,
    required this.command,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String command;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is! NanoLightColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pop(command);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.28 : 0.22),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accentColor, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: colors.onSurface,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({
    required this.title,
    required this.subtitle,
    required this.command,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String command;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is! NanoLightColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 6) / 2;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop(command);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: itemWidth,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: isDark ? 0.40 : 0.70),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.22),
                  width: 0.7,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: colors.primary, size: 14),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: colors.onSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            color: colors.onSurfaceVariant,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is! NanoLightColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: isDark ? 0.40 : 0.70),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.22),
              width: 0.7,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: colors.onSurface,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
