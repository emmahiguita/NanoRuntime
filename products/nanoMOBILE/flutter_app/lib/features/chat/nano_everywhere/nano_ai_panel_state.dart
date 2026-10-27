part of 'nano_ai_controller.dart';

/// Estado de presentación separado de inferencia y ejecución.
extension NanoAiPanelState on NanoAiController {
  /// Prepara texto en el editor visible, sin consultar ni ejecutar.
  void queuePrompt(String prompt) {
    if (prompt.trim().isNotEmpty) {
      _pendingPrompt = prompt;
      _pendingIsDictation = false;
      isVisible = true;
      _emit();
    }
  }

  /// Añade voz al borrador actual: conservar el destinatario evita convertir
  /// una instrucción parcial en otra orden. Reconocer voz nunca ejecuta.
  void queueDictation(String text) {
    if (text.trim().isEmpty || _disposed) return;
    _pendingPrompt = text.trim();
    _pendingIsDictation = true;
    isVisible = true;
    _emit();
  }

  /// Solicita abrir el panel; un prompt opcional sigue siendo un borrador.
  void expand([String? prompt]) {
    _requestExpand = true;
    isVisible = true;
    if (prompt != null && prompt.trim().isNotEmpty) {
      _pendingPrompt = prompt.trim();
      _pendingIsDictation = false;
    }
    _emit();
  }

  /// Oculta la interfaz sin atribuir cancelación a una operación externa.
  void hide() {
    isVisible = false;
    _requestExpand = false;
    _emit();
  }

  /// Alterna presentación usando las mismas solicitudes de abrir y ocultar.
  void toggle() {
    isVisible ? hide() : expand();
  }

  /// Consume la solicitud una sola vez para no reabrir en cada notificación.
  bool checkAndClearExpandRequest() {
    final r = _requestExpand;
    _requestExpand = false;
    return r;
  }

  /// Transfiere el borrador al editor sin retener otra copia pendiente.
  String? takePendingPrompt({String currentText = ''}) {
    final r = _pendingPrompt;
    final append = _pendingIsDictation;
    _pendingPrompt = null;
    _pendingIsDictation = false;
    if (r == null || !append || currentText.trim().isEmpty) return r;
    return '${currentText.trimRight()} $r';
  }
}
