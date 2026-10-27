/// QUÉ: detecta defectos textuales comprobados sin fabricar respuestas.
/// CÓMO: compara contenido léxico sin adornos y busca bucles muy repetitivos.
/// POR QUÉ: un emoji no convierte un eco en comprensión. No mide semántica.
library;

import 'personal_profile_output_guard.dart';

abstract final class ConversationReplyQuality {
  static final _nonWords = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
  static final _letterLoop = RegExp(r'(\p{L})\1{9,}', unicode: true);
  static final _wordLoop = RegExp(
    r'\b(\p{L}{2,})(?:\s+\1){4,}\b',
    unicode: true,
  );

  /// Normaliza únicamente para comparar; nunca modifica lo que se envía.
  /// Conserva números y negaciones para no igualar afirmaciones opuestas.
  static String lexical(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll(_nonWords, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Devuelve una causa auditable o null. No altera permisos ni datos faltantes.
  static String? rejectionReason({
    required String input,
    required String reply,
  }) {
    final clean = reply.trim();
    if (clean.isEmpty) return 'empty';
    if (_letterLoop.hasMatch(clean.toLowerCase())) return 'repeated_characters';
    if (_wordLoop.hasMatch(lexical(clean))) return 'repeated_words';
    final source = lexical(input);
    final target = lexical(clean);
    final profileFailure = PersonalProfileOutputGuard.rejectionReason(
      source,
      clean,
    );
    if (profileFailure != null) return profileFailure;
    // Rebote observado: preguntar lo mismo añadiendo «y tú» no atiende el turno.
    // Se entrega la causa al rescate contextual; nunca se fabrica otra frase.
    if (input.contains('?') &&
        clean.contains('?') &&
        target.replaceFirst(RegExp(r'^y (?:tu|vos|usted) '), '') == source) {
      return 'echo_question';
    }
    // Fallo observado en pesos reales: el modelo se presentaba con el nombre
    // que acababa de dar el contacto. No rechaza citas ni respuestas en 2ª persona.
    final introduction =
        RegExp(r'\b(?:me llamo|mi nombre es)\s+([a-zñ]+)').firstMatch(source) ??
        RegExp(
          r'\b(?:perdon|me equivoque)\b.*?\bsoy\s+([a-zñ]+)',
        ).firstMatch(source);
    final name = introduction?.group(1);
    if (name != null &&
        RegExp(
          '^(?:hola |buenas )?(?:yo )?(?:soy|me llamo|mi nombre es) ${RegExp.escape(name)}\\b',
        ).hasMatch(target)) {
      return 'speaker_confusion';
    }
    if (source.isNotEmpty && source == target) {
      // Coincidir no es siempre copiar: devolver un saludo breve es legítimo.
      // Esta excepción solo valida texto generado; no produce frases estáticas.
      final greeting = RegExp(
        r'^(?:hola|buenas|buenos dias|buenas tardes|buenas noches)$',
      ).hasMatch(source);
      if (!greeting) return 'echo';
    }
    return null;
  }
}
