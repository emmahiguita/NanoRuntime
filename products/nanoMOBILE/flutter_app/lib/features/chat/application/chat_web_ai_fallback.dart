// chat_web_ai_fallback.dart — Enrutador inteligente hacia proveedores de IA web.
// QUÉ HACE: Detecta intenciones ("pregunta a ChatGPT", "usa Kimi") y enruta a la sesión web correspondiente.
// CÓMO FUNCIONA: Consulta al BrowserAiGateway con el proveedor detectado o el preferido por el usuario.
// POR QUÉ: Permite respuestas de alta inteligencia sin requerir GPU de escritorio ni saturar la RAM del teléfono.
library;

import 'package:nanoai/features/browser_ai/application/browser_ai_gateway.dart';
import 'package:nanoai/features/browser_ai/domain/browser_ai_query.dart';
import '../../../core/models/chat_models.dart';
import 'chat_action_listener.dart';

class ChatWebAiFallback {
  const ChatWebAiFallback();

  /// Detecta si el texto del usuario hace referencia a un proveedor web de IA específico.
  String _detectProvider(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('chatgpt') || lower.contains('chat gpt') || lower.contains('gpt-4')) {
      return 'chatgpt';
    }
    if (lower.contains('deepseek') || lower.contains('deep seek') || lower.contains('r1')) {
      return 'deepseek';
    }
    if (lower.contains('kimi') || lower.contains('moonshot')) {
      return 'kimi';
    }
    if (lower.contains('qwen') || lower.contains('tongyi')) {
      return 'qwen';
    }
    if (lower.contains('gemini')) {
      return 'gemini';
    }
    if (lower.contains('claude') || lower.contains('anthropic')) {
      return 'claude';
    }
    if (lower.contains('perplexity')) {
      return 'perplexity';
    }
    if (lower.contains('copilot')) {
      return 'copilot';
    }
    return 'auto';
  }

  /// QUÉ HACE: Ejecuta la consulta de contingencia o delegación hacia el gateway web en navegador.
  Future<void> handleFallback({
    required BrowserAiGateway gateway,
    required String text,
    required ChatActionListener listener,
    String? explicitProviderId,
  }) async {
    final providerId = explicitProviderId ?? _detectProvider(text);

    final aiResp = await gateway.query(
      BrowserAiQuery(
        providerId: providerId,
        prompt: text,
        timeout: const Duration(seconds: 45),
      ),
    );

    final pName = aiResp.providerId.toUpperCase();

    if (aiResp.isCompleted) {
      listener.onMessageAppended(ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: '✦ **$pName · Browser AI**\n\n${aiResp.content}',
        timestamp: DateTime.now(),
        suggestions: ['🌐 Ver sesión', '💬 Continuar', '✨ Probar otra IA'],
        status: MessageStatus.sent,
      ));
      return;
    }

    if (aiResp.needsUserAction) {
      listener.onMessageAppended(ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: '🔐 **Acción requerida en $pName:**\n\n${aiResp.error}\n\n'
            'Puedes iniciar sesión en la ventana flotante y luego volver aquí.',
        timestamp: DateTime.now(),
        suggestions: ['🌐 Ver pestaña $pName', '✦ IA Web', '🤖 Ir a Modelos'],
        status: MessageStatus.sent,
      ));
      return;
    }

    listener.onMessageAppended(ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: MessageSender.ai,
      text: 'Sin modelo local en RAM ni sesión web activa en $pName.\n'
          'Conecta tus cuentas en **Sesiones de IA Web** o carga un modelo local.',
      timestamp: DateTime.now(),
      suggestions: const ['✦ Sesiones de IA Web', '🤖 Ir a Modelos', '🌐 Abrir Navegador'],
      status: MessageStatus.sent,
    ));
  }
}
