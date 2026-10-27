// QUÉ: representa una expresión SELECT con agregado y alias opcionales.
// CÓMO: separa `AS` y reconoce COUNT/SUM/AVG/MIN/MAX.
// POR QUÉ: mantiene pequeño y enfocado el procesador de agregaciones.

final class SqlProjection {
  final String expression;
  final String? function;
  final String label;
  const SqlProjection(this.expression, this.function, this.label);

  factory SqlProjection.parse(String raw) {
    final alias = RegExp(
      r'\s+AS\s+([a-zA-Z0-9_]+)$',
      caseSensitive: false,
    ).firstMatch(raw);
    final body = alias == null
        ? raw.trim()
        : raw.substring(0, alias.start).trim();
    final aggregate = RegExp(
      r'^(COUNT|SUM|AVG|MIN|MAX)\s*\((.*)\)$',
      caseSensitive: false,
    ).firstMatch(body);
    return SqlProjection(
      aggregate?.group(2)?.trim() ?? body,
      aggregate?.group(1)?.toUpperCase(),
      alias?.group(1) ?? body,
    );
  }
}
