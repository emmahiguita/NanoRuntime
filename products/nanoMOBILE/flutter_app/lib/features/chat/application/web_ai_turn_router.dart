import '../../browser_ai/application/browser_ai_gateway.dart';
import '../../browser_ai/domain/browser_ai_query.dart';
import '../../../core/models/chat_models.dart';
import '../domain/chat_turn_route_result.dart';

/// Enrutador para delegar consultas de lenguaje a chats web vía BrowserAiGateway.
///
/// QUÉ HACE:
/// Detecta peticiones como "consulta en deepseek...", "pregunta a chatgpt...",
/// ejecuta la consulta en la sesión web real del navegador y devuelve la respuesta.
///
/// CÓMO FUNCIONA:
/// Extrae el proveedor y el prompt mediante expresiones regulares e interactúa
/// con [BrowserAiGateway] sin secuestrar ni recargar la pestaña del usuario.
///
/// POR QUÉ:
/// Permite al usuario usar sus suscripciones y sesiones web (ChatGPT Plus,
/// DeepSeek, Claude, Gemini) como cerebro para Nano AI sin pagar APIs externas.
class WebAiTurnRouter {
  const WebAiTurnRouter();

  static final _regex = RegExp(
    r'^(?:(?:consulta|pregunta|busca|averigua|pide|dile|usa)(?:\s+(?:en|a|con))?\s+)?(chatgpt|deepseek|gemini|claude|mistral|openai|ia|la ia)\s*[:,\-]?\s*(.+)$',
    caseSensitive: false,
  );

  Future<ChatTurnRouteResult?> tryRoute({
    required String text,
    required BrowserAiGateway? gateway,
  }) async {
    final clean = text.trim();
    final match = _regex.firstMatch(clean);
    if (match == null || gateway == null) return null;

    final rawProvider = match.group(1)!.toLowerCase();
    final prompt = match.group(2)!.trim();
    if (prompt.isEmpty) return null;

    final providerId = _resolveProviderId(rawProvider);

    try {
      final query = BrowserAiQuery(
        providerId: providerId,
        prompt: prompt,
        timeout: const Duration(seconds: 40),
      );
      final aiResp = await gateway.query(query);

      if (aiResp.isCompleted) {
        final title = providerId.toUpperCase();
        return ChatTurnRouteResult.completed(
          ChatMessage(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            sender: MessageSender.ai,
            text: '### 🧠 Respuesta de $title (Web Real):\n\n${aiResp.content}',
            timestamp: DateTime.now(),
            status: MessageStatus.sent,
          ),
        );
      }

      if (aiResp.needsUserAction) {
        // Gateway ya enfocó la pestaña → solo informar al usuario
        return ChatTurnRouteResult.completed(
          ChatMessage(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            sender: MessageSender.ai,
            text: '🔐 **Sesión requerida en ${providerId.toUpperCase()}**\n\n'
                '${aiResp.error}\n\n'
                'La pestaña ya está abierta. Inicia sesión y **reenvía tu mensaje**.',
            timestamp: DateTime.now(),
            suggestions: const ['🌐 Ver pestaña', '🤖 Ir a Modelos'],
            status: MessageStatus.sent,
          ),
        );
      }

      return ChatTurnRouteResult.completed(
        ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: '❌ **Error consultando ${providerId.toUpperCase()}**\n\n${aiResp.error}',
          timestamp: DateTime.now(),
          status: MessageStatus.error,
        ),
      );
    } catch (e) {
      return ChatTurnRouteResult.completed(
        ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: '❌ Error inesperado conectando con Browser AI Gateway: $e',
          timestamp: DateTime.now(),
          status: MessageStatus.error,
        ),
      );
    }
  }

  static String _resolveProviderId(String raw) {
    if (raw == 'openai') return 'chatgpt';
    if (raw == 'ia' || raw == 'la ia') return 'deepseek';
    return raw;
  }
}
