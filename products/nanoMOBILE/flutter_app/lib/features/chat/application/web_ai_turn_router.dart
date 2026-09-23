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
    r'^(?:(?:consulta|pregunta|busca|averigua|pide|dile|usa)(?:\s+(?:en|a|con))?\s+)?(chat\s*gpt|deep\s*seek|gemini|claude|mistral|le\s+chat|openai|ia|la\s+ia)(?:\s*[:,\-]\s*|\s+)(.+)$',
    caseSensitive: false,
  );

  /// Se mantiene público para poder probar el contrato lingüístico sin abrir
  /// una WebView ni fabricar un [BrowserAiGateway].
  static WebAiRouteRequest? parseRequest(String text) {
    final match = _regex.firstMatch(text.trim());
    if (match == null) return null;

    final prompt = match.group(2)!.trim();
    if (prompt.isEmpty) return null;
    return WebAiRouteRequest(
      providerId: _resolveProviderId(match.group(1)!.toLowerCase()),
      prompt: prompt,
    );
  }

  Future<ChatTurnRouteResult?> tryRoute({
    required String text,
    required BrowserAiGateway? gateway,
  }) async {
    final request = parseRequest(text);
    if (request == null || gateway == null) return null;

    final providerId = request.providerId;
    final prompt = request.prompt;

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
            text:
                '🔐 **Sesión requerida en ${providerId.toUpperCase()}**\n\n'
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
          text:
              '❌ **Error consultando ${providerId.toUpperCase()}**\n\n${aiResp.error}',
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
    final compact = raw.replaceAll(RegExp(r'\s+'), '');
    if (compact == 'openai' || compact == 'chatgpt') return 'chatgpt';
    if (compact == 'ia' || compact == 'laia') return 'deepseek';
    if (compact == 'deepseek') return 'deepseek';
    if (compact == 'lechat') return 'mistral';
    return compact;
  }
}

class WebAiRouteRequest {
  const WebAiRouteRequest({required this.providerId, required this.prompt});

  final String providerId;
  final String prompt;
}
