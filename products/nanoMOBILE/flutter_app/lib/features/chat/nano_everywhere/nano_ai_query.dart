part of 'nano_ai_controller.dart';

/// Conversación y login poseen su ciclo; nunca convierten una consulta en envío.
extension _NanoAiQuery on NanoAiController {
  /// Solo una intervención de login por turno. La selección no cambia de modelo
  /// ni transmite el mensaje a otro proveedor tras un fallo de inferencia.
  Future<NanoAnswer> _query(
    String prompt,
    int token,
    Iterable<String>? ids,
  ) async {
    final provider = providers.firstWhere(
      (p) => p.supportsProgrammaticQuery && (ids == null || ids.contains(p.id)),
      orElse: () =>
          throw StateError('No hay una ruta de consulta configurada.'),
    );
    if (provider.isReady?.call() == false) {
      throw StateError(
        provider.unavailableReason?.call() ?? 'El modelo no está listo.',
      );
    }
    _activeProvider = provider;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final text = (await provider.ask!(prompt)).trim();
        return NanoAnswer(
          provider: provider,
          requestId: token,
          text: text,
          error: text.isEmpty
              ? 'El modelo devolvió una respuesta vacía.'
              : null,
        );
      } on NanoUserActionRequiredException {
        if (attempt != 0 || onLoginRequired == null || !_current(token)) {
          rethrow;
        }
        status = 'La conexión necesita iniciar sesión.';
        _emit();
        if (!await onLoginRequired!(provider.id) || !_current(token)) {
          throw StateError('Sesión no iniciada; la consulta no se repitió.');
        }
      }
    }
    throw StateError('No se pudo completar la consulta.');
  }
}
