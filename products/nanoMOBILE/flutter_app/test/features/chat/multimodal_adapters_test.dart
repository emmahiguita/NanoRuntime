import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/chat/domain/camera_capture_backend.dart';
import 'package:nanoai/features/chat/domain/chat_vision_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidCameraCaptureBackend', () {
    const channel = MethodChannel('test/media_capture');

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('mapea una captura nativa real', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'capturePhoto');
            return {
              'path': '/cache/photo.jpg',
              'name': 'photo.jpg',
              'sizeBytes': 321,
            };
          });

      final photo = await const AndroidCameraCaptureBackend(
        channel: channel,
      ).capturePhoto();

      expect(photo?.path, '/cache/photo.jpg');
      expect(photo?.sizeBytes, 321);
    });

    test('cancelar la cámara no inventa un archivo', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);

      final photo = await const AndroidCameraCaptureBackend(
        channel: channel,
      ).capturePhoto();

      expect(photo, isNull);
    });
  });

  group('MlKitChatVisionAdapter', () {
    late Directory tempDir;
    late File image;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nano-vision-test-');
      image = await File('${tempDir.path}/photo.jpg').writeAsBytes([1, 2, 3]);
    });

    tearDown(() async => tempDir.delete(recursive: true));

    test('solo convierte etiquetas reales con confianza suficiente', () async {
      final adapter = MlKitChatVisionAdapter(
        labelImage: (_) async => [
          {'label': 'Cat', 'confidence': 0.91},
          {'label': 'Noise', 'confidence': 0.12},
        ],
      );

      final description = await adapter.describe(image.path);

      expect(description, contains('Cat (91%)'));
      expect(description, isNot(contains('Noise')));
      expect(description, contains('no son OCR'));
    });

    test('rechaza imágenes grandes antes de cargarlas', () async {
      var invoked = false;
      final adapter = MlKitChatVisionAdapter(
        maxBytes: 2,
        labelImage: (_) async {
          invoked = true;
          return const [];
        },
      );

      expect(await adapter.describe(image.path), isNull);
      expect(invoked, isFalse);
    });
  });
}
