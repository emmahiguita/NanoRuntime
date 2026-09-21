import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/features/chat/domain/camera_capture_backend.dart';

import '../../theme/design_tokens.dart';

/// Tipo de adjunto de archivo.
enum NanoAttachKind { photo, video, document }

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

/// Hoja flotante de inyección rápida de IAs, MCP y adjuntos de la barra (+).
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
        NanoAttachKind.photo => FileType.image, // Resuelto arriba por cámara.
        NanoAttachKind.video => FileType.video,
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
    final isDark = colors is NanoDarkColors;
    final mediaQuery = MediaQuery.of(context);
    final isLandscape =
        mediaQuery.orientation == Orientation.landscape ||
        mediaQuery.size.height < 520;
    final maxHeight = mediaQuery.size.height * (isLandscape ? 0.85 : 0.75);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
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
          color: isDark ? const Color(0x4DFF8C2A) : const Color(0x33FF6D00),
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            mediaQuery.padding.bottom + (isLandscape ? 12 : 18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: colors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inyección & Adjuntos (+)',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .2,
                          ),
                        ),
                        Text(
                          'Modelos de IA web, comandos MCP y archivos',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── SECCIÓN 1: IAs WEB ───────────────────────────────────
              const _SectionLabel(
                title: 'Modelos de IA Web (@)',
                icon: Icons.psychology_rounded,
              ),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AiInjectTile(
                    label: 'ChatGPT',
                    command: '@chatgpt ',
                    icon: Icons.smart_toy_rounded,
                    color: Color(0xFF10B981),
                  ),
                  _AiInjectTile(
                    label: 'Gemini',
                    command: '@gemini ',
                    icon: Icons.auto_awesome_rounded,
                    color: Color(0xFF0284C7),
                  ),
                  _AiInjectTile(
                    label: 'DeepSeek',
                    command: '@deepseek ',
                    icon: Icons.explore_rounded,
                    color: Color(0xFFA78BFA),
                  ),
                  _AiInjectTile(
                    label: 'Claude',
                    command: '@claude ',
                    icon: Icons.lightbulb_rounded,
                    color: Color(0xFFF97316),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── SECCIÓN 2: COMANDOS MCP & SISTEMA ───────────────────
              const _SectionLabel(
                title: 'Comandos MCP & Sistema',
                icon: Icons.terminal_rounded,
              ),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CommandTile(
                    title: 'Diagnóstico MCP',
                    subtitle: '@mcp call device.diagnostics',
                    command: '@mcp call device.diagnostics',
                    icon: Icons.phonelink_setup_rounded,
                    iconColor: Color(0xFF34D399),
                  ),
                  _CommandTile(
                    title: 'Git Status',
                    subtitle: '@git status',
                    command: '@git status',
                    icon: Icons.account_tree_rounded,
                    iconColor: Color(0xFFF43F5E),
                  ),
                  _CommandTile(
                    title: 'Búsqueda Web',
                    subtitle: '@buscar <consulta>',
                    command: '@buscar ',
                    icon: Icons.travel_explore_rounded,
                    iconColor: Color(0xFF3B82F6),
                  ),
                  _CommandTile(
                    title: 'Resumen Apps',
                    subtitle: '@mcp call device.app_summary',
                    command: '@mcp call device.app_summary',
                    icon: Icons.apps_rounded,
                    iconColor: Color(0xFF8B5CF6),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── SECCIÓN 3: ADJUNTOS DE ARCHIVO ──────────────────────
              const _SectionLabel(
                title: 'Adjuntar Archivo Local',
                icon: Icons.attach_file_rounded,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _FileTile(
                      icon: Icons.photo_camera_outlined,
                      iconColor: const Color(0xFF10B981),
                      title: 'Cámara',
                      onTap: () =>
                          Navigator.of(context).pop(NanoAttachKind.photo),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FileTile(
                      icon: Icons.videocam_outlined,
                      iconColor: const Color(0xFFA78BFA),
                      title: 'Video',
                      onTap: () =>
                          Navigator.of(context).pop(NanoAttachKind.video),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FileTile(
                      icon: Icons.description_outlined,
                      iconColor: const Color(0xFF34D399),
                      title: 'Documento',
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
        Icon(icon, size: 14, color: colors.textSecondary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
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
    required this.color,
  });

  final String label;
  final String command;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 0.9,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop(command);
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
    required this.iconColor,
  });

  final String title;
  final String subtitle;
  final String command;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 400;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 8) / 2;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0x351D3567) : const Color(0x183B82F6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: iconColor.withValues(alpha: isDark ? 0.30 : 0.20),
              width: 0.9,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop(command);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: itemWidth.clamp(140.0, 300.0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: iconColor.withValues(alpha: isDark ? .20 : .14),
                      ),
                      child: Icon(icon, color: iconColor, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: isCompact ? 11.5 : 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'JetBrainsMono',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x401D3567) : const Color(0x203B82F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.accent.withValues(alpha: isDark ? 0.25 : 0.15),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withValues(alpha: isDark ? .22 : .16),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
