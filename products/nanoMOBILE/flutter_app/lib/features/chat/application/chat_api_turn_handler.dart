import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/chat_models.dart';
import '../../../core/providers/api_provider_service_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api_provider_service.dart';
import 'chat_action_listener.dart';
import 'chat_stream_session.dart';

// QUÉ HACE:
// Gestiona el envío de turnos conversacionales hacia proveedores API externos (OpenAI, Claude, Gemini, etc.).
//
// CÓMO FUNCIONA:
// - Valida la existencia de API key en la configuración ApiProviderConfig.
// - Construye el historial reciente de hasta 24 turnos previos para preservar contexto.
// - Realiza la llamada asíncrona mediante ApiProviderChatService respetando temperatura y maxTokens.
// - Notifica a ChatActionListener con el mensaje generado o el error tipado correspondiente.
//
// POR QUÉ:
// Aplica principios SOLID (Single Responsibility Principle) desacoplando la integración API externa
// del caso de uso de inferencia local, manteniendo los archivos estrictamente bajo 160 líneas.
class ChatApiTurnHandler {
  const ChatApiTurnHandler();

  /// QUÉ HACE: Ejecuta la llamada hacia el proveedor de API configurado.
  /// CÓMO FUNCIONA: Mapea historial, adjuntos y genera la respuesta mediante el cliente HTTP de la API.
  /// POR QUÉ: Permite usar modelos potentes en la nube cuando el usuario no desea consumir RAM local.
  Future<void> execute({
    required Ref ref,
    required String prompt,
    required List<ChatMessage> Function() getMessages,
    required ApiProviderConfig apiSettings,
    required int generationId,
    required bool Function() isMounted,
    required ChatStreamSession streamSession,
    required ChatActionListener listener,
  }) async {
    if (!apiSettings.hasApiKey) {
      listener.onTurnError(
        'Agrega la clave de ${apiSettings.provider.label} en MCP & Skills > Tienda e Inyección.',
      );
      return;
    }

    final messages = getMessages();
    final previousMessages = messages.length > 1
        ? messages.sublist(0, messages.length - 1)
        : const <ChatMessage>[];

    final history = previousMessages
        .where((message) => message.text.trim().isNotEmpty)
        .toList(growable: false)
        .reversed
        .take(24)
        .toList(growable: false)
        .reversed
        .map((message) => {
              'role': message.sender == MessageSender.user ? 'user' : 'assistant',
              'content': message.text,
            })
        .toList(growable: false);

    final settings = ref.read(settingsProvider);
    final response = await ref.read(apiProviderChatServiceProvider).generate(
          prompt: prompt,
          history: history,
          temperature: settings.temperature,
          maxTokens: settings.maxTokens.clamp(32, 4096),
        );

    if (!streamSession.isGenerationCurrent(generationId, isMounted())) return;

    listener.onMessageAppended(
      ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: response,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
        source: MessageSource.model,
      ),
    );
  }
}
