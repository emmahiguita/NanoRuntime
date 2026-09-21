import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/browser_ai_provider.dart';
import '../infrastructure/providers/chatgpt_provider.dart';
import '../infrastructure/providers/claude_provider.dart';
import '../infrastructure/providers/deepseek_provider.dart';
import '../infrastructure/providers/gemini_provider.dart';
import '../infrastructure/providers/mistral_provider.dart';

/// QUÉ HACE:
/// Registro y catálogo central de proveedores web de IA.
///
/// CÓMO FUNCIONA:
/// Mantiene un mapa en memoria de [BrowserAiProvider] indexado por su ID,
/// permitiendo registrar dinámicamente nuevos modelos o consultar por URL.
///
/// POR QUÉ:
/// Cumple con Inversión de Dependencias (DIP) y Responsabilidad Única (SRP).
class BrowserAiProviderRegistry {
  final Map<String, BrowserAiProvider> _providers = {};

  BrowserAiProviderRegistry({List<BrowserAiProvider>? initialProviders}) {
    final list = initialProviders ??
        const [
          ChatGptProvider(),
          GeminiProvider(),
          ClaudeProvider(),
          DeepSeekProvider(),
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
    _providers[provider.id] = provider;
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
}

/// Provider global de Riverpod para el registro de proveedores Browser AI.
final browserAiProviderRegistryProvider = Provider<BrowserAiProviderRegistry>((ref) {
  return BrowserAiProviderRegistry();
});
