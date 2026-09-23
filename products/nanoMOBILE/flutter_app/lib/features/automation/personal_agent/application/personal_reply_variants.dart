/// Operaciones puras para deduplicar y acotar variantes de respuesta.
library;

import 'dart:convert';

import 'personal_learning_text.dart';

List<String> uniqueLearningReplies(Iterable<String> values) {
  final seen = <String>{};
  return [
    for (final value in values)
      if (value.trim().isNotEmpty &&
          seen.add(normalizePersonalLearningText(value)))
        value.trim(),
  ];
}

/// El límite reserva espacio para el resto de campos del JSON nativo (4 KB).
List<String> fitLearningMetadata(List<String> replies) {
  final kept = <String>[];
  for (final reply in replies) {
    final candidate = [...kept, reply];
    if (jsonEncode(candidate).length > 2200) break;
    kept.add(reply);
  }
  return kept.isEmpty ? [replies.first] : kept;
}

bool sameLearningReplies(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (normalizePersonalLearningText(a[index]) !=
        normalizePersonalLearningText(b[index])) {
      return false;
    }
  }
  return true;
}
