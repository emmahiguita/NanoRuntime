// nano_attach_sheet.dart — Ventana modal flotante Liquid Glass de adjuntos y acciones (+).
// QUÉ HACE: Despliega el selector de adjuntos multimedia, modelos web y comandos del sistema.
// CÓMO FUNCIONA: Usa showNanoGlassWindow, interactúa con cámara nativa o SAF y devuelve una intención.
// POR QUÉ: Organiza y limpia el menú (+) con iconografía profesional y módulos < 180 líneas (SRP).
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import 'package:nanoai/features/chat/domain/camera_capture_backend.dart';

import '../../theme/design_tokens.dart';

part 'nano_attach_sheet_tiles.part.dart';
part 'nano_attach_sheet_ai.part.dart';
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

/// Ventana flotante estilo iOS para adjuntar archivos y activar herramientas (+).
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

/// Contenedor interior de la hoja de adjuntos con diseño Liquid Glass organizado.
class _AttachSheet extends StatelessWidget {
  const _AttachSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adjuntos y Acciones',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: colors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Archivos multimedia, modelos web y herramientas rápidas',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: colors.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const _FileAttachSection(),
          const SizedBox(height: 14),
          const _SectionLabel(
            title: 'Modelos de IA Web',
            icon: CupertinoIcons.sparkles,
          ),
          const SizedBox(height: 7),
          const _AiInjectSection(),
          const SizedBox(height: 14),
          const _SectionLabel(
            title: 'Herramientas de Hardware y Sistema',
            icon: CupertinoIcons.bolt_fill,
          ),
          const SizedBox(height: 7),
          const _CommandInjectSection(),
        ],
      ),
    );
  }
}