// nano_action_port_adapter.dart — Adaptador inteligente para NanoActionPort.
// QUÉ: Conecta NanoActionPort con las herramientas reales de AgentToolDispatcher.
// CÓMO: Si el comando empieza con '@', lo despacha directo. Si es una intención
//       natural (leer pantalla, enviar WhatsApp, tocar, navegar, etc.), lo mapea
//       a la herramienta determinista precisa y verificada del agente.
// POR QUÉ: SOLID (DIP/SRP) — el controlador flotante no conoce el motor de automatización.
//          Evita alucinaciones y reintentos ciegos; respeta la política de gobernanza.
import 'nano_ai_models.dart';
import '../../automation/engine/execution/agent_tool_dispatcher.dart';

class NanoActionPortAdapter implements NanoActionPort {
  const NanoActionPortAdapter(this._dispatcher);

  final AgentToolDispatcher _dispatcher;

  @override
  Future<String> executeAuthorizedGoal(String goal) async {
    final clean = goal.trim();
    if (clean.isEmpty) return 'Objetivo vacío.';

    try {
      // 1. Comando directo (@pantalla, @whatsapp, @tap, etc.)
      if (clean.startsWith('@')) {
        return await _dispatcher.runCommand(clean);
      }

      final lower = clean.toLowerCase();

      // 2. Comprensión y lectura de pantalla
      if (lower.contains('leer') || lower.contains('pantalla') || lower.contains('analizar pantalla')) {
        return await _dispatcher.runCommand('@leer_pantalla');
      }

      // 3. WhatsApp: enviar o abrir chat
      if (lower.contains('whatsapp') || lower.contains('mensaje')) {
        return await _handleWhatsAppIntent(clean);
      }

      // 4. Navegación global (atrás, inicio, recientes)
      if (lower == 'atrás' || lower == 'volver' || lower == 'back') {
        return await _dispatcher.runCommand('@back');
      }
      if (lower == 'inicio' || lower == 'home') {
        return await _dispatcher.runCommand('@home');
      }
      if (lower == 'recientes' || lower == 'apps abiertas') {
        return await _dispatcher.runCommand('@recents');
      }

      // 5. Tocar o hacer clic en un elemento
      if (lower.startsWith('toca ') || lower.startsWith('pulsa ') || lower.startsWith('click ')) {
        final target = clean.substring(clean.indexOf(' ') + 1).trim();
        return await _dispatcher.runCommand('@tap text="$target"');
      }

      // 6. Escribir texto
      if (lower.startsWith('escribe ') || lower.startsWith('escribir ')) {
        final content = clean.substring(clean.indexOf(' ') + 1).trim();
        return await _dispatcher.runCommand('@escribir $content | editable=true');
      }

      // 7. Abrir aplicación
      if (lower.startsWith('abre ') || lower.startsWith('abrir ')) {
        final app = clean.substring(clean.indexOf(' ') + 1).trim();
        return await _dispatcher.runCommand('@abrir $app');
      }

      // Fallback: intentar resolver la pantalla para contextualizar
      return await _dispatcher.runCommand('@pantalla');
    } catch (e) {
      return 'Error al ejecutar acción: $e';
    }
  }

  Future<String> _handleWhatsAppIntent(String text) async {
    // Patrón: "envía a [contacto] que [mensaje]" o "mensaje a [contacto]: [mensaje]"
    final match = RegExp(
      r'(?:enviar|manda|mensaje|whatsapp)\s+(?:a\s+)?([a-zA-Z0-9\s]+?)(?:\s+(?:que|diciendo|:)\s+(.+))?$',
      caseSensitive: false,
    ).firstMatch(text);

    if (match != null) {
      final contact = match.group(1)?.trim() ?? '';
      final message = match.group(2)?.trim() ?? '';
      if (contact.isNotEmpty && message.isNotEmpty) {
        return await _dispatcher.runCommand('@whatsapp $contact $message');
      }
    }
    return await _dispatcher.runCommand('@whatsapp $text');
  }
}
