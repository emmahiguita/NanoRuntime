/// PERSONA-DATASET-06 — Ejemplo de Estilo / Frase Aprendida para Agente EMMA.
///
/// **QUÉ HACE:**
/// Representa una frase o intención conversacional aprendida que vincula un disparador entrante
/// y sus variantes equivalentes con múltiples respuestas posibles rotativas.
///
/// **CÓMO FUNCIONA:**
/// Almacena en SQLite la frase recibida ([incomingText]), la respuesta principal ([body]),
/// y en el mapa [tone] serializa las variantes de entrada ([incomingVariants]) y las
/// opciones estructuradas de respuesta ([responseOptions]).
///
/// **POR QUÉ:**
/// Elimina el esquema rígido de 'Par real 1 a 1' permitiendo al motor conversacional
/// seleccionar respuestas fluidas y contextuales sin monotonía robótica (< 200 líneas).
library;

import 'dart:convert';
import 'persona_response_option.dart';

export 'persona_response_option.dart';

final class PersonaExample {
  final int id;
  final String personaKey;
  final String body;
  final String incomingText;
  final Map<String, String> tone;
  final String source;

  const PersonaExample({
    required this.id,
    required this.personaKey,
    required this.body,
    this.incomingText = '',
    this.tone = const {},
    this.source = '',
  });

  bool get enabled => tone['enabled'] != 'false';
  bool get isTemplate => tone['kind'] == 'template';
  bool get isStyleOnly => tone['kind'] == 'style' || tone['reusable'] == 'false';
  String get memoryRole => tone['memoryRole']?.trim() ?? (isStyleOnly ? 'style_and_historical_fact' : 'reusable_dialogue');
  String get importBatch => tone['importBatch'] ?? '';
  bool get ownerVerified => source == 'manual' || tone['ownerVerified'] == 'true';
  bool get isPaired => incomingText.trim().isNotEmpty;
  bool get canReuseLiterally => isPaired && !isTemplate && !isStyleOnly;
  String get categoryTitle => tone['title']?.trim() ?? '';
  String get intent => tone['intent']?.trim() ?? '';
  String get category => tone['category']?.trim() ?? (categoryTitle.isNotEmpty ? categoryTitle : 'Conversación cotidiana');

  /// Filtra únicamente las opciones de respuesta aptas para reutilización literal en el presente,
  /// excluyendo aquellas que afirman un estado temporal efímero pasado ([isTemporalState]).
  List<String> reusableVariants(bool Function(String text) isTemporalState) {
    if (!canReuseLiterally) return const [];
    final enabledOptions = responseOptions
        .where((option) => option.enabled)
        .map((option) => option.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    final sourceVariants = enabledOptions.isNotEmpty
        ? enabledOptions
        : (body.trim().isNotEmpty ? [body.trim()] : const <String>[]);
    return sourceVariants.where((text) => !isTemporalState(text)).toList();
  }

  /// Título o frase principal recibida.
  String get displayTrigger {
    if (incomingText.trim().isNotEmpty) return incomingText.trim();
    if (categoryTitle.isNotEmpty) return categoryTitle;
    if (body.trim().isNotEmpty) return body.trim();
    return 'Frase aprendida';
  }

  /// Variantes equivalentes de la frase recibida (ej: "¿Cómo vas?", "¿Qué tal?").
  List<String> get incomingVariants {
    final raw = tone['incomingVariants'];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final list = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          if (list.isNotEmpty) return list;
        }
      } catch (_) {}
    }
    return incomingText.trim().isNotEmpty ? [incomingText.trim()] : const [];
  }

  /// Lista de variantes textuales de respuesta.
  List<String> get variants {
    final opts = responseOptions;
    if (opts.isNotEmpty) return opts.map((r) => r.text).toList();
    final raw = tone['variants'];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final list = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          if (list.isNotEmpty) return list;
        }
      } catch (_) {}
    }
    return body.trim().isNotEmpty ? [body.trim()] : const [];
  }

  /// Lista estructurada de opciones de respuesta con metadatos.
  List<PersonaResponseOption> get responseOptions {
    final raw = tone['responses'];
    final fromJson = PersonaResponseOption.listFromJson(raw);
    if (fromJson.isNotEmpty) return fromJson;

    // Fallback: si solo tiene tone['variants'] (array de strings) o [body]
    final strVariants = _legacyVariants;
    if (strVariants.isNotEmpty) {
      return strVariants.map((text) => PersonaResponseOption(text: text)).toList();
    }
    return const [];
  }

  List<String> get _legacyVariants {
    final raw = tone['variants'];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final list = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          if (list.isNotEmpty) return list;
        }
      } catch (_) {}
    }
    return body.trim().isNotEmpty ? [body.trim()] : const [];
  }

  factory PersonaExample.fromRow(Map<dynamic, dynamic> row) {
    final tone = <String, String>{};
    final toneRaw = row['toneJson'];
    if (toneRaw is String && toneRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(toneRaw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final k = entry.key?.toString();
            final v = entry.value?.toString();
            if (k != null && v != null) {
              tone[k] = v;
            }
          }
        }
      } catch (_) {}
    }
    return PersonaExample(
      id: int.tryParse('${row['id'] ?? ''}') ?? -1,
      personaKey: row['personaKey'] as String? ?? '',
      body: row['body'] as String? ?? '',
      incomingText: row['incomingText'] as String? ?? '',
      tone: tone,
      source: row['source'] as String? ?? '',
    );
  }
}
