import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/domain/whatsapp_media_payload.dart';
import 'package:nanoai/features/automation/engine/web_bridge/whatsapp_media_dispatcher.dart';
import 'package:nanoai/features/automation/engine/web_bridge/whatsapp_web_bridge_controller.dart';
import 'package:nanoai/features/automation/engine/web_bridge/whatsapp_web_js_bridge.dart';

void main() {
  group('WhatsApp Multi-Device Media Bridge Tests', () {
    test('WhatsAppMediaPayload construye y preserva atributos de imagen', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final payload = WhatsAppMediaPayload(
        bytes: bytes,
        mimeType: 'image/jpeg',
        caption: 'Foto de prueba',
        fileName: 'test.jpg',
        type: WhatsAppMediaType.image,
      );

      expect(payload.type, equals(WhatsAppMediaType.image));
      expect(payload.mimeType, equals('image/jpeg'));
      expect(payload.caption, equals('Foto de prueba'));
      expect(payload.fileName, equals('test.jpg'));
      expect(payload.bytes, isNotNull);
    });

    test('WhatsAppMediaPayload copyWith modifica atributos inmutablemente', () {
      const payload = WhatsAppMediaPayload(
        filePath: '/tmp/video.mp4',
        mimeType: 'video/mp4',
        fileName: 'video.mp4',
        type: WhatsAppMediaType.video,
      );

      final updated = payload.copyWith(caption: 'Video explicativo');
      expect(updated.caption, equals('Video explicativo'));
      expect(updated.filePath, equals('/tmp/video.mp4'));
      expect(payload.caption, isNull);
    });

    test('WhatsAppWebJsBridge genera script JS con escape de comillas en caption', () {
      final script = WhatsAppWebJsBridge.buildSendMediaScript(
        base64Data: 'AQIDBA==',
        mimeType: 'image/png',
        fileName: 'photo.png',
        caption: "Foto del día: 'Nano'",
      );

      expect(script, contains("atob('AQIDBA==')"));
      expect(script, contains("'image/png'"));
      expect(script, contains("'photo.png'"));
      expect(script, contains(r"Foto del día: \'Nano\'"));
    });

    test('WhatsAppWebBridgeController reporta desconectado por defecto', () {
      final controller = WhatsAppWebBridgeController();
      expect(controller.currentSession.status, equals(WhatsAppWebSessionStatus.disconnected));
      expect(controller.currentSession.isConnected, isFalse);
    });

    test('WhatsAppMediaDispatcher canSendMedia false cuando sesión no está conectada', () {
      final controller = WhatsAppWebBridgeController();
      final dispatcher = WhatsAppMediaDispatcher(bridge: controller);
      expect(dispatcher.canSendMedia, isFalse);
    });
  });
}
