import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_provider_service.dart';
import 'llm_engine_client.dart';

abstract interface class GenerativeInferencePort {
  String get providerId;
  bool get isConfigured;
  Future<String?> generate({
    required String prompt,
    double temperature = 0.3,
    int maxTokens = 320,
  });
}

extension GenerativeInferencePortSynergy on GenerativeInferencePort {
  bool shouldUseCloudForTurn({required String messageText}) {
    final self = this;
    return self is CloudGenerativeInferenceAdapter
        ? self.prefersCloudForTurn(messageText: messageText)
        : isConfigured;
  }
}

enum CloudAiVendor { groq, cloudflare, openRouter, gemini }

enum CloudSynergyMode { localOnly, hybridAssist, cloudFirst }

/// Usa las mismas credenciales del Hub; cada solicitud cierra sus conexiones.
final class CloudGenerativeInferenceAdapter implements GenerativeInferencePort {
  static const _storage = FlutterSecureStorage();
  static final _store = ApiProviderSettingsStore.shared;
  static CloudSynergyMode currentMode = CloudSynergyMode.hybridAssist;
  static List<ApiProviderConfig> _configured = [];
  static Future<void>? _loading;
  static int _rotation = 0;
  String _providerId = 'cloud';

  CloudGenerativeInferenceAdapter();

  /// Una carga compartida mientras está en vuelo; los cambios del Hub se releen.
  static Future<void> ensureLoaded() => _loading ??= _load()
      .catchError((Object _) {
        _configured = [];
      })
      .whenComplete(() => _loading = null);
  static Future<void> _load() async {
    final mode = await _storage.read(key: 'nano_cloud_synergy_mode');
    currentMode =
        CloudSynergyMode.values.asNameMap()[mode] ??
        CloudSynergyMode.hybridAssist;
    final selected = await _store.load();
    final providers = <ApiProviderKind>{
      if (selected.provider != ApiProviderKind.local) selected.provider,
      ApiProviderKind.groq,
      ApiProviderKind.gemini,
      ...ApiProviderKind.values.where((p) => p != ApiProviderKind.local),
    };
    final available = <ApiProviderConfig>[];
    for (final provider in providers) {
      final config = await _store.loadForProvider(provider);
      if (config.hasApiKey && config.model.isNotEmpty) available.add(config);
    }
    _configured = available;
  }

  static Future<void> saveMode(CloudSynergyMode mode) async {
    await _storage.write(key: 'nano_cloud_synergy_mode', value: mode.name);
    currentMode = mode;
  }

  @override
  String get providerId => _providerId;
  @override
  bool get isConfigured =>
      currentMode != CloudSynergyMode.localOnly && _configured.isNotEmpty;

  bool prefersCloudForTurn({required String messageText}) {
    if (!isConfigured) return false;
    if (currentMode == CloudSynergyMode.cloudFirst) return true;
    final clean = messageText.trim();
    return clean.length >= 95 ||
        RegExp(r'\?').allMatches(clean).length >= 2 ||
        clean.contains(' · ') ||
        RegExp(r'[.!?]\s+\S').allMatches(clean).length >= 2;
  }

  @override
  Future<String?> generate({
    required String prompt,
    double temperature = 0.3,
    int maxTokens = 320,
  }) async {
    await ensureLoaded();
    if (!isConfigured) return null;
    final configured = List<ApiProviderConfig>.of(_configured);
    final clock = Stopwatch()..start();
    // Dos intentos como máximo y 12 segundos totales antes del respaldo local.
    for (var attempt = 0; attempt < 2; attempt++) {
      final remaining = const Duration(seconds: 12) - clock.elapsed;
      if (remaining <= Duration.zero) break;
      final config = configured[attempt % configured.length];
      final keys = await _store.readApiKeys(config.provider);
      if (keys.isEmpty) continue;
      final key = keys[(_rotation + attempt) % keys.length];
      final service = ApiProviderChatService(
        store: _store,
        requestTimeout: remaining < const Duration(seconds: 6)
            ? remaining
            : const Duration(seconds: 6),
      );
      try {
        final result = await service.generate(
          prompt: _sanitize(prompt),
          temperature: temperature,
          maxTokens: maxTokens,
          configOverride: config,
          apiKeyOverride: key,
        );
        _providerId = 'cloud_${config.provider.name}';
        _rotation++;
        return result;
      } on ApiProviderException {
        // El llamador conserva el respaldo local; no se inventa una respuesta.
      } finally {
        service.close();
      }
    }
    _rotation++;
    return null;
  }

  static String _sanitize(String input) => input
      .replaceAll(
        RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
        '[email]',
      )
      .replaceAll(RegExp(r'\b(?:\d[ -]*?){13,19}\b'), '[tarjeta]')
      .replaceAll(
        RegExp(
          r'(clave|contrase[ñn]a|password|pin)[:\s]+\S+',
          caseSensitive: false,
        ),
        '[credencial oculta]',
      );
}

final class LocalLlamaInferenceAdapter implements GenerativeInferencePort {
  final LLMEngineClient client;
  final String? sessionId;
  const LocalLlamaInferenceAdapter({required this.client, this.sessionId});
  @override
  String get providerId => 'local_llama_cpp';
  @override
  bool get isConfigured => true;
  @override
  Future<String?> generate({
    required String prompt,
    double temperature = 0.3,
    int maxTokens = 320,
  }) async => (await client.generate(
    prompt: prompt,
    temperature: temperature,
    maxTokens: maxTokens,
    sessionId: sessionId,
  )).text;
}
