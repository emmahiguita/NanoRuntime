part of 'persona_import.dart';

/// Utilidades de validación, sanitización, hash y fechas para la importación de persona.
/// Cumple SOLID y límite de < 300 líneas.
final class _Message {
  const _Message(this.role, this.text, this.at);
  final String role, text;
  final int at;
}

extension _PersonaImportUtils on PersonaImportPipeline {
  static Iterable<Map> _list(Map map, String key) sync* {
    final rows = map[key] ?? const [];
    if (rows is! List) throw FormatException('$key debe ser una lista.');
    for (final row in rows) {
      if (row is! Map) throw FormatException('Registro inválido en $key.');
      yield row;
    }
  }

  static String _text(Object? value, String field) {
    if (value == null) return '';
    if (value is! String) {
      throw FormatException('$field debe ser texto.');
    }
    return value;
  }

  static bool _generatedSource(Object? value) {
    final source = '$value'.trim().toLowerCase();
    return source.contains('nano') ||
        source.contains('assistant') ||
        source.contains('generated') ||
        source == 'system' ||
        source == 'ai' ||
        source == 'llm' ||
        source == 'model';
  }

  static bool _generatedRow(Map row) {
    final fields = row.map(
      (key, value) => MapEntry('$key'.toLowerCase(), value),
    );
    final marker = '${fields['generatedbynano'] ?? ''}'.trim().toLowerCase();
    return marker == 'true' ||
        marker == '1' ||
        _generatedSource(fields['role']) ||
        _generatedSource(fields['source']) ||
        _generatedSource(fields['generatedby']);
  }

  static String _author(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static bool _excludedBody(String value) {
    final omitted = RegExp(
      r'^(?:<?(?:multimedia|media|image|imagen|video|vídeo|audio|sticker|gif|document|documento|contact card|tarjeta de contacto)\s+(?:omiti(?:do|da)s?|omitted)>?|\[?(?:this message was deleted|you deleted this message|se eliminó este mensaje|eliminaste este mensaje|mensaje eliminado)\]?|<attached:.*>|.*\(archivo adjunto\))$',
      caseSensitive: false,
    );
    return value.split('\n').any((line) => omitted.hasMatch(line.trim()));
  }

  static bool _systemNotice(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith(
          'messages and calls are end-to-end encrypted',
        ) ||
        normalized.startsWith('los mensajes y las llamadas están cifrados') ||
        normalized.startsWith('your security code with ') ||
        normalized.startsWith('cambió tu código de seguridad con ') ||
        normalized.startsWith('cambió el código de seguridad con ') ||
        normalized.startsWith('you turned on disappearing messages') ||
        normalized.startsWith('you turned off disappearing messages');
  }

  static bool _validDate(int year, int month, int day) {
    if (year < 1970 ||
        year > 9999 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return false;
    }
    final parsed = DateTime.utc(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day;
  }

  static int _timestamp(Object? value) {
    final text = value == null ? '' : '$value'.trim();
    if (text.isEmpty) return 0;
    const maximum = 253402300799999; // 9999-12-31T23:59:59.999Z.
    if (value is num &&
        (!value.isFinite || value != value.truncateToDouble())) {
      throw const FormatException(
        'Unix debe ser un número entero de milisegundos.',
      );
    }
    final numeric = value is num ? value.toInt() : int.tryParse(text);
    if (numeric != null) {
      if (numeric < 0 || numeric > maximum) {
        throw const FormatException('Timestamp fuera del rango 1970–9999.');
      }
      return numeric;
    }
    final iso = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[Tt ](\d{2}):(\d{2})(?::(\d{2})(?:[.,]\d{1,6})?)?(?:[Zz]|[+-](\d{2}):?(\d{2}))?)?$',
    ).firstMatch(text);
    if (iso == null ||
        !_validDate(
          int.parse(iso[1]!),
          int.parse(iso[2]!),
          int.parse(iso[3]!),
        ) ||
        int.parse(iso[4] ?? '0') > 23 ||
        int.parse(iso[5] ?? '0') > 59 ||
        int.parse(iso[6] ?? '0') > 59 ||
        int.parse(iso[7] ?? '0') > 23 ||
        int.parse(iso[8] ?? '0') > 59) {
      throw const FormatException(
        'Fecha inválida; usa ISO 8601 o Unix en milisegundos.',
      );
    }
    final parsed = DateTime.tryParse(text);
    if (parsed == null ||
        parsed.millisecondsSinceEpoch < 0 ||
        parsed.millisecondsSinceEpoch > maximum) {
      throw const FormatException('Fecha fuera del rango 1970–9999.');
    }
    return parsed.millisecondsSinceEpoch;
  }

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
