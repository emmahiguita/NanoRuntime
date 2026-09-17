import 'dart:async';

import '../../browser/reverse_agent_client.dart';

/// Manejador de herramientas para IA en navegadores en segundo plano (SRP).
///
/// Permite que Nano ejecute consultas en segundo plano hacia Gemini, ChatGPT,
/// DeepSeek y Claude mediante `reverse-agent-bridge` de manera invisible (headless),
/// renderizando la respuesta completa directamente en la conversación de Nano.
class BrowserAgentToolHandler {
  final ReverseAgentClient _client;

  const BrowserAgentToolHandler({
    ReverseAgentClient client = const ReverseAgentClient(),
  }) : _client = client;

  /// Determina si el texto o comando `@` corresponde a un proveedor de navegador.
  bool matches(String text) {
    final lower = text.trim().toLowerCase();
    return lower.startsWith('@gemini') ||
        lower.startsWith('@gpt') ||
        lower.startsWith('@chatgpt') ||
        lower.startsWith('@deepseek') ||
        lower.startsWith('@claude') ||
        lower.startsWith('@browser_ai');
  }

  /// Ejecuta un comando determinista `@` hacia el navegador en segundo plano.
  Future<String> handleCommand(String rawCommand) async {
    final trimmed = rawCommand.trim();
    final firstSpace = trimmed.indexOf(' ');
    if (firstSpace == -1) {
      return 'Sintaxis:\n'
          '- `@gemini <pregunta o enlace>`\n'
          '- `@gpt <pregunta o enlace>`\n'
          '- `@deepseek <pregunta o enlace>`\n'
          '- `@claude <pregunta o enlace>`\n'
          '- `@browser_ai provider=<nombre> prompt=<texto>`';
    }

    final prefix = trimmed.substring(0, firstSpace).toLowerCase();
    final content = trimmed.substring(firstSpace + 1).trim();

    // Prompt vacío o marcador sin prompt real.
    if (content.isEmpty || content == '.') {
      return 'Sintaxis:\n'
          '- `@gemini <pregunta o enlace>`\n'
          '- `@gpt <pregunta o enlace>`\n'
          '- `@deepseek <pregunta o enlace>`\n'
          '- `@claude <pregunta o enlace>`\n'
          '- `@browser_ai provider=<nombre> prompt=<texto>`';
    }

    String provider = 'gemini';
    String prompt = content;
    bool headless = true;

    if (prefix == '@gemini') {
      provider = 'gemini';
    } else if (prefix == '@gpt' || prefix == '@chatgpt') {
      provider = 'chatgpt';
    } else if (prefix == '@deepseek') {
      provider = 'deepseek';
    } else if (prefix == '@claude') {
      provider = 'claude';
    } else if (prefix == '@browser_ai') {
      final parsed = _parseKeyValues(content);
      provider = parsed['provider'] ?? 'gemini';
      prompt = parsed['prompt'] ?? content;
      if (parsed.containsKey('headless')) {
        headless = parsed['headless'] != 'false';
      }
    }

    return executeQuery(provider: provider, prompt: prompt, headless: headless);
  }

  /// Ejecuta una consulta al puente y formatea la respuesta para el chat de Nano.
  Future<String> executeQuery({
    required String provider,
    required String prompt,
    bool headless = true,
  }) async {
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty) {
      return '[browser_ai:error] La consulta para $provider no puede estar vacía.';
    }

    final displayProvider = _displayName(provider);
    final result = await _client.query(
      provider: provider,
      prompt: cleanPrompt,
      headless: headless,
    );

    if (!result.ok) {
      return '### [$displayProvider (Segundo Plano)] - Error\n\n'
          '⚠️ ${result.error ?? "No se pudo obtener respuesta del navegador."}\n\n'
          '> Nota: Si el sitio requiere autenticación, inicia sesión una vez con:\n'
          '> `npm run dev -- login --provider config/providers/$provider.json`';
    }

    if (result.source == 'llm_local') {
      return '### [Motor Local Nano (Fallback Autónomo)]\n\n'
          '${result.response.trim()}\n\n'
          '---\n'
          '_Aviso de procedencia: El proveedor remoto solicitado ($displayProvider) no estaba activo en el puente (127.0.0.1:8800). La respuesta fue procesada localmente por el modelo del dispositivo._';
    }

    if (result.source == 'mobile_linux_bridge') {
      return '### [Subsistema Linux Local (Nano Mobile)]\n\n'
          '${result.response.trim()}\n\n'
          '---\n'
          '_Respuesta procesada en tu dispositivo vía subsistema Linux local_';
    }

    if (result.source == 'web_knowledge') {
      return '### [Conocimiento Web Público]\n\n'
          '${result.response.trim()}\n\n'
          '---\n'
          '_Respuesta obtenida de fuentes web públicas consultadas._';
    }

    final modeLabel = headless ? 'Modo silencioso / Headless' : 'Visible';
    return '### [$displayProvider ($modeLabel)]\n\n'
        '${result.response.trim()}\n\n'
        '---\n'
        '_Respuesta generada en tiempo real por tu navegador web_';
  }

  String _displayName(String provider) {
    switch (provider.toLowerCase()) {
      case 'gemini':
        return '♊ Google Gemini';
      case 'chatgpt':
        return '🟢 ChatGPT';
      case 'deepseek':
        return '🐋 DeepSeek';
      case 'claude':
        return '🧠 Anthropic Claude';
      default:
        return '🌐 ${provider.toUpperCase()}';
    }
  }

  Map<String, String> _parseKeyValues(String input) {
    final map = <String, String>{};
    final regex = RegExp(r'(\w+)=("[^"]*"|\S+)');
    for (final match in regex.allMatches(input)) {
      final key = match.group(1)!;
      var val = match.group(2)!;
      if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {
        val = val.substring(1, val.length - 1);
      }
      map[key] = val;
    }
    return map;
  }
}
