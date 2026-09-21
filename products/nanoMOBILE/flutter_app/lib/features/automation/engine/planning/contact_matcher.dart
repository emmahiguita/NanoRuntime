// contact_matcher.dart
// ¿Qué hace?
//   Algoritmo de emparejamiento inteligente de contactos por nombre, número,
//   tokens y similitud fonética/ortográfica común en Latinoamérica.
//
// ¿Cómo funciona?
//   1. Normaliza texto (remueve tildes, símbolos y prefijos de agenda tipo 'A ').
//   2. Aplica equivalencias fonéticas (ej: 'vzla' <-> 'zuela'/'suela').
//   3. Evalúa coincidencia exacta, prefijo, subcadena, tokens y fonética.
//   4. Asigna un puntaje (0-100) y ordena candidatos por relevancia.
//
// ¿Por qué?
//   Aplica SRP (SOLID): desacopla la heurística de búsqueda del handler de WhatsApp.
//   Elimina el bug de devolver el primer contacto al azar cuando no hay coincidencia.

import 'package:nanoai/features/automation/domain/whatsapp_contact.dart';


/// Resultado clasificado de coincidencia con su puntuación de relevancia.
class ContactMatchResult {
  final WhatsAppContact contact;
  final int score;

  const ContactMatchResult({required this.contact, required this.score});
}

/// Motor de emparejamiento y desambiguación de contactos.
abstract final class ContactMatcher {
  /// Umbral mínimo de coincidencia para considerar válido un contacto.
  static const int minAcceptableScore = 45;

  /// Encuentra el mejor contacto para [query], o `null` si ninguno supera el umbral.
  static WhatsAppContact? findBest(String query, List<WhatsAppContact> contacts) {
    final results = rank(query, contacts);
    if (results.isEmpty || results.first.score < minAcceptableScore) {
      return null;
    }
    return results.first.contact;
  }

  /// Ordena y filtra los contactos según relevancia con [query].
  static List<WhatsAppContact> filter(
    String query,
    List<WhatsAppContact> contacts, {
    int limit = 10,
  }) {
    if (query.trim().isEmpty) return contacts.take(limit).toList();
    final ranked = rank(query, contacts);
    return ranked
        .where((r) => r.score >= minAcceptableScore)
        .take(limit)
        .map((r) => r.contact)
        .toList();
  }

  /// Calcula el ranking de todos los contactos respecto a [query].
  static List<ContactMatchResult> rank(String query, List<WhatsAppContact> contacts) {
    final cleanQ = normalize(query);
    if (cleanQ.isEmpty) return const [];

    final qDigits = query.replaceAll(RegExp(r'\D'), '');
    final qTokens = cleanQ.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    final qPhonetic = toPhonetic(cleanQ);

    final scored = <ContactMatchResult>[];

    for (final c in contacts) {
      final score = _scoreContact(
        contact: c,
        cleanQuery: cleanQ,
        queryDigits: qDigits,
        queryTokens: qTokens,
        queryPhonetic: qPhonetic,
      );
      if (score > 0) {
        scored.add(ContactMatchResult(contact: c, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  /// Ponderación de coincidencia entre contacto y consulta.
  static int _scoreContact({
    required WhatsAppContact contact,
    required String cleanQuery,
    required String queryDigits,
    required List<String> queryTokens,
    required String queryPhonetic,
  }) {
    // 1. Coincidencia por número telefónico
    if (queryDigits.length >= 7) {
      final cDigits = contact.number.replaceAll(RegExp(r'\D'), '');
      if (cDigits == queryDigits) return 100;
      if (cDigits.endsWith(queryDigits) || queryDigits.endsWith(cDigits)) return 95;
    }

    final rawName = contact.name.trim();
    final cleanName = normalize(rawName);
    if (cleanName.isEmpty) return 0;

    // 2. Coincidencia exacta o directa
    if (cleanName == cleanQuery) return 100;
    if (cleanName.startsWith(cleanQuery)) return 90;
    if (cleanName.contains(cleanQuery)) return 80;

    // 3. Coincidencia fonética / equivalencias (ej: 'vzla' <-> 'zuela'/'suela')
    final namePhonetic = toPhonetic(cleanName);
    if (namePhonetic == queryPhonetic) return 85;
    if (namePhonetic.contains(queryPhonetic) || queryPhonetic.contains(namePhonetic)) return 75;

    // 4. Coincidencia por tokens (ej: 'luis higuita' o 'poke suela')
    if (queryTokens.isNotEmpty) {
      final nameTokens = cleanName.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
      var matchedTokens = 0;

      for (final qt in queryTokens) {
        final qtPhonetic = toPhonetic(qt);
        final hasMatch = nameTokens.any((nt) {
          if (nt == qt || nt.startsWith(qt) || nt.contains(qt)) return true;
          final ntPhonetic = toPhonetic(nt);
          return ntPhonetic == qtPhonetic || ntPhonetic.contains(qtPhonetic);
        });
        if (hasMatch) matchedTokens++;
      }

      if (matchedTokens == queryTokens.length) return 70;
      if (matchedTokens > 0) {
        return (40 + (matchedTokens * 15)).clamp(45, 65);
      }
    }

    return 0;
  }

  /// Normaliza texto para comparación: quita tildes, signos y prefijos 'A ' de agenda.
  static String normalize(String input) {
    var text = input.trim().toLowerCase();
    // Quita prefijos tipo 'A ', 'A- ', 'AA ' usados para ordenar en agenda
    text = text.replaceFirst(RegExp(r'^[a-z]{1,2}[\s\-_.]+'), '');
    // Quita acentos diacríticos
    const withAccents = 'áéíóúüñ';
    const withoutAccents = 'aeiouun';
    for (var i = 0; i < withAccents.length; i++) {
      text = text.replaceAll(withAccents[i], withoutAccents[i]);
    }
    // Reemplaza caracteres no alfanuméricos por espacios limpios
    return text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Normalización fonética estándar para Hispanoamérica.
  /// Mapea 'vzla' <-> 'zuela'/'suela', 's' <-> 'z', 'b' <-> 'v', 'c' <-> 's'.
  static String toPhonetic(String input) {
    var t = normalize(input);
    // Casos comunes de abreviaturas y pronunciación
    t = t.replaceAll('vzla', 'zuela');
    t = t.replaceAll('suela', 'zuela');
    t = t.replaceAll('b', 'v');
    t = t.replaceAll('z', 's');
    t = t.replaceAll(RegExp(r'c(?=[ei])'), 's');
    t = t.replaceAll('k', 'c');
    t = t.replaceAll('qu', 'c');
    t = t.replaceAll(RegExp(r'(.)\1+'), r'$1'); // Quita letras dobles
    return t.replaceAll(RegExp(r'\s+'), '').trim();
  }
}
