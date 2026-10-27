part of 'nano_ai_controller.dart';

/// Admisión atómica: ninguna petición puede recibir respuestas de otro turno.
extension NanoAiControllerSubmission on NanoAiController {
  /// Un modo solicitado se aplica solo después de aceptar la tarea; cancelar
  /// invalida su resultado, pero no permite solapar trabajo todavía pendiente.
  Future<NanoTurnReceipt> submit(
    String input, {
    Iterable<String>? selectedIds,
    NanoMode? requestedMode,
  }) async {
    final prompt = input.trim();
    if (_disposed || prompt.isEmpty) {
      return NanoTurnReceipt(
        _requestId,
        NanoTurnOutcome.failed,
        'Escribe una instrucción.',
        accepted: false,
      );
    }
    if (isBusy || activity == NanoActivity.acting) {
      return NanoTurnReceipt(
        _requestId,
        NanoTurnOutcome.busy,
        'Hay una petición en curso. Espera su resultado.',
        accepted: false,
      );
    }
    _turnActive = true;
    final token = ++_requestId;
    final turnMode = switch (requestedMode ?? mode) {
      NanoMode.action => NanoMode.action,
      NanoMode.media => NanoMode.media,
      _ => NanoMode.quick,
    };
    mode = turnMode;
    _mediaDownloader.cancelActive();
    answers = const [];
    suggestions = const [];
    detectedMedia = const [];
    activity = turnMode == NanoMode.action
        ? NanoActivity.acting
        : NanoActivity.thinking;
    status = turnMode == NanoMode.media
        ? 'Buscando archivos multimedia…'
        : 'Procesando…';
    _emit();
    try {
      if (turnMode == NanoMode.media) {
        final items = await _mediaDetector.detect(prompt);
        if (!_current(token)) return _cancelled(token);
        detectedMedia = items;
        activity = items.isEmpty ? NanoActivity.error : NanoActivity.success;
        status = items.isEmpty
            ? 'No se encontraron recursos en este enlace.'
            : '${items.length} recursos detectados; la descarga se confirma al guardar.';
        return NanoTurnReceipt(
          token,
          items.isEmpty ? NanoTurnOutcome.failed : NanoTurnOutcome.answered,
          status,
        );
      }
      if (turnMode == NanoMode.action) {
        final text = await actions.executeAuthorizedGoal(prompt);
        if (!_current(token)) return _cancelled(token);
        final receipt = NanoTurnReceipt.fromExecution(token, text);
        status = receipt.text;
        activity = receipt.outcome == NanoTurnOutcome.failed
            ? NanoActivity.error
            : NanoActivity.idle;
        return receipt;
      }
      final answer = await _query(prompt, token, selectedIds);
      if (!_current(token)) return _cancelled(token);
      answers = [answer];
      if (!answer.ok) throw StateError(answer.error ?? 'Respuesta vacía.');
      activity = NanoActivity.success;
      status = 'Listo.';
      suggestions = ChatSuggestionEngine.derive(answer.text);
      return NanoTurnReceipt(token, NanoTurnOutcome.answered, answer.text);
    } catch (error) {
      if (!_current(token)) return _cancelled(token);
      activity = NanoActivity.error;
      status = switch (error) {
        NanoUserActionRequiredException action => action.message,
        StateError stateError => stateError.message.toString(),
        TimeoutException _ =>
          'La consulta dejó de avanzar. Se solicitó detenerla.',
        _ => 'No se pudo completar la petición. Revisa la conexión.',
      };
      return NanoTurnReceipt(token, NanoTurnOutcome.failed, status);
    } finally {
      _activeProvider = null;
      _turnActive = false;
      _emit();
    }
  }

  /// Un resultado cancelado no puede transformarse en la respuesta de otra tarea.
  NanoTurnReceipt _cancelled(int id) => NanoTurnReceipt(
    id,
    NanoTurnOutcome.cancelled,
    'Petición detenida; revisa cualquier acción iniciada.',
  );
}
