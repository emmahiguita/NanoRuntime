/// GAP-02 — LinuxCandidateProvider: adapta [LinuxVoiceCommandParser] al
/// contrato de [CandidateProvider] para que el [CandidateFirstPlanner] pueda
/// resolver goals Linux deterministas SIN invocar el LLM.
///
/// Fuente: [ActionEvidenceSource.linuxToolRegistry] (ya declarado en el modelo).
/// Canal: [ActionChannel.linux] (ya declarado).
/// Riesgo: read para list/readFile; device para writeFile/run.
library;

import '../../execution/tool_registry.dart' show ToolRisk;
import '../../system/system_capability.dart' show SystemCapability;
import '../linux_voice_command_parser.dart' show LinuxVoiceCommandParser;
import 'candidate_action.dart';
import 'candidate_provider.dart';

class LinuxCandidateProvider implements CandidateProvider {
  LinuxCandidateProvider({
    LinuxVoiceCommandParser parser = const LinuxVoiceCommandParser(),
    String? lastFilePath,
  }) : _parser = parser,
       _lastFilePath = lastFilePath;

  final LinuxVoiceCommandParser _parser;

  /// Ruta del último archivo mencionado en esta sesión. Opcional.
  final String? _lastFilePath;

  @override
  String get id => 'linux';

  @override
  Future<List<CandidateAction>> provide(CandidateRequest request) async {
    final parsed = _parser.parse(
      request.goal,
      lastFilePath: _lastFilePath,
    );
    if (parsed == null) return const [];

    final call = parsed.call;
    final tool = call.tool;

    final risk = (tool == 'linux.list' || tool == 'linux.readFile')
        ? ToolRisk.read
        : ToolRisk.device;

    final reversible = risk == ToolRisk.read;

    final Map<String, Object?> args;
    switch (tool) {
      case 'linux.writeFile':
        args = {
          'path': call.textArg ?? call.selectorArg ?? '',
          'content': (call.args?['content'] as String?) ?? '',
        };
      case 'linux.readFile':
      case 'linux.list':
        args = {'path': call.textArg ?? call.selectorArg ?? ''};
      default:
        args = call.args ?? {'command': call.textArg ?? ''};
    }

    final primaryKey = (args['path'] ?? args['command'] ?? '').toString();
    final candidateId = CandidateId('linux:$tool:$primaryKey');

    return [
      CandidateAction(
        id: candidateId,
        semanticAction: _semanticFor(tool),
        tool: tool,
        args: args,
        channel: ActionChannel.linux,
        groundingConfidence: 0.95,
        risk: risk,
        reversible: reversible,
        requiredCapabilities: const {SystemCapability.linuxExecution},
        evidence: [
          ActionEvidence(
            source: ActionEvidenceSource.linuxToolRegistry,
            reference: 'LinuxVoiceCommandParser:$tool',
            confidence: 0.95,
          ),
        ],
      ),
    ];
  }

  static String _semanticFor(String tool) => switch (tool) {
    'linux.list' => 'linux_list_files',
    'linux.readFile' => 'linux_read_file',
    'linux.writeFile' => 'linux_write_file',
    'linux.run' => 'linux_run_command',
    _ => tool,
  };
}
