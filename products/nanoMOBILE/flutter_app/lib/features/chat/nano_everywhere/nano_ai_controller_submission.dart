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

    // BUG-08 FIX: Resetear _lastQuery al inicio de cada submit().
    // Sin este reset, _lastQuery acumula una cadena de Futures encadenados
    // que crecen con cada mensaje. En sesiones largas (50+ mensajes) esto
    // genera presión de memoria y retrasos porque cada nuevo _serialAsk
    // debe esperar a que terminen todos los anteriores en la cadena.
    // Resetear aquí es seguro porque el token ya fue incrementado: cualquier
    // respuesta del Future anterior será descartada por _current(token).
    _lastQuery = Future<void>.value();
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

      // QUÉ: Si el error es login requerido Y hay un callback de UI conectado,
      //      mostrar el sheet y reintentar automáticamente si el usuario confirma.
      // POR QUÉ: Sin esto, el usuario solo ve un texto de error y no sabe qué hacer.
      //          Con onLoginRequired, el widget abre el sheet guiado de login.
      if (error is NanoUserActionRequiredException && onLoginRequired != null) {
        // Extraer el providerId del mensaje de error (el gateway lo incluye)
        // o usar el primer provider disponible como fallback.
        final providerId = providers.firstOrNull?.id ?? 'deepseek';
        activity = NanoActivity.idle;
        status = 'Iniciando sesión en el asistente web…';
        _emit();

        // Mostrar el sheet (el widget decide cómo — bottom sheet, dialog, etc.)
        final confirmed = await onLoginRequired!(providerId);

        if (!_current(token)) return; // cancelado por otra consulta
        if (confirmed) {
          // Usuario confirmó login → reintentar la misma consulta
          status = 'Reintentando consulta…';
          activity = NanoActivity.thinking;
          _emit();
          // submit() usa un nuevo token, así que esta llamada es limpia
          await submit(input);
          return; // submit() ya llama a _emit() internamente
        }
        // Usuario canceló → mensaje amigable sin stack trace
        activity = NanoActivity.idle;
        status = 'Sesión no iniciada. Cuando estés listo, reenvía tu mensaje.';
        _emit();
        return;
      }

      // Error no relacionado con login: comportamiento anterior
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
