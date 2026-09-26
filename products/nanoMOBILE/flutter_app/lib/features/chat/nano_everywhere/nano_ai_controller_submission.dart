part of 'nano_ai_controller.dart';

/// Mantiene en una unidad el turno conversacional, su ruta y su diagnóstico.
extension NanoAiControllerSubmission on NanoAiController {
  /// Resuelve saludos locales y, si hace falta, consulta una sola ruta por turno.
  Future<void> submit(String input, {Iterable<String>? selectedIds}) async {
    final prompt = input.trim();
    if (_disposed || prompt.isEmpty) return;
    if ({NanoActivity.thinking, NanoActivity.acting}.contains(activity)) return;

    // Normaliza modos antiguos para que un Intent legado no active comparación.
    if (mode == NanoMode.compare || mode == NanoMode.debate) {
      mode = NanoMode.quick;
    }
    final token = ++_requestId;
    if (mode == NanoMode.quick &&
        NanoMediaDetector.shouldAutoDetectMedia(prompt)) {
      mode = NanoMode.media;
    }
    answers = const [];
    suggestions = const [];
    detectedMedia = const [];
    activity = mode == NanoMode.action
        ? NanoActivity.acting
        : NanoActivity.thinking;
    status = mode == NanoMode.media
        ? 'Buscando archivos multimedia…'
        : 'Preparando una respuesta…';
    _emit();

    try {
      if (mode == NanoMode.media) {
        final items = await _mediaDetector.detect(prompt);
        if (!_current(token)) return;
        detectedMedia = items;
        activity = items.isNotEmpty ? NanoActivity.success : NanoActivity.error;
        status = items.isNotEmpty
            ? '${items.length} opciones listas para descargar (MP4 / MP3)'
            : 'No se encontraron archivos descargables en este enlace.';
        _emit();
        return;
      }
      if (mode == NanoMode.action) {
        final result = await actions.executeAuthorizedGoal(prompt);
        if (!_current(token)) return;
        status = result;
        activity = NanoActivity.success;
        suggestions = ChatSuggestionEngine.derive(result);
        _emit();
        return;
      }

      final local = const NativeConversationalRouter().tryResolve(prompt);
      if (local != null) {
        final provider =
            providers.firstOrNull ??
            const NanoProvider(
              id: 'nano_local',
              name: 'Nano',
              kind: NanoProviderKind.local,
            );
        answers = [
          NanoAnswer(provider: provider, requestId: token, text: local.text),
        ];
        suggestions = local.suggestions;
        activity = NanoActivity.success;
        status = 'Listo.';
        _emit();
        return;
      }

      final route = providers.firstWhere(
        (provider) =>
            provider.supportsProgrammaticQuery &&
            (selectedIds == null || selectedIds.contains(provider.id)),
        orElse: () =>
            throw StateError('No hay una conexión lista para responder.'),
      );
      // Una ruta por turno evita duplicar consultas y respuestas visibles.
      final answer = await _serialAsk(route, prompt, token);
      if (!_current(token)) return;
      answers = [answer];
      _emit();
      if (!answer.ok) {
        throw StateError(
          'No pude generar una respuesta. Revisa la conexión e inténtalo de nuevo.',
        );
      }
      suggestions = ChatSuggestionEngine.derive(answer.text);
      activity = NanoActivity.success;
      status = 'Listo.';
    } catch (error, stackTrace) {
      if (!_current(token)) return;
      debugPrint('[nano-assistant][${mode.name}] ${error.runtimeType}: $error');
      debugPrintStack(stackTrace: stackTrace);
      activity = NanoActivity.error;
      status = switch (error) {
        NanoUserActionRequiredException action => action.message,
        StateError stateError => stateError.message.toString(),
        _ => 'No pude completar la respuesta. Inténtalo de nuevo.',
      };
    }
    _emit();
  }

  /// Serializa consultas y descarta las que fueron canceladas antes de empezar.
  Future<NanoAnswer> _serialAsk(NanoProvider provider, String prompt, int id) {
    final next = _lastQuery.then<NanoAnswer>(
      (_) => _current(id)
          ? _ask(provider, prompt, id)
          : NanoAnswer(
              provider: provider,
              requestId: id,
              error: 'Consulta descartada',
            ),
    );
    _lastQuery = next.then((_) {});
    return next;
  }

  /// Registra ruta y excepción para diagnóstico, sin guardar el texto personal enviado.
  Future<NanoAnswer> _ask(NanoProvider provider, String prompt, int id) async {
    try {
      final text = (await provider.ask!(prompt)).trim();
      if (text.isEmpty) {
        debugPrint('[nano-assistant][route:${provider.id}] respuesta vacía.');
      }
      return NanoAnswer(
        provider: provider,
        requestId: id,
        text: text,
        error: text.isEmpty ? 'Respuesta vacía' : null,
      );
    } catch (error, stackTrace) {
      if (error is NanoUserActionRequiredException) rethrow;
      debugPrint(
        '[nano-assistant][route:${provider.id}] ${error.runtimeType}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return NanoAnswer(
        provider: provider,
        requestId: id,
        error: error.toString(),
      );
    }
  }
}
