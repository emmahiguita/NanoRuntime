part of 'conversation_detail_sheet.dart';

/// [ConversationDetailAttachmentsShare]
/// QUÉ HACE: Despacha y persiste archivos adjuntos y grabación de notas de voz en WhatsApp.
/// CÓMO FUNCIONA: Usa FilePicker, NanoRuntimeApi para micrófono y registra la salida en ConversationMemoryStore.
/// POR QUÉ: Asegura captura y envío de audio real sin abrir gestores de archivos erróneos (< 195 líneas).
extension ConversationDetailAttachmentsShare on _ConversationDetailSheetState {
  Future<void> _pickAndShareMedia({
    required FileType type,
    List<String>? allowedExtensions,
    required String label,
  }) async {
    try {
      const share = WhatsAppMediaShare();
      final picked = await FilePicker.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
      );
      final file = picked?.files.single;
      if (file == null || file.path == null) return;

      _safeSetState(() {
        _busy = true;
        _statusText = 'Preparando $label para compartir...';
      });

      final stablePath = await share.copyToCatalog(
        file.path!,
        category: NanoMediaCategory.forFileName(file.name),
      );
      if (stablePath == null) {
        _safeSetState(
          () => _statusText = 'No se pudo preparar el archivo para WhatsApp.',
        );
        return;
      }
      final recipient = _verifiedAttachmentRecipient();
      if (recipient == null) {
        _safeSetState(
          () => _statusText =
              'No hay una identidad verificable para ${widget.item.displayName}.',
        );
        return;
      }

      final returnsToNano = await share.isAccessibilityEnabled();
      final caption = _inputController.text.trim();
      final ok = await share.shareFile(
        path: stablePath,
        contact: recipient.contact,
        caption: caption,
        packageName: widget.item.packageName,
        autoSend: true,
        recipientName: recipient.name,
        recipientKind: recipient.kind,
        recipientVerified: recipient.verified,
      );
      if (ok) {
        _recordSharedMedia(stablePath, caption);
      }
      _safeSetState(() {
        _statusText = ok
            ? returnsToNano
                  ? 'Automatización iniciada. Nano regresará tras pulsar Enviar.'
                  : 'Archivo abierto en WhatsApp. Confirma Enviar allí para completar.'
            : 'No se pudo iniciar el envío de $label';
      });
    } catch (e) {
      _safeSetState(() => _statusText = 'Error al adjuntar $label: $e');
    } finally {
      _safeSetState(() => _busy = false);
    }
  }

  /// Alterna entre iniciar o detener/enviar la grabación de nota de voz con el micrófono.
  Future<void> _handleVoiceNoteTap() async {
    if (_busy) return;
    HapticFeedback.heavyImpact();
    if (_isRecordingVoiceNote) {
      await _stopAndSendVoiceNote();
    } else {
      await _startRecordingVoiceNote();
    }
  }

  /// Inicia la captura de audio en vivo desde el micrófono del sistema.
  Future<void> _startRecordingVoiceNote() async {
    final path = await NanoRuntimeApi.instance.startRecordingAudio();
    if (path == null) {
      _safeSetState(() {
        _statusText = 'No se pudo iniciar el micrófono para la nota de voz.';
      });
      return;
    }
    _safeSetState(() {
      _isRecordingVoiceNote = true;
      _recordingSeconds = 0;
      _statusText = 'Grabando nota de voz... Pulsa enviar para despacharla.';
    });
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isRecordingVoiceNote) {
        timer.cancel();
        return;
      }
      _safeSetState(() => _recordingSeconds++);
    });
  }

  /// Detiene la grabación, prepara el archivo .m4a y lo envía a WhatsApp.
  Future<void> _stopAndSendVoiceNote() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _safeSetState(() {
      _isRecordingVoiceNote = false;
      _busy = true;
      _statusText = 'Enviando nota de voz...';
    });

    final recordedPath = await NanoRuntimeApi.instance.stopRecordingAudio();
    if (recordedPath == null || recordedPath.isEmpty) {
      _safeSetState(() {
        _busy = false;
        _statusText = 'Nota de voz descartada.';
      });
      return;
    }

    try {
      const share = WhatsAppMediaShare();
      final stablePath = await share.copyToCatalog(
        recordedPath,
        category: NanoMediaCategory.voice,
      );
      if (stablePath == null) {
        _safeSetState(() {
          _statusText = 'No se pudo preparar la nota de voz.';
          _busy = false;
        });
        return;
      }

      final recipient = _verifiedAttachmentRecipient();
      if (recipient == null) {
        _safeSetState(() {
          _statusText = 'No hay destinatario verificable para enviar audio.';
          _busy = false;
        });
        return;
      }

      final returnsToNano = await share.isAccessibilityEnabled();
      final ok = await share.shareFile(
        path: stablePath,
        contact: recipient.contact,
        caption: '',
        packageName: widget.item.packageName,
        autoSend: true,
        recipientName: recipient.name,
        recipientKind: recipient.kind,
        recipientVerified: recipient.verified,
      );

      if (ok) {
        _recordSharedMedia(stablePath, '');
      }

      _safeSetState(() {
        _statusText = ok
            ? returnsToNano
                ? 'Nota de voz enviada. Nano regresará automáticamente.'
                : 'Nota de voz enviada a WhatsApp.'
            : 'No se pudo enviar la nota de voz.';
      });
    } catch (e) {
      _safeSetState(() => _statusText = 'Error enviando nota de voz: $e');
    } finally {
      _safeSetState(() => _busy = false);
    }
  }

  /// Cancela y elimina la nota de voz actual sin enviarla.
  Future<void> _cancelRecordingVoiceNote() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await NanoRuntimeApi.instance.cancelRecordingAudio();
    _safeSetState(() {
      _isRecordingVoiceNote = false;
      _recordingSeconds = 0;
      _statusText = 'Nota de voz cancelada.';
    });
  }

  /// Registra el archivo enviado en el historial observable del chat.
  void _recordSharedMedia(String path, String caption) {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final memoryStore = ref.read(conversationMemoryStoreProvider);
      final textToSend = caption.isNotEmpty ? '$caption\n$path' : path;

      memoryStore.appendOutbound(
        canonicalConversationId(widget.item.conversationId),
        textToSend,
        kind: ConversationMemoryEntryKind.outboundDispatched,
        atMs: nowMs,
      );

      ref.read(conversationHubVersionProvider.notifier).state++;
      _inputController.clear();
    } catch (_) {}
  }

  /// Selecciona y comparte una nota de voz de audio (.opus, .m4a, .mp3, etc.).
  Future<void> _attachVoiceNote() => _pickAndShareMedia(
    type: FileType.custom,
    allowedExtensions: const ['opus', 'm4a', 'mp3', 'ogg', 'wav', 'aac'],
    label: 'nota de voz',
  );
}
