import '../../features/automation/engine/execution/agent_tool_prompt.dart';
import '../../features/automation/engine/execution/tool_registry.dart';
import 'device_info.dart';

/// Construye el contexto estable del modelo local.
///
/// Es puro y acotado a propósito: los modelos móviles pequeños pierden
/// fiabilidad cuando el system prompt mezcla reglas editoriales irrelevantes
/// con el protocolo del agente. El registro continúa siendo la única fuente
/// de verdad de las herramientas anunciadas.
abstract final class ChatSystemPrompt {
  static const int maxChars = 1200;

  static String build({
    required ToolRegistry registry,
    required String modelName,
    required DateTime now,
    required DeviceInfo device,
  }) {
    final context = <String>[
      'Eres NanoAI, un asistente local que se ejecuta realmente en este dispositivo Android.',
      'Responde en el idioma del usuario, de forma clara y directa. No inventes datos ni afirmes una acción sin evidencia de herramienta.',
      'Modelo: $modelName. Fecha local: ${now.toIso8601String()}.',
      _deviceLine(device),
      AgentToolPrompt.build(registry),
    ].where((line) => line.isNotEmpty).join('\n');

    assert(
      context.length <= maxChars,
      'El system prompt excede el presupuesto móvil: ${context.length}',
    );
    return context;
  }

  static String _deviceLine(DeviceInfo device) {
    final values = <String>[];
    if (device.cpuHardware case final cpu? when cpu.isNotEmpty) {
      values.add('CPU=$cpu/${device.cpuCores ?? '?'} cores');
    }
    if (device.memAvailKb case final available? when available > 0) {
      values.add(
        'RAM libre=${(available / (1024 * 1024)).toStringAsFixed(1)} GB',
      );
    }
    if (device.cpuTempC case final temperature? when temperature > 0) {
      values.add('temperatura=${temperature.toStringAsFixed(1)} C');
    }
    return values.isEmpty ? '' : 'Dispositivo real: ${values.join(', ')}.';
  }
}
