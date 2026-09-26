// chat_web_ai_fallback.dart — Manejador de fallback hacia proveedores de IA web.
// QUÉ HACE: Consulta al BrowserAiGateway cuando no hay un modelo GGUF local activo en RAM.
// CÓMO FUNCIONA: Intenta sesión web iniciada en DeepSeek/ChatGPT; si requiere login notifica con sugerencias.
// POR QUÉ: Permite responder al usuario sin crash ni bloqueo si el dispositivo no tiene modelo cargado.
library;

import 'package:nanoai/features/browser_ai/application/browser_ai_gateway.dart';
import 'package:nanoai/features/browser_ai/domain/browser_ai_query.dart';
import '../../../core/models/chat_models.dart';
import 'chat_action_listener.dart';

class ChatWebAiFallback {
  const ChatWebAiFallback();

  // QUÉ HACE: Ejecuta la consulta de contingencia hacia el gateway web en navegador integrado.
  Future<void> handleFallback({
    required BrowserAiGateway gateway,
    required String text,
    required ChatActionListener listener,
  }) async {
    final aiResp = await gateway.query(
      BrowserAiQuery(
        providerId: 'deepseek',
        prompt: text,
        timeout: const Duration(seconds: 45),
      ),
    );

    if (aiResp.isCompleted) {
      listener.onMessageAppended(ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: '🧠 **DeepSeek vía Nano Browser:**\n\n${aiResp.content}',
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      ));
      return;
    }

    if (aiResp.needsUserAction) {
      listener.onMessageAppended(ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: '🔐 **Acción requerida:**\n\n${aiResp.error}\n\n'
            'Después de iniciar sesión, **vuelve aquí y envía tu mensaje de nuevo**.',
        timestamp: DateTime.now(),
        suggestions: const ['🌐 Ver pestaña DeepSeek', '🤖 Ir a Modelos'],
        status: MessageStatus.sent,
      ));
      return;
    }

    listener.onMessageAppended(ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: MessageSender.ai,
      text: 'Sin modelo local ni sesión web activa. Selecciona un modelo o inicia sesión en el navegador.',
      timestamp: DateTime.now(),
      suggestions: const ['🤖 Ir a Modelos', '🌐 Abrir Navegador'],
      status: MessageStatus.sent,
    ));
  }
}
