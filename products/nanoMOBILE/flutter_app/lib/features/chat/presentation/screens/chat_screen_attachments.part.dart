part of 'chat_screen.dart';

extension _ChatScreenAttachments on _ChatScreenState {
  /// NAV-BAR-FIX-05 — el botón adjuntar abre la hoja flotante de la barra
  /// (Cámara / Video / Documento). La foto capturada pasa por ML Kit y solo
  /// aporta etiquetas reales al prompt; video conserva una referencia honesta.
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
            'La foto se capturó, pero el clasificador visual no devolvió etiquetas.',
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

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool _looksBinary(String text) {
    const window = 512;
    final sample = text.length > window ? text.substring(0, window) : text;
    var controlChars = 0;
    for (final codeUnit in sample.codeUnits) {
      if (codeUnit < 9 || (codeUnit > 13 && codeUnit < 32)) {
        controlChars++;
      }
    }
    return controlChars > sample.length / 100; // >1% de control chars
  }
}
