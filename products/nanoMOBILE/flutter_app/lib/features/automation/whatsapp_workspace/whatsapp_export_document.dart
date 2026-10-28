import 'dart:convert';
import 'dart:io';
import 'bounded_export_zip.dart';

/// Mensaje del archivo oficial: conserva fecha literal y texto original para
/// evitar inventar zona horaria, identidad WhatsApp o contenido multimedia.
class ExportMessage {
  ExportMessage(this.stamp, this.raw, {this.sender = '', this.text = ''});
  final String stamp;
  String raw;
  final String sender;
  String text;
  Map<String, dynamic> toJson() => {
    'stamp': stamp,
    'raw': raw,
    'sender': sender,
    'text': text,
  };
}

/// Documento completo importado, distinto de la lectura parcial de pantalla.
class WhatsAppExportDocument {
  const WhatsAppExportDocument(this.messages, this.sourceName, this.preamble);
  final List<ExportMessage> messages;
  final String sourceName;
  final String preamble;
  Map<String, dynamic> toJson() => {
    'sourceName': sourceName,
    'messages': messages.map((m) => m.toJson()).toList(),
    'preamble': preamble,
    'identityVerified': false,
  };
}

/// Decode ejecutable en isolate. Nunca extrae rutas del ZIP al sistema de
/// archivos: solo acepta un TXT único y comprueba su tamaño antes de inflarlo.
Map<String, dynamic> decodeWhatsAppExport(Map<String, String> input) {
  final file = File(input['path']!);
  final bytes = file.readAsBytesSync();
  if (bytes.isEmpty || bytes.length > 16 * 1024 * 1024) {
    throw const FormatException('El archivo está vacío o supera 16 MB.');
  }
  List<int> content = bytes;
  if ((input['name'] ?? '').toLowerCase().endsWith('.zip')) {
    content = readExportZip(bytes);
  }
  if (content.length > 8 * 1024 * 1024) {
    throw const FormatException(
      'El texto supera el límite de 8 MB; no se importó parcialmente.',
    );
  }
  final text = utf8.decode(content).replaceFirst('\uFEFF', '');
  final messages = <ExportMessage>[];
  final preamble = StringBuffer();
  final header = RegExp(
    r'^\[?(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}),?\s+'
    r'(\d{1,2}:\d{2}(?::\d{2})?(?:\s*[ap]\.?(?:\s*)m\.?)?)'
    r'\]?(?:\s*-\s*|\s+)(.*)$',
    caseSensitive: false,
  );
  for (final original in const LineSplitter().convert(text)) {
    final line = original.replaceAll(
      RegExp('[\u200e\u200f\u202a-\u202e\u2066-\u2069]'),
      '',
    );
    final match = header.firstMatch(line);
    if (match == null) {
      if (messages.isNotEmpty) {
        messages.last.raw += '\n$original';
        messages.last.text += '\n$original';
      } else {
        preamble.writeln(original);
      }
      continue;
    }
    final body = match[3]!;
    final colon = body.indexOf(': ');
    messages.add(
      ExportMessage(
        '${match[1]} ${match[2]}',
        original,
        sender: colon < 0 ? '' : body.substring(0, colon),
        text: colon < 0 ? body : body.substring(colon + 2),
      ),
    );
    if (messages.length > 60000) {
      throw const FormatException(
        'Más de 60000 mensajes: no se truncó ni guardó un historial incompleto.',
      );
    }
  }
  if (messages.isEmpty)
    throw const FormatException(
      'No se reconoció un historial de WhatsApp con fechas.',
    );
  return WhatsAppExportDocument(
    messages,
    input['name'] ?? file.uri.pathSegments.last,
    preamble.toString(),
  ).toJson();
}
