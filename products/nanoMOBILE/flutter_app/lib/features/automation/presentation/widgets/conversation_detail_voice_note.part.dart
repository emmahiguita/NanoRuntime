part of 'conversation_detail_sheet.dart';

/// [ConversationDetailVoiceNote]
/// QUÉ HACE: Gestiona el ciclo de vida de grabación en vivo de notas de voz con micrófono.
/// CÓMO FUNCIONA: Llama a NanoRuntimeApi para captura nativa .m4a, temporizador y despacho a WhatsApp.
/// POR QUÉ: Permite grabar directamente con un tap en el micrófono sin abrir gestor de archivos (< 120 líneas).
extension ConversationDetailVoiceNote on _ConversationDetailSheetState {
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
        category: NanoMediaCategory.forFileName(recordedPath),
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
}
