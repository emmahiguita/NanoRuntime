import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_prompt.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';

void main() {
  test('prompt se deriva del registro sin tools duplicadas', () {
    final registry = ToolRegistry.builtin;
    final prompt = AgentToolPrompt.build(registry);
    final advertised = registry.all
        .where((definition) => definition.promptSyntax != null)
        .toList(growable: false);

    for (final definition in advertised) {
      expect(
        definition.promptSyntax!.allMatches(prompt),
        hasLength(1),
        reason: '${definition.name} debe anunciarse exactamente una vez',
      );
    }
    expect(prompt, contains('canReply=true'));
    expect(prompt, contains('copia su key exacta'));
    expect(prompt, contains('pregunta al usuario; no respondas'));
    expect(prompt, isNot(contains('{"tool":"launch_app"')));
  });
}
