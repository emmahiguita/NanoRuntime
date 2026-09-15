import '../governance/action_confirmation.dart' show canonicalFingerprint;

/// Llamada a herramienta extraída de una respuesta del LLM.
class ToolCall {
  final String tool;
  final String? selector;
  final String? text;
  final String? key;

  /// Postcondiciones declaradas por el llamador (LLM o comando @):
  /// `{package, appear, disappear, text, forbidden}` — ver [ActionVerifier].
  final Map<String, dynamic>? expect;

  /// Argumentos tipados (A1, canónico desde A4): `args` es la vía preferente.
  /// `selector`/`text`/`key` quedan como aliases legacy (compat) leídos a
  /// través de los getters tipados de abajo.
  final Map<String, Object?>? args;
  const ToolCall({
    required this.tool,
    this.selector,
    this.text,
    this.key,
    this.expect,
    this.args,
  });

  // ── Getters tipados (args primero, fallback legacy) ──────────────────────
  // El dispatcher y el planner leen SOLO estos getters. Un tool nuevo puede
  // definir su propio getter (p. ej. `destinationArg`) sin sobrecargar
  // `selector`/`text`. A4 establece `args` como contrato canónico.

  /// Selector UI (tap/write/resolve). `args.selector` o `selector` legacy.
  String? get selectorArg => (args?['selector'] as String?) ?? selector;

  /// Texto de acción (write/reply). `args.text` o `text` legacy.
  String? get textArg => (args?['text'] as String?) ?? text;

  /// Key de notificación (reply_notification). `args.key` o `key` legacy.
  String? get keyArg => (args?['key'] as String?) ?? key;

  /// packageName para launch_app (A2). `args.packageName` o `selector` legacy.
  String? get packageNameArg => (args?['packageName'] as String?) ?? selector;

  /// destination para open_system (A3). Solo `args.destination`.
  String? get destinationArg => args?['destination'] as String?;

  /// path para herramientas Linux / FS. `args.path` o `textArg` / `selectorArg`.
  String? get pathArg => (args?['path'] as String?) ?? textArg ?? selectorArg;

  /// command para linux.run. `args.command` o `textArg`.
  String? get commandArg => (args?['command'] as String?) ?? textArg;

  /// Lee un input declarado por la política sin depender de si el caller usa
  /// `args` canónico o los aliases legacy. Esta validación ocurre de nuevo en
  /// el dispatcher para que el origen del plan no pueda omitirla.
  Object? inputValue(String input) => switch (input) {
    'selector' => selectorArg,
    'text' => textArg,
    'key' => keyArg,
    'packageName' => packageNameArg,
    'destination' => destinationArg,
    'url' || 'path' || 'command' || 'apkPath' => args?[input] ?? textArg,
    _ => args?[input],
  };

  bool hasInput(String input) {
    final value = inputValue(input);
    if (value == null) return false;
    return value is! String || value.trim().isNotEmpty;
  }

  /// Firma canónica para vincular una aprobación a esta llamada exacta.
  /// Incluye argumentos y postcondiciones; cambiar cualquier campo invalida
  /// el consentimiento pendiente.
  String get confirmationSignature => canonicalFingerprint({
    'tool': tool,
    'selector': selector,
    'text': text,
    'key': key,
    'expect': expect,
    'args': args,
  });
}
