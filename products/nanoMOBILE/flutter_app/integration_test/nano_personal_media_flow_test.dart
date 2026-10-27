import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:nanoai/features/automation/data/media/message_document_reader.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_media_enricher.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';

/// Prueba real Android: archivos de prueba conocidos -> canales nativos -> texto.
/// Ejecutar SOLO con --flavor personalValidation: Flutter desinstala ese paquete.
/// Usa datos desechables y no envía mensajes a contactos.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('OCR, PDF digital y PDF escaneado alimentan el turno real', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Verificando lectura local')),
      ),
    );
    await tester.runAsync(() async {
      final temp = await getTemporaryDirectory();
      final folder = await Directory(
        '${temp.path}/nano-media-proof-${DateTime.now().microsecondsSinceEpoch}',
      ).create();
      final timings = <String, Object>{};
      try {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
        final painter = TextPainter(
          text: const TextSpan(
            text: 'TOTAL 25000\nLUNCH 12:00',
            style: TextStyle(fontSize: 68, color: Colors.black),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 1100);
        painter.paint(canvas, const Offset(45, 45));
        final picture = recorder.endRecording();
        final image = await picture.toImage(1200, 400);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        image.dispose();
        picture.dispose();
        painter.dispose();
        final photo = await File(
          '${folder.path}/receipt.png',
        ).writeAsBytes(bytes);
        final reader = MessageDocumentReader();
        var watch = Stopwatch()..start();
        final observed = await reader.read(photo.path, image: true);
        timings['ocr_ms'] = watch.elapsedMilliseconds;
        expect('${observed['text']}', contains('25000'));

        final digital = pw.Document()
          ..addPage(pw.Page(build: (_) => pw.Text('INVOICE TOTAL 25000')));
        final pdf = await File(
          '${folder.path}/digital.pdf',
        ).writeAsBytes(await digital.save());
        watch = Stopwatch()..start();
        final pages = await reader.read(pdf.path, image: false);
        timings['pdf_text_ms'] = watch.elapsedMilliseconds;
        expect('${(pages['pages'] as List).first}', contains('25000'));
        expect(pages['totalPages'], 1);

        final scanned = pw.Document()
          ..addPage(pw.Page(build: (_) => pw.Image(pw.MemoryImage(bytes))));
        final scan = await File(
          '${folder.path}/scan.pdf',
        ).writeAsBytes(await scanned.save());
        watch = Stopwatch()..start();
        final scans = await reader.read(scan.path, image: false);
        timings['pdf_ocr_ms'] = watch.elapsedMilliseconds;
        expect('${(scans['pages'] as List).first}', contains('25000'));
        expect(((scans['pages'] as List).first as Map)['ocr'], isTrue);

        final notification = NotificationObject.fromMap({
          'key': 'fixture',
          'package': 'com.whatsapp',
          'shortcutId': 'local-proof',
          'messageText': '¿Qué total dice?\n[Imagen: ${photo.path}]',
          'imagePath': photo.path,
          'mediaMimeType': 'image/png',
          'messageTimestamp': 1,
        });
        watch = Stopwatch()..start();
        final enriched = await ConversationMediaEnricher.enrich(notification);
        timings['image_to_turn_ms'] = watch.elapsedMilliseconds;
        expect(enriched.notification.interpretableText, contains('25000'));
        expect(
          enriched.notification.interpretableText,
          contains('¿Qué total dice?'),
        );
        expect(
          enriched.notification.sourceText,
          notification.interpretableText,
        );
        expect(enriched.photoUnprocessed, isFalse);
        binding.reportData = timings;
        debugPrint('NANO_MEDIA_PROOF $timings');
      } finally {
        await folder.delete(recursive: true);
      }
    });
  });
}
