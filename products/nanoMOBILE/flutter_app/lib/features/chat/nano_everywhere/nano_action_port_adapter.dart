import 'nano_action_intent_resolver.dart';
export 'nano_action_intent_resolver.dart' show NanoActionIntentResolver;
import 'nano_ai_models.dart';
import 'nano_workspace_commands.dart';
import '../../automation/application/automation_artifact_commands.dart';
import 'nano_action_input.dart';
import '../../automation/engine/planning/whatsapp_automation_input.dart';
import '../../automation/engine/planning/whatsapp_current_chat_request.dart';
import '../../automation/engine/execution/agent_tool_dispatcher.dart';

/// Traduce órdenes explícitas del Búho al mismo coordinador y sus permisos.
/// Cada turno conserva su identidad hasta terminar, incluso al preparar un PDF.
class NanoActionPortAdapter implements NanoCancellableActionPort {
  /// Inyecta el coordinador propietario; el dispatcher conserva compatibilidad.
  NanoActionPortAdapter(
    this._dispatcher, {
    Future<String> Function(String)? runCommand,
    Future<String> Function(String, String)? runOwnedCommand,
    bool Function(String)? cancelOwnedCommand,
    Future<String> Function(String, String, bool Function())? runOwnedGoal,
    void Function()? cancelGoal,
    this.workspace,
  }) : _goal = runOwnedGoal,
       _cancelGoal = cancelGoal,
       _command = runCommand,
       _ownedCommand = runOwnedCommand,
       _cancelOwnedCommand = cancelOwnedCommand;

  final AgentToolDispatcher _dispatcher;
  final NanoWorkspaceCommands? workspace;
  final Future<String> Function(String)? _command;
  final Future<String> Function(String, String)? _ownedCommand;
  final bool Function(String)? _cancelOwnedCommand;
  final Future<String> Function(String, String, bool Function())? _goal;
  final void Function()? _cancelGoal;
  String? _executionId;
  bool _cancelled = false;

  /// Revalida cancelación inmediatamente antes de cualquier efecto externo.
  Future<String> _runCommand(String command) {
    if (_cancelled) return Future.value('[cancelled] Acción cancelada.');
    return _ownedCommand != null
        ? _ownedCommand(command, _executionId!)
        : (_command ?? _dispatcher.runCommand)(command);
  }

  /// Invalida preparación local y solicita detener solo la ejecución de este Búho.
  @override
  void cancelActiveAction() {
    workspace?.cancel();
    _cancelled = true;
    _cancelGoal?.call();
    final id = _executionId;
    if (id != null) _cancelOwnedCommand?.call(id);
  }

  /// Admite un único efecto por turno y publica errores con estado explícito.
  @override
  Future<String> executeAuthorizedGoal(String goal) async {
    if (_executionId != null) {
      return '[error] Otra acción del flotante sigue en curso.';
    }
    // Otra instrucción revoca la autorización pendiente del objetivo anterior.
    if (!NanoActionInput.isConfirm(goal)) _cancelGoal?.call();
    _executionId = 'overlay-${DateTime.now().microsecondsSinceEpoch}';
    _cancelled = false;
    try {
      return await _executeGoal(goal.trim());
    } on FormatException catch (error) {
      return '[clarification] ${error.message}';
    } catch (error) {
      return '[error] Error al ejecutar acción: $error';
    } finally {
      _executionId = null;
    }
  }

