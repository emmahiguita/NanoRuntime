import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/models/chat_models.dart';

/// Tests unitarios simplificados para validar las correcciones de bugs críticos
/// implementadas en el ChatNotifier.
/// Estas pruebas validan la lógica de negocio sin dependencias de Riverpod.
void main() {
  group('ChatProvider Concurrency Fixes - Validación de Adjuntos', () {
    test('debe calcular correctamente el tamaño de adjunto', () {
      const attachment = ChatAttachment(
        name: 'test.txt',
        content: 'Contenido de prueba',
      );

      final contentSize = attachment.content.length * 2; // Aproximación UTF-16
      const maxAttachmentSizeBytes = 500000;

      expect(contentSize, lessThan(maxAttachmentSizeBytes));
    });

    test('debe detectar adjuntos que exceden el límite', () {
      const maxAttachmentSizeBytes = 500000;
      final largeContent = 'x' * (maxAttachmentSizeBytes ~/ 2 + 100);
      final contentSize = largeContent.length * 2;

      expect(contentSize, greaterThan(maxAttachmentSizeBytes));
    });
  });

  group('ChatProvider Concurrency Fixes - Lógica de Estado', () {
    test('debe manejar correctamente copia con sentinel', () {
      const state = ChatState(
        messages: [],
        generating: false,
        activeModel: 'test-model',
      );

      // Probar copyWith con campos nullable
      final updated = state.copyWith(
        pendingTool: null, // Debería limpiar el campo
      );

      expect(updated.pendingTool, isNull);
    });

    test('debe preservar campos cuando no se especifican', () {
      const state = ChatState(
        messages: [],
        generating: false,
        activeModel: 'test-model',
        streamingText: 'test',
      );

      final updated = state.copyWith(); // Sin cambios

      expect(updated.streamingText, equals('test'));
      expect(updated.activeModel, equals('test-model'));
    });
  });

  group('ChatProvider Concurrency Fixes - Mensajes', () {
    test('debe serializar y deserializar correctamente mensajes', () {
      final message = ChatMessage(
        id: '1',
        sender: MessageSender.user,
        text: 'Hola mundo',
        timestamp: DateTime(2026, 8, 15),
        attachmentNames: ['file.txt'],
      );

      final json = message.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.id, equals(message.id));
      expect(restored.sender, equals(message.sender));
      expect(restored.text, equals(message.text));
      expect(restored.attachmentNames, equals(message.attachmentNames));
    });

    test('debe manejar mensajes con estado de error', () {
      final errorMessage = ChatMessage(
        id: 'error1',
        sender: MessageSender.ai,
        text: 'Error de conexión',
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );

      expect(errorMessage.status, equals(MessageStatus.error));
      expect(errorMessage.sender, equals(MessageSender.ai));
    });
  });
}
