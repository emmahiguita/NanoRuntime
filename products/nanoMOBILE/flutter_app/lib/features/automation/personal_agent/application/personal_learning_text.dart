/// Normalización compartida para comparar preguntas, saludos y enlaces sin
/// confundir diferencias de mayúsculas, tildes o signos de puntuación.
library;

import '../../engine/business/fact_selector.dart' show normalizeText;

const _trackingKeys = {'fbclid', 'gclid', 'mc_cid', 'mc_eid'};

String normalizePersonalLearningText(String raw) {
  final canonicalLinks = raw.replaceAllMapped(
    RegExp(r'https?://[^\s]+', caseSensitive: false),
    (match) => _withoutTracking(match.group(0) ?? ''),
  );
  return normalizeText(canonicalLinks)
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Conserva el recurso y sus parámetros funcionales; sólo elimina rastreo.
String _withoutTracking(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.host.isEmpty) return raw;
  final kept =
      uri.queryParameters.entries
          .where(
            (entry) =>
                !entry.key.toLowerCase().startsWith('utm_') &&
                !_trackingKeys.contains(entry.key.toLowerCase()),
          )
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
  final query = kept
      .map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      )
      .join('&');
  return uri
      .replace(
        scheme: uri.scheme.toLowerCase(),
        host: uri.host.toLowerCase(),
        query: query,
        fragment: '',
      )
      .toString();
}
