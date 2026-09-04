import '../../features/automation/engine/execution/agent_tool_prompt.dart';
import '../../features/automation/engine/execution/tool_registry.dart';
import '../models/chat_models.dart';
import 'device_info.dart';

/// Construye el contexto estable del modelo local.
///
/// Es puro y acotado a propósito: los modelos móviles pequeños pierden
/// fiabilidad cuando el system prompt mezcla reglas editoriales irrelevantes
/// con el protocolo del agente. El registro continúa siendo la única fuente
/// de verdad de las herramientas anunciadas.
abstract final class ChatSystemPrompt {
  static const int maxChars = 2200;

  static String build({
    required ToolRegistry registry,
    required String modelName,
    required DateTime now,
    required DeviceInfo device,
  }) {
    final core = <String>[
      'Eres NanoAI, un asistente local que se ejecuta realmente en este dispositivo Android.',
      'Responde SIEMPRE en el idioma del usuario. En español usa ortografía completa: tildes, «ñ», signos de apertura (¿ ¡) y puntuación correctos. Sé claro y directo. No inventes datos ni afirmes una acción sin evidencia de herramienta.',
      'Modelo: $modelName. Fecha local: ${now.toIso8601String()}.',
      _deviceLine(device),
    ].where((line) => line.isNotEmpty).join('\n');

    // El bloque de herramientas NUNCA se trunca a mitad: un formato de agente
    // cortado desboca la generación (bug real — el recorte por substring dejó
    // al modelo generando 1300+ tokens sin fin). Si no cabe entero, se omite
    // completo con marca honesta; jamás se parte.
    final toolsBlock = AgentToolPrompt.build(registry);
    final context = core.length + 1 + toolsBlock.length <= maxChars
        ? '$core\n$toolsBlock'
        : '$core\n[herramientas omitidas: exceden el presupuesto móvil]';
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

  /// Escapa tokens especiales de plantilla (ChatML/Gemma/Llama) para que el
  /// modelo no los interprete como marcadores de conversación — anti-inyección
  /// de formato en texto no confiable. Puro y reutilizable.
  static String promptSafe(String value) => value
      .replaceAll('<|im_start|>', '< |im_start| >')
      .replaceAll('<|im_end|>', '< |im_end| >')
      .replaceAll(
        '<\uFF5Cbegin\u2581of\u2581sentence\uFF5C>',
        '< |begin_of_sentence| >',
      )
      .replaceAll(
        '<\uFF5Cend\u2581of\u2581sentence\uFF5C>',
        '< |end_of_sentence| >',
      )
      .replaceAll('<|start_header_id|>', '< |start_header_id| >')
      .replaceAll('<|end_header_id|>', '< |end_header_id| >')
      .replaceAll('<|eot_id|>', '< |eot_id| >')
      .replaceAll('<|begin_of_text|>', '< |begin_of_text| >')
      .replaceAll('<start_of_turn>', '< start_of_turn >')
      .replaceAll('<end_of_turn>', '< end_of_turn >')
      .replaceAll('[INST]', '[ INST ]')
      .replaceAll('[/INST]', '[ /INST ]');

  /// Recorta a [maxChars] tras escapar, con marca de recorte.
  static String promptClip(String value, int maxChars) {
    final safe = promptSafe(value);
    if (safe.length <= maxChars) return safe;
    return '${safe.substring(0, maxChars)}\n[recortado]';
  }

  /// Bloque de adjuntos inyectado al turno user del prompt: contenido REAL del
  /// archivo, delimitado para que el modelo lo distinga del texto del usuario.
  static String attachmentsBlock(
    List<ChatAttachment> attachments,
    int maxAttachmentChars,
  ) {
    final buffer = StringBuffer();
    for (final a in attachments) {
      buffer
        ..writeln('[Adjunto: ${promptClip(a.name, 160)}]')
        ..writeln(promptClip(a.content, maxAttachmentChars))
        ..writeln('[Fin de adjunto]');
    }
    return buffer.toString();
  }
}
