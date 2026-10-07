import 'dart:io';

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
          color: isDark ? const Color(0x333B82F6) : const Color(0x1F2563EB),
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
                  ),
                  _AiInjectTile(
                    label: 'Gemini',
                    command: '@gemini ',
                    icon: Icons.auto_awesome_rounded,
                  ),
                  _AiInjectTile(
                    label: 'DeepSeek',
                    command: '@deepseek ',
                    icon: Icons.explore_rounded,
                  ),
                  _AiInjectTile(
                    label: 'Claude',
                    command: '@claude ',
                    icon: Icons.lightbulb_rounded,
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
                      title: 'Cámara',
                      onTap: () =>
                          Navigator.of(context).pop(NanoAttachKind.photo),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FileTile(
                      icon: Icons.audiotrack_outlined,
                      title: 'Audio',
                      onTap: () =>
                          Navigator.of(context).pop(NanoAttachKind.audio),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FileTile(
                      icon: Icons.videocam_outlined,
                      title: 'Video',
                      onTap: () =>
                          Navigator.of(context).pop(NanoAttachKind.video),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FileTile(
                      icon: Icons.description_outlined,
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
  });

  final String label;
  final String command;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x1F3B82F6) : const Color(0x0F1D6FE8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0x333B82F6) : const Color(0x1F2563EB),
          width: 0.9,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop(command);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: colors.accent, size: 16),
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
  });

  final String title;
  final String subtitle;
  final String command;
  final IconData icon;

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
            color: isDark ? const Color(0x221E293B) : const Color(0x0A0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0x26334155) : const Color(0x140F172A),
              width: 0.9,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop(command);
              },
              borderRadius: BorderRadius.circular(12),
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
                        color: colors.accent.withValues(alpha: isDark ? .16 : .10),
                      ),
                      child: Icon(icon, color: colors.accent, size: 16),
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
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x221E293B) : const Color(0x0A0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0x26334155) : const Color(0x140F172A),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
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
                    color: colors.accent.withValues(alpha: isDark ? .16 : .10),
                  ),
                  child: Icon(icon, color: colors.accent, size: 18),
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
