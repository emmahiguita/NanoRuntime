import '../engine/execution/handlers/whatsapp_command_input.dart';
import 'automation_activity_store.dart';

/// Resume la llamada realmente despachada sin persistir texto del mensaje,
/// valores de formularios, contenido del documento ni claves de otras herramientas.
class AutomationCommandAudit {
  AutomationCommandAudit(String command, String? executionId)
    : runId = executionId ?? 'command-${DateTime.now().microsecondsSinceEpoch}',
      verb = command.trim().split(RegExp(r'\s+')).first {
    final match = RegExp(
      r'^@(whatsapp|wpp)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(command.trim());
    if (match != null && match[2] != '--estado') {
      final input = WhatsAppCommandInput.parse(match[2]!);
      target = input?.contact ?? '';
      action = input == null
          ? 'whatsapp'
          : input.message.startsWith('--archivo ')
          ? 'whatsapp.share_file'
          : input.message.isEmpty
          ? 'whatsapp.open_chat'
          : 'whatsapp.send_message';
    } else {
      action = match == null ? verb : 'whatsapp.status';
    }
  }
  final String runId, verb;
  late final String action;
  String target = '';
  final _store = AutomationActivityStore.instance;

  void started() => _store.record(
    runId: runId,
    route: 'Nano → router → $action',
    state: 'call',
    target: target,
    detail:
        'Llamada iniciada por la entrada de acciones. No acredita su efecto.',
  );

  void finished(String feedback) {
    final marker = RegExp(r'^\[([^\]]+)\]').firstMatch(feedback)?.group(1);
    _store.record(
      runId: runId,
      route: '$action → Nano',
      state: marker ?? 'unverified',
      target: target,
      detail: action.startsWith('whatsapp.')
          ? feedback
          : 'La herramienta devolvió ${marker ?? 'un resultado sin verificación explícita'}.',
    );
  }

  void failed(Object error) => _store.record(
    runId: runId,
    route: '$action → Nano',
    state: 'failed',
    target: target,
    detail: 'La llamada terminó con ${error.runtimeType}.',
  );
}
