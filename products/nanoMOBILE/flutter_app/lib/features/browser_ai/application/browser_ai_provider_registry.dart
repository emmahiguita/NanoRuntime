// browser_ai_provider_registry.dart — Registro central de proveedores web de IA.
// QUÉ HACE: Administra catálogo inmutable de proveedores oficiales y dinámicos creados por el usuario.
// CÓMO FUNCIONA: Mantiene un mapa indexado por ID e incorpora Kimi, Qwen, ChatGPT, Gemini, Copilot, etc.
// POR QUÉ: Permite al usuario interactuar con cualquier IA web sin modificar el núcleo de Nano AI.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/browser_ai_custom_provider_model.dart';
import '../domain/browser_ai_provider.dart';
import '../infrastructure/browser_ai_preferences.dart';
import '../infrastructure/providers/chatgpt_provider.dart';
import '../infrastructure/providers/claude_provider.dart';
import '../infrastructure/providers/copilot_provider.dart';
import '../infrastructure/providers/custom_dynamic_provider.dart';
import '../infrastructure/providers/deepseek_provider.dart';
import '../infrastructure/providers/gemini_provider.dart';
import '../infrastructure/providers/kimi_provider.dart';
import '../infrastructure/providers/mistral_provider.dart';
import '../infrastructure/providers/perplexity_provider.dart';
import '../infrastructure/providers/qwen_provider.dart';

class BrowserAiProviderRegistry {
  final Map<String, BrowserAiProvider> _providers = {};

  BrowserAiProviderRegistry({List<BrowserAiProvider>? initialProviders}) {
    final list = initialProviders ??
        const [
          ChatGptProvider(),
          DeepSeekProvider(),
          GeminiProvider(),
          KimiProvider(),
          QwenProvider(),
          ClaudeProvider(),
          PerplexityProvider(),
          CopilotProvider(),
          MistralProvider(),
        ];
    for (final p in list) {
      _providers[p.id] = p;
    }
  }

  /// Retorna la lista inmutable de todos los proveedores registrados.
  List<BrowserAiProvider> get allProviders => List.unmodifiable(_providers.values);

  /// Registra o actualiza un proveedor.
  void register(BrowserAiProvider provider) {
    _providers[provider.id.trim().toLowerCase()] = provider;
  }

  /// Busca un proveedor por su ID.
  BrowserAiProvider? getProvider(String id) {
    return _providers[id.trim().toLowerCase()];
  }

  /// Identifica qué proveedor puede atender una URL específica.
  BrowserAiProvider? providerForUrl(Uri url) {
    for (final p in _providers.values) {
      if (p.canHandle(url)) return p;
    }
    return null;
  }

  /// Registra un proveedor dinámico creado por el usuario.
  void registerCustom(BrowserAiCustomProviderModel model) {
    final uri = Uri.tryParse(model.url);
    if (uri != null) {
      register(CustomDynamicProvider(
        customId: model.id,
        name: model.name,
        url: uri,
      ));
    }
  }
}

/// Provider global de Riverpod con carga inicial de proveedores personalizados.
final browserAiProviderRegistryProvider = Provider<BrowserAiProviderRegistry>((ref) {
  final registry = BrowserAiProviderRegistry();
  // Carga asíncrona no bloqueante de proveedores guardados en disco
  BrowserAiPreferences.loadCustomProviders().then((customs) {
    for (final c in customs) {
      registry.registerCustom(c);
    }
  });
  return registry;
});
