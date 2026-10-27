part of 'chat_screen.dart';

extension _ChatScreenAttachments on _ChatScreenState {
  /// NAV-BAR-FIX-05 — el botón adjuntar abre la hoja flotante de la barra
  /// (Cámara / Video / Documento). La foto pasa por OCR y clasificación local;
  /// video conserva una referencia honesta.
  /// Binarios o archivos ilegibles se reportan, no se inventa texto.
  Future<void> _attachFile() async {
    final selection = await NanoAttachSheet.show(context);
    if (selection == null || !mounted) return;

    if (selection.type == NanoAttachSelectionType.command &&
        selection.command != null) {
      final cmd = selection.command!;
      setState(() => _dictatedText = cmd);
      return;
    }

    final picked = selection.attachment;
    if (picked == null) return;
    final notifier = ref.read(chatProvider.notifier);
    switch (picked.kind) {
      case NanoAttachKind.photo:
        final analyzed = await notifier.addPhotoAttachment(
          name: picked.name,
          path: picked.path,
          sizeBytes: picked.sizeBytes,
        );
        // La observación ya está en memoria; borrar la captura temporal evita
        // que el cache crezca con cada uso de cámara.
        try {
          await File(picked.path).delete();
        } catch (_) {
          // El sistema también puede limpiar cache; ausencia no es un error.
        }
        if (!analyzed && mounted) {
          _showHonestError(
            'No se pudo extraer texto ni etiquetas locales de la foto.',
          );
        }
      case NanoAttachKind.video:
        notifier.addAttachment(
          ChatAttachment(
            name: picked.name,
            content:
                '[Archivo de video adjuntado: ${picked.name} '
                '(${_formatBytes(picked.sizeBytes)})]\n'
                'El modelo local actual no puede procesar video todavía; '
                'este adjunto se envía como referencia de que el usuario lo '
                'incluyó en el mensaje.',
            kind: ChatAttachmentKind.video,
            sizeBytes: picked.sizeBytes,
          ),
        );
      case NanoAttachKind.audio:
        await notifier.addAudioAttachment(
          name: picked.name,
          path: picked.path,
          sizeBytes: picked.sizeBytes,
        );
      case NanoAttachKind.document:
        await _attachTextDocument(picked, notifier);
    }
  }

  /// Documento → texto real. Ruta cacheada del SAF, límites de peso y
  /// heurística binaria: si no es texto imprimible no se inventa contenido.
  Future<void> _attachTextDocument(
    NanoAttachResult picked,
    ChatNotifier notifier,
  ) async {
    try {
      final selected = File(picked.path);
      if (picked.name.toLowerCase().endsWith('.pdf')) {
        await _attachPdfDocument(selected, picked, notifier);
        return;
      }
      if (picked.sizeBytes > _ChatScreenState._maxAttachBytes) {
        _showHonestError(
          'El archivo supera ${_ChatScreenState._maxAttachBytes ~/ 1024} KB. '
          'Adjunta un fragmento de texto más pequeño.',
        );
        return;
      }
      final bytes = await selected.readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);

      // Heurística honesta: si el contenido no es texto imprimible, no sirve.
      if (text.trim().isEmpty ||
          text.contains('\u0000') ||
          _looksBinary(text)) {
        _showHonestError(
          'El archivo no parece texto legible; adjunta '
          'archivos .txt/.md/.log.',
        );
        return;
      }

      final clipped = text.length > _ChatScreenState._maxAttachChars
          ? '${text.substring(0, _ChatScreenState._maxAttachChars)}\n…[truncado]'
          : text;
      notifier.addAttachment(
        ChatAttachment(
          name: picked.name,
          content: clipped,
          kind: ChatAttachmentKind.document,
          sizeBytes: picked.sizeBytes,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showHonestError('No se pudo leer el archivo: $e');
    }
  }

  Future<void> _attachPdfDocument(
    File selected,
    NanoAttachResult picked,
    ChatNotifier notifier,
  ) async {
    const maxPdfBytes = 50 * 1024 * 1024;
    if (picked.sizeBytes > maxPdfBytes) {
      _showHonestError('El PDF supera el límite de 50 MB.');
      return;
    }

    File? privateCopy;
    try {
      final cache = await getTemporaryDirectory();
      privateCopy = File(
        '${cache.path}/nano_chat_${DateTime.now().microsecondsSinceEpoch}.pdf',
      );
      await selected.copy(privateCopy.path);
      final document = await const PdfTextExtractionService().readMessagePdf(
        privateCopy.path,
      );
      final readablePages = document.pages
          .where((page) => page.text.trim().isNotEmpty)
          .toList(growable: false);
      if (readablePages.isEmpty) {
        _showHonestError(
          'No se pudo extraer texto del PDF. Puede estar protegido o sus '
          'páginas no pudieron leerse con OCR.',
        );
        return;
      }

      final coverage = document.partial
          ? 'Se leyeron ${readablePages.length} páginas con contenido de '
                '${document.totalPages}; el análisis es parcial.'
          : 'Se leyeron ${readablePages.length} páginas con contenido.';
      final extracted = readablePages
          .map(
            (page) =>
                'Página ${page.page}${page.ocr ? ' (OCR)' : ''}:\n${page.text}',
          )
          .join('\n\n');
      final content = 'PDF leído localmente. $coverage\n\n$extracted';
      final clipped = content.length > _ChatScreenState._maxAttachChars
          ? '${content.substring(0, _ChatScreenState._maxAttachChars)}\n…[texto recortado]'
          : content;
      notifier.addAttachment(
        ChatAttachment(
          name: picked.name,
          content: clipped,
          kind: ChatAttachmentKind.document,
          sizeBytes: picked.sizeBytes,
        ),
      );
    } catch (e) {
      if (mounted) _showHonestError('No se pudo leer el PDF: $e');
    } finally {
      try {
        if (privateCopy != null && await privateCopy.exists()) {
          await privateCopy.delete();
        }
      } catch (_) {
        // La copia temporal puede ser limpiada por el sistema.
      }
    }
  }

  static String _formatBytes(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  bool _looksBinary(String text) {
    const window = 512;
    final sample = text.length > window ? text.substring(0, window) : text;
    var controlChars = 0;
    for (final c in sample.codeUnits) {
      if (c < 9 || (c > 13 && c < 32)) controlChars++;
    }
    return controlChars > sample.length / 100; // >1% de control chars
  }
}
