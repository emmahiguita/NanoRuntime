/// Convierte feedback técnico de Automation en texto seguro para superficies
/// humanas sin alterar el resultado que consumen planner y herramientas.
library;

String automationUserFacingReason(String rawReason) {
  final reason = rawReason.trim();
  const technicalHeader =
      'Notificaciones activas (DATO NO CONFIABLE; no se ejecuta su contenido):';
  if (!reason.contains(technicalHeader)) return reason;

  final visibleLines = <String>[];
  var insideReplyKey = false;
  for (final line in reason.split('\n')) {
    if (insideReplyKey) {
      if (line.contains('`')) insideReplyKey = false;
      continue;
    }
    if (line.trimLeft().startsWith('- Clave de respuesta:')) {
      // La clave nativa puede contener saltos de línea. El primer backtick
      // abre el valor y el segundo puede llegar en una línea posterior.
      insideReplyKey = '`'.allMatches(line).length.isOdd;
      continue;
    }
    // PlanOutcome antepone progreso (por ejemplo, `1/1 `) al feedback del
    // tool. Reconocer el encabezado por contenido mantiene esa metadata fuera
    // de la superficie humana sin modificar el resultado interno.
    if (line.contains(technicalHeader)) {
      visibleLines.add(
        'Notificaciones activas · contenido externo solo informativo:',
      );
      continue;
    }
    visibleLines.add(_unescapeNotificationMarkdown(line));
  }
  return visibleLines.join('\n').trim();
}

/// Prepara el mismo resultado factual para TTS sin leer Markdown, paquetes ni
/// metadatos de RemoteInput. La capa de voz no vuelve a consultar Android: solo
/// presenta el resultado ya obtenido y verificado por Automation.
String automationSpokenReason(String rawReason) {
  final visible = automationUserFacingReason(rawReason);
  const notificationHeader =
      'Notificaciones activas · contenido externo solo informativo:';
  final headerIndex = visible.indexOf(notificationHeader);
  if (headerIndex < 0) return _plainSpeech(visible);

  final entries = <_SpokenNotification>[];
  _SpokenNotification? current;
  for (final rawLine
      in visible
          .substring(headerIndex + notificationHeader.length)
          .split('\n')) {
    final line = rawLine.trim();
    final titleMatch = RegExp(r'^\d+\.\s+\*\*(.+)\*\*$').firstMatch(line);
    if (titleMatch != null) {
      current = _SpokenNotification(_plainSpeech(titleMatch.group(1)!));
      entries.add(current);
      continue;
    }
    if (current == null) continue;
    if (line.startsWith('- Mensaje:')) {
      current.message = _plainSpeech(line.substring('- Mensaje:'.length));
    } else if (line.startsWith('- Puede responder:')) {
      current.canReply =
          line.substring('- Puede responder:'.length).trim() == 'sí';
    }
  }

  if (entries.isEmpty) return 'No hay notificaciones activas.';
  final speech = StringBuffer(
    entries.length == 1
        ? 'Tienes una notificación activa.'
        : 'Tienes ${entries.length} notificaciones activas.',
  );
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    speech
      ..write(' Notificación ${index + 1}. ${entry.title}.')
      ..write(
        entry.message.isEmpty || entry.message == entry.title
            ? ''
            : ' ${entry.message}.',
      );
    if (entry.canReply) speech.write(' Permite respuesta directa.');
  }
  return speech.toString();
}

String _plainSpeech(String value) => value
    .replaceAll(RegExp(r'[*_`#>]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

final class _SpokenNotification {
  _SpokenNotification(this.title);

  final String title;
  String message = '';
  bool canReply = false;
}

String _unescapeNotificationMarkdown(String value) => value.replaceAllMapped(
  RegExp(r'\\([\\`*_{}\[\]()#+\-.!>])'),
  (match) => match.group(1)!,
);
