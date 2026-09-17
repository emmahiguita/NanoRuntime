part of 'persona_import.dart';

/// Parser especializado para historiales exportados de WhatsApp en formato TXT.
/// Cumple SOLID y límite de < 300 líneas.
extension _PersonaImportWhatsApp on PersonaImportPipeline {
  void _parseWhatsAppTxt({
    required String normalizedContent,
    required String ownerName,
    required List<_Message> messages,
    required List<String> warnings,
    required void Function(String role, String text, int at) addMessage,
  }) {
    if (ownerName.trim().isEmpty) {
      throw const FormatException(
        'Escribe tu nombre exactamente como aparece en la exportación TXT.',
      );
    }
    final pattern = RegExp(
      r'^\[?(\d{1,2})[/-](\d{1,2})[/-](\d{2,4}),?\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([ap]\.?(?:\s*m)\.?)?\]?\s*(?:-\s*)?(.*)$',
      caseSensitive: false,
    );
    final datePrefix = RegExp(r'^\[?\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:,|\s)');
    final authors = <String>{};
    final expectedOwner = _PersonaImportUtils._author(ownerName);
    var ownerSeen = false;

    for (final raw in normalizedContent.split('\n')) {
      final line = raw
          .replaceAll('\u200e', '')
          .replaceAll('\u200f', '')
          .replaceAll('\u202f', ' ')
          .replaceAll('\u00a0', ' ');
      final match = pattern.firstMatch(line);
      if (match == null) {
        if (datePrefix.hasMatch(line)) {
          messages.add(const _Message('break', '', 0));
          warnings.add(
            'Línea con fecha no reconocida; se separaron sus pares.',
          );
        } else if (messages.isNotEmpty &&
            messages.last.role != 'break' &&
            line.isNotEmpty) {
          final previous = messages.removeLast();
          addMessage(previous.role, '${previous.text}\n$line', previous.at);
        } else if (line.trim().isNotEmpty) {
          warnings.add('Línea sin mensaje anterior reconocible excluida.');
        }
        continue;
      }
      var year = int.parse(match[3]!);
      if (year < 100) year += 2000;
      final day = int.parse(match[1]!), month = int.parse(match[2]!);
      var hour = int.parse(match[4]!);
      final minute = int.parse(match[5]!),
          second = int.parse(match[6] ?? '0');
      final meridiem = (match[7] ?? '').toLowerCase();
      if (minute > 59 ||
          second > 59 ||
          (meridiem.isEmpty ? hour > 23 : hour < 1 || hour > 12) ||
          !_PersonaImportUtils._validDate(year, month, day)) {
        throw const FormatException(
          'TXT requiere fechas día/mes/año y horas válidas.',
        );
      }
      if (meridiem.isNotEmpty) {
        hour %= 12;
        if (meridiem.startsWith('p')) hour += 12;
      }
      final time = DateTime(year, month, day, hour, minute, second);
      final payload = match[8]!;
      final separator = payload.indexOf(': ');
      if (separator <= 0 || _PersonaImportUtils._systemNotice(payload)) {
        messages.add(const _Message('break', '', 0));
        warnings.add(
          'Aviso del sistema sin autor excluido; se separaron sus pares.',
        );
        continue;
      }
      final author = _PersonaImportUtils._author(payload.substring(0, separator));
      final isOwner = author == expectedOwner;
      if (isOwner) {
        ownerSeen = true;
      } else {
        authors.add(author);
        if (authors.length > 1) {
          throw const FormatException(
            'El TXT contiene varios interlocutores o un grupo. Importa un contacto por archivo para no mezclar su identidad ni sus respuestas.',
          );
        }
      }
      addMessage(
        isOwner ? 'owner' : 'contact',
        payload.substring(separator + 2),
        time.millisecondsSinceEpoch,
      );
    }
    if (messages.isEmpty) {
      throw const FormatException(
        'No se reconocieron mensajes de exportación WhatsApp TXT.',
      );
    }
    if (!ownerSeen) {
      throw const FormatException(
        'Tu nombre no coincide con ningún autor del TXT. Escríbelo exactamente como aparece en la exportación.',
      );
    }
  }
}
