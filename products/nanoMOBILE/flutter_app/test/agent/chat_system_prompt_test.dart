import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/services/chat_system_prompt.dart';
import 'package:nanoai/core/services/device_info.dart';
import 'package:nanoai/features/automation/engine/execution/tool_registry.dart';

void main() {
  test('prompt móvil es compacto, real y conserva las reglas de respuesta', () {
    final prompt = ChatSystemPrompt.build(
      registry: ToolRegistry.builtin,
      modelName: 'qwen.gguf',
      now: DateTime.utc(2026, 8, 24, 21, 0),
      device: const DeviceInfo(
        cpuHardware: 'ARMv8',
        cpuCores: 8,
        memAvailKb: 3 * 1024 * 1024,
        cpuTempC: 40,
      ),
    );

    expect(prompt.length, lessThanOrEqualTo(ChatSystemPrompt.maxChars));
    expect(prompt, contains('realmente en este dispositivo Android'));
    expect(prompt, contains('{"tool":"notifications"}'));
    expect(prompt, contains('canReply=true'));
    expect(prompt, contains('requiere confirmación humana'));
    expect(prompt, isNot(contains('TABLAS DE DATOS')));
    expect(prompt, isNot(contains('diagramas mermaid')));
  });
}
