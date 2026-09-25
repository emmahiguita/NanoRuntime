/// Clasificación semántica compacta compartida por el motor y la interfaz.
library;

import '../business/fact_selector.dart' show normalizeText;

enum ConversationSemanticTag {
  greeting('saludo', 'Saludo'),
  farewell('farewell', 'Despedida'),
  gratitude('thanks', 'Agradecimiento'),
  question('question', 'Pregunta'),
  request('request', 'Solicitud'),
  correction('correction', 'Corrección'),
  profile('profile', 'Perfil'),
  media('media', 'Multimedia'),
  conversation('conversation', 'Conversación');

  const ConversationSemanticTag(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static ConversationSemanticTag fromStorageKey(String? value) {
    for (final tag in values) {
      if (tag.storageKey == value) return tag;
    }
    return ConversationSemanticTag.conversation;
  }
}

final class ConversationSemanticClassifier {
  const ConversationSemanticClassifier._();

  static final _media = RegExp(
    r'(\[(?:image|video|pdf|document|audio):|https?://\S+\.(?:jpe?g|png|webp|gif|mp4|mov|webm|pdf)(?:\?\S*)?$)',
    caseSensitive: false,
  );
  static final _farewell = RegExp(
    r'\b(chao|chau|adios|hasta luego|hasta manana|nos vemos|hablamos luego|descansa|que descanses)\b',
  );
  static final _greeting = RegExp(
    r'\b(hola|holi|buenas|buen dia|buenos dias|buenas tardes|buenas noches|hey|que mas|quiubo)\b',
  );
  static final _gratitude = RegExp(
    r'\b(gracias|muchas gracias|te agradezco|mil gracias|muy amable)\b',
  );
  static final _profile = RegExp(
    r'\b(me llamo|mi nombre|soy de|vivo en|trabajo en|me gusta|prefiero|mi horario|mi cumpleanos)\b',
  );
  static final _correction = RegExp(
    r'\b(me referia|quise decir|no era|correccion|corrijo|en realidad)\b',
  );
  static final _request = RegExp(
    r'\b(puedes|podrias|necesito|quiero que|ayudame|envia|mandame|dime|avisa|recuerda)\b',
  );
  static final _question = RegExp(
    r'\b(que|como|cuando|donde|quien|cual|cuanto|por que|para que|tienes|sabes|puedo)\b',
  );

  /// Extrae todas las etiquetas semánticas presentes en un mensaje (soporte multi-intent).
  static Set<ConversationSemanticTag> classifyAll(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return const {ConversationSemanticTag.conversation};
    final normalized = normalizeText(clean);
    final tags = <ConversationSemanticTag>{};
    if (_media.hasMatch(clean)) tags.add(ConversationSemanticTag.media);
    if (_correction.hasMatch(normalized)) tags.add(ConversationSemanticTag.correction);
    if (_request.hasMatch(normalized)) tags.add(ConversationSemanticTag.request);
    if (clean.contains('?') || _question.hasMatch(normalized)) {
      tags.add(ConversationSemanticTag.question);
    }
    if (_profile.hasMatch(normalized)) tags.add(ConversationSemanticTag.profile);
    if (_gratitude.hasMatch(normalized)) tags.add(ConversationSemanticTag.gratitude);
    if (!clean.contains('?') && _farewell.hasMatch(normalized)) {
      tags.add(ConversationSemanticTag.farewell);
    }
    if (_greeting.hasMatch(normalized)) tags.add(ConversationSemanticTag.greeting);
    if (tags.isEmpty) tags.add(ConversationSemanticTag.conversation);
    return tags;
  }

  /// Devuelve la intención dominante sin destruir la intención sustantiva cuando
  /// el mensaje comienza con un saludo ("Hola bro, ¿qué haces?").
  static ConversationSemanticTag classify(String raw) {
    final tags = classifyAll(raw);
    const priority = [
      ConversationSemanticTag.media,
      ConversationSemanticTag.correction,
      ConversationSemanticTag.request,
      ConversationSemanticTag.question,
      ConversationSemanticTag.profile,
      ConversationSemanticTag.gratitude,
      ConversationSemanticTag.farewell,
      ConversationSemanticTag.greeting,
      ConversationSemanticTag.conversation,
    ];
    for (final candidate in priority) {
      if (tags.contains(candidate)) return candidate;
    }
    return ConversationSemanticTag.conversation;
  }
}