  /// Reserva primero el chat actual: su texto es dato, no una orden de archivos
  /// ni otra aplicación. Después conserva los adaptadores de las demás acciones.
  Future<String> _executeGoal(String clean) async {
    if (clean.isEmpty) return '[clarification] Indica la acción que deseas.';
    if (WhatsAppCurrentChatRequest.parse(clean) != null) {
      final owner = _goal;
      if (owner == null) {
        return '[error] No está disponible el coordinador del chat actual.';
      }
      final id = _executionId!;
      return owner(clean, id, () => !_cancelled && _executionId == id);
    }
    final local = await workspace?.execute(
      clean,
      command: _runCommand,
      cancelled: () => _cancelled,
    );
    if (local != null) return local;
    final artifact = await NanoArtifactCommands.execute(
      clean,
      runCommand: _runCommand,
      isCancelled: () => _cancelled,
    );
    if (artifact != null) return artifact;
    final intent = NanoActionIntentResolver.resolve(clean);
    final goal = _goal;
    if (goal != null &&
        intent == NanoActionIntent.whatsApp &&
        !NanoActionInput.isNavigationSequence(clean)) {
      String? atomic;
      try {
        atomic = WhatsAppAutomationInput.command(clean);
      } on FormatException {
        // Solo falla la preparación pura: todavía no hubo ningún efecto.
        // Una orden de navegación no reconocida aquí pertenece a runGoal.
      }
      if (atomic != null && AgentToolDispatcher.isToolCommand(atomic)) {
        return _runCommand(atomic);
      }
    }
    if (goal != null &&
        (NanoActionInput.isConfirm(clean) ||
            NanoActionInput.isNavigationSequence(clean) ||
            !const {
              NanoActionIntent.directCommand,
              NanoActionIntent.navBack,
              NanoActionIntent.navHome,
              NanoActionIntent.navRecents,
              NanoActionIntent.readScreen,
              NanoActionIntent.telegram,
              NanoActionIntent.messenger,
            }.contains(intent))) {
      final id = _executionId!;
      return goal(clean, id, () => !_cancelled && _executionId == id);
    }
    return switch (intent) {
      NanoActionIntent.directCommand => await _runCommand(clean),
      NanoActionIntent.navBack => await _runCommand('@back'),
      NanoActionIntent.navHome => await _runCommand('@home'),
      NanoActionIntent.navRecents => await _runCommand('@recents'),
      NanoActionIntent.readScreen => await _runCommand('@leer_pantalla'),
      // El normalizador compartido mantiene findContact como @contactos y
      // conserva nombres completos; nunca envía una búsqueda como mensaje.
      NanoActionIntent.whatsApp => await _runCommand(
        WhatsAppAutomationInput.command(clean),
      ),
      NanoActionIntent.telegram => await _resolveMessaging(
        clean,
        'telegram',
        r'envía|envia|enviar|manda|telegram|tg',
      ),
      NanoActionIntent.messenger => await _resolveMessaging(
        clean,
        'messenger',
        r'envía|envia|enviar|manda|messenger|facebook|fb',
      ),
      NanoActionIntent.tapElement => await _runCommand(
        '@tap text="${_argument(clean)}"',
      ),
      NanoActionIntent.typeText => await _runCommand(
        '@escribir ${_argument(clean)} | editable=true',
      ),
      NanoActionIntent.openApp => await _runCommand(
        '@abrir ${_argument(clean)}',
      ),
      NanoActionIntent.unknown =>
        '[clarification] No reconocí esa acción. Indica qué deseas hacer, '
            'sobre qué elemento y, si vas a compartir, con quién.',
    };
  }

  /// Separa solo el verbo inicial; mantiene espacios internos del argumento.
  String _argument(String text) => text.replaceFirst(RegExp(r'^\S+\s+'), '');

  /// Conserva las rutas existentes de Telegram y Messenger, sin otro ejecutor.
  Future<String> _resolveMessaging(
    String text,
    String command,
    String verbs,
  ) async {
    final match = RegExp(
      '(?:$verbs)\\s+(?:a\\s+)?([a-zA-Z0-9_áéíóúÁÉÍÓÚñÑ\\s@]+?)(?:\\s+(?:que|diciendo|:)\\s+(.+))?\$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      final contact = match.group(1)?.trim() ?? '';
      final message = match.group(2)?.trim() ?? '';
      if (contact.isNotEmpty && message.isNotEmpty) {
        return _runCommand('@$command $contact $message');
      }
    }
    return _runCommand('@$command $text');
  }
}
