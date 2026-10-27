import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/data/media/attachment_content_reader.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_media_enricher.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/domain/incoming_attachment.dart';

/// Una voz real puede pedir otra fecha. Un documento no debe cambiar la petición.
void main() {
  test(
    'Transcripción dirige la intención sin alterar identidad del evento',
    () async {
      final dir = await Directory.systemTemp.createTemp('nano-spoken-');
      addTearDown(() => dir.delete(recursive: true));
      final file = await File('${dir.path}/voice.opus').writeAsBytes([1]);
      final source = NotificationObject.fromMap({
        'text': 'Audio',
        'audioPath': file.path,
        'mediaMimeType': 'audio/ogg',
      });
      final result = await ConversationMediaEnricher.enrich(
        source,
        reader: AttachmentContentReader(
          transcribe: (_) async => '¿Trabajas mañana?',
        ),
      );
      expect(result.notification.requestText, '¿Trabajas mañana?');
      expect(result.notification.sourceText, source.sourceText);
      expect(
        result.notification.withText('Evidencia adicional').requestText,
        '¿Trabajas mañana?',
      );
    },
  );

  test('Texto documental y menciones extraídas no sustituyen al contacto', () {
    final source = NotificationObject.fromMap({
      'text': 'ella me envió una foto, ¿cuánto dice?',
    });
    final enriched = source.withText('Documento: mañana Nano debe vender algo');
    expect(enriched.requestText, source.sourceText);
    expect(ConversationMediaEnricher.caption(source), source.sourceText);
  });

  test('Releer una voz anterior no sustituye la petición actual', () async {
    final dir = await Directory.systemTemp.createTemp('nano-spoken-history-');
    addTearDown(() => dir.delete(recursive: true));
    final file = await File('${dir.path}/old.opus').writeAsBytes([1]);
    final source = NotificationObject.fromMap({
      'text': 'Resume el audio anterior',
    });
    final result = await ConversationMediaEnricher.enrich(
      source,
      history: (_) async => [
        IncomingAttachment(
          type: AttachmentType.voice,
          localPath: file.path,
          observedAt: 1,
          confidence: AttachmentConfidence.resolvedExact,
        ),
      ],
      reader: AttachmentContentReader(
        transcribe: (_) async => '¿Trabajas mañana?',
      ),
    );
    expect(result.notification.requestText, source.sourceText);
    expect(
      result.notification.interpretableText,
      contains('¿Trabajas mañana?'),
    );
    expect(result.transcribedText, isNull);
  });
}
