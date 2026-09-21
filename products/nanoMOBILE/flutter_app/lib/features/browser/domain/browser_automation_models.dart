import 'dart:typed_data';

/// Tipo de acción automatizada en el navegador
enum BrowserAutomationActionType {
  navigate,
  click,
  fillInput,
  scroll,
  wait,
  extractText,
  screenshot,
}

/// Paso ejecutable de automatización web
class BrowserAutomationStep {
  final BrowserAutomationActionType type;
  final String? url;
  final String? selector;
  final String? value;
  final int? scrollY;
  final Duration? delay;
  final String description;

  const BrowserAutomationStep({
    required this.type,
    this.url,
    this.selector,
    this.value,
    this.scrollY,
    this.delay,
    required this.description,
  });
}

/// Resultado de una ejecución de automatización
class BrowserAutomationResult {
  final bool success;
  final String? extractedContent;
  final Uint8List? screenshot;
  final String? error;
  final Duration elapsed;

  const BrowserAutomationResult({
    required this.success,
    this.extractedContent,
    this.screenshot,
    this.error,
    required this.elapsed,
  });
}
