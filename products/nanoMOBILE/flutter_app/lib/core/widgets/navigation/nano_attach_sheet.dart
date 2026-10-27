import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import 'package:nanoai/features/chat/domain/camera_capture_backend.dart';

import '../../theme/design_tokens.dart';

part 'nano_attach_sheet_tiles.part.dart';
part 'nano_attach_sheet_items.part.dart';

/// Tipo de adjunto de archivo.
enum NanoAttachKind { photo, video, audio, document }

/// Tipo de selección realizada en la ventana flotante: comando o archivo.
enum NanoAttachSelectionType { attachment, command }

/// Resultado de la elección en la ventana flotante (+).
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

/// Ventana flotante de inyección rápida de IAs, MCP y adjuntos (+).
class NanoAttachSheet {
  const NanoAttachSheet._();

  static Future<NanoAttachSelection?> show(
    BuildContext context, {
    CameraCaptureBackend camera = const AndroidCameraCaptureBackend(),
  }) async {
    final rawResult = await showNanoGlassWindow<Object>(
      context: context,
      useRootNavigator: true,
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(Icons.add_rounded, color: colors.primary, size: 17),
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
          const _SectionLabel(
            title: 'Modelos de IA Web (@)',
            icon: Icons.psychology_rounded,
          ),
          const SizedBox(height: 6),
          const _AiInjectSection(),
          const SizedBox(height: 12),
          const _SectionLabel(
            title: 'Comandos MCP & Sistema',
            icon: Icons.terminal_rounded,
          ),
          const SizedBox(height: 6),
          const _CommandInjectSection(),
          const SizedBox(height: 12),
          const _SectionLabel(
            title: 'Adjuntar Archivo Local',
            icon: Icons.attach_file_rounded,
          ),
          const SizedBox(height: 6),
          const _FileAttachSection(),
        ],
      ),
    );
  }
}
