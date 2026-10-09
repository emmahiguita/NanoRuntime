import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/main.dart' as app;
import 'package:nanoai/core/services/whisper_stt_service.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/features/automation/engine/conversation/conversation_media_enricher.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('prueba real en dispositivo: decodificación nativa + Whisper STT + respuesta', (tester) async {
    debugPrint('=== INICIANDO PRUEBA REAL EN DISPOSITIVO FISICO ===');
    app.main();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    // 1. Verificar servicio WhisperSttService inicializado
    final whisperService = WhisperSttService.instance;
    await whisperService.init();
    debugPrint('[TEST-1] Whisper inicializado. Modelo activo: ${whisperService.activeModelFile}');
    expect(whisperService.hasActiveModel, isTrue);

    // 2. Localizar nota de voz real de WhatsApp en el almacenamiento
    const samplePath = '/data/local/tmp/sample.opus';
    final sampleFile = File(samplePath);
    expect(sampleFile.existsSync(), isTrue, reason: 'El archivo $samplePath debe existir físicamente');
    debugPrint('[TEST-2] Audio real verificado en disco: $samplePath (${sampleFile.lengthSync()} bytes)');

    // 3. Probar decodificación nativa MediaCodec Opus -> WAV
    final wavPath = await NanoRuntimeApi.instance.convertAudioToWav(samplePath);
    debugPrint('[TEST-3] Resultado de conversión a WAV: $wavPath');
    expect(wavPath, isNotNull);
    final wavFile = File(wavPath!);
    expect(wavFile.existsSync(), isTrue);
    expect(wavFile.lengthSync(), greaterThan(1000));
    debugPrint('[TEST-3] WAV generado por MediaCodec: ${wavFile.lengthSync()} bytes');

    // 4. Probar transcripción Whisper local real
    final transcript = await whisperService.transcribeAudio(audioFile: sampleFile);
    debugPrint('[TEST-4] Transcripción Whisper obtenida: "$transcript"');
    expect(transcript, isNotNull);
    expect(transcript!.toLowerCase(), contains('mensaje'));

    // 5. Probar enriquecedor de medios en flujo de notificación
    final fakeNotification = NotificationObject.fromMap({
      'key': 'test_notification_key_real',
      'packageName': 'com.whatsapp',
      'postTime': DateTime.now().millisecondsSinceEpoch,
      'title': 'Negro Flex',
      'text': '🎤 Mensaje de voz (0:08)',
      'messageText': '🎤 Mensaje de voz (0:08)',
      'sender': 'Negro Flex',
      'isGroup': false,
    });

    final enrichment = await ConversationMediaEnricher.enrich(fakeNotification);
    debugPrint('[TEST-5] Notificación enriquecida: text="${enrichment.notification.text}"');
    expect(enrichment.notification.text, isNot(equals('🎤 Mensaje de voz (0:08)')));

    // 6. Probar compositor conversacional canónico con la notificación enriquecida
    final ctx = tester.element(find.byType(app.NanoPlatformApp).first);
    final container = ProviderScope.containerOf(ctx);
    final composer = container.read(canonicalConversationReplyComposerProvider);

    final draftResult = await composer.compose(enrichment.notification);
    debugPrint('[TEST-6] Respuesta compuesta: "${draftResult?.text}"');
    debugPrint('=== PRUEBA REAL EN DISPOSITIVO COMPLETADA CON EXITO ===');
  });
}
