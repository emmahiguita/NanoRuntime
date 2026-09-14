import 'ai_provider.dart';

/// Enrutador Inteligente de Modelos y Proveedores (Clean Architecture).
///
/// Selecciona de forma transparente la mejor fuente de inteligencia disponible
/// (Local llama.cpp, Cloud API, Web PC Bridge o Android App Capabilities)
/// aislando el chat de la complejidad interna del transporte.
class IntelligenceRouter {
  IntelligenceRouter();

  final Map<String, IAiProvider> _providers = {};
  String? _preferredProviderName;

  void registerProvider(IAiProvider provider) {
    _providers[provider.name.toLowerCase()] = provider;
  }

  void setPreferredProvider(String providerName) {
    _preferredProviderName = providerName.toLowerCase();
  }

  List<IAiProvider> get registeredProviders =>
      List.unmodifiable(_providers.values);

  /// Resuelve el proveedor óptimo disponible para procesar una solicitud.
  Future<IAiProvider?> resolveActiveProvider() async {
    if (_preferredProviderName != null &&
        _providers.containsKey(_preferredProviderName)) {
      final preferred = _providers[_preferredProviderName]!;
      if (await preferred.isAvailable()) {
        return preferred;
      }
    }

    // Fallback: primer proveedor disponible
    for (final provider in _providers.values) {
      if (await provider.isAvailable()) {
        return provider;
      }
    }
    return null;
  }

  /// Ejecuta un prompt dirigiéndolo al proveedor activo.
  Future<AiProviderResponse> routePrompt(
    String prompt, {
    Map<String, dynamic> options = const {},
  }) async {
    final active = await resolveActiveProvider();
    if (active == null) {
      return const AiProviderResponse(
        text: '[Error] No hay un proveedor de inteligencia disponible.',
        providerName: 'IntelligenceRouter',
        kind: AiProviderKind.local,
      );
    }
    return active.sendPrompt(prompt, options: options);
  }

  /// Inicia streaming del prompt desde el proveedor activo.
  Stream<String> routeStream(
    String prompt, {
    Map<String, dynamic> options = const {},
  }) async* {
    final active = await resolveActiveProvider();
    if (active == null) {
      yield '[Error] No hay un proveedor de inteligencia disponible.';
      return;
    }
    yield* active.streamPrompt(prompt, options: options);
  }
}
