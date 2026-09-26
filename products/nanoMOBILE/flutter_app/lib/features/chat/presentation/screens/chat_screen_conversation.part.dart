part of 'chat_screen.dart';

extension _ChatScreenConversation on _ChatScreenState {
  void _showHonestError(String message) {
    if (!mounted) return;
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: colors.surfaceVariant,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Dictado por voz REAL con streaming: los parciales llenan el campo en
  /// vivo y el resultado final queda escrito para que el usuario revise y
  /// envíe cuando quiera (patrón de teclado). Nunca se envía un partial ni
  /// el final por sí solo. El modo manos libres vive en la conversación
  /// continua (∞): ahí la voz SÍ se ejecuta directo.
  Future<void> _toggleMic() async {
    // Conversación continua en curso: detenerla antes de dictar (un solo
    // micrófono — dictado y conversación no compiten por el audio).
    if (!_listening && _conversationActive) {
      await _toggleConversation();
    }
    if (_listening) {
      setState(() => _listening = false);
      await _partialSub?.cancel();
      _partialSub = null;
      await NanoRuntimeApi.instance.stopSpeech();
      return;
    }
    setState(() => _listening = true);
    _partialSub = NanoRuntimeApi.instance.voicePartialStream.listen((partial) {
      if (!mounted || !_listening) return;
      setState(() => _dictatedText = partial);
    });
    final text = await NanoRuntimeApi.instance.startVoiceRecognition();
    await _partialSub?.cancel();
    _partialSub = null;
    if (!mounted) return;
    setState(() => _listening = false);
    if (text == null || text.trim().isEmpty) {
      // Sin texto final: si el dictado en vivo dejó algo se conserva; si no,
      // aviso honesto.
      if (_dictatedText.trim().isEmpty) {
        _showHonestError('No se pudo reconocer el audio. Inténtalo de nuevo.');
      }
      return;
    }
    setState(() => _dictatedText = text.trim());
    // VOICE-PRO-04: el dictado LLENA el campo y el usuario decide cuándo
    // enviar. El autoenvío sorprendía: no daba tiempo a revisar lo que el
    // reconocedor había entendido (y un error de transcripción se ejecutaba
    // igual). El envío queda en el botón; el modo manos libres es la
    // conversación continua (∞), que sí ejecuta directo.
  }

  /// VOICE-NATURAL-01 — activa/detiene el modo conversación continua. Tap en ∞
  /// inicia el ciclo (hablar ↔ responder ↔ volver a escuchar); tap en ■ lo
  /// detiene con barge-in. El dictado del mic sigue intacto.
  Future<void> _toggleConversation() async {
    final notifier = ref.read(chatProvider.notifier);
    if (notifier.isVoiceConversationActive) {
      notifier.stopVoiceConversation();
      if (mounted) setState(() => _conversationActive = false);
      return;
    }
    if (_listening) return; // dictado en curso: no pisar el micrófono
    setState(() => _conversationActive = true);
    final completed = await notifier.startVoiceConversation();
    if (mounted) setState(() => _conversationActive = false);
    if (!completed && mounted) {
      // El ciclo terminó sin escuchar nada: fallo del reconocedor o silencio
      // instantáneo. Aviso honesto en vez de "no pasó nada".
      _showHonestError(
        'No se pudo escuchar nada. Verifica el micrófono y la conexión.',
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Guard: el widget puede desmontarse antes de que se ejecute el callback.
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
