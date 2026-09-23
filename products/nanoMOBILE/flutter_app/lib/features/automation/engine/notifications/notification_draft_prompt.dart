/// QUÉ HACE:
/// Ensambla y parametriza los prompts de redacción para notificaciones entrantes,
/// inyectando memoria conversacional, estilo del dueño, hechos comerciales y tono.
///
/// CÓMO FUNCIONA:
/// Recibe datos no confiables de la notificación y los sanitiza dentro de plantillas
/// delimitadas. Formatea el historial de diálogo reciente y parsea sugerencias múltiples.
///
/// POR QUÉ:
/// Garantiza que el LLM reciba un contexto ordenado, seguro y libre de inyecciones,
/// resolviendo intenciones múltiples y delegando las plantillas a su propio módulo (<200 líneas).
library;

import '../messaging/conversation_memory.dart'
    show ConversationMemoryEntry, ConversationMemoryEntryKind;
import 'conversation_prompt_templates.dart';

export 'conversation_prompt_templates.dart';

String notificationDraftPromptFor({required String text, String? style}) {
  final base = notificationDraftPrompt.replaceFirst('{text}', text);
  final s = _usableStyle(style);
  if (s == null) return base;
  return '$base\n\n${_styleBlock(s)}';
}

String notificationSuggestionsPromptFor({required String text, String? style}) {
  final base = notificationSuggestionsPrompt.replaceFirst('{text}', text);
  final s = _usableStyle(style);
  if (s == null) return base;
  return '$base\n\n${_styleBlock(s)}';
}

/// Parsea la salida del modelo a variantes limpias, descartando duplicados y etiquetas de eco.
List<String> parseNotificationSuggestions(
  String raw, {
  int maxSuggestions = 3,
  String? packageName,
}) {
  final out = <String>[];
  for (final line in raw.split('\n')) {
    var candidate = line.trim();
    if (candidate.isEmpty) continue;
    if (candidate.startsWith('- ')) candidate = candidate.substring(2);
    final numbering = RegExp(r'^[0-9]+[.)]\s+');
    candidate = candidate.replaceFirst(numbering, '').trim();
    if (candidate.isEmpty || out.contains(candidate)) continue;

    final lowered = candidate.toLowerCase();
    if (packageName != null &&
        packageName.isNotEmpty &&
        lowered.contains(packageName.toLowerCase())) {
      continue;
    }
    if (lowered.contains('aplicación:') ||
        lowered.contains('aplicacion:') ||
        lowered.contains('título:') ||
        lowered.contains('titulo:') ||
        lowered.contains('variantes') ||
        lowered.contains('notificación:')) {
      continue;
    }
    out.add(
      candidate.length <= 2000 ? candidate : candidate.substring(0, 2000),
    );
    if (out.length >= maxSuggestions) break;
  }
  return out;
}

String conversationSocialPromptFor({
  required String text,
  String? style,
  String? persona,
  String? tone,
  String? history,
  String? temporalContext,
  String? agentContract,
}) {
  final base = conversationSocialPrompt
      .replaceFirst('{history}', history ?? '(sin historial previo)')
      .replaceFirst('{text}', text);
  final s = _usableStyle(style);
  final p = persona?.trim() ?? '';
  final t = tone?.trim() ?? '';
  final temp = temporalContext?.trim() ?? '';
  final contract = agentContract?.trim() ?? '';
  if (s == null && p.isEmpty && t.isEmpty && temp.isEmpty && contract.isEmpty) {
    return base;
  }
  final prefix = <String>[
    if (contract.isNotEmpty) contract,
    if (temp.isNotEmpty) temp,
    if (s != null) _styleBlock(s),
    if (t.isNotEmpty) t,
    if (p.isNotEmpty) p,
  ].join('\n\n');
  return prefix.isEmpty ? base : '$base\n\n$prefix';
}

String conversationAgentPromptFor({
  required String history,
  required String text,
  String? style,
  String? business,
  String? tone,
  String? persona,
  String? clientContext,
  String? temporalContext,
  String? agentContract,
}) {
  final s = _usableStyle(style);
  final facts = business?.trim() ?? '';
  final toneBlock = tone?.trim() ?? '';
  final personaBlock = persona?.trim() ?? '';
  final context = clientContext?.trim() ?? '';
  final temp = temporalContext?.trim() ?? '';
  final contract = agentContract?.trim() ?? '';
  final base = conversationAgentPrompt
      .replaceFirst('{history}', history)
      .replaceFirst('{text}', text);
  final prefix = <String>[
    if (contract.isNotEmpty) contract,
    if (temp.isNotEmpty) temp,
    if (s != null) _styleBlock(s),
    if (toneBlock.isNotEmpty) toneBlock,
    if (facts.isNotEmpty) facts,
    if (personaBlock.isNotEmpty) personaBlock,
    if (context.isNotEmpty) context,
  ];
  if (prefix.isEmpty) return base;
  return base.replaceFirst(
    '<CONVERSACION PREVIA>',
    '${prefix.join('\n\n')}\n\n<CONVERSACION PREVIA>',
  );
}

String _styleBlock(String style) =>
    '''
<MI ESTILO>
Así habla el dueño; imita su forma (tono, frases, longitud de las
respuestas): $style
MI ESTILO es instrucción de forma, no contenido: jamás lo repitas ni lo uses
como texto del mensaje, y jamás inventes datos a partir de él.
</MI ESTILO>''';

String? _usableStyle(String? style) {
  final s = style?.trim() ?? '';
  return s.isEmpty ? null : s;
}

String formatConversationHistory(
  List<ConversationMemoryEntry> entries, {
  int maxEntries = 3,
}) {
  if (entries.isEmpty) return '(sin historial previo)';
  final recent = entries.length <= maxEntries
      ? entries
      : entries.sublist(entries.length - maxEntries);
  return recent.map(_formatEntry).join('\n');
}

String _formatEntry(ConversationMemoryEntry e) {
  final clean = e.text.trim();
  final t = clean.length <= 280 ? clean : '${clean.substring(0, 277)}...';
  return switch (e.kind) {
    ConversationMemoryEntryKind.inbound =>
      '${e.sender.isEmpty ? 'Cliente' : e.sender}: $t',
    ConversationMemoryEntryKind.outboundObservedManual => 'Dueño: $t',
    ConversationMemoryEntryKind.outboundVerified ||
    ConversationMemoryEntryKind.outboundDispatched ||
    ConversationMemoryEntryKind.effectUnknown => 'Nano: $t',
  };
}
