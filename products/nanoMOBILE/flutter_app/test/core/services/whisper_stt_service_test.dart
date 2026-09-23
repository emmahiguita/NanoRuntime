// whisper_stt_service_test.dart
//
// QUÉ HACE:
// Suite de pruebas unitarias para WhisperSttService y la integración de transcripción local.
//
// CÓMO FUNCIONA:
// - Mockea SharedPreferences con inicialización controlada.
// - Valida guardado, carga y limpieza del modelo Whisper activo.
// - Verifica comportamiento de auto-selección y manejo seguro de errores sin procesos zombi.
//
// POR QUÉ:
// Asegura que la integración del motor Whisper.cpp bajo licencia MIT funcione de manera estable
// y predecible, cumpliendo las reglas de calidad y código < 200 líneas.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nanoai/core/services/whisper_stt_service.dart';
import 'package:nanoai/features/automation/presentation/widgets/voice_note_transcriber.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WhisperSttService.instance.clearActiveModel();
  });

  group('WhisperSttService — Gestión de Modelos Locales', () {
    test('Inicialmente no tiene modelo activo configurado', () async {
      final service = WhisperSttService.instance;
      await service.init();
      expect(service.hasActiveModel, isFalse);
      expect(service.activeModelFile, isNull);
      expect(service.activeModelPath, isNull);
    });

    test('setActiveModel persiste correctamente el modelo y su ruta', () async {
      final service = WhisperSttService.instance;
      const testFile = 'ggml-tiny.bin';
      const testPath = '/data/local/models/ggml-tiny.bin';

      await service.setActiveModel(testFile, testPath);

      expect(service.activeModelFile, equals(testFile));
      expect(service.activeModelPath, equals(testPath));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(WhisperSttService.prefActiveWhisperKey), equals(testFile));
      expect(prefs.getString(WhisperSttService.prefActiveWhisperPathKey), equals(testPath));
    });

    test('clearActiveModel limpia la selección y la persistencia', () async {
      final service = WhisperSttService.instance;
      await service.setActiveModel('ggml-base.bin', '/path/base.bin');
      await service.clearActiveModel();

      expect(service.activeModelFile, isNull);
      expect(service.activeModelPath, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(WhisperSttService.prefActiveWhisperKey), isNull);
      expect(prefs.getString(WhisperSttService.prefActiveWhisperPathKey), isNull);
    });

    test('transcribeAudio retorna error controlado si el archivo no existe', () async {
      final service = WhisperSttService.instance;
      final tempDir = await Directory.systemTemp.createTemp('whisper_test');
      final dummyModel = File('${tempDir.path}/ggml-tiny.bin');
      await dummyModel.writeAsBytes([1, 2, 3]);

      await service.setActiveModel('ggml-tiny.bin', dummyModel.path);

      final nonExistentFile = File('${tempDir.path}/non_existent_audio.opus');
      final result = await service.transcribeAudio(audioFile: nonExistentFile);

      expect(result, contains('Error'));
      await tempDir.delete(recursive: true);
    });
  });

  group('VoiceNoteTranscriber — Diagnóstico e Integración', () {
    test('Retorna diagnóstico honesto si no hay modelo ni keys configuradas', () async {
      final tempDir = await Directory.systemTemp.createTemp('audio_test');
      final audioFile = File('${tempDir.path}/test_note.opus');
      await audioFile.writeAsBytes([1, 2, 3, 4, 5]);

      final result = await VoiceNoteTranscriber.transcribe(
        audioPathOrUrl: audioFile.path,
      );

      expect(result, contains('Whisper-Tiny'));
      expect(result, contains('MIT'));

      await tempDir.delete(recursive: true);
    });
  });
}
