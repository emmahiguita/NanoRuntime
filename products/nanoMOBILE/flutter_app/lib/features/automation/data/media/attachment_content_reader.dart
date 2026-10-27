import 'dart:io';
import '../../../../core/services/whisper_stt_service.dart';
import '../../../../core/services/shared_gemini_media_reader.dart';
import '../../domain/incoming_attachment.dart';
import 'message_document_reader.dart';

/// Resultado de percepción: texto real y cobertura, nunca una respuesta al chat.
final class AttachmentReadEvidence {
  const AttachmentReadEvidence(
    this.text, {
    this.available = true,
    this.spokenText = '',
  });
  final String text;
  final bool available;
  final String spokenText;
}

typedef AudioFileTranscriber = Future<String?> Function(File file);
typedef CloudFileReader =
    Future<String?> Function(File file, String mime, {required bool allowed});
typedef DocumentFileReader =
    Future<Map<String, dynamic>> Function(String path, {required bool image});

/// QUÉ: adapta audio, OCR, etiquetas y páginas al mismo contrato de evidencia.
/// CÓMO: reutiliza Whisper local y el canal de documentos, sin claves duplicadas.
/// POR QUÉ: el modelo debe recibir contenido; una ruta no es una transcripción.
final class AttachmentContentReader {
  AttachmentContentReader({
    AudioFileTranscriber? transcribe,
    DocumentFileReader? document,
    CloudFileReader? cloud,
  }) : _transcribe =
           transcribe ??
           ((file) =>
               WhisperSttService.instance.transcribeAudio(audioFile: file)),
       _document = document ?? MessageDocumentReader().read,
       _cloud = cloud ?? SharedGeminiMediaReader().read;
  final AudioFileTranscriber _transcribe;
  final DocumentFileReader _document;
  final CloudFileReader _cloud;

  Future<AttachmentReadEvidence> read(
    IncomingAttachment attachment, {
    bool allowCloud = false,
    bool detailedVisual = false,
  }) async {
    final path = attachment.localPath;
    if (!attachment.isResolved || path == null) {
      return const AttachmentReadEvidence(
        'Archivo no expuesto por la aplicación de origen; contenido desconocido.',
        available: false,
      );
    }
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      return const AttachmentReadEvidence(
        'Archivo ausente o vacío; contenido desconocido.',
        available: false,
      );
    }
    switch (attachment.type) {
      case AttachmentType.voice:
      case AttachmentType.audio:
        final text = (await _transcribe(file))?.trim() ?? '';
        if (text.isEmpty || text.startsWith('Error:')) {
          if (allowCloud) {
            final remote = await _cloud(
              file,
              attachment.mimeType,
              allowed: true,
            );
            if (remote != null) {
              return AttachmentReadEvidence(
                'Transcripción con Gemini configurado:\n$remote',
                spokenText: remote,
              );
            }
          }
          return const AttachmentReadEvidence(
            'Audio recibido sin transcripción disponible. No se ha comprendido su contenido.',
            available: false,
          );
        }
        return AttachmentReadEvidence(
          'Transcripción local del audio:\n$text',
          spokenText: text,
        );
      case AttachmentType.image:
        final raw = await _localDocument(path, image: true);
        final text = '${raw['text'] ?? ''}'.trim();
        if (allowCloud && (detailedVisual || text.isEmpty)) {
          final remote = await _cloud(file, attachment.mimeType, allowed: true);
          if (remote != null) {
            return AttachmentReadEvidence(
              'Interpretación visual del Gemini configurado '
              '(inferencia del modelo; no prueba identidad ni hechos fuera de la imagen):\n$remote',
            );
          }
        }
        final labels = (raw['labels'] as List? ?? const [])
            .whereType<Map>()
            .map((row) => '${row['label'] ?? ''}')
            .where((label) => label.isNotEmpty)
            .join(', ');
        if (text.isEmpty && labels.isEmpty) {
          return const AttachmentReadEvidence(
            'Imagen recibida sin texto ni observaciones visuales utilizables.',
            available: false,
          );
        }
        return AttachmentReadEvidence(
          [
            if (text.isNotEmpty) 'Texto observado por OCR en la imagen:\n$text',
            if (labels.isNotEmpty) 'Etiquetas visuales generales: $labels.',
            'Cobertura: OCR y clasificación local; no identifica personas ni demuestra relaciones espaciales o detalles no observados.',
          ].join('\n'),
        );
      case AttachmentType.document:
        if (attachment.mimeType != 'application/pdf') {
          return const AttachmentReadEvidence(
            'Documento recibido con formato sin lector integrado.',
            available: false,
          );
        }
        final raw = await _localDocument(path, image: false);
        final pages = (raw['pages'] as List? ?? const [])
            .whereType<Map>()
            .toList();
        final lines = [
          for (final page in pages)
            if ('${page['text'] ?? ''}'.trim().isNotEmpty)
              'Página ${page['page']}${page['ocr'] == true ? ' (OCR)' : ''}: ${page['text']}',
        ];
        if (lines.isEmpty && allowCloud) {
          final remote = await _cloud(file, attachment.mimeType, allowed: true);
          if (remote != null) {
            return AttachmentReadEvidence(
              'Lectura del PDF con Gemini configurado:\n$remote',
            );
          }
        }
        return AttachmentReadEvidence(
          lines.isEmpty
              ? 'PDF sin texto legible en las páginas procesadas.'
              : 'PDF: procesadas ${pages.length} de ${raw['totalPages']} páginas; '
                    '${raw['partial'] == true ? 'lectura parcial' : 'páginas procesadas'}; '
                    'no supongas contenido omitido.\n${lines.join('\n')}',
          available: lines.isNotEmpty,
        );
      case AttachmentType.video:
        return const AttachmentReadEvidence(
          'Video recibido; no hay análisis de video integrado en este flujo.',
          available: false,
        );
    }
  }

  /// Un fallo local conserva la posibilidad de rescate autorizado, no inventa texto.
  Future<Map<String, dynamic>> _localDocument(
    String path, {
    required bool image,
  }) async {
    try {
      return await _document(path, image: image);
    } catch (_) {
      return const {};
    }
  }
}
